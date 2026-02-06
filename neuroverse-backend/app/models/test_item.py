"""
TestItem Model - Individual mini-tests within a session
Examples: Stroop, N-Back, Word Recall (within Cognitive session)
          Story Recall, Sustained Vowel (within Speech session)
          Finger Tapping, Spiral Drawing (within Motor session)
"""

from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, JSON
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.db.database import Base


class TestItem(Base):
    __tablename__ = "test_items"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(Integer, ForeignKey("test_sessions.id"), nullable=False, index=True)

    # Mini-test identification
    item_name = Column(String, nullable=False)  # "stroop", "nback", "word_recall", "spiral", etc.
    item_type = Column(String, nullable=True)   # "cognitive", "audio", "motor", "sensor", "video"

    # Raw data from the test (JSON - varies by test type)
    # Examples:
    # Stroop: {"responses": [...], "times": [...], "errors": 3, "correct": 27}
    # N-Back: {"sequence": [...], "user_responses": [...], "accuracy": 0.78, "level": 2}
    # Spiral: {"coordinates": [[x,y,t], ...], "pressure": [...], "duration_ms": 45000}
    # Speech: {"audio_path": "...", "transcript": "...", "duration_s": 30}
    raw_data = Column(JSON, nullable=True)

    # Processed/extracted value (optional - for quick access)
    raw_value = Column(String, nullable=True)      # Text representation if needed
    processed_value = Column(Float, nullable=True) # Numeric score if applicable

    # Timestamps
    started_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    session = relationship("TestSession", back_populates="test_items")
