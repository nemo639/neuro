"""
Report Model - Generated PDF reports with aggregated test results
"""

from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, JSON, Boolean
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.db.database import Base


class Report(Base):
    __tablename__ = "reports"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    # Report metadata
    title = Column(String, nullable=False)  # "Comprehensive Neuro Assessment"
    report_type = Column(String, nullable=True)  # "comprehensive", "speech_cognitive", "motor_gait"

    # Sessions included in this report (JSON array of session IDs)
    sessions_included = Column(JSON, nullable=True)
    tests_count = Column(Integer, default=0)

    # Aggregated risk scores at time of report
    ad_risk_score = Column(Float, default=0.0)
    pd_risk_score = Column(Float, default=0.0)

    # Category scores at time of report
    cognitive_score = Column(Float, nullable=True)
    speech_score = Column(Float, nullable=True)
    motor_score = Column(Float, nullable=True)
    gait_score = Column(Float, nullable=True)
    facial_score = Column(Float, nullable=True)

    # Stage classification at time of report
    ad_stage = Column(String, nullable=True)
    pd_stage = Column(String, nullable=True)

    # Wellness data included
    include_wellness = Column(Boolean, default=False)

    # PDF file path
    pdf_path = Column(String, nullable=True)

    # Status
    is_ready = Column(Boolean, default=False)

    # Timestamps
    date_range_start = Column(DateTime, nullable=True)
    date_range_end = Column(DateTime, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    user = relationship("User", back_populates="reports")
