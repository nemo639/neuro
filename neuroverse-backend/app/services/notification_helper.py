"""
Notification Helper - Creates notifications for key user events.
"""

from sqlalchemy.ext.asyncio import AsyncSession
from app.models.notification import Notification


async def create_notification(
    db: AsyncSession,
    user_id: int,
    title: str,
    message: str,
    notification_type: str = "system",
    action_type: str = None,
    action_id: int = None,
):
    """Insert a notification row for the given user."""
    notif = Notification(
        user_id=user_id,
        title=title,
        message=message,
        notification_type=notification_type,
        action_type=action_type,
        action_id=action_id,
    )
    db.add(notif)
    await db.flush()
    return notif


async def notify_signup(db: AsyncSession, user_id: int, first_name: str):
    """Welcome notification on signup."""
    await create_notification(
        db, user_id,
        title="Welcome to NeuroVerse!",
        message=f"Hi {first_name}, your account has been created. Verify your email to get started with brain health screening.",
        notification_type="system",
    )


async def notify_login(db: AsyncSession, user_id: int, first_name: str):
    """Login alert notification."""
    from datetime import datetime
    now = datetime.utcnow().strftime("%b %d, %Y at %I:%M %p")
    await create_notification(
        db, user_id,
        title="Login Detected",
        message=f"Hi {first_name}, you logged in on {now} (UTC). If this wasn't you, please change your password immediately.",
        notification_type="login_alert",
    )


async def notify_test_complete(db: AsyncSession, user_id: int, test_type: str, session_id: int):
    """Notification when a test session is completed."""
    await create_notification(
        db, user_id,
        title="Test Completed",
        message=f"Your {test_type} test has been analyzed. View your results and risk assessment now.",
        notification_type="report_ready",
        action_type="view_test",
        action_id=session_id,
    )


async def notify_report_generated(db: AsyncSession, user_id: int, report_id: int):
    """Notification when a report PDF is generated."""
    await create_notification(
        db, user_id,
        title="Report Ready",
        message="Your NeuroVerse screening report has been generated and is ready to download.",
        notification_type="report_ready",
        action_type="view_report",
        action_id=report_id,
    )
