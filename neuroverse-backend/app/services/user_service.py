"""
User Service - Profile management and dashboard data
"""

from datetime import datetime, timedelta
from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from sqlalchemy.orm import selectinload
from fastapi import HTTPException, status

from app.models.user import User
from app.models.test_session import TestSession
from app.models.test_result import TestResult
from app.schemas.user import (
    UserUpdateRequest, UserProfileResponse, UserDashboardResponse,
    CategoryScore
)


class UserService:
    """User profile and dashboard service."""
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def get_user(self, user_id: int) -> User:
        """Get user by ID."""
        result = await self.db.execute(
            select(User).where(User.id == user_id)
        )
        user = result.scalar_one_or_none()
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        return user
    
    async def update_user(self, user_id: int, data: UserUpdateRequest) -> User:
        """Update user profile."""
        user = await self.get_user(user_id)
        
        # Update only provided fields
        update_data = data.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(user, field, value)
        
        user.updated_at = datetime.utcnow()
        
        await self.db.commit()
        await self.db.refresh(user)
        
        return user
    
    async def get_profile(self, user_id: int) -> UserProfileResponse:
        """Get full user profile with stats."""
        user = await self.get_user(user_id)
        
        # Get test stats
        total_tests = await self._get_total_tests(user_id)
        last_test_date = await self._get_last_test_date(user_id)
        
        return UserProfileResponse(
            id=user.id,
            email=user.email,
            first_name=user.first_name,
            last_name=user.last_name,
            full_name=user.full_name,
            phone=user.phone,
            date_of_birth=user.date_of_birth,
            age=user.age,
            gender=user.gender,
            profile_image_path=user.profile_image_path,
            is_verified=user.is_verified,
            ad_risk_score=user.ad_risk_score or 0.0,
            pd_risk_score=user.pd_risk_score or 0.0,
            cognitive_score=user.cognitive_score or 0.0,
            speech_score=user.speech_score or 0.0,
            motor_score=user.motor_score or 0.0,
            gait_score=user.gait_score or 0.0,
            facial_score=user.facial_score or 0.0,
            ad_stage=user.ad_stage,
            pd_stage=user.pd_stage,
            total_tests=total_tests,
            last_test_date=last_test_date,
            created_at=user.created_at,
            updated_at=user.updated_at,
        )
    
    async def get_dashboard(self, user_id: int) -> UserDashboardResponse:
        """Get user dashboard data."""
        user = await self.get_user(user_id)
        
        # Get category breakdown
        categories = await self._get_category_scores(user_id, user)
        
        # Get stats
        total_tests = await self._get_total_tests(user_id)
        tests_this_week = await self._get_tests_this_week(user_id)
        last_assessment = await self._get_last_test_date(user_id)
        
        # Get risk trend (last 30 days)
        risk_trend = await self._get_risk_trend(user_id)
        
        # Determine recommended next test
        recommended = self._get_recommended_test(categories)
        
        return UserDashboardResponse(
            user_id=user.id,
            full_name=user.full_name,
            ad_risk_score=user.ad_risk_score or 0.0,
            pd_risk_score=user.pd_risk_score or 0.0,
            ad_stage=user.ad_stage,
            pd_stage=user.pd_stage,
            categories=categories,
            total_tests_completed=total_tests,
            tests_this_week=tests_this_week,
            last_assessment_date=last_assessment,
            next_recommended_test=recommended,
            risk_trend=risk_trend,
        )
    
    async def update_profile_image(self, user_id: int, image_path: str) -> User:
        """Update user's profile image."""
        user = await self.get_user(user_id)
        user.profile_image_path = image_path
        user.updated_at = datetime.utcnow()
        
        await self.db.commit()
        await self.db.refresh(user)
        
        return user
    
    # ============== PRIVATE HELPERS ==============
    
    async def _get_total_tests(self, user_id: int) -> int:
        """Get total completed test sessions."""
        result = await self.db.execute(
            select(func.count(TestSession.id)).where(
                and_(
                    TestSession.user_id == user_id,
                    TestSession.status == "completed"
                )
            )
        )
        return result.scalar() or 0
    
    async def _get_tests_this_week(self, user_id: int) -> int:
        """Get tests completed this week."""
        week_ago = datetime.utcnow() - timedelta(days=7)
        result = await self.db.execute(
            select(func.count(TestSession.id)).where(
                and_(
                    TestSession.user_id == user_id,
                    TestSession.status == "completed",
                    TestSession.completed_at >= week_ago
                )
            )
        )
        return result.scalar() or 0
    
    async def _get_last_test_date(self, user_id: int) -> Optional[datetime]:
        """Get date of last completed test."""
        result = await self.db.execute(
            select(TestSession.completed_at)
            .where(
                and_(
                    TestSession.user_id == user_id,
                    TestSession.status == "completed"
                )
            )
            .order_by(TestSession.completed_at.desc())
            .limit(1)
        )
        row = result.first()
        return row[0] if row else None
    
    async def _get_category_scores(self, user_id: int, user: User) -> List[CategoryScore]:
        """Get scores by category."""
        categories_config = [
            ("cognitive", "Cognitive", user.cognitive_score),
            ("speech", "Speech", user.speech_score),
            ("motor", "Motor", user.motor_score),
            ("gait", "Gait", user.gait_score),
            ("facial", "Facial", user.facial_score),
        ]
        
        result = []
        for cat_id, cat_name, score in categories_config:
            # Get last test date for category
            last_tested = await self._get_last_category_test(user_id, cat_id)
            tests_count = await self._get_category_test_count(user_id, cat_id)
            
            result.append(CategoryScore(
                category=cat_id,
                score=score or 0.0,
                status=self._score_to_status(score or 0.0),
                last_tested=last_tested,
                tests_completed=tests_count,
            ))
        
        return result
    
    async def _get_last_category_test(self, user_id: int, category: str) -> Optional[datetime]:
        """Get last test date for a category."""
        result = await self.db.execute(
            select(TestSession.completed_at)
            .where(
                and_(
                    TestSession.user_id == user_id,
                    TestSession.category == category,
                    TestSession.status == "completed"
                )
            )
            .order_by(TestSession.completed_at.desc())
            .limit(1)
        )
        row = result.first()
        return row[0] if row else None
    
    async def _get_category_test_count(self, user_id: int, category: str) -> int:
        """Get test count for a category."""
        result = await self.db.execute(
            select(func.count(TestSession.id)).where(
                and_(
                    TestSession.user_id == user_id,
                    TestSession.category == category,
                    TestSession.status == "completed"
                )
            )
        )
        return result.scalar() or 0
    
    async def _get_risk_trend(self, user_id: int, days: int = 30) -> List[dict]:
        """Get risk score trend over time."""
        # Get completed sessions with results in date range
        start_date = datetime.utcnow() - timedelta(days=days)
        
        result = await self.db.execute(
            select(TestSession, TestResult)
            .join(TestResult, TestSession.id == TestResult.session_id)
            .where(
                and_(
                    TestSession.user_id == user_id,
                    TestSession.status == "completed",
                    TestSession.completed_at >= start_date
                )
            )
            .order_by(TestSession.completed_at)
        )
        
        trend = []
        for session, test_result in result.all():
            trend.append({
                "date": session.completed_at.strftime("%Y-%m-%d") if session.completed_at else None,
                "ad": test_result.ad_risk_score or 0,
                "pd": test_result.pd_risk_score or 0,
                "category": session.category,
            })
        
        return trend
    
    def _score_to_status(self, score: float) -> str:
        """Convert score to status string."""
        if score >= 80:
            return "normal"
        elif score >= 60:
            return "mild"
        elif score >= 40:
            return "moderate"
        else:
            return "severe"
    
    def _get_recommended_test(self, categories: List[CategoryScore]) -> Optional[str]:
        """Determine which test to recommend next."""
        # Find category with oldest test or no tests
        oldest = None
        oldest_date = None
        
        for cat in categories:
            if cat.tests_completed == 0:
                return cat.category  # Prioritize untested categories
            
            if oldest_date is None or (cat.last_tested and cat.last_tested < oldest_date):
                oldest_date = cat.last_tested
                oldest = cat.category
        
        return oldest
