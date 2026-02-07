# app/api/v1/endpoints/admin.py
# ============================================================
# ADMIN API ENDPOINTS
# ============================================================

from fastapi import APIRouter, Depends, HTTPException, status, Query, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, or_, desc
from typing import Optional
from datetime import datetime, timedelta
import os
import uuid as uuid_mod

from app.db.database import get_db
from app.core.security import (
    verify_password, 
    get_password_hash, 
    create_access_token, 
    create_refresh_token,
    get_current_admin,
)
from app.models.admin import Admin, SupportTicket, TicketMessage, AdminActivityLog, DataPermission, AdminTask
from app.models.user import User
from app.models.doctor_model import Doctor, DoctorStatus, DatasetRequest
from app.models.test_session import TestSession
from app.schemas.admin import (
    AdminLogin,
    AdminLoginResponse,
    AdminProfile,
    AdminDashboard,
    ActivityItem,
    TicketSummary,
    UserListResponse,
    UserSummary,
    DoctorListResponse,
    DoctorSummary,
    VerifyDoctorRequest,
    TicketListResponse,
    TicketDetail,
    TicketMessageItem,
    AssignTicketRequest,
    ResolveTicketRequest,
    TicketReplyRequest,
    PermissionListResponse,
    PermissionItem,
    GrantPermissionRequest,
    RevokePermissionRequest,
    AnalyticsSummary,
    KpiData,
    MonthlyGrowthItem,
    WeeklyActivityItem,
    DemographicItem,
    AssessmentItem,
    TopDoctorItem,
    TaskListResponse,
    TaskItem,
    CreateTaskRequest,
    UpdateTaskRequest,
    UpdateProfileRequest,
    UpdateProfileResponse,
    ChangePasswordRequest,
    ChangePasswordResponse,
    AdminSettingsProfile,
    AvatarUploadResponse,
)
from app.core.config import settings as app_settings

router = APIRouter(prefix="/admin", tags=["Admin"])


# ==================== AUTHENTICATION ====================

@router.post("/login", response_model=AdminLoginResponse)
async def admin_login(credentials: AdminLogin, db: AsyncSession = Depends(get_db)):
    """Admin login endpoint."""
    result = await db.execute(
        select(Admin).where(Admin.email == credentials.email.lower())
    )
    admin = result.scalar_one_or_none()
    
    if not admin or not verify_password(credentials.password, admin.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password"
        )
    
    if not admin.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated"
        )
    
    admin.last_login_at = datetime.utcnow()
    await db.commit()
    
    access_token = create_access_token(
        data={"sub": str(admin.id), "type": "admin", "role": admin.role.value}
    )
    refresh_token = create_refresh_token(data={"sub": str(admin.id), "type": "admin"})
    
    return AdminLoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        admin=AdminProfile.model_validate(admin)
    )


# ==================== DASHBOARD ====================

