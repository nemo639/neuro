"""
Feedback Model - Stores user feedback and suggestions
"""

from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, Enum as SQLEnum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import enum

from app.db.database import Base


class FeedbackCategory(str, enum.Enum):
    """Feedback category enum with lowercase values"""
    GENERAL = "general"
    BUG_REPORT = "bug_report"
    FEATURE_REQUEST = "feature_request"
    UI_UX = "ui_ux"
    TEST_QUALITY = "test_quality"
    PERFORMANCE = "performance"
    OTHER = "other"


class FeedbackStatus(str, enum.Enum):
    """Feedback status enum with lowercase values"""
    PENDING = "pending"
    REVIEWED = "reviewed"
    IN_PROGRESS = "in_progress"
    RESOLVED = "resolved"
    CLOSED = "closed"


class Feedback(Base):
    __tablename__ = "feedbacks"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    # Feedback content - Use SQLAlchemy Enum with values_callable to use lowercase values
    category = Column(
        SQLEnum(
            FeedbackCategory,
            name="feedbackcategory",
            values_callable=lambda x: [e.value for e in x]  # Use the lowercase values
        ),
        default=FeedbackCategory.GENERAL,
        nullable=False
    )
    rating = Column(Integer, nullable=True)  # 1-5 stars
    message = Column(Text, nullable=False)
    
    # Status tracking - Use SQLAlchemy Enum with values_callable to use lowercase values
    status = Column(
        SQLEnum(
            FeedbackStatus,
            name="feedbackstatus",
            values_callable=lambda x: [e.value for e in x]  # Use the lowercase values
        ),
        default=FeedbackStatus.PENDING,
        nullable=False
    )
    admin_notes = Column(Text, nullable=True)  # Internal notes for team
    
    # Device/App info (optional, for bug reports)
    app_version = Column(String(20), nullable=True)
    device_info = Column(String(200), nullable=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    resolved_at = Column(DateTime(timezone=True), nullable=True)

    # Relationships
    user = relationship("User", back_populates="feedbacks")

    def __repr__(self):
        return f"<Feedback {self.id} - {self.category} by User {self.user_id}>"