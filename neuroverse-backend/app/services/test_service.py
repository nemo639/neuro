"""
Test Service - Test sessions, items, and result management
Core business logic for test flow
"""

from datetime import datetime
from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_
from sqlalchemy.orm import selectinload
from fastapi import HTTPException, status

from app.models.user import User
from app.models.test_session import TestSession, SessionStatus
from app.models.test_item import TestItem
from app.models.test_result import TestResult
from app.services.notification_helper import notify_test_complete
from app.schemas.test_session import (
    TestSessionCreate, TestSessionResponse, TestSessionDetailResponse,
    TestDashboardResponse, CategoryTestInfo
)
from app.schemas.test_item import TestItemCreate, TestItemBatchCreate, TestItemResponse
from app.schemas.test_result import TestResultDetailResponse
from app.services.ml_service import MLService
from app.services.fusion_service import FusionService, CompositeFusionService
from app.services.xai_service import XAIService
import numpy as np


def _sanitize_for_json(obj):
    """Recursively convert numpy types to native Python types for JSON serialization."""
    if isinstance(obj, dict):
        return {k: _sanitize_for_json(v) for k, v in obj.items()}
    if isinstance(obj, (list, tuple)):
        return [_sanitize_for_json(v) for v in obj]
    if isinstance(obj, (np.integer,)):
        return int(obj)
    if isinstance(obj, (np.floating,)):
        return float(obj)
    if isinstance(obj, np.ndarray):
        return obj.tolist()
    if isinstance(obj, np.bool_):
        return bool(obj)
    return obj


# Category configuration
CATEGORY_CONFIG = {
    "cognitive": {
        "display_name": "Cognitive & Memory",
        "description": "Tests for memory, attention, and executive function",
        "mini_tests": ["stroop", "nback", "word_recall", "clock_drawing", "trail_making"],
        "estimated_duration": "18-22 min"
    },
    "speech": {
        "display_name": "Speech & Language",
        "description": "Tests for speech patterns and language processing",
        "mini_tests": ["story_recall", "sustained_vowel", "picture_description"],
        "estimated_duration": "8-12 min"
    },
    "motor": {
        "display_name": "Motor Functions",
        "description": "Tests for fine motor control and coordination",
        "mini_tests": ["resting_tremor", "spiral_drawing", "meander_drawing"],
        "estimated_duration": "8-10 min"
    },
    "facial": {
        "display_name": "Facial Analysis",
        "description": "Facial expression and movement analysis for PD screening",
        "mini_tests": ["facial_analysis"],
        "estimated_duration": "2-3 min"
    }
}