@router.get("/dashboard", response_model=AdminDashboard)
async def get_dashboard(
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Get admin dashboard."""
    # Counts
    users_count = await db.execute(select(func.count(User.id)))
    total_users = users_count.scalar() or 0
    
    doctors_count = await db.execute(select(func.count(Doctor.id)))
    total_doctors = doctors_count.scalar() or 0
    
    pending_count = await db.execute(
        select(func.count(Doctor.id)).where(Doctor.status == DoctorStatus.PENDING_VERIFICATION)
    )
    pending_verifications = pending_count.scalar() or 0
    
    tickets_count = await db.execute(
        select(func.count(SupportTicket.id)).where(SupportTicket.status.in_(["open", "in_progress"]))
    )
    open_tickets = tickets_count.scalar() or 0
    
    dataset_count = await db.execute(
        select(func.count(DatasetRequest.id)).where(DatasetRequest.status == "pending")
    )
    dataset_requests = dataset_count.scalar() or 0
    
    # Recent activities
    activities_result = await db.execute(
        select(AdminActivityLog)
        .order_by(desc(AdminActivityLog.created_at))
        .limit(5)
    )
    activities = activities_result.scalars().all()
    
    recent_activities = [
        ActivityItem(
            action=a.action,
            details=a.details or "",
            time=_format_time_ago(a.created_at),
            type=_get_activity_type(a.action_type)
        )
        for a in activities
    ]
    
    # Pending tickets
    tickets_result = await db.execute(
        select(SupportTicket)
        .where(SupportTicket.status.in_(["open", "in_progress"]))
        .order_by(
            desc(SupportTicket.priority == "urgent"),
            desc(SupportTicket.priority == "high"),
            desc(SupportTicket.created_at)
        )
        .limit(5)
    )
    tickets = tickets_result.scalars().all()
    
    pending_tickets = [
        TicketSummary(
            id=t.id,
            ticket_number=t.ticket_number,
            subject=t.subject,
            user_name=t.user_name or "Guest",
            user_email=t.user_email,
            priority=t.priority,
            status=t.status,
            created_at=t.created_at
        )
        for t in tickets
    ]
    
    return AdminDashboard(
        admin_name=f"{current_admin.first_name} {current_admin.last_name}",
        role=current_admin.role.value,
        total_users=total_users,
        total_doctors=total_doctors,
        pending_verifications=pending_verifications,
        open_tickets=open_tickets,
        dataset_requests=dataset_requests,
        recent_activities=recent_activities,
        pending_tickets=pending_tickets
    )


# ==================== USER MANAGEMENT ====================

@router.get("/users", response_model=UserListResponse)
async def list_users(
    search: Optional[str] = None,
    is_verified: Optional[bool] = None,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """List all users with filters."""
    if not current_admin.can_manage_users:
        raise HTTPException(status_code=403, detail="Permission denied")
    
    query = select(User)
    
    if search:
        search_term = f"%{search}%"
        query = query.where(
            or_(
                User.first_name.ilike(search_term),
                User.last_name.ilike(search_term),
                User.email.ilike(search_term)
            )
        )
    
    if is_verified is not None:
        query = query.where(User.is_verified == is_verified)
    
    query = query.order_by(desc(User.created_at))
    
    # Count
    count_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = count_result.scalar() or 0
    
    # Paginate
    offset = (page - 1) * limit
    result = await db.execute(query.offset(offset).limit(limit))
    users = result.scalars().all()
    
    return UserListResponse(
        users=[
            UserSummary(
                id=u.id,
                email=u.email,
                first_name=u.first_name,
                last_name=u.last_name,
                is_verified=u.is_verified,
                ad_risk_score=u.ad_risk_score or 0,
                pd_risk_score=u.pd_risk_score or 0,
                total_tests=0,
                created_at=u.created_at,
                last_active=u.updated_at
            )
            for u in users
        ],
        total=total,
        page=page,
        limit=limit
    )


@router.get("/doctors", response_model=DoctorListResponse)
async def list_doctors(
    search: Optional[str] = None,
    status: Optional[str] = None,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """List all doctors."""
    if not current_admin.can_manage_doctors:
        raise HTTPException(status_code=403, detail="Permission denied")
    
    query = select(Doctor)
    
    if search:
        search_term = f"%{search}%"
        query = query.where(
            or_(
                Doctor.first_name.ilike(search_term),
                Doctor.last_name.ilike(search_term),
                Doctor.email.ilike(search_term)
            )
        )
    
    if status:
        query = query.where(Doctor.status == status)
    
    query = query.order_by(desc(Doctor.created_at))
    
    count_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = count_result.scalar() or 0
    
    offset = (page - 1) * limit
    result = await db.execute(query.offset(offset).limit(limit))
    doctors = result.scalars().all()
    
    return DoctorListResponse(
        doctors=[
            DoctorSummary(
                id=d.id,
                email=d.email,
                first_name=d.first_name,
                last_name=d.last_name,
                specialization=d.specialization or "",
                hospital_affiliation=d.hospital_affiliation,
                status=d.status or "",
                is_verified=d.is_verified,
                total_patients_viewed=d.total_patients_viewed,
                created_at=d.created_at
            )
            for d in doctors
        ],
        total=total,
        page=page,
        limit=limit
    )


@router.post("/doctors/verify")
async def verify_doctor(
    request: VerifyDoctorRequest,
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Approve or reject doctor verification."""
    if not current_admin.can_manage_doctors:
        raise HTTPException(status_code=403, detail="Permission denied")
    
    result = await db.execute(select(Doctor).where(Doctor.id == int(request.doctor_id)))
    doctor = result.scalar_one_or_none()
    
    if not doctor:
        raise HTTPException(status_code=404, detail="Doctor not found")
    
    if request.approve:
        doctor.status = DoctorStatus.ACTIVE
        doctor.is_verified = True
        doctor.verified_at = datetime.utcnow()
        doctor.verified_by = current_admin.id
        action = "doctor_verified"
    else:
        doctor.status = DoctorStatus.INACTIVE
        action = "doctor_rejected"
    
    # Log activity
    log = AdminActivityLog(
        admin_id=current_admin.id,
        action=action,
        action_type="update",
        target_type="doctor",
        target_id=doctor.id,
        details=request.rejection_reason if not request.approve else "Approved"
    )
    db.add(log)
    
    current_admin.total_actions += 1
    await db.commit()
    
    return {"success": True, "message": "Doctor verified" if request.approve else "Doctor rejected"}


# ==================== SUPPORT TICKETS ====================

@router.get("/tickets", response_model=TicketListResponse)
async def list_tickets(
    status: Optional[str] = None,
    priority: Optional[str] = None,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """List support tickets."""
    if not current_admin.can_resolve_tickets:
        raise HTTPException(status_code=403, detail="Permission denied")
    
    query = select(SupportTicket)
    
    if status:
        query = query.where(SupportTicket.status == status)
    
    if priority:
        query = query.where(SupportTicket.priority == priority)
    
    query = query.order_by(
        desc(SupportTicket.priority == "urgent"),
        desc(SupportTicket.priority == "high"),
        desc(SupportTicket.created_at)
    )
    
    count_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = count_result.scalar() or 0
    
    offset = (page - 1) * limit
    result = await db.execute(query.offset(offset).limit(limit))
    tickets = result.scalars().all()
    
    return TicketListResponse(
        tickets=[
            TicketSummary(
                id=t.id,
                ticket_number=t.ticket_number,
                subject=t.subject,
                user_name=t.user_name or "Guest",
                user_email=t.user_email,
                priority=t.priority,
                status=t.status,
                created_at=t.created_at
            )
            for t in tickets
        ],
        total=total,
        page=page,
        limit=limit
    )


@router.get("/tickets/{ticket_id}", response_model=TicketDetail)
async def get_ticket(
    ticket_id: str,
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Get ticket details."""
    result = await db.execute(select(SupportTicket).where(SupportTicket.id == ticket_id))
    ticket = result.scalar_one_or_none()
    
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")
    
    # Get messages
    messages_result = await db.execute(
        select(TicketMessage)
        .where(TicketMessage.ticket_id == ticket_id)
        .order_by(TicketMessage.created_at)
    )
    messages = messages_result.scalars().all()
    
    # Get assigned admin name
    assigned_admin_name = None
    if ticket.assigned_to:
        admin_result = await db.execute(select(Admin).where(Admin.id == ticket.assigned_to))
        assigned_admin = admin_result.scalar_one_or_none()
        if assigned_admin:
            assigned_admin_name = f"{assigned_admin.first_name} {assigned_admin.last_name}"
    
    return TicketDetail(
        id=ticket.id,
        ticket_number=ticket.ticket_number,
        user_id=ticket.user_id,
        user_email=ticket.user_email,
        user_name=ticket.user_name,
        subject=ticket.subject,
        description=ticket.description,
        category=ticket.category,
        priority=ticket.priority,
        status=ticket.status,
        assigned_to=ticket.assigned_to,
        assigned_admin_name=assigned_admin_name,
        resolution_notes=ticket.resolution_notes,
        resolved_by=ticket.resolved_by,
        resolved_at=ticket.resolved_at,
        messages=[
            TicketMessageItem(
                id=m.id,
                sender_type=m.sender_type,
                sender_name=m.sender_name or "Unknown",
                message=m.message,
                created_at=m.created_at
            )
            for m in messages
        ],
        created_at=ticket.created_at,
        updated_at=ticket.updated_at
    )


@router.post("/tickets/assign")
async def assign_ticket(
    request: AssignTicketRequest,
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Assign ticket to admin."""
    result = await db.execute(select(SupportTicket).where(SupportTicket.id == request.ticket_id))
    ticket = result.scalar_one_or_none()
    
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")
    
    ticket.assigned_to = request.admin_id or current_admin.id
    ticket.assigned_at = datetime.utcnow()
    ticket.status = "in_progress"
    
    await db.commit()
    
    return {"success": True, "message": "Ticket assigned"}


@router.post("/tickets/resolve")
async def resolve_ticket(
    request: ResolveTicketRequest,
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Resolve a ticket."""
    result = await db.execute(select(SupportTicket).where(SupportTicket.id == request.ticket_id))
    ticket = result.scalar_one_or_none()
    
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")
    
    ticket.status = "resolved"
    ticket.resolution_notes = request.resolution_notes
    ticket.resolved_by = current_admin.id
    ticket.resolved_at = datetime.utcnow()
    
    current_admin.tickets_resolved += 1
    current_admin.total_actions += 1
    
    # Log
    log = AdminActivityLog(
        admin_id=current_admin.id,
        action="ticket_resolved",
        action_type="update",
        target_type="ticket",
        target_id=ticket.id
    )
    db.add(log)
    
    await db.commit()
    
    return {"success": True, "message": "Ticket resolved"}


@router.post("/tickets/reply")
async def reply_to_ticket(
    request: TicketReplyRequest,
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Reply to a ticket."""
    result = await db.execute(select(SupportTicket).where(SupportTicket.id == request.ticket_id))
    ticket = result.scalar_one_or_none()
    
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")
    
    message = TicketMessage(
        ticket_id=ticket.id,
        sender_type="admin",
        sender_id=current_admin.id,
        sender_name=f"{current_admin.first_name} {current_admin.last_name}",
        message=request.message
    )
    db.add(message)
    
    ticket.updated_at = datetime.utcnow()
    await db.commit()
    
    return {"success": True, "message": "Reply sent"}


# ==================== PERMISSIONS ====================

@router.get("/permissions", response_model=PermissionListResponse)
async def list_permissions(
    grantee_type: Optional[str] = None,
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """List data permissions."""
    if not current_admin.can_manage_permissions:
        raise HTTPException(status_code=403, detail="Permission denied")
    
    query = select(DataPermission).where(DataPermission.is_active == True)
    
    if grantee_type:
        query = query.where(DataPermission.grantee_type == grantee_type)
    
    result = await db.execute(query.order_by(desc(DataPermission.granted_at)))
    permissions = result.scalars().all()
    
    permission_items = []
    for p in permissions:
        # Get grantee name
        grantee_name = "Unknown"
        if p.grantee_type == "doctor":
            doc_result = await db.execute(select(Doctor).where(Doctor.id == p.grantee_id))
            doc = doc_result.scalar_one_or_none()
            if doc:
                grantee_name = f"Dr. {doc.first_name} {doc.last_name}"
        
        # Get admin name
        admin_result = await db.execute(select(Admin).where(Admin.id == p.granted_by))
        granting_admin = admin_result.scalar_one_or_none()
        granted_by_name = f"{granting_admin.first_name} {granting_admin.last_name}" if granting_admin else "System"
        
        permission_items.append(PermissionItem(
            id=p.id,
            grantee_type=p.grantee_type,
            grantee_id=p.grantee_id,
            grantee_name=grantee_name,
            permission_type=p.permission_type,
            resource_type=p.resource_type,
            granted_by_name=granted_by_name,
            granted_at=p.granted_at,
            expires_at=p.expires_at,
            is_active=p.is_active
        ))
    
    return PermissionListResponse(permissions=permission_items, total=len(permission_items))


@router.post("/permissions/grant")
async def grant_permission(
    request: GrantPermissionRequest,
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Grant data permission."""
    if not current_admin.can_manage_permissions:
        raise HTTPException(status_code=403, detail="Permission denied")
    
    expires_at = None
    if request.expires_in_days:
        expires_at = datetime.utcnow() + timedelta(days=request.expires_in_days)
    
    permission = DataPermission(
        grantee_type=request.grantee_type,
        grantee_id=request.grantee_id,
        permission_type=request.permission_type,
        resource_type=request.resource_type,
        granted_by=current_admin.id,
        expires_at=expires_at
    )
    
    db.add(permission)
    
    # Update doctor permissions if applicable
    if request.grantee_type == "doctor" and request.permission_type == "request_dataset":
        doc_result = await db.execute(select(Doctor).where(Doctor.id == request.grantee_id))
        doctor = doc_result.scalar_one_or_none()
        if doctor:
            doctor.can_request_dataset = True
    
    await db.commit()
    
    return {"success": True, "message": "Permission granted"}


@router.post("/permissions/revoke")
async def revoke_permission(
    request: RevokePermissionRequest,
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Revoke data permission."""
    if not current_admin.can_manage_permissions:
        raise HTTPException(status_code=403, detail="Permission denied")
    
    result = await db.execute(select(DataPermission).where(DataPermission.id == request.permission_id))
    permission = result.scalar_one_or_none()
    
    if not permission:
        raise HTTPException(status_code=404, detail="Permission not found")
    
    permission.is_active = False
    permission.revoked_by = current_admin.id
    permission.revoked_at = datetime.utcnow()
    permission.revoke_reason = request.reason
    
    await db.commit()
    
    return {"success": True, "message": "Permission revoked"}


# ==================== TASKS ====================

@router.get("/tasks", response_model=TaskListResponse)
async def list_tasks(
    show_completed: bool = False,
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """List admin tasks."""
    query = select(AdminTask).where(AdminTask.admin_id == str(current_admin.id))
    if not show_completed:
        query = query.where(AdminTask.is_completed == False)
    query = query.order_by(AdminTask.due_date.asc().nullslast(), desc(AdminTask.created_at))
    
    count_result = await db.execute(select(func.count()).select_from(query.subquery()))
    total = count_result.scalar() or 0
    
    result = await db.execute(query.limit(50))
    tasks = result.scalars().all()
    
    return TaskListResponse(
        tasks=[
            TaskItem(
                id=t.id,
                title=t.title,
                description=t.description,
                category=t.category or "general",
                due_date=t.due_date,
                is_completed=t.is_completed,
                completed_at=t.completed_at,
                created_at=t.created_at
            )
            for t in tasks
        ],
        total=total
    )


@router.post("/tasks", response_model=TaskItem)
async def create_task(
    request: CreateTaskRequest,
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Create a new admin task."""
    task = AdminTask(
        admin_id=str(current_admin.id),
        title=request.title,
        description=request.description,
        category=request.category,
        due_date=request.due_date
    )
    db.add(task)
    await db.commit()
    await db.refresh(task)
    
    return TaskItem(
        id=task.id,
        title=task.title,
        description=task.description,
        category=task.category or "general",
        due_date=task.due_date,
        is_completed=task.is_completed,
        completed_at=task.completed_at,
        created_at=task.created_at
    )


@router.patch("/tasks/{task_id}", response_model=TaskItem)
async def update_task(
    task_id: str,
    request: UpdateTaskRequest,
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Update a task (edit or toggle completion)."""
    result = await db.execute(
        select(AdminTask).where(
            AdminTask.id == task_id,
            AdminTask.admin_id == str(current_admin.id)
        )
    )
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    if request.title is not None:
        task.title = request.title
    if request.description is not None:
        task.description = request.description
    if request.category is not None:
        task.category = request.category
    if request.due_date is not None:
        task.due_date = request.due_date
    if request.is_completed is not None:
        task.is_completed = request.is_completed
        task.completed_at = datetime.utcnow() if request.is_completed else None
    
    await db.commit()
    await db.refresh(task)
    
    return TaskItem(
        id=task.id,
        title=task.title,
        description=task.description,
        category=task.category or "general",
        due_date=task.due_date,
        is_completed=task.is_completed,
        completed_at=task.completed_at,
        created_at=task.created_at
    )


@router.delete("/tasks/{task_id}")
async def delete_task(
    task_id: str,
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Delete a task."""
    result = await db.execute(
        select(AdminTask).where(
            AdminTask.id == task_id,
            AdminTask.admin_id == str(current_admin.id)
        )
    )
    task = result.scalar_one_or_none()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    await db.delete(task)
    await db.commit()
    
    return {"success": True, "message": "Task deleted"}


# ==================== ANALYTICS ====================

@router.get("/analytics", response_model=AnalyticsSummary)
async def get_analytics(
    time_range: str = Query("30d", pattern="^(7d|30d|90d|1y)$"),
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Get platform analytics data."""
    from datetime import timezone as tz, date
    import calendar

    now = datetime.now(tz.utc)

    # Map time_range to days
    range_days = {"7d": 7, "30d": 30, "90d": 90, "1y": 365}
    days = range_days.get(time_range, 30)
    period_start = now - timedelta(days=days)
    prev_period_start = period_start - timedelta(days=days)

    # ---- KPIs ----
    total_users_res = await db.execute(select(func.count(User.id)))
    total_users = total_users_res.scalar() or 0

    current_new_users_res = await db.execute(
        select(func.count(User.id)).where(User.created_at >= period_start)
    )
    current_new_users = current_new_users_res.scalar() or 0

    prev_new_users_res = await db.execute(
        select(func.count(User.id)).where(
            and_(User.created_at >= prev_period_start, User.created_at < period_start)
        )
    )
    prev_new_users = prev_new_users_res.scalar() or 0
    users_change = _calc_change(current_new_users, prev_new_users)

    total_doctors_res = await db.execute(select(func.count(Doctor.id)))
    total_doctors = total_doctors_res.scalar() or 0

    current_new_doctors_res = await db.execute(
        select(func.count(Doctor.id)).where(Doctor.created_at >= period_start)
    )
    current_new_doctors = current_new_doctors_res.scalar() or 0

    prev_new_doctors_res = await db.execute(
        select(func.count(Doctor.id)).where(
            and_(Doctor.created_at >= prev_period_start, Doctor.created_at < period_start)
        )
    )
    prev_new_doctors = prev_new_doctors_res.scalar() or 0
    doctors_change = _calc_change(current_new_doctors, prev_new_doctors)

    total_tests_res = await db.execute(
        select(func.count(TestSession.id)).where(TestSession.status == "completed")
    )
    total_tests = total_tests_res.scalar() or 0

    current_tests_res = await db.execute(
        select(func.count(TestSession.id)).where(
            and_(TestSession.status == "completed", TestSession.created_at >= period_start)
        )
    )
    current_tests = current_tests_res.scalar() or 0

    prev_tests_res = await db.execute(
        select(func.count(TestSession.id)).where(
            and_(
                TestSession.status == "completed",
                TestSession.created_at >= prev_period_start,
                TestSession.created_at < period_start,
            )
        )
    )
    prev_tests = prev_tests_res.scalar() or 0
    tests_change = _calc_change(current_tests, prev_tests)

    total_tickets_res = await db.execute(select(func.count(SupportTicket.id)))
    total_tickets = total_tickets_res.scalar() or 0

    current_tickets_res = await db.execute(
        select(func.count(SupportTicket.id)).where(SupportTicket.created_at >= period_start)
    )
    current_tickets = current_tickets_res.scalar() or 0

    prev_tickets_res = await db.execute(
        select(func.count(SupportTicket.id)).where(
            and_(SupportTicket.created_at >= prev_period_start, SupportTicket.created_at < period_start)
        )
    )
    prev_tickets = prev_tickets_res.scalar() or 0
    tickets_change = _calc_change(current_tickets, prev_tickets)

    kpis = KpiData(
        total_users=total_users,
        users_change=users_change,
        total_doctors=total_doctors,
        doctors_change=doctors_change,
        total_tests=total_tests,
        tests_change=tests_change,
        total_tickets=total_tickets,
        tickets_change=tickets_change,
    )

    # ---- Monthly Growth (last 7 months) ----
    monthly_growth = []
    for i in range(6, -1, -1):
        target = now - timedelta(days=i * 30)
        month_start = target.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        last_day = calendar.monthrange(month_start.year, month_start.month)[1]
        month_end = month_start.replace(day=last_day, hour=23, minute=59, second=59)
        month_label = month_start.strftime("%b")

        m_users = (await db.execute(
            select(func.count(User.id)).where(
                and_(User.created_at >= month_start, User.created_at <= month_end)
            )
        )).scalar() or 0

        m_doctors = (await db.execute(
            select(func.count(Doctor.id)).where(
                and_(Doctor.created_at >= month_start, Doctor.created_at <= month_end)
            )
        )).scalar() or 0

        m_tickets = (await db.execute(
            select(func.count(SupportTicket.id)).where(
                and_(SupportTicket.created_at >= month_start, SupportTicket.created_at <= month_end)
            )
        )).scalar() or 0

        m_sessions = (await db.execute(
            select(func.count(TestSession.id)).where(
                and_(TestSession.created_at >= month_start, TestSession.created_at <= month_end)
            )
        )).scalar() or 0

        monthly_growth.append(MonthlyGrowthItem(
            month=month_label, users=m_users, doctors=m_doctors,
            tickets=m_tickets, sessions=m_sessions
        ))

    # ---- User Demographics (age ranges) ----
    today = date.today()
    age_ranges = [
        ("18-24", 18, 24),
        ("25-34", 25, 34),
        ("35-44", 35, 44),
        ("45-54", 45, 54),
        ("55+", 55, 120),
    ]
    demographics = []
    for label, min_age, max_age in age_ranges:
        max_dob = today.replace(year=today.year - min_age)
        min_dob = today.replace(year=today.year - max_age - 1)
        count_res = await db.execute(
            select(func.count(User.id)).where(
                and_(
                    User.date_of_birth != None,
                    User.date_of_birth >= min_dob,
                    User.date_of_birth <= max_dob,
                )
            )
        )
        demographics.append(DemographicItem(name=label, value=count_res.scalar() or 0))

    # ---- Weekly Activity (last 7 days) ----
    weekly_activity = []
    day_names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    for i in range(6, -1, -1):
        target_day = now - timedelta(days=i)
        day_start = target_day.replace(hour=0, minute=0, second=0, microsecond=0)
        day_end = target_day.replace(hour=23, minute=59, second=59, microsecond=999999)
        day_label = day_names[day_start.weekday()]

        d_signups = (await db.execute(
            select(func.count(User.id)).where(
                and_(User.created_at >= day_start, User.created_at <= day_end)
            )
        )).scalar() or 0

        d_assessments = (await db.execute(
            select(func.count(TestSession.id)).where(
                and_(TestSession.created_at >= day_start, TestSession.created_at <= day_end)
            )
        )).scalar() or 0

        d_consultations = (await db.execute(
            select(func.count(SupportTicket.id)).where(
                and_(SupportTicket.created_at >= day_start, SupportTicket.created_at <= day_end)
            )
        )).scalar() or 0

        weekly_activity.append(WeeklyActivityItem(
            day=day_label, signups=d_signups, assessments=d_assessments,
            consultations=d_consultations,
        ))

    # ---- Assessment Data (by test category) ----
    category_labels = {
        "cognitive": "Cognitive",
        "speech": "Speech",
        "motor": "Motor",
        "gait": "Gait",
        "facial": "Facial",
    }
    assessment_data = []
    for cat_key, cat_label in category_labels.items():
        cat_count = (await db.execute(
            select(func.count(TestSession.id)).where(
                and_(TestSession.category == cat_key, TestSession.status == "completed")
            )
        )).scalar() or 0
        assessment_data.append(AssessmentItem(name=cat_label, completed=cat_count))

    # ---- Top Doctors ----
    top_docs_result = await db.execute(
        select(Doctor)
        .where(Doctor.status == "active")
        .order_by(desc(Doctor.total_patients_viewed))
        .limit(5)
    )
    top_doctors_rows = top_docs_result.scalars().all()
    top_doctors = [
        TopDoctorItem(
            name=f"Dr. {doc.first_name} {doc.last_name}",
            specialization=doc.specialization.replace("_", " ").title() if doc.specialization else "General",
            patients=doc.total_patients_viewed or 0,
            rating=round(min(5.0, 3.5 + (doc.total_patients_viewed or 0) * 0.01), 1),
        )
        for doc in top_doctors_rows
    ]

    return AnalyticsSummary(
        kpis=kpis,
        monthly_growth=monthly_growth,
        user_demographics=demographics,
        weekly_activity=weekly_activity,
        assessment_data=assessment_data,
        top_doctors=top_doctors,
        total_users=total_users,
    )


def _calc_change(current: int, previous: int) -> float:
    """Calculate percentage change."""
    if previous == 0:
        return 100.0 if current > 0 else 0.0
    return round(((current - previous) / previous) * 100, 1)


# ==================== SETTINGS ====================

@router.get("/settings/profile", response_model=AdminSettingsProfile)
async def get_settings_profile(
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Get current admin's full profile for settings page."""
    result = await db.execute(select(Admin).where(Admin.id == current_admin.id))
    admin = result.scalar_one_or_none()
    if not admin:
        raise HTTPException(status_code=404, detail="Admin not found")
    profile_image_url = None
    if admin.profile_image_path:
        profile_image_url = f"/uploads/{admin.profile_image_path}"

    return AdminSettingsProfile(
        id=admin.id,
        email=admin.email,
        first_name=admin.first_name,
        last_name=admin.last_name,
        phone=admin.phone,
        role=admin.role.value if hasattr(admin.role, 'value') else str(admin.role),
        profile_image_url=profile_image_url,
        is_active=admin.is_active,
        total_actions=admin.total_actions or 0,
        tickets_resolved=admin.tickets_resolved or 0,
        users_managed=admin.users_managed or 0,
        created_at=admin.created_at,
        last_login_at=admin.last_login_at,
    )


@router.put("/settings/profile", response_model=UpdateProfileResponse)
async def update_profile(
    data: UpdateProfileRequest,
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Update admin profile."""
    result = await db.execute(select(Admin).where(Admin.id == current_admin.id))
    admin = result.scalar_one_or_none()
    if not admin:
        raise HTTPException(status_code=404, detail="Admin not found")

    if data.first_name is not None:
        admin.first_name = data.first_name
    if data.last_name is not None:
        admin.last_name = data.last_name
    if data.phone is not None:
        admin.phone = data.phone

    await db.commit()
    await db.refresh(admin)

    return UpdateProfileResponse(
        admin=AdminProfile.model_validate(admin)
    )


@router.post("/settings/change-password", response_model=ChangePasswordResponse)
async def change_password(
    data: ChangePasswordRequest,
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Change admin password."""
    result = await db.execute(select(Admin).where(Admin.id == current_admin.id))
    admin = result.scalar_one_or_none()
    if not admin:
        raise HTTPException(status_code=404, detail="Admin not found")

    if not verify_password(data.current_password, admin.password_hash):
        raise HTTPException(status_code=400, detail="Current password is incorrect")

    admin.password_hash = get_password_hash(data.new_password)
    await db.commit()

    return ChangePasswordResponse(message="Password changed successfully")


@router.post("/settings/avatar", response_model=AvatarUploadResponse)
async def upload_avatar(
    file: UploadFile = File(...),
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Upload admin profile avatar."""
    # Validate content type
    if file.content_type not in app_settings.ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type. Allowed: {app_settings.ALLOWED_IMAGE_TYPES}"
        )

    content = await file.read()

    # Validate file size
    if len(content) > app_settings.MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File too large. Max size: {app_settings.MAX_FILE_SIZE // (1024*1024)}MB"
        )

    # Generate unique filename
    ext = file.filename.split(".")[-1] if file.filename and "." in file.filename else "jpg"
    filename = f"admin_{current_admin.id}_{uuid_mod.uuid4().hex[:8]}.{ext}"

    # Ensure directory exists
    avatar_dir = os.path.join(app_settings.UPLOAD_DIR, "avatars")
    os.makedirs(avatar_dir, exist_ok=True)

    # Delete old avatar if exists
    result = await db.execute(select(Admin).where(Admin.id == current_admin.id))
    admin = result.scalar_one_or_none()
    if not admin:
        raise HTTPException(status_code=404, detail="Admin not found")

    if admin.profile_image_path:
        old_path = os.path.join(app_settings.UPLOAD_DIR, admin.profile_image_path)
        if os.path.exists(old_path):
            os.remove(old_path)

    # Save file
    filepath = os.path.join(avatar_dir, filename)
    with open(filepath, "wb") as f:
        f.write(content)

    # Update DB
    relative_path = f"avatars/{filename}"
    admin.profile_image_path = relative_path
    await db.commit()
    await db.refresh(admin)

    return AvatarUploadResponse(profile_image_url=f"/uploads/{relative_path}")


@router.delete("/settings/avatar")
async def delete_avatar(
    current_admin: Admin = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db)
):
    """Delete admin profile avatar."""
    result = await db.execute(select(Admin).where(Admin.id == current_admin.id))
    admin = result.scalar_one_or_none()
    if not admin:
        raise HTTPException(status_code=404, detail="Admin not found")

    if admin.profile_image_path:
        old_path = os.path.join(app_settings.UPLOAD_DIR, admin.profile_image_path)
        if os.path.exists(old_path):
            os.remove(old_path)
        admin.profile_image_path = None
        await db.commit()

    return {"success": True, "message": "Avatar removed"}


# ==================== HELPERS ====================

def _format_time_ago(dt: datetime) -> str:
    from datetime import timezone as tz
    now = datetime.now(tz.utc)
    # Make dt timezone-aware if it isn't
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=tz.utc)
    diff = now - dt
    
    total_seconds = int(diff.total_seconds())
    if total_seconds < 60:
        return "Just now"
    elif total_seconds < 3600:
        mins = total_seconds // 60
        return f"{mins} min ago"
    elif total_seconds < 86400:
        hours = total_seconds // 3600
        return f"{hours} hour{'s' if hours > 1 else ''} ago"
    else:
        days = diff.days
        return f"{days} day{'s' if days > 1 else ''} ago"


def _get_activity_type(action_type: str) -> str:
    mapping = {
        "create": "success",
        "update": "info",
        "delete": "warning",
        "view": "info"
    }
    return mapping.get(action_type, "info")