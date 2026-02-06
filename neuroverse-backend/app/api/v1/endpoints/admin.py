# app/api/v1/endpoints/admin.py
# ============================================================
# ADMIN API ENDPOINTS
# ============================================================

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, or_, desc
from typing import Optional
from datetime import datetime, timedelta

from app.db.database import get_db
from app.core.security import (
    verify_password, 
    get_password_hash, 
    create_access_token, 
    create_refresh_token,
    get_current_admin,
)
from app.models.admin import Admin, SupportTicket, TicketMessage, AdminActivityLog, DataPermission
from app.models.user import User
from app.models.doctor_model import Doctor, DoctorStatus, DatasetRequest
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
)

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
        data={"sub": admin.id, "type": "admin", "role": admin.role.value}
    )
    refresh_token = create_refresh_token(data={"sub": admin.id, "type": "admin"})
    
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
                specialization=d.specialization.value,
                hospital_affiliation=d.hospital_affiliation,
                status=d.status.value,
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
    
    result = await db.execute(select(Doctor).where(Doctor.id == request.doctor_id))
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


# ==================== HELPERS ====================

def _format_time_ago(dt: datetime) -> str:
    now = datetime.utcnow()
    diff = now - dt
    
    if diff.seconds < 60:
        return "Just now"
    elif diff.seconds < 3600:
        mins = diff.seconds // 60
        return f"{mins} min ago"
    elif diff.seconds < 86400:
        hours = diff.seconds // 3600
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