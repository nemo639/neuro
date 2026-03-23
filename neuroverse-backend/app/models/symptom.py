"""
Symptom Tracker Model - Daily symptom logging for AD/PD monitoring
"""

from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, JSON, Date
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.db.database import Base


class SymptomEntry(Base):
    __tablename__ = "symptom_entries"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    # Date of entry
    entry_date = Column(Date, nullable=False, index=True)

    # Core symptoms (severity 0-10)
    memory_issues = Column(Integer, default=0)       # Forgetting names, events, conversations
    confusion = Column(Integer, default=0)            # Disorientation, difficulty with tasks
    tremors = Column(Integer, default=0)              # Hand/body tremors
    balance_issues = Column(Integer, default=0)       # Difficulty walking, stumbling
    speech_difficulty = Column(Integer, default=0)    # Slurred speech, word-finding
    sleep_disturbance = Column(Integer, default=0)    # Insomnia, restless sleep
    mood_changes = Column(Integer, default=0)         # Anxiety, depression, irritability
    fatigue = Column(Integer, default=0)              # Unusual tiredness

    # Overall severity (auto-calculated)
    overall_severity = Column(Float, default=0.0)

    # Notes
    notes = Column(String, nullable=True)

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    user = relationship("User")
