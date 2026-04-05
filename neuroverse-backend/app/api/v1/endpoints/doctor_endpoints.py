# app/api/v1/endpoints/doctors.py
# ============================================================
# DOCTOR API ENDPOINTS
# ============================================================

from fastapi import APIRouter, Depends, HTTPException, status, Query, UploadFile, File
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, or_, desc
from typing import Optional, List
from datetime import datetime, timedelta
import os, uuid, json as _json
from app.services.email_service import EmailService
from app.core.config import settings

from app.db.database import get_db
from app.core.security import (
    verify_password, 
    get_password_hash, 
    create_access_token, 
    create_refresh_token,
    get_current_doctor,
    generate_otp,
    verify_otp
)
from app.models.doctor_model import Doctor, ClinicalNote, PatientAccess, DatasetRequest, DoctorStatus
from app.models.user import User
from app.models.test_session import TestSession
from app.models.test_result import TestResult
from app.models.report import Report
from app.schemas.doctor_schemas import (
    DoctorLogin,
    DoctorLoginResponse,
    DoctorProfile,
    DoctorProfileUpdate,
    DoctorDashboard,
    PatientSummary,
    PendingDiagnostic,
    TestCategoryCount,
    MonthlyPatientFlow,
    WeeklyVisit,
    RiskDistribution,
    PatientListRequest,
    PatientListResponse,
    PatientDetailResponse,
    TestSessionSummary,
    ClinicalNoteCreate,
    ClinicalNoteUpdate,
    ClinicalNoteSummary,
    ClinicalNoteResponse,
    ClinicalNotesListResponse,
    ExportReportRequest,
    ExportReportResponse,
    DatasetRequestCreate,
    DatasetRequestResponse,
    DatasetRequestListResponse,
    AlertItem,
    AlertsResponse,
    DoctorForgotPassword,
    DoctorResetPassword
)


router = APIRouter(prefix="/doctors", tags=["Doctors"])

import logging
logger = logging.getLogger(__name__)

# ==================== TEST ENDPOINT ====================

@router.get("/ping")
async def ping():
    """Simple test endpoint."""
    return {"status": "ok", "message": "Doctor endpoint working"}

# ==================== AUTHENTICATION ====================

@router.post("/login", response_model=DoctorLoginResponse)
async def doctor_login(
    credentials: DoctorLogin,
    db: AsyncSession = Depends(get_db)
):
    """
    Doctor login endpoint.
    Returns JWT tokens on successful authentication.
    """
    try:
        logger.info(f"Login attempt for: {credentials.email}")
        
        # Find doctor by email
        result = await db.execute(
            select(Doctor).where(Doctor.email == credentials.email.lower())
        )
        doctor = result.scalar_one_or_none()
        
        if not doctor:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )
        
        # Verify password
        if not verify_password(credentials.password, doctor.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )
        
        # Check doctor status
        if doctor.status == DoctorStatus.SUSPENDED:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Your account has been suspended. Please contact admin."
            )
        
        if doctor.status == DoctorStatus.PENDING_VERIFICATION:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Your account is pending verification. Please wait for admin approval."
            )
        
        if doctor.status == DoctorStatus.INACTIVE:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Your account is inactive. Please contact admin."
            )
        
        # Update last login
        doctor.last_login_at = datetime.utcnow()
        await db.commit()
        
        # Generate tokens
        access_token = create_access_token(
            data={"sub": str(doctor.id), "type": "doctor", "email": doctor.email}
        )
        refresh_token = create_refresh_token(
            data={"sub": str(doctor.id), "type": "doctor"}
        )
        
        logger.info(f"Login successful for: {credentials.email}")
        
        return DoctorLoginResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            doctor=DoctorProfile.model_validate(doctor)
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Login error for {credentials.email}: {str(e)}")
        import traceback
        logger.error(traceback.format_exc())
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal server error: {str(e)}"
        )


@router.post("/forgot-password")
async def doctor_forgot_password(
    request: DoctorForgotPassword,
    db: AsyncSession = Depends(get_db)
):
    """Send OTP to doctor's email for password reset."""
    result = await db.execute(
        select(Doctor).where(Doctor.email == request.email.lower())
    )
    doctor = result.scalar_one_or_none()
    
    if not doctor:
        # Don't reveal if email exists
        return {"success": True, "message": "If the email exists, an OTP has been sent"}
    
    # Generate and save OTP
    otp = generate_otp()
    doctor.otp_code = otp
    doctor.otp_expires_at = datetime.utcnow() + timedelta(minutes=10)
    await db.commit()
    
    # Send OTP email
    email_service = EmailService()
    await email_service.send_otp_email(doctor.email, otp, "Doctor Portal Password Reset")
    
    return {"success": True, "message": "OTP sent to your email"}


@router.post("/reset-password")
async def doctor_reset_password(
    request: DoctorResetPassword,
    db: AsyncSession = Depends(get_db)
):
    """Reset doctor password using OTP."""
    result = await db.execute(
        select(Doctor).where(Doctor.email == request.email.lower())
    )
    doctor = result.scalar_one_or_none()
    
    if not doctor:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid request"
        )
    
    # Verify OTP
    if not verify_otp(doctor.otp_code, doctor.otp_expires_at, request.otp):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired OTP"
        )
    
    # Update password
    doctor.password_hash = get_password_hash(request.new_password)
    doctor.otp_code = None
    doctor.otp_expires_at = None
    await db.commit()
    
    return {"success": True, "message": "Password reset successfully"}


# ==================== PROFILE ====================

