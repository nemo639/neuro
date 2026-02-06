"""
Wellness Endpoints
GET /dashboard, POST /data, GET /history, GET /{id}, PATCH /{id}
"""

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.core.security import get_current_user_id
from app.services.wellness_service import WellnessService
from app.schemas.wellness import (
    WellnessEntryCreate, WellnessEntryUpdate, WellnessEntryResponse,
    WellnessDashboardResponse, WellnessHistoryResponse
)

router = APIRouter()


@router.get("/dashboard", response_model=WellnessDashboardResponse)
async def get_wellness_dashboard(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Get wellness dashboard.
    
    - Today's entry status
    - Weekly averages
    - Metrics and trends
    - Recommendations
    """
    service = WellnessService(db)
    return await service.get_dashboard(user_id)


@router.post("/data", response_model=WellnessEntryResponse, status_code=201)
async def create_wellness_entry(
    data: WellnessEntryCreate,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Log daily wellness data.
    
    - One entry per day
    - All fields optional
    """
    service = WellnessService(db)
    entry = await service.create_entry(user_id, data)
    return WellnessEntryResponse.model_validate(entry)


@router.get("/history", response_model=WellnessHistoryResponse)
async def get_wellness_history(
    days: int = Query(30, ge=1, le=365),
    limit: int = Query(100, ge=1, le=365),
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Get wellness history.
    
    - Daily entries for specified period
    - Summary data for charts
    """
    service = WellnessService(db)
    return await service.get_history(user_id, days, limit)


@router.get("/today", response_model=WellnessEntryResponse)
async def get_today_entry(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Get today's wellness entry if exists."""
    service = WellnessService(db)
    entry = await service.get_today_entry(user_id)
    if not entry:
        from fastapi import HTTPException, status
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No wellness entry for today"
        )
    return WellnessEntryResponse.model_validate(entry)


@router.get("/{entry_id}", response_model=WellnessEntryResponse)
async def get_wellness_entry(
    entry_id: int,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Get a specific wellness entry."""
    service = WellnessService(db)
    entry = await service.get_entry(user_id, entry_id)
    return WellnessEntryResponse.model_validate(entry)


@router.patch("/{entry_id}", response_model=WellnessEntryResponse)
async def update_wellness_entry(
    entry_id: int,
    data: WellnessEntryUpdate,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Update a wellness entry."""
    service = WellnessService(db)
    entry = await service.update_entry(user_id, entry_id, data)
    return WellnessEntryResponse.model_validate(entry)
