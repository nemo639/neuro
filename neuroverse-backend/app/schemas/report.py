"""
Report Schemas - PDF report generation
Matches Flutter: reports_screen.dart
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime, date
from enum import Enum


class ReportType(str, Enum):
    COMPREHENSIVE = "comprehensive"  # All categories
    COGNITIVE_SPEECH = "cognitive_speech"  # Cognitive + Speech only
    MOTOR_GAIT = "motor_gait"  # Motor + Gait only
    SINGLE_CATEGORY = "single_category"  # One category only
    WELLNESS = "wellness"  # Wellness report only
    PROGRESS = "progress"  # Progress over time


# ============== REQUEST SCHEMAS ==============

class ReportCreate(BaseModel):
    """Create a new report."""
    title: Optional[str] = Field(None, max_length=200)
    report_type: ReportType = ReportType.COMPREHENSIVE
    
    # Which sessions to include (optional - defaults to all completed)
    session_ids: Optional[List[int]] = None
    
    # Category filter (for single_category type)
    category: Optional[str] = None
    
    # Date range filter
    date_range_start: Optional[date] = None
    date_range_end: Optional[date] = None
    
    # Include wellness data
    include_wellness: bool = False


class ReportGenerateRequest(BaseModel):
    """Request to generate/regenerate report PDF."""
    report_id: int


# ============== RESPONSE SCHEMAS ==============

class ReportSessionInfo(BaseModel):
    """Session info included in report."""
    session_id: int
    category: str
    completed_at: Optional[datetime] = None
    category_score: float = 0.0


class ReportResponse(BaseModel):
    """Basic report response."""
    id: int
    user_id: int
    title: str
    report_type: Optional[str] = None
    
    # Scores at time of report
    ad_risk_score: float = 0.0
    pd_risk_score: float = 0.0
    
    # Category scores
    cognitive_score: Optional[float] = None
    speech_score: Optional[float] = None
    motor_score: Optional[float] = None
    gait_score: Optional[float] = None
    facial_score: Optional[float] = None
    
    # Stage classification
    ad_stage: Optional[str] = None
    pd_stage: Optional[str] = None
    
    # Metadata
    tests_count: int = 0
    include_wellness: bool = False
    is_ready: bool = False
    pdf_path: Optional[str] = None
    
    # Date range
    date_range_start: Optional[datetime] = None
    date_range_end: Optional[datetime] = None
    
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class ReportDetailResponse(BaseModel):
    """Detailed report with sessions info."""
    id: int
    user_id: int
    title: str
    report_type: Optional[str] = None
    
    # Scores
    ad_risk_score: float = 0.0
    pd_risk_score: float = 0.0
    cognitive_score: Optional[float] = None
    speech_score: Optional[float] = None
    motor_score: Optional[float] = None
    gait_score: Optional[float] = None
    facial_score: Optional[float] = None
    ad_stage: Optional[str] = None
    pd_stage: Optional[str] = None
    
    # Sessions included
    sessions_included: Optional[List[int]] = None
    sessions_info: List[ReportSessionInfo] = []
    tests_count: int = 0
    
    # Wellness
    include_wellness: bool = False
    wellness_summary: Optional[dict] = None
    
    # PDF
    is_ready: bool = False
    pdf_path: Optional[str] = None
    pdf_url: Optional[str] = None
    
    # Date range
    date_range_start: Optional[datetime] = None
    date_range_end: Optional[datetime] = None
    
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class ReportListResponse(BaseModel):
    """List of reports."""
    reports: List[ReportResponse]
    total: int
    page: int = 1
    page_size: int = 20


class ReportDownloadResponse(BaseModel):
    """Report download info."""
    report_id: int
    pdf_url: str
    filename: str
    generated_at: datetime
