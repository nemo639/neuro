"""
Authentication Schemas - Request/Response models for auth endpoints
Matches Flutter: register.dart, login.dart, otp-verification.dart, forgot_password_screen.dart
"""

from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional
from datetime import date, datetime
import re


# ============== REQUEST SCHEMAS ==============

class RegisterRequest(BaseModel):
    """User registration - matches Flutter register.dart fields."""
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=100)
    first_name: str = Field(..., min_length=1, max_length=50)
    last_name: str = Field(..., min_length=1, max_length=50)
    phone: Optional[str] = Field(None, max_length=20)
    date_of_birth: Optional[date] = None
    gender: Optional[str] = Field(None, pattern="^(male|female|other)$")

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not re.search(r"[a-z]", v):
            raise ValueError("Password must contain at least one lowercase letter")
        if not re.search(r"\d", v):
            raise ValueError("Password must contain at least one digit")
        return v

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, v: Optional[str]) -> Optional[str]:
        if v is not None:
            # Remove spaces and dashes for validation
            cleaned = re.sub(r"[\s\-]", "", v)
            if not re.match(r"^\+?\d{10,15}$", cleaned):
                raise ValueError("Invalid phone number format")
        return v


class VerifyOTPRequest(BaseModel):
    """OTP verification - matches Flutter otp-verification.dart."""
    email: EmailStr
    otp: str = Field(..., min_length=6, max_length=6)


class ResendOTPRequest(BaseModel):
    """Resend OTP request."""
    email: EmailStr


class LoginRequest(BaseModel):
    """User login - matches Flutter login.dart."""
    email: EmailStr
    password: str = Field(..., min_length=1)


class RefreshTokenRequest(BaseModel):
    """Refresh token request."""
    refresh_token: str


class ForgotPasswordRequest(BaseModel):
    """Forgot password - matches Flutter forgot_password_screen.dart."""
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    """Reset password with token."""
    token: str
    new_password: str = Field(..., min_length=8, max_length=100)

    @field_validator("new_password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not re.search(r"[a-z]", v):
            raise ValueError("Password must contain at least one lowercase letter")
        if not re.search(r"\d", v):
            raise ValueError("Password must contain at least one digit")
        return v


class ChangePasswordRequest(BaseModel):
    """Change password (authenticated user)."""
    current_password: str
    new_password: str = Field(..., min_length=8, max_length=100)


# ============== RESPONSE SCHEMAS ==============

class MessageResponse(BaseModel):
    """Generic message response."""
    message: str
    success: bool = True


class TokenResponse(BaseModel):
    """JWT token response."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class AuthUserResponse(BaseModel):
    """User data returned after authentication - matches Flutter profile needs."""
    id: int
    email: str
    first_name: str
    last_name: str
    phone: Optional[str] = None
    date_of_birth: Optional[date] = None
    gender: Optional[str] = None
    profile_image_path: Optional[str] = None
    is_verified: bool = False
    
    # Risk scores (0-100)
    ad_risk_score: float = 0.0
    pd_risk_score: float = 0.0
    
    # Category scores (0-100)
    cognitive_score: float = 0.0
    speech_score: float = 0.0
    motor_score: float = 0.0
    gait_score: float = 0.0
    facial_score: float = 0.0
    
    # Stage classification
    ad_stage: Optional[str] = None
    pd_stage: Optional[str] = None
    
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class LoginResponse(BaseModel):
    """Complete login response with tokens and user data."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: AuthUserResponse
