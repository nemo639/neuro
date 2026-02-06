"""
User Endpoints
GET /me, PATCH /me, GET /dashboard, POST /profile-image
"""

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
import os
import uuid
from datetime import datetime

from app.db.database import get_db
from app.core.security import get_current_user_id
from app.core.config import settings
from app.services.user_service import UserService
from app.schemas.user import (
    UserUpdateRequest, UserProfileResponse, UserDashboardResponse
)
from app.schemas.auth import AuthUserResponse

router = APIRouter()


@router.get("/me", response_model=AuthUserResponse)
async def get_current_user(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Get current authenticated user.
    
    - Returns basic user data
    """
    service = UserService(db)
    user = await service.get_user(user_id)
    return AuthUserResponse.model_validate(user)


@router.patch("/me", response_model=AuthUserResponse)
async def update_current_user(
    data: UserUpdateRequest,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Update current user profile.
    
    - Partial update supported
    - Cannot change email
    """
    service = UserService(db)
    user = await service.update_user(user_id, data)
    return AuthUserResponse.model_validate(user)


@router.get("/profile", response_model=UserProfileResponse)
async def get_profile(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Get full user profile with stats.
    
    - Includes test statistics
    - Includes risk scores
    """
    service = UserService(db)
    return await service.get_profile(user_id)


@router.get("/dashboard", response_model=UserDashboardResponse)
async def get_dashboard(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Get user dashboard data.
    
    - Risk scores and trends
    - Category breakdown
    - Recommendations
    """
    service = UserService(db)
    return await service.get_dashboard(user_id)


@router.post("/profile-image", response_model=AuthUserResponse)
async def upload_profile_image(
    file: UploadFile = File(...),
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Upload profile image.
    
    - Accepts JPEG, PNG, WebP
    - Max size: 10MB
    """
    # Validate file type
    if file.content_type not in settings.ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid file type. Allowed: {settings.ALLOWED_IMAGE_TYPES}"
        )
    
    # Read file content
    content = await file.read()
    
    # Validate file size
    if len(content) > settings.MAX_FILE_SIZE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File too large. Max size: {settings.MAX_FILE_SIZE // (1024*1024)}MB"
        )
    
    # Generate unique filename
    ext = file.filename.split(".")[-1] if "." in file.filename else "jpg"
    filename = f"profile_{user_id}_{uuid.uuid4().hex[:8]}.{ext}"
    
    # Ensure directory exists
    profile_dir = os.path.join(settings.UPLOAD_DIR, "profiles")
    os.makedirs(profile_dir, exist_ok=True)
    
    # Save file
    filepath = os.path.join(profile_dir, filename)
    with open(filepath, "wb") as f:
        f.write(content)
    
    # Update user
    service = UserService(db)
    relative_path = f"profiles/{filename}"
    user = await service.update_profile_image(user_id, relative_path)
    
    return AuthUserResponse.model_validate(user)

@router.delete("/profile-image", response_model=AuthUserResponse)
async def delete_profile_image(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Delete profile image.
    - Removes file from storage
    - Clears profile_image_path in DB
    """
    service = UserService(db)
    user = await service.get_user(user_id)

    # If no image, return same user
    if not user.profile_image_path:
        return AuthUserResponse.model_validate(user)

    # Delete physical file (optional)
    filepath = os.path.join(settings.UPLOAD_DIR, user.profile_image_path)
    if os.path.exists(filepath):
        os.remove(filepath)

    # Clear DB field
    updated = await service.update_profile_image(user_id, None)

    return AuthUserResponse.model_validate(updated)