@router.get("/me", response_model=DoctorProfile)
async def get_doctor_profile(
    current_doctor: Doctor = Depends(get_current_doctor)
):
    """Get current doctor's profile."""
    return DoctorProfile.model_validate(current_doctor)


@router.patch("/me", response_model=DoctorProfile)
async def update_doctor_profile(
    updates: DoctorProfileUpdate,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db)
):
    """Update doctor's profile."""
    update_data = updates.model_dump(exclude_unset=True)
    
    for field, value in update_data.items():
        setattr(current_doctor, field, value)
    
    current_doctor.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(current_doctor)
    
    return DoctorProfile.model_validate(current_doctor)


# ==================== DASHBOARD ====================

@router.get("/dashboard", response_model=DoctorDashboard)
async def get_doctor_dashboard(
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db)
):
    """Get doctor's dashboard with statistics and recent activity."""
    
    # Total patients count
    total_patients_result = await db.execute(select(func.count(User.id)))
    total_patients = total_patients_result.scalar() or 0
    
    # Pending reviews (completed sessions without doctor notes)
    pending_result = await db.execute(
        select(func.count(TestSession.id))
        .where(
            and_(
                TestSession.status == "completed",
                TestSession.completed_at >= datetime.utcnow() - timedelta(days=7)
            )
        )
    )
    pending_reviews = pending_result.scalar() or 0
    
    # Reports today
    today_start = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    reports_today_result = await db.execute(
        select(func.count(TestSession.id))
        .where(
            and_(
                TestSession.status == "completed",
                TestSession.completed_at >= today_start
            )
        )
    )
    reports_today = reports_today_result.scalar() or 0
    
    # Critical alerts (high risk patients)
    critical_result = await db.execute(
        select(func.count(User.id))
        .where(
            or_(
                User.ad_risk_score >= 70,
                User.pd_risk_score >= 70
            )
        )
    )
    critical_alerts = critical_result.scalar() or 0
    
    # Recent patients (deduplicated, ordered by latest test)
    recent_patients_result = await db.execute(
        select(User)
        .where(
            User.id.in_(
                select(TestSession.user_id)
                .where(TestSession.status == "completed")
                .group_by(TestSession.user_id)
                .order_by(func.max(TestSession.completed_at).desc())
                .limit(5)
            )
        )
    )
    recent_users = recent_patients_result.scalars().all()
    
    recent_patients = []
    for user in recent_users:
        risk_level = "Low"
        max_risk = max(user.ad_risk_score or 0, user.pd_risk_score or 0)
        if max_risk >= 70:
            risk_level = "High"
        elif max_risk >= 40:
            risk_level = "Moderate"
        
        recent_patients.append(PatientSummary(
            id=user.id,
            name=f"{user.first_name} {user.last_name}",
            age=_calculate_age(user.date_of_birth) if user.date_of_birth else 0,
            gender=user.gender,
            risk_level=risk_level,
            ad_risk_score=user.ad_risk_score or 0,
            pd_risk_score=user.pd_risk_score or 0,
            last_test_date=None,
            last_test_category=None
        ))
    
    # Pending diagnostics
    pending_diag_result = await db.execute(
        select(TestSession, User)
        .join(User, User.id == TestSession.user_id)
        .where(TestSession.status == "completed")
        .order_by(desc(TestSession.completed_at))
        .limit(5)
    )
    pending_rows = pending_diag_result.all()
    
    pending_diagnostics = [
        PendingDiagnostic(
            id=session.id,
            patient_id=user.id,
            patient_name=f"{user.first_name} {user.last_name}",
            test_category=session.category,
            test_name=session.category or "Unknown",
            completed_at=session.completed_at,
            status="awaiting_review"
        )
        for session, user in pending_rows
    ]
    
    # ── Build analytics charts ──
    total_tests, tests_by_category, monthly_flow, weekly, risk_dist = \
        await _build_dashboard_analytics(db)

    return DoctorDashboard(
        doctor_name=f"Dr. {current_doctor.first_name} {current_doctor.last_name}",
        specialization=current_doctor.specialization.value if hasattr(current_doctor.specialization, 'value') else str(current_doctor.specialization or ''),
        total_patients=total_patients,
        pending_reviews=pending_reviews,
        reports_today=reports_today,
        critical_alerts=critical_alerts,
        tests_completed=total_tests,
        recent_patients=recent_patients,
        pending_diagnostics=pending_diagnostics,
        tests_by_category=tests_by_category,
        monthly_patient_flow=monthly_flow,
        weekly_visits=weekly,
        risk_distribution=risk_dist,
    )


# ── Analytics helpers (called after the basic dashboard data) ──

