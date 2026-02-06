"""
Report Endpoints
GET /, POST /, GET /{id}, GET /{id}/download, DELETE /{id}
"""

from fastapi import APIRouter, Depends, Query
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession
import os

from app.db.database import get_db
from app.core.security import get_current_user_id
from app.services.report_service import ReportService
from app.schemas.report import (
    ReportCreate, ReportResponse, ReportDetailResponse, ReportListResponse
)
from app.schemas.auth import MessageResponse

router = APIRouter()


@router.get("/", response_model=ReportListResponse)
async def list_reports(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    List user's reports.
    
    - Paginated
    - Most recent first
    """
    service = ReportService(db)
    return await service.list_reports(user_id, limit, offset)


@router.post("/", response_model=ReportDetailResponse, status_code=201)
async def create_report(
    data: ReportCreate,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Create a new report.
    
    - Aggregates test results
    - Generates PDF
    - Can include wellness data
    """
    service = ReportService(db)
    report = await service.create_report(user_id, data)
    return await service.get_report(user_id, report.id)


@router.get("/{report_id}", response_model=ReportDetailResponse)
async def get_report(
    report_id: int,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Get report details."""
    service = ReportService(db)
    return await service.get_report(user_id, report_id)


@router.get("/{report_id}/download")
async def download_report(
    report_id: int,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """
    Download report PDF.
    
    - Returns PDF file
    """
    service = ReportService(db)
    report_detail = await service.get_report(user_id, report_id)
    
    if not report_detail.is_ready or not report_detail.pdf_path:
        from fastapi import HTTPException, status
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Report PDF not ready"
        )
    
    if not os.path.exists(report_detail.pdf_path):
        from fastapi import HTTPException, status
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Report file not found"
        )
    
    filename = f"NeuroVerse_Report_{report_id}.pdf"
    return FileResponse(
        path=report_detail.pdf_path,
        filename=filename,
        media_type="application/pdf"
    )


@router.post("/{report_id}/regenerate", response_model=ReportDetailResponse)
async def regenerate_report(
    report_id: int,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Regenerate report PDF."""
    service = ReportService(db)
    await service.regenerate_pdf(user_id, report_id)
    return await service.get_report(user_id, report_id)


@router.delete("/{report_id}", response_model=MessageResponse)
async def delete_report(
    report_id: int,
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db)
):
    """Delete a report."""
    service = ReportService(db)
    await service.delete_report(user_id, report_id)
    return MessageResponse(message="Report deleted", success=True)
