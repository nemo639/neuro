"""
Test Endpoints
GET /dashboard, POST /, GET /, GET /{id}, POST /{id}/start, POST /{id}/items, POST /{id}/items/batch, POST /{id}/complete, DELETE /{id}
"""

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional

from app.db.database import get_db
from app.core.security import get_current_user_id
from app.services.test_service import TestService
from app.schemas.test_session import (
    TestSessionCreate, TestSessionResponse, TestSessionDetailResponse,
    TestSessionListResponse, TestDashboardResponse
)
from app.schemas.test_item import TestItemCreate, TestItemBatchCreate, TestItemResponse
from app.schemas.test_result import TestResultDetailResponse
from app.schemas.auth import MessageResponse

router = APIRouter()


@router.get("/dashboard", response_model=TestDashboardResponse)
async def get_test_dashboard(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Get test dashboard with categories and status."""
    service = TestService(db)
    return await service.get_dashboard(user_id)


@router.post("/", response_model=TestSessionResponse, status_code=201)
async def create_test_session(
    data: TestSessionCreate,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Create a new test session for a category."""
    service = TestService(db)
    session = await service.create_session(user_id, data)
    return TestSessionResponse.model_validate(session)


@router.get("/", response_model=TestSessionListResponse)
async def list_test_sessions(
    category: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """List user's test sessions with optional filters."""
    service = TestService(db)
    sessions = await service.list_sessions(user_id, category, status, limit, offset)
    return TestSessionListResponse(
        sessions=[TestSessionResponse.model_validate(s) for s in sessions],
        total=len(sessions),
        page=(offset // limit) + 1,
        page_size=limit
    )


@router.get("/{session_id}", response_model=TestSessionDetailResponse)
async def get_test_session(
    session_id: int,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Get test session details with items and result."""
    service = TestService(db)
    return await service.get_session(user_id, session_id)


@router.post("/{session_id}/start", response_model=TestSessionResponse)
async def start_test_session(
    session_id: int,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Start a test session."""
    service = TestService(db)
    session = await service.start_session(user_id, session_id)
    return TestSessionResponse.model_validate(session)


@router.post("/{session_id}/items", response_model=TestItemResponse, status_code=201)
async def add_test_item(
    session_id: int,
    data: TestItemCreate,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Add a test item (mini-test result) to session.
    
    Example raw_data for different tests:
    - Stroop: {"responses": [...], "times": [...], "total_correct": 27, "total_errors": 3}
    - N-Back: {"level": 2, "accuracy": 0.78, "hits": 20, "false_alarms": 5}
    - Spiral: {"coordinates": [[x,y,t]...], "tremor_detected": false, "duration_ms": 45000}
    """
    service = TestService(db)
    item = await service.add_test_item(user_id, session_id, data)
    return TestItemResponse.model_validate(item)


@router.post("/{session_id}/items/batch", response_model=list[TestItemResponse], status_code=201)
async def add_test_items_batch(
    session_id: int,
    data: TestItemBatchCreate,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Add multiple test items at once."""
    service = TestService(db)
    items = await service.add_test_items_batch(user_id, session_id, data)
    return [TestItemResponse.model_validate(i) for i in items]


@router.post("/{session_id}/complete", response_model=TestResultDetailResponse)
async def complete_test_session(
    session_id: int,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Complete test session and get ML results.
    
    This triggers:
    1. Feature extraction from all test items
    2. Risk score calculation via ML fusion
    3. XAI explanation generation
    4. User score updates
    
    Returns complete result with XAI explanation.
    """
    service = TestService(db)
    return await service.complete_session(user_id, session_id)


@router.delete("/{session_id}", response_model=MessageResponse)
async def cancel_test_session(
    session_id: int,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Cancel an incomplete test session."""
    service = TestService(db)
    await service.cancel_session(user_id, session_id)
    return MessageResponse(message="Session cancelled", success=True)
