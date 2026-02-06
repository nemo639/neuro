"""
TestResult Model - Aggregated result for a test session after ML fusion
One result per session, contains scores and XAI explanations
"""

from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, JSON
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.db.database import Base


class TestResult(Base):
    __tablename__ = "test_results"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("test_sessions.id"), nullable=False, unique=True, index=True)

    # Risk Scores (0-100) - calculated by ML fusion
    ad_risk_score = Column(Float, default=0.0)  # Alzheimer's contribution from this session
    pd_risk_score = Column(Float, default=0.0)  # Parkinson's contribution from this session

    # Category-specific score (0-100)
    category_score = Column(Float, default=0.0)  # Overall score for this category

    # Stage classification for this session
    stage = Column(String, nullable=True)  # "Normal", "Mild", "Moderate", "Severe"
    severity = Column(String, nullable=True)  # "low", "medium", "high"

    # Extracted features from ML processing (JSON)
    # Example: {"speech_rate": 4.2, "pause_count": 8, "tremor_amplitude": 0.3, ...}
    extracted_features = Column(JSON, nullable=True)

    # XAI Explanations (JSON)
    # Structure matches frontend XAI.dart requirements:
    # {
    #   "shap_values": [{"name": "Speech Pauses", "value": 0.24, "level": "High"}, ...],
    #   "feature_importance": [{"name": "Pauses", "value": 0.85}, ...],
    #   "interpretation": [{"title": "...", "description": "..."}, ...],
    #   "saliency_data": {...}  # For visualization
    # }
    xai_explanation = Column(JSON, nullable=True)

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    session = relationship("TestSession", back_populates="test_result")
