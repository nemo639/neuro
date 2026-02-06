"""
Wellness Schemas - Daily wellness and lifestyle tracking
Correlates with cognitive/motor performance per proposal
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime, date
from enum import Enum


class SleepQuality(str, Enum):
    POOR = "poor"
    FAIR = "fair"
    GOOD = "good"
    EXCELLENT = "excellent"


class Mood(str, Enum):
    VERY_BAD = "very_bad"
    BAD = "bad"
    NEUTRAL = "neutral"
    GOOD = "good"
    VERY_GOOD = "very_good"


# ============== REQUEST SCHEMAS ==============

class WellnessEntryCreate(BaseModel):
    """Create wellness entry - daily tracking data."""
    # Sleep
    sleep_hours: Optional[float] = Field(None, ge=0, le=24)
    sleep_quality: Optional[SleepQuality] = None
    
    # Digital wellness (per proposal)
    screen_time_hours: Optional[float] = Field(None, ge=0, le=24)
    gaming_hours: Optional[float] = Field(None, ge=0, le=24)
    
    # Mental state
    stress_level: Optional[int] = Field(None, ge=1, le=10)
    mood: Optional[Mood] = None
    anxiety_level: Optional[int] = Field(None, ge=1, le=10)
    
    # Physical activity
    physical_activity_minutes: Optional[int] = Field(None, ge=0)
    exercise_type: Optional[str] = None
    
    # Hydration
    water_intake_glasses: Optional[int] = Field(None, ge=0)
    
    # Notes
    notes: Optional[str] = Field(None, max_length=500)
    
    # Date (defaults to today)
    entry_date: Optional[date] = None


class WellnessEntryUpdate(BaseModel):
    """Update wellness entry."""
    sleep_hours: Optional[float] = Field(None, ge=0, le=24)
    sleep_quality: Optional[SleepQuality] = None
    screen_time_hours: Optional[float] = Field(None, ge=0, le=24)
    gaming_hours: Optional[float] = Field(None, ge=0, le=24)
    stress_level: Optional[int] = Field(None, ge=1, le=10)
    mood: Optional[Mood] = None
    anxiety_level: Optional[int] = Field(None, ge=1, le=10)
    physical_activity_minutes: Optional[int] = Field(None, ge=0)
    exercise_type: Optional[str] = None
    water_intake_glasses: Optional[int] = Field(None, ge=0)
    notes: Optional[str] = Field(None, max_length=500)


# ============== RESPONSE SCHEMAS ==============

class WellnessEntryResponse(BaseModel):
    """Wellness entry response."""
    id: int
    user_id: int
    
    # Sleep
    sleep_hours: Optional[float] = None
    sleep_quality: Optional[str] = None
    
    # Digital wellness
    screen_time_hours: Optional[float] = None
    gaming_hours: Optional[float] = None
    
    # Mental state
    stress_level: Optional[int] = None
    mood: Optional[str] = None
    anxiety_level: Optional[int] = None
    
    # Physical activity
    physical_activity_minutes: Optional[int] = None
    exercise_type: Optional[str] = None
    
    # Hydration
    water_intake_glasses: Optional[int] = None
    
    # Notes
    notes: Optional[str] = None
    
    # Timestamps
    entry_date: Optional[datetime] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class WellnessMetric(BaseModel):
    """Single wellness metric for dashboard."""
    name: str
    current_value: Optional[float] = None
    unit: str
    trend: str  # "up", "down", "stable"
    trend_percentage: float = 0.0
    status: str  # "good", "fair", "poor"
    recommendation: Optional[str] = None


class WellnessDashboardResponse(BaseModel):
    """Wellness dashboard - summary and trends."""
    user_id: int
    
    # Today's entry (if exists)
    today_entry: Optional[WellnessEntryResponse] = None
    has_logged_today: bool = False
    
    # Weekly averages
    avg_sleep_hours: Optional[float] = None
    avg_screen_time: Optional[float] = None
    avg_stress_level: Optional[float] = None
    avg_activity_minutes: Optional[float] = None
    
    # Metrics breakdown
    metrics: List[WellnessMetric] = []
    
    # Correlation insights (wellness vs test performance)
    correlations: List[dict] = []  # [{"factor": "sleep", "correlation": 0.65, "insight": "..."}, ...]
    
    # Streak
    logging_streak: int = 0
    
    # Recommendations
    recommendations: List[str] = []


class WellnessHistoryResponse(BaseModel):
    """Wellness history for charts."""
    entries: List[WellnessEntryResponse]
    total: int
    
    # Aggregated data for charts
    daily_summary: List[dict] = []  # [{"date": "2024-01-01", "sleep": 7, "stress": 5, ...}, ...]
    weekly_averages: List[dict] = []
    monthly_averages: List[dict] = []
