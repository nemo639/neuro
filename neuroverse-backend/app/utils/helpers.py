"""
Utility Helper Functions
"""

import os
import uuid
from datetime import datetime, date
from typing import Optional, Any
import json


def generate_unique_filename(original_filename: str, prefix: str = "") -> str:
    """Generate a unique filename with UUID."""
    ext = original_filename.split(".")[-1] if "." in original_filename else ""
    unique_id = uuid.uuid4().hex[:12]
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    if prefix:
        return f"{prefix}_{timestamp}_{unique_id}.{ext}"
    return f"{timestamp}_{unique_id}.{ext}"


def ensure_directory(path: str) -> str:
    """Ensure directory exists, create if not."""
    os.makedirs(path, exist_ok=True)
    return path


def calculate_age(birth_date: date) -> int:
    """Calculate age from birth date."""
    today = date.today()
    return today.year - birth_date.year - (
        (today.month, today.day) < (birth_date.month, birth_date.day)
    )


def safe_json_loads(json_str: str, default: Any = None) -> Any:
    """Safely parse JSON string."""
    try:
        return json.loads(json_str)
    except (json.JSONDecodeError, TypeError):
        return default


def safe_float(value: Any, default: float = 0.0) -> float:
    """Safely convert to float."""
    try:
        return float(value)
    except (ValueError, TypeError):
        return default


def safe_int(value: Any, default: int = 0) -> int:
    """Safely convert to int."""
    try:
        return int(value)
    except (ValueError, TypeError):
        return default


def clamp(value: float, min_val: float, max_val: float) -> float:
    """Clamp value between min and max."""
    return max(min_val, min(max_val, value))


def score_to_percentage(score: float, max_score: float = 100) -> float:
    """Convert score to percentage (0-100)."""
    if max_score == 0:
        return 0.0
    return clamp((score / max_score) * 100, 0, 100)


def format_duration(seconds: float) -> str:
    """Format duration in human readable format."""
    if seconds < 60:
        return f"{seconds:.0f}s"
    elif seconds < 3600:
        minutes = seconds // 60
        secs = seconds % 60
        return f"{minutes:.0f}m {secs:.0f}s"
    else:
        hours = seconds // 3600
        minutes = (seconds % 3600) // 60
        return f"{hours:.0f}h {minutes:.0f}m"


def mask_email(email: str) -> str:
    """Mask email for privacy."""
    if "@" not in email:
        return email
    
    local, domain = email.split("@")
    if len(local) <= 2:
        masked_local = "*" * len(local)
    else:
        masked_local = local[0] + "*" * (len(local) - 2) + local[-1]
    
    return f"{masked_local}@{domain}"


def get_risk_level(score: float) -> str:
    """Get risk level from score."""
    if score < 25:
        return "low"
    elif score < 50:
        return "moderate"
    elif score < 75:
        return "elevated"
    else:
        return "high"


def get_health_status(score: float) -> str:
    """Get health status from score (higher = healthier)."""
    if score >= 80:
        return "excellent"
    elif score >= 60:
        return "good"
    elif score >= 40:
        return "fair"
    else:
        return "needs_attention"


def sanitize_filename(filename: str) -> str:
    """Sanitize filename to remove dangerous characters."""
    # Remove path separators and null bytes
    dangerous_chars = ['/', '\\', '\x00', '..']
    for char in dangerous_chars:
        filename = filename.replace(char, '_')
    return filename


def truncate_string(s: str, max_length: int = 100, suffix: str = "...") -> str:
    """Truncate string to max length."""
    if len(s) <= max_length:
        return s
    return s[:max_length - len(suffix)] + suffix
