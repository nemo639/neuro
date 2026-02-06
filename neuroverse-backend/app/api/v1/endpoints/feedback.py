"""
Feedback API Endpoints - Updated with delete restrictions
"""

from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional

from app.db.database import get_db
from app.core.security import get_current_user_id
from app.models.feedback import FeedbackCategory, FeedbackStatus
from app.schemas.feedback import (
    FeedbackCreate,
    FeedbackUpdate,
    FeedbackResponse,
    FeedbackDetailResponse,
    FeedbackListResponse,
    FeedbackSubmitResponse,
    FeedbackStats
)
from app.services.feedback_service import FeedbackService

router = APIRouter()

# ==================== USER ENDPOINTS ====================

@router.post(
    "/",
    response_model=FeedbackSubmitResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Submit Feedback",
)
async def submit_feedback(
    feedback_data: FeedbackCreate,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_current_user_id)
):
    """Submit new feedback."""
    
    try:
        feedback = await FeedbackService.create_feedback(
            db=db,
            user_id=user_id,
            feedback_data=feedback_data
        )
        
        return FeedbackSubmitResponse(
            success=True,
            message="Thank you for your feedback! We'll review it shortly.",
            feedback_id=feedback.id
        )
    except Exception as e:
        print(f"Error submitting feedback: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create feedback: {str(e)}"
        )


@router.get(
    "/my-feedbacks",
    response_model=FeedbackListResponse,
    summary="Get My Feedbacks",
)
async def get_my_feedbacks(
    page: int = Query(1, ge=1),
    per_page: int = Query(10, ge=1, le=50),
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_current_user_id)
):
    """Paginated list of user feedback."""
    
    skip = (page - 1) * per_page
    
    feedbacks, total = await FeedbackService.get_user_feedbacks(
        db=db,
        user_id=user_id,
        skip=skip,
        limit=per_page
    )
    
    total_pages = (total + per_page - 1) // per_page
    
    return FeedbackListResponse(
        feedbacks=feedbacks,
        total=total,
        page=page,
        per_page=per_page,
        total_pages=total_pages
    )


@router.get(
    "/{feedback_id}",
    response_model=FeedbackResponse,
    summary="Get Feedback Detail",
)
async def get_feedback(
    feedback_id: int,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_current_user_id)
):
    """Return a specific user's feedback."""
    
    feedback = await FeedbackService.get_feedback_by_id(db, feedback_id)
    
    if not feedback:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Feedback not found"
        )
    
    if feedback.user_id != user_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only view your own feedback"
        )
    
    return feedback


@router.delete(
    "/{feedback_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete Feedback",
)
async def delete_feedback(
    feedback_id: int,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_current_user_id)
):
    """
    Delete feedback belonging to the current user.
    
    Restrictions:
    - Can only delete within 5 minutes of submission
    - Cannot delete if status is not PENDING
    - Cannot delete if admin has added notes
    """
    
    success, error_message = await FeedbackService.delete_feedback(
        db=db,
        feedback_id=feedback_id,
        user_id=user_id
    )
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=error_message or "Cannot delete this feedback"
        )

    return None


# ==================== ADMIN ENDPOINTS ====================

@router.get(
    "/admin/all",
    response_model=FeedbackListResponse,
    summary="Get All Feedbacks (Admin)",
)
async def get_all_feedbacks(
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    category: Optional[FeedbackCategory] = Query(None),
    status_filter: Optional[FeedbackStatus] = Query(None, alias="status"),
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_current_user_id)
):
    """Admin: Get all feedbacks with filters."""
    
    skip = (page - 1) * per_page
    
    feedbacks, total = await FeedbackService.get_all_feedbacks(
        db=db,
        skip=skip,
        limit=per_page,
        category=category,
        status=status_filter
    )
    
    total_pages = (total + per_page - 1) // per_page
    
    return FeedbackListResponse(
        feedbacks=feedbacks,
        total=total,
        page=page,
        per_page=per_page,
        total_pages=total_pages
    )


@router.patch(
    "/admin/{feedback_id}",
    response_model=FeedbackDetailResponse,
    summary="Update Feedback Status (Admin)",
)
async def update_feedback(
    feedback_id: int,
    update_data: FeedbackUpdate,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_current_user_id)
):
    """Admin: Update feedback status and notes."""
    
    feedback = await FeedbackService.update_feedback_status(
        db=db,
        feedback_id=feedback_id,
        update_data=update_data
    )
    
    if not feedback:
        raise HTTPException(404, "Feedback not found")
    
    # Add user info
    response = FeedbackDetailResponse.model_validate(feedback)
    if feedback.user:
        response.user_email = feedback.user.email
        response.user_name = f"{feedback.user.first_name} {feedback.user.last_name}"
    
    return response


@router.get(
    "/admin/stats",
    response_model=FeedbackStats,
    summary="Get Feedback Statistics (Admin)",
)
async def get_feedback_stats(
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_current_user_id)
):
    """Admin: feedback summary statistics."""
    
    return await FeedbackService.get_feedback_stats(db)


@router.delete(
    "/admin/{feedback_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Force Delete Feedback (Admin)",
)
async def admin_delete_feedback(
    feedback_id: int,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(get_current_user_id)
):
    """
    Admin: Force delete any feedback regardless of restrictions.
    This bypasses all deletion rules.
    """
    
    feedback = await FeedbackService.get_feedback_by_id(db, feedback_id)
    
    if not feedback:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Feedback not found"
        )
    
    await db.delete(feedback)
    await db.commit()
    
    return None