class TestService:
    """Test session and result management service."""
    
    def __init__(self, db: AsyncSession):
        self.db = db
        self.ml_service = MLService()
        self.fusion_service = FusionService()
        self.xai_service = XAIService()
    
    # ============== SESSION MANAGEMENT ==============
    
    async def create_session(self, user_id: int, data: TestSessionCreate) -> TestSession:
        """Create a new test session."""
        # Check for existing in-progress session
        existing = await self.db.execute(
            select(TestSession).where(
                and_(
                    TestSession.user_id == user_id,
                    TestSession.status.in_(["created", "in_progress"])
                )
            )
        )
        if existing.scalars().first():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You have an incomplete test session. Please complete or cancel it first."
            )
        
        session = TestSession(
            user_id=user_id,
            category=data.category.value,
            status=SessionStatus.CREATED.value,
        )
        
        self.db.add(session)
        await self.db.commit()
        await self.db.refresh(session)
        
        return session
    
    async def start_session(self, user_id: int, session_id: int) -> TestSession:
        """Start a test session."""
        session = await self._get_session(session_id, user_id)
        
        if session.status != SessionStatus.CREATED.value:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Session already started or completed"
            )
        
        session.status = SessionStatus.IN_PROGRESS.value
        session.started_at = datetime.utcnow()
        
        await self.db.commit()
        await self.db.refresh(session)
        
        return session
    
    async def complete_session(self, user_id: int, session_id: int) -> TestResultDetailResponse:
        """
        Complete a test session and process results.
        This triggers ML feature extraction, fusion, and XAI generation.
        """
        session = await self._get_session(session_id, user_id, load_items=True)
        
        if session.status == SessionStatus.COMPLETED.value:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Session already completed"
            )
        
        if not session.test_items or len(session.test_items) == 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No test items in session. Please complete at least one test."
            )
        
        # 1. Extract features from all test items
        extracted_features = await self.ml_service.extract_features(
            category=session.category,
            test_items=session.test_items
        )

        # 2. Run model inference to get risk predictions
        predictions = await self.ml_service.predict(
            category=session.category,
            features=extracted_features
        )

        # 3. Calculate clinical risk scores using fusion service
        risk_scores = await self.fusion_service.calculate_risk_scores(
            category=session.category,
            features=extracted_features,
            predictions=predictions
        )

        # 4. Generate XAI explanations
        xai_explanation = await self.xai_service.generate_explanation(
            category=session.category,
            features=extracted_features,
            risk_scores=risk_scores,
            predictions=predictions
        )

        # 5. Create test result (sanitize numpy types for JSON serialization)
        test_result = TestResult(
            session_id=session.id,
            ad_risk_score=float(risk_scores["ad_risk"]),
            pd_risk_score=float(risk_scores["pd_risk"]),
            category_score=float(risk_scores["category_score"]),
            stage=risk_scores.get("stage"),
            severity=risk_scores.get("severity"),
            extracted_features=_sanitize_for_json(extracted_features),
            xai_explanation=_sanitize_for_json(xai_explanation),
        )
        
        self.db.add(test_result)
        
        # 5. Update session status
        session.status = SessionStatus.COMPLETED.value
        session.completed_at = datetime.utcnow()
        
        # 6. Update user's scores
        await self._update_user_scores(user_id, session.category, risk_scores)
        
        await self.db.commit()
        await self.db.refresh(test_result)

        # Notification for test completion
        try:
            await notify_test_complete(self.db, user_id, session.category, session.id)
            await self.db.commit()
        except Exception:
            pass

        return TestResultDetailResponse(
            id=test_result.id,
            session_id=test_result.session_id,
            ad_risk_score=test_result.ad_risk_score,
            pd_risk_score=test_result.pd_risk_score,
            category_score=test_result.category_score,
            stage=test_result.stage,
            severity=test_result.severity,
            extracted_features=test_result.extracted_features,
            xai_explanation=xai_explanation,
            category=session.category,
            items_processed=len(session.test_items),
            created_at=test_result.created_at,
        )
    
    async def cancel_session(self, user_id: int, session_id: int) -> TestSession:
        """Cancel a test session."""
        session = await self._get_session(session_id, user_id)
        
        if session.status == SessionStatus.COMPLETED.value:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot cancel completed session"
            )
        
        session.status = SessionStatus.CANCELLED.value
        
        await self.db.commit()
        await self.db.refresh(session)
        
        return session
    
    async def get_session(self, user_id: int, session_id: int) -> TestSessionDetailResponse:
        """Get session details with items and result."""
        session = await self._get_session(session_id, user_id, load_items=True, load_result=True)
        
        return TestSessionDetailResponse(
            id=session.id,
            user_id=session.user_id,
            category=session.category,
            status=session.status,
            started_at=session.started_at,
            completed_at=session.completed_at,
            created_at=session.created_at,
            test_items=[TestItemResponse.model_validate(item) for item in session.test_items],
            test_result=session.test_result,
        )
    
    async def list_sessions(
        self, 
        user_id: int, 
        category: Optional[str] = None,
        status: Optional[str] = None,
        limit: int = 20,
        offset: int = 0
    ) -> List[TestSession]:
        """List user's test sessions."""
        query = select(TestSession).where(TestSession.user_id == user_id)
        
        if category:
            query = query.where(TestSession.category == category)
        if status:
            query = query.where(TestSession.status == status)
        
        query = query.order_by(TestSession.created_at.desc()).limit(limit).offset(offset)
        
        result = await self.db.execute(query)
        return list(result.scalars().all())
    
    async def get_latest_results_with_xai(self, user_id: int) -> dict:
        """Get latest completed test result per category with full XAI explanations."""
        categories = ["cognitive", "speech", "motor", "facial"]
        results = {}

        for cat in categories:
            query = (
                select(TestResult)
                .join(TestSession, TestResult.session_id == TestSession.id)
                .where(
                    and_(
                        TestSession.user_id == user_id,
                        TestSession.category == cat,
                        TestSession.status == SessionStatus.COMPLETED.value,
                    )
                )
                .order_by(TestResult.created_at.desc())
                .limit(1)
            )
            result = await self.db.execute(query)
            test_result = result.scalar_one_or_none()

            if test_result:
                results[cat] = {
                    "id": test_result.id,
                    "session_id": test_result.session_id,
                    "ad_risk_score": test_result.ad_risk_score,
                    "pd_risk_score": test_result.pd_risk_score,
                    "category_score": test_result.category_score,
                    "stage": test_result.stage,
                    "severity": test_result.severity,
                    "extracted_features": test_result.extracted_features,
                    "xai_explanation": test_result.xai_explanation,
                    "created_at": str(test_result.created_at) if test_result.created_at else None,
                }

        return results

    # ============== TEST ITEMS ==============
    
    async def add_test_item(
        self, 
        user_id: int, 
        session_id: int, 
        data: TestItemCreate
    ) -> TestItem:
        """Add a test item to a session."""
        session = await self._get_session(session_id, user_id)
        
        if session.status == SessionStatus.COMPLETED.value:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot add items to completed session"
            )
        
        # Auto-start session if not started
        if session.status == SessionStatus.CREATED.value:
            session.status = SessionStatus.IN_PROGRESS.value
            session.started_at = datetime.utcnow()
        
        item = TestItem(
            session_id=session_id,
            item_name=data.item_name,
            item_type=data.item_type,
            raw_data=data.raw_data,
            raw_value=data.raw_value,
            processed_value=data.processed_value,
            started_at=data.started_at,
            completed_at=data.completed_at or datetime.utcnow(),
        )
        
        self.db.add(item)
        await self.db.commit()
        await self.db.refresh(item)
        
        return item
    
    async def add_test_items_batch(
        self, 
        user_id: int, 
        session_id: int, 
        data: TestItemBatchCreate
    ) -> List[TestItem]:
        """Add multiple test items at once."""
        session = await self._get_session(session_id, user_id)
        
        if session.status == SessionStatus.COMPLETED.value:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cannot add items to completed session"
            )
        
        if session.status == SessionStatus.CREATED.value:
            session.status = SessionStatus.IN_PROGRESS.value
            session.started_at = datetime.utcnow()
        
        items = []
        for item_data in data.items:
            item = TestItem(
                session_id=session_id,
                item_name=item_data.item_name,
                item_type=item_data.item_type,
                raw_data=item_data.raw_data,
                raw_value=item_data.raw_value,
                processed_value=item_data.processed_value,
                started_at=item_data.started_at,
                completed_at=item_data.completed_at or datetime.utcnow(),
            )
            self.db.add(item)
            items.append(item)
        
        await self.db.commit()
        
        for item in items:
            await self.db.refresh(item)
        
        return items
    
    # ============== DASHBOARD ==============
    
    async def get_dashboard(self, user_id: int) -> TestDashboardResponse:
        """Get test dashboard data."""
        # Get user for current scores
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        
        # Get session counts
        total_sessions = await self._count_sessions(user_id)
        completed_sessions = await self._count_sessions(user_id, status="completed")
        
        # Get in-progress session
        in_progress = await self._get_in_progress_session(user_id)
        
        # Build category info
        categories = []
        for cat_id, config in CATEGORY_CONFIG.items():
            last_completed = await self._get_last_category_session(user_id, cat_id)
            total_cat = await self._count_sessions(user_id, category=cat_id, status="completed")
            
            current_score = None
            if user:
                score_field = f"{cat_id}_score"
                current_score = getattr(user, score_field, None)
            
            categories.append(CategoryTestInfo(
                category=cat_id,
                display_name=config["display_name"],
                description=config["description"],
                mini_tests=config["mini_tests"],
                estimated_duration=config["estimated_duration"],
                last_completed=last_completed,
                total_completed=total_cat,
                current_score=current_score,
            ))
        
        # Determine recommendation
        recommended = self._get_recommended_category(categories)
        
        return TestDashboardResponse(
            user_id=user_id,
            total_sessions=total_sessions,
            completed_sessions=completed_sessions,
            categories=categories,
           in_progress_session=TestSessionResponse(
    id=in_progress.id,
    user_id=in_progress.user_id,
    category=in_progress.category,
    status=in_progress.status,
    started_at=in_progress.started_at,
    completed_at=in_progress.completed_at,
    created_at=in_progress.created_at,
    items_count=0
) if in_progress else None,
            recommended_category=recommended,
            recommendation_reason="Based on your test history" if recommended else None,
        )
    
    # ============== PRIVATE HELPERS ==============
    
    async def _get_session(
        self, 
        session_id: int, 
        user_id: int,
        load_items: bool = False,
        load_result: bool = False
    ) -> TestSession:
        """Get session by ID, verify ownership."""
        query = select(TestSession).where(
            and_(
                TestSession.id == session_id,
                TestSession.user_id == user_id
            )
        )
        
        if load_items:
            query = query.options(selectinload(TestSession.test_items))
        if load_result:
            query = query.options(selectinload(TestSession.test_result))
        
        result = await self.db.execute(query)
        session = result.scalar_one_or_none()
        
        if not session:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Test session not found"
            )
        
        return session
    
    async def _update_user_scores(self, user_id: int, category: str, risk_scores: dict):
        """
        Update user's overall scores after test completion.

        Queries actual ad_risk_score and pd_risk_score from the test_results
        table for each category, then applies weighted fusion using
        CompositeFusionService weights (single source of truth).
        AD and PD risks are tracked SEPARATELY — never mixed via max().
        """
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user:
            return

        # 1. Update the per-category health score
        score_field = f"{category}_score"
        setattr(user, score_field, risk_scores["category_score"])

        # 2. Fetch actual ad_risk / pd_risk per category from test_results
        #    (NOT derived from category_score — these are separate signals)
        cat_ad_risks = {}
        cat_pd_risks = {}
        for cat in ("cognitive", "speech", "motor", "facial"):
            if cat == category:
                # Use current session's values directly (not yet committed)
                cat_ad_risks[cat] = float(risk_scores.get("ad_risk", 0))
                cat_pd_risks[cat] = float(risk_scores.get("pd_risk", 0))
            else:
                # Query latest completed test_result for this category
                query = (
                    select(TestResult.ad_risk_score, TestResult.pd_risk_score)
                    .join(TestSession, TestResult.session_id == TestSession.id)
                    .where(
                        and_(
                            TestSession.user_id == user_id,
                            TestSession.category == cat,
                            TestSession.status == SessionStatus.COMPLETED.value,
                        )
                    )
                    .order_by(TestResult.created_at.desc())
                    .limit(1)
                )
                res = await self.db.execute(query)
                row = res.first()
                if row and row[0] is not None:
                    cat_ad_risks[cat] = float(row[0])
                    cat_pd_risks[cat] = float(row[1] or 0)

        # 3. Weighted fusion using CompositeFusionService weights (single source of truth)
        WEIGHTS_AD = CompositeFusionService.WEIGHTS_AD
        WEIGHTS_PD = CompositeFusionService.WEIGHTS_PD

        # AD fusion — uses per-category AD risk values separately
        ad_num, ad_den = 0.0, 0.0
        for cat, w in WEIGHTS_AD.items():
            if cat in cat_ad_risks:
                ad_num += cat_ad_risks[cat] * w
                ad_den += w
        fused_ad = (ad_num / ad_den) if ad_den > 0 else risk_scores.get("ad_risk", 0)

        # PD fusion — uses per-category PD risk values separately
        pd_num, pd_den = 0.0, 0.0
        for cat, w in WEIGHTS_PD.items():
            if cat in cat_pd_risks:
                pd_num += cat_pd_risks[cat] * w
                pd_den += w
        fused_pd = (pd_num / pd_den) if pd_den > 0 else risk_scores.get("pd_risk", 0)

        user.ad_risk_score = round(fused_ad, 2)
        user.pd_risk_score = round(fused_pd, 2)
        user.ad_stage = risk_scores.get("ad_stage")
        user.pd_stage = risk_scores.get("pd_stage")
        user.updated_at = datetime.utcnow()
    
    async def _count_sessions(
        self, 
        user_id: int, 
        category: Optional[str] = None,
        status: Optional[str] = None
    ) -> int:
        """Count sessions with filters."""
        from sqlalchemy import func
        
        query = select(func.count(TestSession.id)).where(TestSession.user_id == user_id)
        
        if category:
            query = query.where(TestSession.category == category)
        if status:
            query = query.where(TestSession.status == status)
        
        result = await self.db.execute(query)
        return result.scalar() or 0
    
    async def _get_in_progress_session(self, user_id: int) -> Optional[TestSession]:
        """Get current in-progress session."""
        result = await self.db.execute(
            select(TestSession).where(
                and_(
                    TestSession.user_id == user_id,
                    TestSession.status.in_(["created", "in_progress"])
                )
            ).limit(1)
        )
        return result.scalars().first()
    
    async def _get_last_category_session(self, user_id: int, category: str) -> Optional[datetime]:
        """Get last completed session date for category."""
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
    
    def _get_recommended_category(self, categories: List[CategoryTestInfo]) -> Optional[str]:
        """Determine recommended test category."""
        # Prioritize untested categories
        for cat in categories:
            if cat.total_completed == 0:
                return cat.category
        
        # Then oldest tested
        oldest = None
        oldest_date = None
        for cat in categories:
            if oldest_date is None or (cat.last_completed and cat.last_completed < oldest_date):
                oldest_date = cat.last_completed
                oldest = cat.category
        
        return oldest