async def _build_dashboard_analytics(db: AsyncSession):
    """Build chart analytics data from real DB."""
    from calendar import month_abbr

    # ── Tests by category ──
    CATEGORY_COLORS = {
        "cognitive": "#C6E94B",
        "speech": "#6366F1",
        "motor": "#A855F7",
        "facial": "#EC4899",
    }
    cat_rows = (await db.execute(
        select(TestSession.category, func.count(TestSession.id))
        .where(TestSession.status == "completed")
        .group_by(TestSession.category)
    )).all()
    tests_by_category = [
        TestCategoryCount(
            category=cat.title() if cat else "Other",
            count=cnt,
            color=CATEGORY_COLORS.get(cat, "#22D3EE"),
        )
        for cat, cnt in cat_rows
    ]
    total_tests = sum(c.count for c in tests_by_category)

    # ── Monthly patient flow (last 8 months) ──
    monthly_flow = []
    now = datetime.utcnow()
    for i in range(7, -1, -1):
        dt = now - timedelta(days=30 * i)
        m_start = dt.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        if m_start.month == 12:
            m_end = m_start.replace(year=m_start.year + 1, month=1)
        else:
            m_end = m_start.replace(month=m_start.month + 1)

        new_q = await db.execute(
            select(func.count(User.id)).where(
                and_(User.created_at >= m_start, User.created_at < m_end)
            )
        )
        completed_q = await db.execute(
            select(func.count(TestSession.id)).where(
                and_(
                    TestSession.status == "completed",
                    TestSession.completed_at >= m_start,
                    TestSession.completed_at < m_end,
                )
            )
        )
        monthly_flow.append(MonthlyPatientFlow(
            month=month_abbr[m_start.month],
            new_patients=new_q.scalar() or 0,
            discharged=completed_q.scalar() or 0,
        ))

    # ── Weekly visits (last 7 days) ──
    DAY_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    weekly = []
    for i in range(6, -1, -1):
        day = (now - timedelta(days=i)).replace(hour=0, minute=0, second=0, microsecond=0)
        day_end = day + timedelta(days=1)
        cnt_q = await db.execute(
            select(func.count(TestSession.id)).where(
                and_(TestSession.completed_at >= day, TestSession.completed_at < day_end)
            )
        )
        weekly.append(WeeklyVisit(
            day=DAY_NAMES[day.weekday()],
            visits=cnt_q.scalar() or 0,
        ))

    # ── Risk distribution ──
    risk_dist = []
    for label, lo, hi in [("Low", 0, 40), ("Moderate", 40, 70), ("High", 70, 101)]:
        cnt_q = await db.execute(
            select(func.count(User.id)).where(
                and_(
                    func.greatest(User.ad_risk_score, User.pd_risk_score) >= lo,
                    func.greatest(User.ad_risk_score, User.pd_risk_score) < hi,
                )
            )
        )
        risk_dist.append(RiskDistribution(level=label, count=cnt_q.scalar() or 0))

    return total_tests, tests_by_category, monthly_flow, weekly, risk_dist


# ==================== PATIENTS ====================

@router.get("/patients", response_model=PatientListResponse)
async def list_patients(
    search: Optional[str] = None,
    risk_level: Optional[str] = None,
    age_min: Optional[int] = None,
    age_max: Optional[int] = None,
    sort_by: str = "last_test_date",
    sort_order: str = "desc",
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db)
):
    """List all patients with filtering and pagination."""
    
    if not current_doctor.can_view_patients:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to view patients"
        )
    
    query = select(User)
    
    # Search filter
    if search:
        search_term = f"%{search}%"
        query = query.where(
            or_(
                User.first_name.ilike(search_term),
                User.last_name.ilike(search_term),
                User.email.ilike(search_term)
            )
        )
    
    # Risk level filter
    if risk_level:
        if risk_level.lower() == "high":
            query = query.where(or_(User.ad_risk_score >= 70, User.pd_risk_score >= 70))
        elif risk_level.lower() == "moderate":
            query = query.where(
                and_(
                    User.ad_risk_score.between(40, 69),
                    User.pd_risk_score.between(40, 69)
                )
            )
        elif risk_level.lower() == "low":
            query = query.where(
                and_(
                    User.ad_risk_score < 40,
                    User.pd_risk_score < 40
                )
            )
    
    # Sorting
    if sort_by == "risk_score":
        order_col = User.ad_risk_score
    elif sort_by == "name":
        order_col = User.first_name
    else:
        order_col = User.updated_at
    
    if sort_order == "desc":
        query = query.order_by(desc(order_col))
    else:
        query = query.order_by(order_col)
    
    # Count total
    count_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = count_result.scalar() or 0
    
    # Pagination
    offset = (page - 1) * limit
    query = query.offset(offset).limit(limit)
    
    result = await db.execute(query)
    users = result.scalars().all()
    
    patients = []
    for user in users:
        risk_level_str = "Low"
        max_risk = max(user.ad_risk_score or 0, user.pd_risk_score or 0)
        if max_risk >= 70:
            risk_level_str = "High"
        elif max_risk >= 40:
            risk_level_str = "Moderate"
        
        patients.append(PatientSummary(
            id=user.id,
            name=f"{user.first_name} {user.last_name}",
            age=_calculate_age(user.date_of_birth) if user.date_of_birth else 0,
            gender=user.gender,
            risk_level=risk_level_str,
            ad_risk_score=user.ad_risk_score or 0,
            pd_risk_score=user.pd_risk_score or 0,
            last_test_date=user.updated_at,
            last_test_category=None
        ))
    
    # Compute global risk counts (unfiltered)
    high_q = select(func.count(User.id)).where(or_(User.ad_risk_score >= 70, User.pd_risk_score >= 70))
    mod_q = select(func.count(User.id)).where(
        and_(User.ad_risk_score.between(40, 69), User.pd_risk_score.between(40, 69))
    )
    low_q = select(func.count(User.id)).where(
        and_(User.ad_risk_score < 40, User.pd_risk_score < 40)
    )
    high_risk_count = (await db.execute(high_q)).scalar() or 0
    moderate_risk_count = (await db.execute(mod_q)).scalar() or 0
    low_risk_count = (await db.execute(low_q)).scalar() or 0

    # Log access
    current_doctor.total_patients_viewed += len(patients)
    await db.commit()
    
    return PatientListResponse(
        patients=patients,
        total=total,
        page=page,
        limit=limit,
        total_pages=(total + limit - 1) // limit,
        high_risk_count=high_risk_count,
        moderate_risk_count=moderate_risk_count,
        low_risk_count=low_risk_count
    )


