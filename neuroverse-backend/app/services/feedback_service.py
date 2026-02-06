# ============================================================================
# FILE: app/services/feedback_service.py - Updated delete method
# ============================================================================
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, desc
from sqlalchemy.exc import SQLAlchemyError
from typing import Optional
from datetime import datetime, timedelta

from app.models.feedback import Feedback, FeedbackCategory, FeedbackStatus
from app.schemas.feedback import FeedbackCreate, FeedbackUpdate, FeedbackStats


class FeedbackService:
    """Service for managing user feedback"""

    # Define time window for allowing deletions (e.g., 5 minutes)
    DELETION_GRACE_PERIOD_MINUTES = 5
   
    @staticmethod
    async def create_feedback(
        db: AsyncSession,
        user_id: int,
        feedback_data: FeedbackCreate
    ) -> Feedback:
        """Create new feedback entry"""
        try:
            category_value = feedback_data.category
            if isinstance(category_value, str):
                category_value = FeedbackCategory(feedback_data.category.lower().strip())
            
            feedback = Feedback(
                user_id=user_id,
                category=category_value,
                rating=feedback_data.rating,
                message=feedback_data.message,
                app_version=feedback_data.app_version,
                device_info=feedback_data.device_info,
                status=FeedbackStatus.PENDING
            )
            
            db.add(feedback)
            await db.commit()
            await db.refresh(feedback)
            
            if feedback.id is None:
                raise ValueError("Feedback was not assigned an ID after commit")
            
            return feedback
            
        except SQLAlchemyError as e:
            await db.rollback()
            print(f"Database error creating feedback: {str(e)}")
            raise
        except Exception as e:
            await db.rollback()
            print(f"Unexpected error creating feedback: {str(e)}")
            raise

    @staticmethod
    async def get_feedback_by_id(db: AsyncSession, feedback_id: int) -> Optional[Feedback]:
        """Get single feedback by ID"""
        result = await db.execute(
            select(Feedback).where(Feedback.id == feedback_id)
        )
        return result.scalar_one_or_none()

    @staticmethod
    async def get_user_feedbacks(
        db: AsyncSession,
        user_id: int,
        skip: int = 0,
        limit: int = 20
    ) -> tuple[list[Feedback], int]:
        """Get all feedbacks submitted by a user"""
        count_result = await db.execute(
            select(func.count(Feedback.id)).where(Feedback.user_id == user_id)
        )
        total = count_result.scalar() or 0
        
        result = await db.execute(
            select(Feedback)
            .where(Feedback.user_id == user_id)
            .order_by(desc(Feedback.created_at))
            .offset(skip)
            .limit(limit)
        )
        feedbacks = result.scalars().all()
        
        return list(feedbacks), total

    @staticmethod
    async def get_all_feedbacks(
        db: AsyncSession,
        skip: int = 0,
        limit: int = 50,
        category: Optional[FeedbackCategory] = None,
        status: Optional[FeedbackStatus] = None
    ) -> tuple[list[Feedback], int]:
        """Get all feedbacks with optional filters (admin use)"""
        query = select(Feedback)
        
        if category:
            query = query.where(Feedback.category == category)
        if status:
            query = query.where(Feedback.status == status)
        
        count_query = select(func.count(Feedback.id))
        if category:
            count_query = count_query.where(Feedback.category == category)
        if status:
            count_query = count_query.where(Feedback.status == status)
            
        count_result = await db.execute(count_query)
        total = count_result.scalar() or 0
        
        result = await db.execute(
            query.order_by(desc(Feedback.created_at)).offset(skip).limit(limit)
        )
        feedbacks = result.scalars().all()
        
        return list(feedbacks), total

    @staticmethod
    async def update_feedback_status(
        db: AsyncSession,
        feedback_id: int,
        update_data: FeedbackUpdate
    ) -> Optional[Feedback]:
        """Update feedback status and admin notes (admin use)"""
        result = await db.execute(
            select(Feedback).where(Feedback.id == feedback_id)
        )
        feedback = result.scalar_one_or_none()
        
        if not feedback:
            return None
        
        if update_data.status:
            feedback.status = update_data.status
            if update_data.status == FeedbackStatus.RESOLVED:
                feedback.resolved_at = datetime.utcnow()
        
        if update_data.admin_notes is not None:
            feedback.admin_notes = update_data.admin_notes
        
        await db.commit()
        await db.refresh(feedback)
        return feedback

    @staticmethod
    async def delete_feedback(
        db: AsyncSession, 
        feedback_id: int, 
        user_id: int
    ) -> tuple[bool, Optional[str]]:
        """
        Delete feedback (user can only delete their own recent feedback)
        
        Returns:
            tuple: (success: bool, error_message: Optional[str])
        """
        result = await db.execute(
            select(Feedback).where(
                Feedback.id == feedback_id,
                Feedback.user_id == user_id
            )
        )
        feedback = result.scalar_one_or_none()
        
        if not feedback:
            return False, "Feedback not found or you don't have permission to delete it"
        
        # Check if feedback is within the grace period for deletion
        if feedback.created_at:
            time_since_creation = datetime.utcnow() - feedback.created_at.replace(tzinfo=None)
            grace_period = timedelta(minutes=FeedbackService.DELETION_GRACE_PERIOD_MINUTES)
            
            if time_since_creation > grace_period:
                return False, f"Feedback can only be deleted within {FeedbackService.DELETION_GRACE_PERIOD_MINUTES} minutes of submission"
        
        # Check if feedback has been reviewed or acted upon
        if feedback.status != FeedbackStatus.PENDING:
            return False, "Cannot delete feedback that has been reviewed or processed"
        
        if feedback.admin_notes:
            return False, "Cannot delete feedback that has admin notes"
        
        # All checks passed, proceed with deletion
        await db.delete(feedback)
        await db.commit()
        return True, None

    @staticmethod
    async def get_feedback_stats(db: AsyncSession) -> FeedbackStats:
        """Get feedback statistics (admin use)"""
        # Total count
        total_result = await db.execute(select(func.count(Feedback.id)))
        total = total_result.scalar() or 0
        
        # Pending count
        pending_result = await db.execute(
            select(func.count(Feedback.id)).where(Feedback.status == FeedbackStatus.PENDING)
        )
        pending = pending_result.scalar() or 0
        
        # Resolved count
        resolved_result = await db.execute(
            select(func.count(Feedback.id)).where(Feedback.status == FeedbackStatus.RESOLVED)
        )
        resolved = resolved_result.scalar() or 0
        
        # Average rating
        avg_result = await db.execute(
            select(func.avg(Feedback.rating)).where(Feedback.rating.isnot(None))
        )
        avg_rating = avg_result.scalar()
        
        # Category breakdown
        category_result = await db.execute(
            select(Feedback.category, func.count(Feedback.id))
            .group_by(Feedback.category)
        )
        category_counts = category_result.all()
        category_breakdown = {str(cat.value): count for cat, count in category_counts}
        
        return FeedbackStats(
            total_feedbacks=total,
            pending_count=pending,
            resolved_count=resolved,
            average_rating=round(float(avg_rating), 2) if avg_rating else None,
            category_breakdown=category_breakdown
        )