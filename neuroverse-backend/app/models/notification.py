"""
Notification model for user alerts.
"""

from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.sql import func
from app.db.database import Base


class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False, index=True)

    # Notification content
    title = Column(String(200), nullable=False)
    message = Column(Text, nullable=False)

    # Type: report_ready, doctor_message, login_alert, test_reminder, wellness_tip, system
    notification_type = Column(String(50), nullable=False, default="system")

    # Optional link (e.g., report_id, test_id)
    action_type = Column(String(50), nullable=True)  # e.g., "view_report", "start_test"
    action_id = Column(Integer, nullable=True)  # e.g., report_id

    # Status
    is_read = Column(Boolean, default=False)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