@router.get("/patients/{patient_id}", response_model=PatientDetailResponse)
async def get_patient_detail(
    patient_id: int,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db)
):
    """Get detailed patient information including test history."""
    
    if not current_doctor.can_view_patients:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to view patients"
        )
    
    # Get patient
    result = await db.execute(select(User).where(User.id == patient_id))
    patient = result.scalar_one_or_none()
    
    if not patient:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Patient not found"
        )
    
    # Get test sessions with their results
    sessions_result = await db.execute(
        select(TestSession, TestResult)
        .outerjoin(TestResult, TestResult.session_id == TestSession.id)
        .where(TestSession.user_id == patient_id)
        .order_by(desc(TestSession.created_at))
    )
    session_rows = sessions_result.all()
    
    test_sessions = []
    sessions_only = []
    for s, r in session_rows:
        sessions_only.append(s)
        test_sessions.append(
            TestSessionSummary(
                id=s.id,
                category=s.category,
                status=s.status,
                started_at=s.started_at,
                completed_at=s.completed_at,
                ad_risk_contribution=r.ad_risk_score if r else None,
                pd_risk_contribution=r.pd_risk_score if r else None,
                category_score=r.category_score if r else None,
            )
        )
    
    # Get clinical notes for this patient
    notes_result = await db.execute(
        select(ClinicalNote, Doctor)
        .join(Doctor, Doctor.id == ClinicalNote.doctor_id)
        .where(ClinicalNote.patient_id == patient_id)
        .order_by(desc(ClinicalNote.created_at))
    )
    notes_rows = notes_result.all()
    
    clinical_notes = [
        ClinicalNoteSummary(
            id=note.id,
            doctor_id=note.doctor_id,
            doctor_name=f"Dr. {doctor.first_name} {doctor.last_name}",
            patient_id=note.patient_id,
            patient_name=f"{patient.first_name} {patient.last_name}",
            title=note.title,
            content=note.content,
            note_type=note.note_type,
            is_private=note.is_private,
            is_flagged=note.is_flagged,
            created_at=note.created_at,
            updated_at=note.updated_at
        )
        for note, doctor in notes_rows
        if not note.is_private or note.doctor_id == current_doctor.id
    ]
    
    # Log access
    access_log = PatientAccess(
        doctor_id=current_doctor.id,
        patient_id=patient_id,
        access_type="view"
    )
    db.add(access_log)
    await db.commit()
    
    return PatientDetailResponse(
        id=patient.id,
        first_name=patient.first_name,
        last_name=patient.last_name,
        email=patient.email,
        phone=patient.phone,
        date_of_birth=str(patient.date_of_birth) if patient.date_of_birth else None,
        gender=patient.gender,
        ad_risk_score=patient.ad_risk_score or 0,
        pd_risk_score=patient.pd_risk_score or 0,
        cognitive_score=patient.cognitive_score,
        speech_score=patient.speech_score,
        motor_score=patient.motor_score,
        gait_score=patient.gait_score,
        facial_score=patient.facial_score,
        ad_stage=patient.ad_stage,
        pd_stage=patient.pd_stage,
        total_tests_completed=len([s for s in sessions_only if s.status == "completed"]),
        test_sessions=test_sessions,
        clinical_notes=clinical_notes,
        member_since=patient.created_at,
        last_active=patient.updated_at
    )


# ==================== CLINICAL NOTES ====================

@router.post("/notes", response_model=ClinicalNoteResponse)
async def create_clinical_note(
    note_data: ClinicalNoteCreate,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db)
):
    """Create a clinical note for a patient."""
    
    if not current_doctor.can_add_notes:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to add clinical notes"
        )
    
    # Verify patient exists
    result = await db.execute(select(User).where(User.id == note_data.patient_id))
    patient = result.scalar_one_or_none()
    
    if not patient:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Patient not found"
        )
    
    # Create note
    note = ClinicalNote(
        doctor_id=current_doctor.id,
        patient_id=note_data.patient_id,
        title=note_data.title,
        content=note_data.content,
        note_type=note_data.note_type.value,
        related_session_id=note_data.related_session_id,
        related_report_id=note_data.related_report_id,
        is_private=note_data.is_private,
        is_flagged=note_data.is_flagged
    )
    
    db.add(note)
    current_doctor.total_notes_created += 1
    await db.commit()
    await db.refresh(note)
    
    return ClinicalNoteResponse(
        note=ClinicalNoteSummary(
            id=note.id,
            doctor_id=note.doctor_id,
            doctor_name=f"Dr. {current_doctor.first_name} {current_doctor.last_name}",
            patient_id=note.patient_id,
            patient_name=f"{patient.first_name} {patient.last_name}",
            title=note.title,
            content=note.content,
            note_type=note.note_type,
            is_private=note.is_private,
            is_flagged=note.is_flagged,
            created_at=note.created_at,
            updated_at=note.updated_at
        )
    )


