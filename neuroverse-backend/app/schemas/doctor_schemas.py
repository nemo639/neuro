# app/schemas/doctor.py
# ============================================================
# DOCTOR SCHEMAS - Request/Response Models
# ============================================================

from pydantic import BaseModel, EmailStr, Field, validator
from typing import Optional, List
from datetime import datetime
from enum import Enum


# ==================== ENUMS ====================

class DoctorSpecialization(str, Enum):
    NEUROLOGIST = "neurologist"
    PSYCHIATRIST = "psychiatrist"
    GERIATRICIAN = "geriatrician"
    GENERAL_PHYSICIAN = "general_physician"
    PSYCHOLOGIST = "psychologist"
    RESEARCHER = "researcher"
    OTHER = "other"


class DoctorStatus(str, Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    SUSPENDED = "suspended"
    PENDING_VERIFICATION = "pending_verification"


class NoteType(str, Enum):
    GENERAL = "general"
    DIAGNOSIS = "diagnosis"
    TREATMENT = "treatment"
    FOLLOW_UP = "follow_up"
    OBSERVATION = "observation"


class DatasetRequestStatus(str, Enum):
    PENDING = "pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    COMPLETED = "completed"


# ==================== AUTH SCHEMAS ====================

class DoctorLogin(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=6)


class DoctorLoginResponse(BaseModel):
    success: bool = True
    message: str = "Login successful"
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    doctor: "DoctorProfile"


class DoctorForgotPassword(BaseModel):
    email: EmailStr


class DoctorResetPassword(BaseModel):
    email: EmailStr
    otp: str = Field(..., min_length=6, max_length=6)
    new_password: str = Field(..., min_length=8)


# ==================== PROFILE SCHEMAS ====================

class DoctorProfile(BaseModel):
    id: int  # ← FIXED: Changed from str to int
    email: str
    first_name: str
    last_name: str
    phone: Optional[str] = None
    specialization: DoctorSpecialization
    license_number: Optional[str] = None
    hospital_affiliation: Optional[str] = None
    department: Optional[str] = None
    years_of_experience: Optional[int] = None
    profile_image_path: Optional[str] = None
    bio: Optional[str] = None
    status: DoctorStatus
    is_verified: bool
    can_view_patients: bool
    can_add_notes: bool
    can_export_reports: bool
    can_request_dataset: bool
    total_patients_viewed: int
    total_notes_created: int
    total_reports_exported: int
    last_login_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True


class DoctorProfileUpdate(BaseModel):
    first_name: Optional[str] = Field(None, max_length=100)
    last_name: Optional[str] = Field(None, max_length=100)
    phone: Optional[str] = Field(None, max_length=20)
    hospital_affiliation: Optional[str] = Field(None, max_length=255)
    department: Optional[str] = Field(None, max_length=100)
    bio: Optional[str] = None


# ==================== DASHBOARD SCHEMAS ====================

class DoctorDashboard(BaseModel):
    doctor_name: str
    specialization: str
    total_patients: int
    pending_reviews: int
    reports_today: int
    critical_alerts: int
    recent_patients: List["PatientSummary"]
    pending_diagnostics: List["PendingDiagnostic"]


class PatientSummary(BaseModel):
    id: int  # ← FIXED: Changed from str to int
    name: str
    age: int
    gender: Optional[str] = None
    risk_level: str  # Low, Moderate, High
    ad_risk_score: int
    pd_risk_score: int
    last_test_date: Optional[datetime] = None
    last_test_category: Optional[str] = None


class PendingDiagnostic(BaseModel):
    id: int  # ← FIXED: Changed from str to int
    patient_id: int  # ← FIXED: Changed from str to int
    patient_name: str
    test_category: str
    test_name: str
    completed_at: datetime
    status: str = "awaiting_review"


# ==================== PATIENT BROWSING SCHEMAS ====================

class PatientListRequest(BaseModel):
    search: Optional[str] = None
    risk_level: Optional[str] = None  # Low, Moderate, High
    age_min: Optional[int] = None
    age_max: Optional[int] = None
    has_recent_tests: Optional[bool] = None
    sort_by: str = "last_test_date"  # last_test_date, risk_score, name
    sort_order: str = "desc"
    page: int = 1
    limit: int = 20


class PatientListResponse(BaseModel):
    success: bool = True
    patients: List[PatientSummary]
    total: int
    page: int
    limit: int
    total_pages: int


class PatientDetailResponse(BaseModel):
    id: int  # ← FIXED: Changed from str to int
    first_name: str
    last_name: str
    email: str
    phone: Optional[str] = None
    date_of_birth: Optional[str] = None
    gender: Optional[str] = None
    
    # Risk Scores
    ad_risk_score: int
    pd_risk_score: int
    cognitive_score: Optional[int] = None
    speech_score: Optional[int] = None
    motor_score: Optional[int] = None
    gait_score: Optional[int] = None
    facial_score: Optional[int] = None
    
    # Stages
    ad_stage: Optional[str] = None
    pd_stage: Optional[str] = None
    
    # History
    total_tests_completed: int
    test_sessions: List["TestSessionSummary"]
    clinical_notes: List["ClinicalNoteSummary"]
    
    # Metadata
    member_since: datetime
    last_active: Optional[datetime] = None


class TestSessionSummary(BaseModel):
    id: int  # ← FIXED: Changed from str to int
    category: str
    status: str
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    ad_risk_contribution: Optional[int] = None
    pd_risk_contribution: Optional[int] = None
    category_score: Optional[int] = None


# ==================== CLINICAL NOTES SCHEMAS ====================

class ClinicalNoteCreate(BaseModel):
    patient_id: int  # ← FIXED: Changed from str to int
    title: str = Field(..., max_length=255)
    content: str
    note_type: NoteType = NoteType.GENERAL
    related_session_id: Optional[int] = None  # ← FIXED: Changed from str to int
    related_report_id: Optional[int] = None  # ← FIXED: Changed from str to int
    is_private: bool = False
    is_flagged: bool = False


class ClinicalNoteUpdate(BaseModel):
    title: Optional[str] = Field(None, max_length=255)
    content: Optional[str] = None
    note_type: Optional[NoteType] = None
    is_private: Optional[bool] = None
    is_flagged: Optional[bool] = None


class ClinicalNoteSummary(BaseModel):
    id: int  # ← FIXED: Changed from str to int
    doctor_id: int  # ← FIXED: Changed from str to int
    doctor_name: str
    patient_id: int  # ← FIXED: Changed from str to int
    title: str
    content: str
    note_type: str
    is_private: bool
    is_flagged: bool
    created_at: datetime
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class ClinicalNoteResponse(BaseModel):
    success: bool = True
    note: ClinicalNoteSummary


class ClinicalNotesListResponse(BaseModel):
    success: bool = True
    notes: List[ClinicalNoteSummary]
    total: int
    page: int
    limit: int


# ==================== REPORT ANALYSIS SCHEMAS ====================

class ReportAnalysisRequest(BaseModel):
    patient_id: int  # ← FIXED: Changed from str to int
    session_ids: Optional[List[int]] = None  # ← FIXED: Changed from str to int
    date_range_start: Optional[datetime] = None
    date_range_end: Optional[datetime] = None


class DiagnosticReport(BaseModel):
    id: int  # ← FIXED: Changed from str to int
    patient_id: int  # ← FIXED: Changed from str to int
    patient_name: str
    
    # Scores
    ad_risk_score: int
    pd_risk_score: int
    cognitive_score: Optional[int] = None
    speech_score: Optional[int] = None
    motor_score: Optional[int] = None
    gait_score: Optional[int] = None
    facial_score: Optional[int] = None
    
    # Analysis
    ad_stage: Optional[str] = None
    pd_stage: Optional[str] = None
    primary_concerns: List[str]
    recommendations: List[str]
    
    # XAI Data
    xai_explanations: dict
    feature_importance: dict
    
    # Sessions Included
    sessions_analyzed: int
    date_range: str
    
    # Metadata
    generated_at: datetime


# ==================== EXPORT SCHEMAS ====================

class ExportReportRequest(BaseModel):
    patient_id: int  # ← FIXED: Changed from str to int
    report_type: str = "comprehensive"  # comprehensive, summary, specific_category
    categories: Optional[List[str]] = None  # If specific_category
    date_range_start: Optional[datetime] = None
    date_range_end: Optional[datetime] = None
    include_xai: bool = True
    include_raw_data: bool = False
    format: str = "pdf"  # pdf, csv, json


class ExportReportResponse(BaseModel):
    success: bool = True
    report_id: int  # ← FIXED: Changed from str to int
    download_url: str
    expires_at: datetime


# ==================== DATASET REQUEST SCHEMAS ====================

class DatasetRequestCreate(BaseModel):
    purpose: str
    research_title: Optional[str] = None
    institution: Optional[str] = None
    data_types: List[str] = ["cognitive", "motor", "speech", "gait", "facial"]
    date_range_start: Optional[datetime] = None
    date_range_end: Optional[datetime] = None
    min_samples: int = Field(default=100, ge=10, le=10000)


class DatasetRequestResponse(BaseModel):
    id: int  # ← FIXED: Changed from str to int
    doctor_id: int  # ← FIXED: Changed from str to int
    purpose: str
    research_title: Optional[str] = None
    institution: Optional[str] = None
    data_types: List[str]
    status: DatasetRequestStatus
    reviewed_by: Optional[int] = None  # ← FIXED: Changed from str to int
    reviewed_at: Optional[datetime] = None
    rejection_reason: Optional[str] = None
    samples_included: Optional[int] = None
    dataset_path: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class DatasetRequestListResponse(BaseModel):
    success: bool = True
    requests: List[DatasetRequestResponse]
    total: int


# ==================== ALERT SCHEMAS ====================

class AlertItem(BaseModel):
    id: str  # Keep as str for composite IDs like "high_risk_123"
    type: str  # high_risk, pending_review, new_test, critical
    title: str
    message: str
    patient_id: Optional[int] = None  # ← FIXED: Changed from str to int
    patient_name: Optional[str] = None
    severity: str  # info, warning, critical
    is_read: bool = False
    created_at: datetime


class AlertsResponse(BaseModel):
    success: bool = True
    alerts: List[AlertItem]
    unread_count: int


# Forward references update
DoctorLoginResponse.model_rebuild()
DoctorDashboard.model_rebuild()
PatientDetailResponse.model_rebuild()