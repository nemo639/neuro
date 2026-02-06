"""
User Schemas - Profile management
"""

from pydantic import BaseModel, Field, field_validator
from typing import Optional, List
from datetime import date, datetime
import re


class UserUpdateRequest(BaseModel):
    """Update user profile."""
    first_name: Optional[str] = Field(None, min_length=1, max_length=50)
    last_name: Optional[str] = Field(None, min_length=1, max_length=50)
    phone: Optional[str] = Field(None, max_length=20)
    date_of_birth: Optional[date] = None
    gender: Optional[str] = Field(None, pattern="^(male|female|other)$")
    profile_image_path: Optional[str] = None


class UserResponse(BaseModel):
    id: int
    email: str
    first_name: str
    last_name: str
    phone: Optional[str] = None
    date_of_birth: Optional[date] = None
    gender: Optional[str] = None
    profile_image_path: Optional[str] = None
    is_verified: bool = False
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class CategoryScore(BaseModel):
    category: str
    score: float
    status: str
    last_tested: Optional[datetime] = None
    tests_completed: int = 0


class UserProfileResponse(BaseModel):
    id: int
    email: str
    first_name: str
    last_name: str
    full_name: str
    phone: Optional[str] = None
    date_of_birth: Optional[date] = None
    age: Optional[int] = None
    gender: Optional[str] = None
    profile_image_path: Optional[str] = None
    is_verified: bool = False
    ad_risk_score: float = 0.0
    pd_risk_score: float = 0.0
    cognitive_score: float = 0.0
    speech_score: float = 0.0
    motor_score: float = 0.0
    gait_score: float = 0.0
    facial_score: float = 0.0
    ad_stage: Optional[str] = None
    pd_stage: Optional[str] = None
    total_tests: int = 0
    last_test_date: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class UserDashboardResponse(BaseModel):
    user_id: int
    full_name: str
    ad_risk_score: float = 0.0
    pd_risk_score: float = 0.0
    ad_stage: Optional[str] = None
    pd_stage: Optional[str] = None
    categories: List[CategoryScore] = []
    total_tests_completed: int = 0
    tests_this_week: int = 0
    last_assessment_date: Optional[datetime] = None
    next_recommended_test: Optional[str] = None
    risk_trend: List[dict] = []