@router.get("/notes", response_model=ClinicalNotesListResponse)
async def list_clinical_notes(
    patient_id: Optional[int] = None,
    note_type: Optional[str] = None,
    flagged_only: bool = False,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db)
):
    """List clinical notes with filtering."""
    
    query = (
        select(ClinicalNote, Doctor, User)
        .join(Doctor, Doctor.id == ClinicalNote.doctor_id)
        .join(User, User.id == ClinicalNote.patient_id)
    )
    
    # Only show own private notes, all public notes
    query = query.where(
        or_(
            ClinicalNote.is_private == False,
            ClinicalNote.doctor_id == current_doctor.id
        )
    )
    
    if patient_id:
        query = query.where(ClinicalNote.patient_id == patient_id)
    
    if note_type:
        query = query.where(ClinicalNote.note_type == note_type)
    
    if flagged_only:
        query = query.where(ClinicalNote.is_flagged == True)
    
    query = query.order_by(desc(ClinicalNote.created_at))
    
    # Count
    count_query = select(func.count(ClinicalNote.id)).where(
        or_(
            ClinicalNote.is_private == False,
            ClinicalNote.doctor_id == current_doctor.id
        )
    )
    if patient_id:
        count_query = count_query.where(ClinicalNote.patient_id == patient_id)
    
    count_result = await db.execute(count_query)
    total = count_result.scalar() or 0
    
    # Pagination
    offset = (page - 1) * limit
    query = query.offset(offset).limit(limit)
    
    result = await db.execute(query)
    notes_rows = result.all()
    
    notes = [
        ClinicalNoteSummary(
            id=note.id,
            doctor_id=note.doctor_id,
            doctor_name=f"Dr. {doctor.first_name} {doctor.last_name}",
            patient_id=note.patient_id,
            patient_name=f"{patient.first_name} {patient.last_name}",
            title=note.title,
            content=note.content,
            note_type=note.note_type,
            is_private=note.is_private,
            is_flagged=note.is_flagged,
            created_at=note.created_at,
            updated_at=note.updated_at
        )
        for note, doctor, patient in notes_rows
    ]
    
    return ClinicalNotesListResponse(
        notes=notes,
        total=total,
        page=page,
        limit=limit
    )


@router.patch("/notes/{note_id}", response_model=ClinicalNoteResponse)
async def update_clinical_note(
    note_id: int,
    updates: ClinicalNoteUpdate,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db)
):
    """Update a clinical note (only own notes)."""
    
    result = await db.execute(
        select(ClinicalNote).where(ClinicalNote.id == note_id)
    )
    note = result.scalar_one_or_none()
    
    if not note:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Note not found"
        )
    
    if note.doctor_id != current_doctor.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only edit your own notes"
        )
    
    update_data = updates.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if field == "note_type" and value:
            value = value.value
        setattr(note, field, value)
    
    note.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(note)
    
    # Get patient name
    patient_result = await db.execute(select(User).where(User.id == note.patient_id))
    patient_user = patient_result.scalar_one_or_none()
    patient_name = f"{patient_user.first_name} {patient_user.last_name}" if patient_user else None
    
    return ClinicalNoteResponse(
        note=ClinicalNoteSummary(
            id=note.id,
            doctor_id=note.doctor_id,
            doctor_name=f"Dr. {current_doctor.first_name} {current_doctor.last_name}",
            patient_id=note.patient_id,
            patient_name=patient_name,
            title=note.title,
            content=note.content,
            note_type=note.note_type,
            is_private=note.is_private,
            is_flagged=note.is_flagged,
            created_at=note.created_at,
            updated_at=note.updated_at
        )
    )


@router.delete("/notes/{note_id}")
async def delete_clinical_note(
    note_id: int,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db)
):
    """Delete a clinical note (only own notes)."""
    
    result = await db.execute(
        select(ClinicalNote).where(ClinicalNote.id == note_id)
    )
    note = result.scalar_one_or_none()
    
    if not note:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Note not found"
        )
    
    if note.doctor_id != current_doctor.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only delete your own notes"
        )
    
    await db.delete(note)
    await db.commit()
    
    return {"success": True, "message": "Note deleted successfully"}


# ==================== ALERTS ====================

@router.get("/alerts", response_model=AlertsResponse)
async def get_alerts(
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db)
):
    """Get doctor's alerts and notifications."""
    
    alerts = []
    
    # High risk patients (recent)
    high_risk_result = await db.execute(
        select(User)
        .where(
            and_(
                or_(User.ad_risk_score >= 70, User.pd_risk_score >= 70),
                User.updated_at >= datetime.utcnow() - timedelta(days=7)
            )
        )
        .order_by(desc(User.updated_at))
        .limit(5)
    )
    high_risk_patients = high_risk_result.scalars().all()
    
    for patient in high_risk_patients:
        alerts.append(AlertItem(
            id=f"high_risk_{patient.id}",
            type="high_risk",
            title="High Risk Patient",
            message=f"{patient.first_name} {patient.last_name} has elevated risk scores",
            patient_id=patient.id,
            patient_name=f"{patient.first_name} {patient.last_name}",
            severity="critical" if max(patient.ad_risk_score or 0, patient.pd_risk_score or 0) >= 80 else "warning",
            is_read=False,
            created_at=patient.updated_at or datetime.utcnow()
        ))
    
    # Recent completed tests
    recent_tests_result = await db.execute(
        select(TestSession, User)
        .join(User, User.id == TestSession.user_id)
        .where(
            and_(
                TestSession.status == "completed",
                TestSession.completed_at >= datetime.utcnow() - timedelta(hours=24)
            )
        )
        .order_by(desc(TestSession.completed_at))
        .limit(5)
    )
    recent_tests = recent_tests_result.all()
    
    for session, user in recent_tests:
        alerts.append(AlertItem(
            id=f"new_test_{session.id}",
            type="new_test",
            title="New Test Completed",
            message=f"{user.first_name} {user.last_name} completed {session.category} test",
            patient_id=user.id,
            patient_name=f"{user.first_name} {user.last_name}",
            severity="info",
            is_read=False,
            created_at=session.completed_at or datetime.utcnow()
        ))
    
    return AlertsResponse(
        alerts=alerts,
        unread_count=len(alerts)
    )


