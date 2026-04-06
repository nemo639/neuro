"""
Report Endpoints
GET /, POST /, GET /{id}, GET /{id}/download, DELETE /{id}
"""

from fastapi import APIRouter, Depends, Query
from fastapi.responses import FileResponse, Response
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import os

from app.db.database import get_db
from app.core.security import get_current_user_id
from app.services.report_service import ReportService
from app.models.report import Report
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
    """Download report PDF — served from DB (cloud-safe)."""
    from fastapi import HTTPException, status as http_status

    # Fetch raw report to access pdf_data
    result = await db.execute(
        select(Report).where(Report.id == report_id, Report.user_id == user_id)
    )
    report = result.scalar_one_or_none()

    if not report or not report.is_ready:
        raise HTTPException(status_code=http_status.HTTP_404_NOT_FOUND, detail="Report not ready")

    # Serve from DB binary if available
    if report.pdf_data:
        filename = f"NeuroVerse_Report_{report_id}.pdf"
        return Response(
            content=report.pdf_data,
            media_type="application/pdf",
            headers={"Content-Disposition": f'attachment; filename="{filename}"'},
        )

    # Fallback: serve from filesystem (local dev)
    if report.pdf_path and not report.pdf_path.startswith("db:") and os.path.exists(report.pdf_path):
        filename = f"NeuroVerse_Report_{report_id}.pdf"
        return FileResponse(path=report.pdf_path, filename=filename, media_type="application/pdf")

    raise HTTPException(status_code=http_status.HTTP_404_NOT_FOUND, detail="Report file not found")


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
