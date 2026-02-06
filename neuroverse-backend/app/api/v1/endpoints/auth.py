"""
Authentication Endpoints
POST /register, /verify-otp, /resend-otp, /login, /logout, /refresh, /forgot-password, /reset-password
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.services.auth_service import AuthService
from app.schemas.auth import (
    RegisterRequest, VerifyOTPRequest, ResendOTPRequest,
    LoginRequest, RefreshTokenRequest, ForgotPasswordRequest,
    ResetPasswordRequest, TokenResponse, MessageResponse,
    AuthUserResponse, LoginResponse
)

router = APIRouter()


@router.post("/register", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
async def register(
    data: RegisterRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Register a new user.
    
    - Validates email uniqueness
    - Creates user with hashed password
    - Sends OTP to email for verification
    """
    service = AuthService(db)
    user = await service.register(data)
    
    return MessageResponse(
        message=f"Registration successful. OTP sent to {user.email}",
        success=True
    )


@router.post("/verify-otp", response_model=LoginResponse)
async def verify_otp(
    data: VerifyOTPRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Verify OTP and activate user account.
    
    - Returns tokens on successful verification
    - User can now login
    """
    service = AuthService(db)
    user = await service.verify_otp(data)
    
    # Generate tokens after verification
    from app.core.security import create_access_token, create_refresh_token
    access_token = create_access_token({"sub": str(user.id)})
    refresh_token = create_refresh_token({"sub": str(user.id)})
    
    return LoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        user=AuthUserResponse.model_validate(user)
    )


@router.post("/resend-otp", response_model=MessageResponse)
async def resend_otp(
    data: ResendOTPRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Resend OTP to user email.
    
    - Generates new OTP
    - Previous OTP is invalidated
    """
    service = AuthService(db)
    sent = await service.resend_otp(data.email)
    
    return MessageResponse(
        message="OTP sent successfully" if sent else "Failed to send OTP",
        success=sent
    )


@router.post("/login", response_model=LoginResponse)
async def login(
    data: LoginRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Login with email and password.
    
    - Returns access and refresh tokens
    - User must be verified
    """
    service = AuthService(db)
    user, access_token, refresh_token = await service.login(data)
    
    return LoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        user=AuthUserResponse.model_validate(user)
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh_tokens(
    data: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Refresh access and refresh tokens.
    
    - Requires valid refresh token
    - Returns new token pair
    """
    service = AuthService(db)
    access_token, refresh_token = await service.refresh_tokens(data.refresh_token)
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer"
    )


@router.post("/logout", response_model=MessageResponse)
async def logout():
    """
    Logout user.
    
    - Client should discard tokens
    - Server-side token invalidation can be added
    """
    # For JWT, logout is mainly client-side (discard tokens)
    # Could implement token blacklist for server-side invalidation
    return MessageResponse(
        message="Logged out successfully",
        success=True
    )


@router.post("/forgot-password", response_model=MessageResponse)
async def forgot_password(
    data: ForgotPasswordRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Request password reset.
    
    - Sends OTP to email for password reset
    """
    service = AuthService(db)
    sent = await service.forgot_password(data.email)
    
    return MessageResponse(
        message="Password reset OTP sent to your email" if sent else "Failed to send OTP",
        success=sent
    )


@router.post("/reset-password", response_model=MessageResponse)
async def reset_password(
    email: str,
    otp: str,
    new_password: str,
    db: AsyncSession = Depends(get_db)
):
    """
    Reset password with OTP.
    
    - Verifies OTP
    - Updates password
    """
    service = AuthService(db)
    success = await service.reset_password(email, otp, new_password)
    
    return MessageResponse(
        message="Password reset successful" if success else "Failed to reset password",
        success=success
    )