@router.post("/alerts/{alert_id}/read")
async def mark_alert_read(
    alert_id: str,
    current_doctor: Doctor = Depends(get_current_doctor),
):
    """Mark an alert as read. Alerts are ephemeral so this is a no-op acknowledgement."""
    return {"success": True, "alert_id": alert_id, "is_read": True}


# ==================== DATASET REQUESTS ====================

@router.post("/dataset-requests", response_model=DatasetRequestResponse)
async def create_dataset_request(
    request_data: DatasetRequestCreate,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db)
):
    """Request anonymized dataset for research."""
    
    if not current_doctor.can_request_dataset:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to request datasets. Please contact admin."
        )
    
    import json
    
    dataset_request = DatasetRequest(
        doctor_id=current_doctor.id,
        purpose=request_data.purpose,
        research_title=request_data.research_title,
        institution=request_data.institution,
        data_types=json.dumps(request_data.data_types),
        date_range_start=request_data.date_range_start,
        date_range_end=request_data.date_range_end,
        min_samples=request_data.min_samples
    )
    
    db.add(dataset_request)
    await db.commit()
    await db.refresh(dataset_request)
    
    return DatasetRequestResponse(
        id=dataset_request.id,
        doctor_id=dataset_request.doctor_id,
        purpose=dataset_request.purpose,
        research_title=dataset_request.research_title,
        institution=dataset_request.institution,
        data_types=request_data.data_types,
        status=dataset_request.status,
        created_at=dataset_request.created_at
    )


@router.get("/dataset-requests", response_model=DatasetRequestListResponse)
async def list_dataset_requests(
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db)
):
    """List doctor's dataset requests."""
    
    result = await db.execute(
        select(DatasetRequest)
        .where(DatasetRequest.doctor_id == current_doctor.id)
        .order_by(desc(DatasetRequest.created_at))
    )
    requests = result.scalars().all()
    
    import json
    
    return DatasetRequestListResponse(
        requests=[
            DatasetRequestResponse(
                id=r.id,
                doctor_id=r.doctor_id,
                purpose=r.purpose,
                research_title=r.research_title,
                institution=r.institution,
                data_types=json.loads(r.data_types) if r.data_types else [],
                status=r.status,
                reviewed_by=r.reviewed_by,
                reviewed_at=r.reviewed_at,
                rejection_reason=r.rejection_reason,
                samples_included=r.samples_included,
                dataset_path=r.dataset_path,
                created_at=r.created_at
            )
            for r in requests
        ],
        total=len(requests)
    )


# ==================== REPORTS ====================

@router.get("/reports/exports")
async def list_reports(
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
    patient_id: Optional[int] = Query(None),
    report_type: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
):
    """List all reports (from Report table) visible to the doctor."""
    query = select(Report, User).join(User, Report.user_id == User.id)

    if patient_id:
        query = query.where(Report.user_id == patient_id)
    if report_type:
        query = query.where(Report.report_type == report_type)

    count_q = select(func.count()).select_from(Report)
    total = (await db.execute(count_q)).scalar() or 0

    query = query.order_by(desc(Report.created_at)).offset((page - 1) * limit).limit(limit)
    rows = (await db.execute(query)).all()

    reports = []
    for report, user in rows:
        reports.append({
            "id": str(report.id),
            "patient_name": f"{user.first_name or ''} {user.last_name or ''}".strip() or user.email,
            "patient_id": user.id,
            "report_type": report.report_type or "comprehensive",
            "title": report.title or "Assessment Report",
            "ad_risk": round(report.ad_risk_score or 0),
            "pd_risk": round(report.pd_risk_score or 0),
            "cognitive_score": report.cognitive_score,
            "speech_score": report.speech_score,
            "motor_score": report.motor_score,
            "gait_score": report.gait_score,
            "facial_score": report.facial_score,
            "ad_stage": report.ad_stage,
            "pd_stage": report.pd_stage,
            "tests_count": report.tests_count or 0,
            "generated_at": report.created_at.isoformat() if report.created_at else None,
            "status": "ready" if report.is_ready else "processing",
            "has_pdf": bool(report.pdf_path),
        })

    return {"reports": reports, "total": total, "page": page, "limit": limit}


