# app/schemas/admin.py
# ============================================================
# ADMIN SCHEMAS - Request/Response Models
# ============================================================

from pydantic import BaseModel, EmailStr, Field, model_validator
from typing import Optional, List, Any
from datetime import datetime
from enum import Enum


# ==================== ENUMS ====================

class AdminRole(str, Enum):
    SUPER_ADMIN = "super_admin"
    ADMIN = "admin"
    MODERATOR = "moderator"
    SUPPORT = "support"


class TicketStatus(str, Enum):
    OPEN = "open"
    IN_PROGRESS = "in_progress"
    RESOLVED = "resolved"
    CLOSED = "closed"


class TicketPriority(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    URGENT = "urgent"


# ==================== AUTH ====================

class AdminLogin(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=6)


class AdminLoginResponse(BaseModel):
    success: bool = True
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    admin: "AdminProfile"


# ==================== PROFILE ====================

class AdminProfile(BaseModel):
    id: str
    email: str
    first_name: str
    last_name: str
    phone: Optional[str] = None
    role: AdminRole
    profile_image_url: Optional[str] = None
    can_manage_users: bool
    can_manage_doctors: bool
    can_manage_permissions: bool
    can_resolve_tickets: bool
    can_view_analytics: bool
    can_export_data: bool
    can_manage_admins: bool
    is_active: bool
    total_actions: int
    tickets_resolved: int
    last_login_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True

    @model_validator(mode='before')
    @classmethod
    def compute_image_url(cls, data: Any) -> Any:
        """Compute profile_image_url from profile_image_path (ORM field)."""
        if hasattr(data, 'profile_image_path'):
            path = data.profile_image_path
            if path:
                data.profile_image_url = f"/uploads/{path}"
        elif isinstance(data, dict) and 'profile_image_path' in data:
            path = data.get('profile_image_path')
            if path:
                data['profile_image_url'] = f"/uploads/{path}"
        return data


# ==================== DASHBOARD ====================

class AdminDashboard(BaseModel):
    admin_name: str
    role: str
    total_users: int
    total_doctors: int
    pending_verifications: int
    open_tickets: int
    dataset_requests: int
    recent_activities: List["ActivityItem"]
    pending_tickets: List["TicketSummary"]


class ActivityItem(BaseModel):
    action: str
    details: str
    time: str
    type: str  # success, warning, error, info, pending


class TicketSummary(BaseModel):
    id: str
    ticket_number: str
    subject: str
    user_name: str
    user_email: str
    priority: str
    status: str
    created_at: datetime


# ==================== USER MANAGEMENT ====================

class UserListResponse(BaseModel):
    success: bool = True
    users: List["UserSummary"]
    total: int
    page: int
    limit: int


class UserSummary(BaseModel):
    id: int
    email: str
    first_name: str
    last_name: str
    is_verified: bool
    ad_risk_score: float = 0.0
    pd_risk_score: float = 0.0
    total_tests: int = 0
    created_at: datetime
    last_active: Optional[datetime] = None


class DoctorListResponse(BaseModel):
    success: bool = True
    doctors: List["DoctorSummary"]
    total: int
    page: int
    limit: int


class DoctorSummary(BaseModel):
    id: int
    email: str
    first_name: str
    last_name: str
    specialization: str
    hospital_affiliation: Optional[str] = None
    status: str
    is_verified: bool
    total_patients_viewed: int = 0
    created_at: datetime


class VerifyDoctorRequest(BaseModel):
    doctor_id: int
    approve: bool
    rejection_reason: Optional[str] = None


# ==================== SUPPORT TICKETS ====================

class TicketListResponse(BaseModel):
    success: bool = True
    tickets: List[TicketSummary]
    total: int
    page: int
    limit: int


class TicketDetail(BaseModel):
    id: str
    ticket_number: str
    user_id: Optional[str] = None
    user_email: str
    user_name: Optional[str] = None
    subject: str
    description: str
    category: str
    priority: str
    status: str
    assigned_to: Optional[str] = None
    assigned_admin_name: Optional[str] = None
    resolution_notes: Optional[str] = None
    resolved_by: Optional[str] = None
    resolved_at: Optional[datetime] = None
    messages: List["TicketMessageItem"]
    created_at: datetime
    updated_at: Optional[datetime] = None


class TicketMessageItem(BaseModel):
    id: str
    sender_type: str
    sender_name: str
    message: str
    created_at: datetime


class AssignTicketRequest(BaseModel):
    ticket_id: str
    admin_id: Optional[str] = None  # None = assign to self


class ResolveTicketRequest(BaseModel):
    ticket_id: str
    resolution_notes: str


class TicketReplyRequest(BaseModel):
    ticket_id: str
    message: str


# ==================== PERMISSIONS ====================

class PermissionListResponse(BaseModel):
    success: bool = True
    permissions: List["PermissionItem"]
    total: int


class PermissionItem(BaseModel):
    id: str
    grantee_type: str
    grantee_id: str
    grantee_name: str
    permission_type: str
    resource_type: Optional[str] = None
    granted_by_name: str
    granted_at: datetime
    expires_at: Optional[datetime] = None
    is_active: bool


class GrantPermissionRequest(BaseModel):
    grantee_type: str  # doctor, researcher
    grantee_id: str
    permission_type: str  # view_patients, export_data, request_dataset
    resource_type: Optional[str] = None
    expires_in_days: Optional[int] = None


class RevokePermissionRequest(BaseModel):
    permission_id: str
    reason: str


# ==================== TASKS ====================

class TaskItem(BaseModel):
    id: str
    title: str
    description: Optional[str] = None
    category: str = "general"
    due_date: Optional[datetime] = None
    is_completed: bool = False
    completed_at: Optional[datetime] = None
    created_at: datetime


class TaskListResponse(BaseModel):
    success: bool = True
    tasks: List[TaskItem]
    total: int


class CreateTaskRequest(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None
    category: str = "general"
    due_date: Optional[datetime] = None


class UpdateTaskRequest(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    due_date: Optional[datetime] = None
    is_completed: Optional[bool] = None


# ==================== ANALYTICS ====================

class KpiData(BaseModel):
    total_users: int = 0
    users_change: float = 0.0
    total_doctors: int = 0
    doctors_change: float = 0.0
    total_tests: int = 0
    tests_change: float = 0.0
    total_tickets: int = 0
    tickets_change: float = 0.0


class MonthlyGrowthItem(BaseModel):
    month: str
    users: int = 0
    doctors: int = 0
    tickets: int = 0
    sessions: int = 0


class WeeklyActivityItem(BaseModel):
    day: str
    signups: int = 0
    assessments: int = 0
    consultations: int = 0


class DemographicItem(BaseModel):
    name: str
    value: int = 0


class AssessmentItem(BaseModel):
    name: str
    completed: int = 0


class TopDoctorItem(BaseModel):
    name: str
    specialization: str
    patients: int = 0
    rating: float = 0.0


class AnalyticsSummary(BaseModel):
    kpis: KpiData
    monthly_growth: List[MonthlyGrowthItem]
    user_demographics: List[DemographicItem]
    weekly_activity: List[WeeklyActivityItem]
    assessment_data: List[AssessmentItem]
    top_doctors: List[TopDoctorItem]
    total_users: int = 0


# ==================== SETTINGS ====================

class UpdateProfileRequest(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone: Optional[str] = None


class UpdateProfileResponse(BaseModel):
    success: bool = True
    admin: AdminProfile


class ChangePasswordRequest(BaseModel):
    current_password: str = Field(..., min_length=6)
    new_password: str = Field(..., min_length=6)


class ChangePasswordResponse(BaseModel):
    success: bool = True
    message: str


class AdminSettingsProfile(BaseModel):
    id: str
    email: str
    first_name: str
    last_name: str
    phone: Optional[str] = None
    role: str
    profile_image_url: Optional[str] = None
    is_active: bool
    total_actions: int = 0
    tickets_resolved: int = 0
    users_managed: int = 0
    created_at: datetime
    last_login_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class AvatarUploadResponse(BaseModel):
    success: bool = True
    profile_image_url: str


# Forward references
AdminLoginResponse.model_rebuild()
AdminDashboard.model_rebuild()
TicketDetail.model_rebuild()