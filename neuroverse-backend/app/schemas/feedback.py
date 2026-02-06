# ============================================================================
# FILE 2: app/schemas/feedback.py
# ============================================================================
from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime
from enum import Enum


class FeedbackCategory(str, Enum):
    GENERAL = "general"
    BUG_REPORT = "bug_report"
    FEATURE_REQUEST = "feature_request"
    UI_UX = "ui_ux"
    TEST_QUALITY = "test_quality"
    PERFORMANCE = "performance"
    OTHER = "other"


class FeedbackStatus(str, Enum):
    PENDING = "pending"
    REVIEWED = "reviewed"
    IN_PROGRESS = "in_progress"
    RESOLVED = "resolved"
    CLOSED = "closed"


# ==================== Request Schemas ====================

class FeedbackCreate(BaseModel):
    """Schema for creating new feedback"""
    category: FeedbackCategory = FeedbackCategory.GENERAL
    rating: Optional[int] = Field(None, ge=1, le=5, description="Rating from 1-5 stars")
    message: str = Field(..., min_length=5, max_length=1000, description="Feedback message")
    app_version: Optional[str] = Field(None, max_length=20)
    device_info: Optional[str] = Field(None, max_length=200)

    @field_validator('message')
    @classmethod
    def message_not_empty(cls, v):
        if not v or not v.strip():
            raise ValueError('Feedback message cannot be empty')
        if len(v.strip()) < 5:
            raise ValueError('Feedback message must be at least 5 characters')
        return v.strip()

    @field_validator('category', mode='before')
    @classmethod
    def normalize_category(cls, v):
        """Convert category to lowercase and handle frontend values"""
        if isinstance(v, str):
            v_clean = v.lower().strip().replace(' ', '_').replace('/', '_')
            # Direct lowercase conversion for enum matching
            return v_clean
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "category": "bug_report",
                "rating": 4,
                "message": "The speech test sometimes freezes when recording for more than 30 seconds.",
                "app_version": "1.0.0",
                "device_info": "iPhone 14 Pro, iOS 17.2"
            }
        }


class FeedbackUpdate(BaseModel):
    """Schema for updating feedback (admin use)"""
    status: Optional[FeedbackStatus] = None
    admin_notes: Optional[str] = Field(None, max_length=500)


# ==================== Response Schemas ====================

class FeedbackResponse(BaseModel):
    """Schema for feedback response"""
    id: int
    user_id: int
    category: FeedbackCategory
    rating: Optional[int]
    message: str
    status: FeedbackStatus
    app_version: Optional[str]
    device_info: Optional[str]
    created_at: datetime
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True


class FeedbackDetailResponse(FeedbackResponse):
    """Detailed feedback response with admin notes (for admin use)"""
    admin_notes: Optional[str]
    resolved_at: Optional[datetime]
    user_email: Optional[str] = None
    user_name: Optional[str] = None

    class Config:
        from_attributes = True


class FeedbackListResponse(BaseModel):
    """Schema for paginated feedback list"""
    feedbacks: list[FeedbackResponse]
    total: int
    page: int
    per_page: int
    total_pages: int


class FeedbackStats(BaseModel):
    """Feedback statistics"""
    total_feedbacks: int
    pending_count: int
    resolved_count: int
    average_rating: Optional[float]
    category_breakdown: dict[str, int]


class FeedbackSubmitResponse(BaseModel):
    """Response after submitting feedback"""
    success: bool
    message: str
    feedback_id: int

    class Config:
        json_schema_extra = {
            "example": {
                "success": True,
                "message": "Thank you for your feedback! We'll review it shortly.",
                "feedback_id": 123
            }
        }