@router.post("/reports/generate")
async def generate_report_pdf(
    body: ExportReportRequest,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    Generate a comprehensive PDF report with full XAI visualizations.

    Includes: risk summary, category breakdowns, SHAP charts, GradCAM overlays
    on patient drawings, cognitive radar, LIME, integrated gradients,
    counterfactual analysis, fusion breakdown, doctor notes, and recommendations.
    """
    from app.services.report_pdf_generator import generate_comprehensive_report

    # Get the patient
    patient = await db.get(User, body.patient_id)
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")

    # Gather completed sessions
    sess_q = (
        select(TestSession)
        .where(TestSession.user_id == body.patient_id, TestSession.status == "completed")
        .order_by(desc(TestSession.completed_at))
    )
    sessions = list((await db.execute(sess_q)).scalars().all())

    # Gather latest test result per category (with XAI + features)
    results_q = (
        select(TestResult, TestSession.category)
        .join(TestSession, TestResult.session_id == TestSession.id)
        .where(TestSession.user_id == body.patient_id)
        .order_by(desc(TestResult.created_at))
    )
    result_rows = (await db.execute(results_q)).all()

    # Build per-category data: latest result wins
    test_results: dict = {}
    category_scores: dict = {}
    for result, category in result_rows:
        if category not in test_results:
            test_results[category] = {
                "ad_risk_score": result.ad_risk_score or 0,
                "pd_risk_score": result.pd_risk_score or 0,
                "category_score": result.category_score or 0,
                "stage": result.stage,
                "severity": result.severity,
                "extracted_features": result.extracted_features or {},
                "xai_explanation": result.xai_explanation or {},
            }
            category_scores[category] = round(result.category_score or 0, 1)

    # Overall risk from user record (fused scores)
    ad_risk = round(patient.ad_risk_score or 0, 1)
    pd_risk = round(patient.pd_risk_score or 0, 1)

    def _stage(score):
        if score >= 75: return "Severe"
        if score >= 50: return "Moderate"
        if score >= 25: return "Mild"
        return "Normal"

    ad_stage = patient.ad_stage or _stage(ad_risk)
    pd_stage = patient.pd_stage or _stage(pd_risk)

    # Generate comprehensive PDF
    filepath, filename = generate_comprehensive_report(
        patient=patient,
        doctor=current_doctor,
        sessions=sessions,
        test_results=test_results,
        report_type=body.report_type,
        doctor_notes=body.doctor_notes or "",
        ad_risk=ad_risk,
        pd_risk=pd_risk,
        ad_stage=ad_stage,
        pd_stage=pd_stage,
        category_scores=category_scores,
    )

    patient_name = f"{patient.first_name or ''} {patient.last_name or ''}".strip() or patient.email

    # Create Report record
    new_report = Report(
        user_id=patient.id,
        title=f"{body.report_type.replace('_', ' ').title()} Report",
        report_type=body.report_type,
        sessions_included=[s.id for s in sessions[:20]],
        tests_count=len(sessions),
        ad_risk_score=ad_risk,
        pd_risk_score=pd_risk,
        cognitive_score=category_scores.get("cognitive"),
        speech_score=category_scores.get("speech"),
        motor_score=category_scores.get("motor"),
        gait_score=category_scores.get("gait"),
        facial_score=category_scores.get("facial"),
        ad_stage=ad_stage,
        pd_stage=pd_stage,
        doctor_notes=body.doctor_notes,
        pdf_path=f"reports/{filename}",
        is_ready=True,
    )
    db.add(new_report)
    current_doctor.total_reports_exported = (current_doctor.total_reports_exported or 0) + 1
    await db.commit()
    await db.refresh(new_report)

    return {
        "success": True,
        "report_id": new_report.id,
        "download_url": f"/uploads/reports/{filename}",
        "patient_name": patient_name,
    }


@router.get("/reports/{report_id}/download")
async def download_report(
    report_id: int,
    token: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
):
    """Download a generated PDF report. Accepts token query param for direct links."""
    from jose import jwt as _jwt, JWTError as _JWTError
    # Resolve doctor from query-param token
    if not token:
        raise HTTPException(status_code=401, detail="Token required")
    try:
        payload = _jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        doctor_id = payload.get("sub")
        if not doctor_id or payload.get("type") != "doctor":
            raise HTTPException(status_code=401, detail="Invalid token")
    except _JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
    doctor = await db.get(Doctor, int(doctor_id))
    if not doctor:
        raise HTTPException(status_code=401, detail="Doctor not found")

    report = await db.get(Report, report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Report not found")
    if not report.pdf_path:
        raise HTTPException(status_code=404, detail="PDF not yet generated")
    filepath = os.path.join(settings.UPLOAD_DIR, report.pdf_path)
    if not os.path.exists(filepath):
        raise HTTPException(status_code=404, detail="PDF file missing")
    return FileResponse(filepath, media_type="application/pdf", filename=os.path.basename(filepath))


# ==================== SEND REPORT TO PATIENT ====================

@router.post("/patients/{patient_id}/send-report")
async def send_report_to_patient(
    patient_id: int,
    body: dict,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """
    Generate and send a report to a specific patient.
    The report will appear in the patient's Reports screen.

    Body: { "report_type": "comprehensive", "doctor_notes": "...", "title": "..." }
    """
    from app.services.report_pdf_generator import generate_comprehensive_report

    if not current_doctor.can_view_patients:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You don't have permission to manage patients"
        )

    # Get the patient
    patient = await db.get(User, patient_id)
    if not patient:
        raise HTTPException(status_code=404, detail="Patient not found")

    report_type = body.get("report_type", "comprehensive")
    doctor_notes = body.get("doctor_notes", "")
    custom_title = body.get("title", "")

    # Gather completed sessions
    sess_q = (
        select(TestSession)
        .where(TestSession.user_id == patient_id, TestSession.status == "completed")
        .order_by(desc(TestSession.completed_at))
    )
    sessions = list((await db.execute(sess_q)).scalars().all())

    # Gather latest test result per category
    results_q = (
        select(TestResult, TestSession.category)
        .join(TestSession, TestResult.session_id == TestSession.id)
        .where(TestSession.user_id == patient_id)
        .order_by(desc(TestResult.created_at))
    )
    result_rows = (await db.execute(results_q)).all()

    test_results: dict = {}
    category_scores: dict = {}
    for result, category in result_rows:
        if category not in test_results:
            test_results[category] = {
                "ad_risk_score": result.ad_risk_score or 0,
                "pd_risk_score": result.pd_risk_score or 0,
                "category_score": result.category_score or 0,
                "stage": result.stage,
                "severity": result.severity,
                "extracted_features": result.extracted_features or {},
                "xai_explanation": result.xai_explanation or {},
            }
            category_scores[category] = round(result.category_score or 0, 1)

    ad_risk = round(patient.ad_risk_score or 0, 1)
    pd_risk = round(patient.pd_risk_score or 0, 1)

    def _stage(score):
        if score >= 75: return "Severe"
        if score >= 50: return "Moderate"
        if score >= 25: return "Mild"
        return "Normal"

    ad_stage = patient.ad_stage or _stage(ad_risk)
    pd_stage = patient.pd_stage or _stage(pd_risk)

    # Generate PDF
    filepath, filename = generate_comprehensive_report(
        patient=patient,
        doctor=current_doctor,
        sessions=sessions,
        test_results=test_results,
        report_type=report_type,
        doctor_notes=doctor_notes,
        ad_risk=ad_risk,
        pd_risk=pd_risk,
        ad_stage=ad_stage,
        pd_stage=pd_stage,
        category_scores=category_scores,
    )

    patient_name = f"{patient.first_name or ''} {patient.last_name or ''}".strip() or patient.email
    title = custom_title or f"{report_type.replace('_', ' ').title()} Report"

    # Create Report record linked to patient
    new_report = Report(
        user_id=patient.id,
        title=title,
        report_type=report_type,
        sessions_included=[s.id for s in sessions[:20]],
        tests_count=len(sessions),
        ad_risk_score=ad_risk,
        pd_risk_score=pd_risk,
        cognitive_score=category_scores.get("cognitive"),
        speech_score=category_scores.get("speech"),
        motor_score=category_scores.get("motor"),
        gait_score=category_scores.get("gait"),
        facial_score=category_scores.get("facial"),
        ad_stage=ad_stage,
        pd_stage=pd_stage,
        doctor_notes=doctor_notes,
        pdf_path=f"reports/{filename}",
        is_ready=True,
    )
    db.add(new_report)
    current_doctor.total_reports_exported = (current_doctor.total_reports_exported or 0) + 1
    await db.flush()
    await db.refresh(new_report)

    # Create notification for the patient
    from app.models.notification import Notification as NotifModel
    doctor_name = f"Dr. {current_doctor.first_name or ''} {current_doctor.last_name or ''}".strip()
    notif = NotifModel(
        user_id=patient.id,
        title="New Report Available",
        message=f"{doctor_name} has sent you a {report_type.replace('_', ' ')} report: {title}",
        notification_type="report_ready",
        action_type="view_report",
        action_id=new_report.id,
    )
    db.add(notif)

    return {
        "success": True,
        "report_id": new_report.id,
        "patient_name": patient_name,
        "title": title,
        "download_url": f"/uploads/reports/{filename}",
        "message": f"Report sent to {patient_name}",
    }


# ==================== AVATAR UPLOAD ====================

@router.post("/me/avatar")
async def upload_avatar(
    file: UploadFile = File(...),
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """Upload doctor profile avatar image."""
    allowed = {"image/jpeg", "image/png", "image/webp", "image/jpg"}
    if file.content_type not in allowed:
        raise HTTPException(status_code=400, detail="Only JPEG, PNG, or WebP images are allowed")
    content = await file.read()
    if len(content) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large (max 10 MB)")

    os.makedirs(os.path.join(settings.UPLOAD_DIR, "avatars"), exist_ok=True)
    ext = file.filename.rsplit(".", 1)[-1] if "." in (file.filename or "") else "png"
    filename = f"doc_{current_doctor.id}_{uuid.uuid4().hex[:8]}.{ext}"
    filepath = os.path.join(settings.UPLOAD_DIR, "avatars", filename)

    # Delete old avatar if exists
    if current_doctor.profile_image_path:
        old_path = os.path.join(settings.UPLOAD_DIR, current_doctor.profile_image_path)
        if os.path.exists(old_path):
            os.remove(old_path)

    with open(filepath, "wb") as f:
        f.write(content)

    current_doctor.profile_image_path = f"avatars/{filename}"
    current_doctor.updated_at = datetime.utcnow()
    await db.commit()

    return {"success": True, "image_url": f"/uploads/avatars/{filename}"}


@router.delete("/me/avatar")
async def remove_avatar(
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """Remove doctor profile avatar."""
    if current_doctor.profile_image_path:
        old_path = os.path.join(settings.UPLOAD_DIR, current_doctor.profile_image_path)
        if os.path.exists(old_path):
            os.remove(old_path)
        current_doctor.profile_image_path = None
        current_doctor.updated_at = datetime.utcnow()
        await db.commit()
    return {"success": True}


# ==================== PASSWORD CHANGE ====================

@router.post("/me/change-password")
async def change_password(
    body: dict,
    current_doctor: Doctor = Depends(get_current_doctor),
    db: AsyncSession = Depends(get_db),
):
    """Change doctor's password."""
    current_pw = body.get("current_password", "")
    new_pw = body.get("new_password", "")
    if not current_pw or not new_pw:
        raise HTTPException(status_code=400, detail="Both current and new password are required")
    if len(new_pw) < 6:
        raise HTTPException(status_code=400, detail="New password must be at least 6 characters")
    if not verify_password(current_pw, current_doctor.password_hash):
        raise HTTPException(status_code=400, detail="Current password is incorrect")
    current_doctor.password_hash = get_password_hash(new_pw)
    current_doctor.updated_at = datetime.utcnow()
    await db.commit()
    return {"success": True, "message": "Password changed successfully"}


# ==================== HELPERS ====================

def _calculate_age(date_of_birth) -> int:
    """Calculate age from date of birth."""
    if not date_of_birth:
        return 0
    today = datetime.utcnow().date()
    if isinstance(date_of_birth, str):
        from datetime import datetime as dt
        date_of_birth = dt.strptime(date_of_birth, "%Y-%m-%d").date()
    return today.year - date_of_birth.year - (
        (today.month, today.day) < (date_of_birth.month, date_of_birth.day)
    )