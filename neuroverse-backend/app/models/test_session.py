"""
TestSession Model - One session per test category (Cognitive, Speech, Motor, etc.)
Contains multiple test_items (mini-tests) and one aggregated test_result
"""

from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Enum
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.db.database import Base
import enum


class TestCategory(str, enum.Enum):
    COGNITIVE = "cognitive"
    SPEECH = "speech"
    MOTOR = "motor"
    GAIT = "gait"
    FACIAL = "facial"


class SessionStatus(str, enum.Enum):
    CREATED = "created"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class TestSession(Base):
    __tablename__ = "test_sessions"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    # Category: cognitive, speech, motor, gait, facial
    category = Column(String, nullable=False, index=True)

    # Status tracking
    status = Column(String, default=SessionStatus.CREATED.value)

    # Timestamps
    started_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relationships
    user = relationship("User", back_populates="test_sessions")
    test_items = relationship("TestItem", back_populates="session", cascade="all, delete-orphan")
    test_result = relationship("TestResult", back_populates="session", uselist=False, cascade="all, delete-orphan")

    