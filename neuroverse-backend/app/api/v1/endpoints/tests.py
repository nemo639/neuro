"""
Test Endpoints
GET /dashboard, POST /, GET /, GET /{id}, POST /{id}/start, POST /{id}/items,
POST /{id}/items/batch, POST /{id}/complete, POST /{id}/audio, DELETE /{id}
"""

import os
import uuid

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional

from app.db.database import get_db
from app.core.config import settings
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


@router.get("/latest-results")
async def get_latest_results_with_xai(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Get latest test result per category with full XAI explanations."""
    service = TestService(db)
    return await service.get_latest_results_with_xai(user_id)


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


@router.post("/{session_id}/audio")
async def upload_audio(
    session_id: int,
    file: UploadFile = File(...),
    item_name: str = Query(..., description="Test item name: story_recall, sustained_vowel, picture_description"),
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Upload an audio recording for a speech test item.

    The returned ``audio_url`` should be stored in the test item's
    ``raw_data.server_audio_path`` so the speech extractor can find it
    during feature extraction.
    """
    # Validate content type
    if file.content_type not in settings.ALLOWED_AUDIO_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported audio type: {file.content_type}. "
                   f"Allowed: {settings.ALLOWED_AUDIO_TYPES}",
        )

    content = await file.read()
    if len(content) > settings.MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="File too large (max 10 MB)")

    # Determine extension
    ext = (file.filename or "audio.wav").rsplit(".", 1)[-1] if file.filename else "wav"
    filename = f"speech_{user_id}_{session_id}_{item_name}_{uuid.uuid4().hex[:8]}.{ext}"

    audio_dir = os.path.join(settings.UPLOAD_DIR, "audio")
    os.makedirs(audio_dir, exist_ok=True)

    filepath = os.path.join(audio_dir, filename)
    with open(filepath, "wb") as f:
        f.write(content)

    relative_path = f"audio/{filename}"

    return {
        "success": True,
        "audio_url": f"/uploads/{relative_path}",
        "server_audio_path": relative_path,
        "filename": filename,
        "size_bytes": len(content),
    }


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
