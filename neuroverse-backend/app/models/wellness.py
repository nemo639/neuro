"""
WellnessEntry Model - Daily wellness and lifestyle tracking
Correlates with cognitive/motor performance per proposal
"""

from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.db.database import Base


class WellnessEntry(Base):
    __tablename__ = "wellness_entries"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    # Sleep tracking
    sleep_hours = Column(Float, nullable=True)
    sleep_quality = Column(String, nullable=True)  # "poor", "fair", "good", "excellent"

    # Digital wellness (per proposal - correlate with cognitive decline)
    screen_time_hours = Column(Float, nullable=True)
    gaming_hours = Column(Float, nullable=True)

    # Mental state
    stress_level = Column(Integer, nullable=True)  # 1-10
    mood = Column(String, nullable=True)  # "very_bad", "bad", "neutral", "good", "very_good"
    anxiety_level = Column(Integer, nullable=True)  # 1-10

    # Physical activity
    physical_activity_minutes = Column(Integer, nullable=True)
    exercise_type = Column(String, nullable=True)

    # Hydration
    water_intake_glasses = Column(Integer, nullable=True)

    # Notes
    notes = Column(String, nullable=True)

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    entry_date = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    user = relationship("User", back_populates="wellness_entries")
