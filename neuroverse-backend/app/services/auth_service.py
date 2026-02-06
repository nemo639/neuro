"""
Authentication Service - Registration, Login, OTP, Password Reset
"""

from datetime import datetime, timedelta
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from fastapi import HTTPException, status

from app.models.user import User
from app.schemas.auth import (
    RegisterRequest, LoginRequest, AuthUserResponse, 
    VerifyOTPRequest, ForgotPasswordRequest
)
from app.core.security import (
    get_password_hash, verify_password,
    create_access_token, create_refresh_token,
    generate_otp, decode_token
)
from app.core.config import settings
from app.services.email_service import EmailService


class AuthService:
    """Authentication service for user management."""
    
    def __init__(self, db: AsyncSession):
        self.db = db
        self.email_service = EmailService()
    
    async def register(self, data: RegisterRequest) -> User:
        """Register a new user and send OTP."""
        # Check if email exists
        existing = await self.db.execute(
            select(User).where(User.email == data.email)
        )
        if existing.scalar_one_or_none():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email already registered"
            )
        
        # Create user
        user = User(
            email=data.email,
            password_hash=get_password_hash(data.password),
            first_name=data.first_name,
            last_name=data.last_name,
            phone=data.phone,
            date_of_birth=data.date_of_birth,
            gender=data.gender,
            is_verified=False,
        )
        
        # Generate OTP
        otp = generate_otp()
        user.otp_code = otp
        user.otp_expires_at = datetime.utcnow() + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)
        
        self.db.add(user)
        await self.db.commit()
        await self.db.refresh(user)
        
        # Send OTP email (async, don't wait)
        try:
            await self.email_service.send_otp_email(user.email, otp, user.first_name)
        except Exception as e:
            print(f"Failed to send OTP email: {e}")
        
        return user
    
    async def verify_otp(self, data: VerifyOTPRequest) -> User:
        """Verify OTP and activate user."""
        user = await self._get_user_by_email(data.email)
        
        if user.is_verified:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User already verified"
            )
        
        if not user.otp_code or user.otp_code != data.otp:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid OTP"
            )
        
        if user.otp_expires_at and user.otp_expires_at < datetime.utcnow():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="OTP expired"
            )
        
        # Verify user
        user.is_verified = True
        user.otp_code = None
        user.otp_expires_at = None
        
        await self.db.commit()
        await self.db.refresh(user)
        
        return user
    
    async def resend_otp(self, email: str) -> bool:
        """Resend OTP to user."""
        user = await self._get_user_by_email(email)
        
        if user.is_verified:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User already verified"
            )
        
        # Generate new OTP
        otp = generate_otp()
        user.otp_code = otp
        user.otp_expires_at = datetime.utcnow() + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)
        
        await self.db.commit()
        
        # Send OTP email
        try:
            await self.email_service.send_otp_email(user.email, otp, user.first_name)
            return True
        except Exception as e:
            print(f"Failed to send OTP email: {e}")
            return False
    
    async def login(self, data: LoginRequest) -> tuple[User, str, str]:
        """Authenticate user and return tokens."""
        user = await self._get_user_by_email(data.email)
        
        if not verify_password(data.password, user.password_hash):
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password"
            )
        
        if not user.is_verified:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Please verify your email first"
            )
        
        # Generate tokens
        access_token = create_access_token({"sub": str(user.id)})
        refresh_token = create_refresh_token({"sub": str(user.id)})
        
        return user, access_token, refresh_token
    
    async def refresh_tokens(self, refresh_token: str) -> tuple[str, str]:
        """Refresh access and refresh tokens."""
        payload = decode_token(refresh_token)
        
        if not payload or payload.get("type") != "refresh":
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid refresh token"
            )
        
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token payload"
            )
        
        # Verify user exists
        result = await self.db.execute(select(User).where(User.id == int(user_id)))
        user = result.scalar_one_or_none()
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        # Generate new tokens
        new_access = create_access_token({"sub": str(user.id)})
        new_refresh = create_refresh_token({"sub": str(user.id)})
        
        return new_access, new_refresh
    
    async def forgot_password(self, email: str) -> bool:
        """Send password reset OTP."""
        user = await self._get_user_by_email(email)
        
        # Generate OTP for reset
        otp = generate_otp()
        user.otp_code = otp
        user.otp_expires_at = datetime.utcnow() + timedelta(minutes=settings.OTP_EXPIRE_MINUTES)
        
        await self.db.commit()
        
        # Send reset email
        try:
            await self.email_service.send_password_reset_email(user.email, otp, user.first_name)
            return True
        except Exception as e:
            print(f"Failed to send reset email: {e}")
            return False
    
    async def reset_password(self, email: str, otp: str, new_password: str) -> bool:
        """Reset password with OTP verification."""
        user = await self._get_user_by_email(email)
        
        if not user.otp_code or user.otp_code != otp:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid OTP"
            )
        
        if user.otp_expires_at and user.otp_expires_at < datetime.utcnow():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="OTP expired"
            )
        
        # Update password
        user.password_hash = get_password_hash(new_password)
        user.otp_code = None
        user.otp_expires_at = None
        
        await self.db.commit()
        return True
    
    async def _get_user_by_email(self, email: str) -> User:
        """Get user by email or raise 404."""
        result = await self.db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        return user
    
    async def get_user_by_id(self, user_id: int) -> User:
        """Get user by ID or raise 404."""
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        return user
