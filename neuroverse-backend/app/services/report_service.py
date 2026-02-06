"""
Report Service - PDF report generation
"""

from datetime import datetime, timedelta
from typing import Optional, List
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func
from sqlalchemy.orm import selectinload
from fastapi import HTTPException, status
import os

from app.models.user import User
from app.models.report import Report
from app.models.test_session import TestSession
from app.models.test_result import TestResult
from app.schemas.report import (
    ReportCreate, ReportResponse, ReportDetailResponse,
    ReportListResponse, ReportSessionInfo
)
from app.core.config import settings


class ReportService:
    """Report generation and management service."""
    
    def __init__(self, db: AsyncSession):
        self.db = db
    
    async def create_report(self, user_id: int, data: ReportCreate) -> Report:
        """Create a new report."""
        # Get user for current scores
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        
        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="User not found"
            )
        
        # Determine sessions to include
        sessions = await self._get_sessions_for_report(
            user_id=user_id,
            session_ids=data.session_ids,
            category=data.category,
            date_start=data.date_range_start,
            date_end=data.date_range_end,
        )
        
        if not sessions:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No completed test sessions found for the specified criteria"
            )
        
        # Generate title if not provided
        title = data.title or self._generate_title(data.report_type, len(sessions))
        
        # Create report
        report = Report(
            user_id=user_id,
            title=title,
            report_type=data.report_type.value,
            sessions_included=[s.id for s in sessions],
            tests_count=len(sessions),
            ad_risk_score=user.ad_risk_score or 0.0,
            pd_risk_score=user.pd_risk_score or 0.0,
            cognitive_score=user.cognitive_score,
            speech_score=user.speech_score,
            motor_score=user.motor_score,
            gait_score=user.gait_score,
            facial_score=user.facial_score,
            ad_stage=user.ad_stage,
            pd_stage=user.pd_stage,
            include_wellness=data.include_wellness,
            date_range_start=datetime.combine(data.date_range_start, datetime.min.time()) if data.date_range_start else None,
            date_range_end=datetime.combine(data.date_range_end, datetime.max.time()) if data.date_range_end else None,
            is_ready=False,
        )
        
        self.db.add(report)
        await self.db.commit()
        await self.db.refresh(report)
        
        # Generate PDF (async in background ideally)
        await self._generate_pdf(report, user, sessions)
        
        return report
    
    async def get_report(self, user_id: int, report_id: int) -> ReportDetailResponse:
        """Get report details."""
        report = await self._get_report(report_id, user_id)
        
        # Get session info
        sessions_info = []
        if report.sessions_included:
            result = await self.db.execute(
                select(TestSession, TestResult)
                .outerjoin(TestResult, TestSession.id == TestResult.session_id)
                .where(TestSession.id.in_(report.sessions_included))
            )
            
            for session, test_result in result.all():
                sessions_info.append(ReportSessionInfo(
                    session_id=session.id,
                    category=session.category,
                    completed_at=session.completed_at,
                    category_score=test_result.category_score if test_result else 0.0,
                ))
        
        # Generate PDF URL if ready
        pdf_url = None
        if report.is_ready and report.pdf_path:
            pdf_url = f"/uploads/reports/{os.path.basename(report.pdf_path)}"
        
        return ReportDetailResponse(
            id=report.id,
            user_id=report.user_id,
            title=report.title,
            report_type=report.report_type,
            ad_risk_score=report.ad_risk_score,
            pd_risk_score=report.pd_risk_score,
            cognitive_score=report.cognitive_score,
            speech_score=report.speech_score,
            motor_score=report.motor_score,
            gait_score=report.gait_score,
            facial_score=report.facial_score,
            ad_stage=report.ad_stage,
            pd_stage=report.pd_stage,
            sessions_included=report.sessions_included,
            sessions_info=sessions_info,
            tests_count=report.tests_count,
            include_wellness=report.include_wellness,
            is_ready=report.is_ready,
            pdf_path=report.pdf_path,
            pdf_url=pdf_url,
            date_range_start=report.date_range_start,
            date_range_end=report.date_range_end,
            created_at=report.created_at,
        )
    
    async def list_reports(
        self, 
        user_id: int,
        limit: int = 20,
        offset: int = 0
    ) -> ReportListResponse:
        """List user's reports."""
        # Get total count
        count_result = await self.db.execute(
            select(func.count(Report.id)).where(Report.user_id == user_id)
        )
        total = count_result.scalar() or 0
        
        # Get reports
        result = await self.db.execute(
            select(Report)
            .where(Report.user_id == user_id)
            .order_by(Report.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
        reports = list(result.scalars().all())
        
        return ReportListResponse(
            reports=[ReportResponse.model_validate(r) for r in reports],
            total=total,
            page=(offset // limit) + 1,
            page_size=limit,
        )
    
    async def delete_report(self, user_id: int, report_id: int) -> bool:
        """Delete a report."""
        report = await self._get_report(report_id, user_id)
        
        # Delete PDF file if exists
        if report.pdf_path and os.path.exists(report.pdf_path):
            try:
                os.remove(report.pdf_path)
            except Exception:
                pass
        
        await self.db.delete(report)
        await self.db.commit()
        
        return True
    
    async def regenerate_pdf(self, user_id: int, report_id: int) -> Report:
        """Regenerate PDF for a report."""
        report = await self._get_report(report_id, user_id)
        
        # Get user
        result = await self.db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        
        # Get sessions
        sessions = []
        if report.sessions_included:
            result = await self.db.execute(
                select(TestSession)
                .options(selectinload(TestSession.test_result))
                .where(TestSession.id.in_(report.sessions_included))
            )
            sessions = list(result.scalars().all())
        
        # Regenerate PDF
        await self._generate_pdf(report, user, sessions)
        
        return report
    
    # ============== PRIVATE HELPERS ==============
    
    async def _get_report(self, report_id: int, user_id: int) -> Report:
        """Get report by ID, verify ownership."""
        result = await self.db.execute(
            select(Report).where(
                and_(
                    Report.id == report_id,
                    Report.user_id == user_id
                )
            )
        )
        report = result.scalar_one_or_none()
        
        if not report:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Report not found"
            )
        
        return report
    
    async def _get_sessions_for_report(
        self,
        user_id: int,
        session_ids: Optional[List[int]] = None,
        category: Optional[str] = None,
        date_start=None,
        date_end=None,
    ) -> List[TestSession]:
        """Get sessions to include in report."""
        query = select(TestSession).options(
            selectinload(TestSession.test_result)
        ).where(
            and_(
                TestSession.user_id == user_id,
                TestSession.status == "completed"
            )
        )
        
        if session_ids:
            query = query.where(TestSession.id.in_(session_ids))
        
        if category:
            query = query.where(TestSession.category == category)
        
        if date_start:
            start_dt = datetime.combine(date_start, datetime.min.time())
            query = query.where(TestSession.completed_at >= start_dt)
        
        if date_end:
            end_dt = datetime.combine(date_end, datetime.max.time())
            query = query.where(TestSession.completed_at <= end_dt)
        
        query = query.order_by(TestSession.completed_at.desc())
        
        result = await self.db.execute(query)
        return list(result.scalars().all())
    
    def _generate_title(self, report_type: str, session_count: int) -> str:
        """Generate report title."""
        type_titles = {
            "comprehensive": "Comprehensive Neurological Assessment",
            "cognitive_speech": "Cognitive & Speech Assessment",
            "motor_gait": "Motor & Gait Assessment",
            "single_category": "Category Assessment",
            "wellness": "Wellness Report",
            "progress": "Progress Report",
        }
        base_title = type_titles.get(report_type, "Assessment Report")
        date_str = datetime.now().strftime("%B %d, %Y")
        return f"{base_title} - {date_str}"
    
    async def _generate_pdf(self, report: Report, user: User, sessions: List[TestSession]):
        """
        Generate PDF report.
        
        This is a placeholder. In production, use a proper PDF library like:
        - reportlab
        - weasyprint
        - fpdf2
        """
        try:
            # Ensure reports directory exists
            reports_dir = os.path.join(settings.UPLOAD_DIR, "reports")
            os.makedirs(reports_dir, exist_ok=True)
            
            # Generate filename
            filename = f"report_{report.id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.pdf"
            filepath = os.path.join(reports_dir, filename)
            
            # TODO: Generate actual PDF using reportlab or similar
            # For now, create a placeholder file
            with open(filepath, 'w') as f:
                f.write(f"NeuroVerse Report\n")
                f.write(f"================\n\n")
                f.write(f"Patient: {user.full_name}\n")
                f.write(f"Date: {datetime.now().strftime('%Y-%m-%d')}\n\n")
                f.write(f"AD Risk Score: {report.ad_risk_score:.1f}%\n")
                f.write(f"PD Risk Score: {report.pd_risk_score:.1f}%\n\n")
                f.write(f"Sessions Included: {report.tests_count}\n")
                
                for session in sessions:
                    f.write(f"\n- {session.category}: ")
                    if session.test_result:
                        f.write(f"Score {session.test_result.category_score:.1f}")
                    f.write("\n")
            
            # Update report
            report.pdf_path = filepath
            report.is_ready = True
            
            await self.db.commit()
            await self.db.refresh(report)
            
        except Exception as e:
            print(f"Error generating PDF: {e}")
            report.is_ready = False
            await self.db.commit()
