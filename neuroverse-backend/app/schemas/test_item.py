"""
Test Item Schemas - Individual mini-test data
Matches Flutter test screens: cognitive_memory_test.dart, speech_language_test.dart,
motor_functions_test.dart, gait_movement_test.dart
"""

from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime


# ============== RAW DATA STRUCTURES ==============
# These match what Flutter sends for each mini-test

class StroopTestData(BaseModel):
    """Stroop test raw data."""
    trials: List[Dict[str, Any]]  # [{color, word, response, correct, time_ms}, ...]
    total_correct: int
    total_errors: int
    avg_response_time_ms: float
    congruent_avg_ms: float
    incongruent_avg_ms: float
    interference_score: float


class NBackTestData(BaseModel):
    """N-Back test raw data."""
    level: int  # 1, 2, or 3
    sequence: List[str]
    user_responses: List[Dict[str, Any]]  # [{position, responded, correct, time_ms}, ...]
    hits: int
    misses: int
    false_alarms: int
    correct_rejections: int
    accuracy: float
    avg_response_time_ms: float


class WordRecallTestData(BaseModel):
    """Word recall test raw data."""
    words_shown: List[str]
    words_recalled: List[str]
    correct_recalls: int
    intrusions: int  # Wrong words
    recall_order: List[int]  # Order of correct recalls
    time_to_first_recall_ms: int
    total_time_ms: int


class StoryRecallTestData(BaseModel):
    """Story recall test raw data (Speech)."""
    story_id: str
    audio_path: Optional[str] = None
    transcript: Optional[str] = None
    duration_seconds: float
    key_points_recalled: int
    total_key_points: int
    coherence_score: Optional[float] = None


class SustainedVowelTestData(BaseModel):
    """Sustained vowel test raw data (Speech)."""
    vowel: str  # "ah", "ee", "oo"
    audio_path: str
    duration_seconds: float
    max_duration_achieved: float
    frequency_stability: Optional[float] = None
    amplitude_variation: Optional[float] = None


class PictureDescriptionTestData(BaseModel):
    """Picture description test raw data (Speech)."""
    picture_id: str
    audio_path: str
    transcript: Optional[str] = None
    duration_seconds: float
    word_count: Optional[int] = None
    unique_words: Optional[int] = None
    pause_count: Optional[int] = None


class FingerTappingTestData(BaseModel):
    """Finger tapping test raw data (Motor)."""
    hand: str  # "left", "right", "both"
    taps: List[Dict[str, Any]]  # [{timestamp_ms, x, y, pressure}, ...]
    total_taps: int
    duration_seconds: float
    tapping_rate: float  # taps per second
    regularity_score: float
    fatigue_index: float  # Rate decrease over time


class SpiralDrawingTestData(BaseModel):
    """Spiral drawing test raw data (Motor)."""
    coordinates: List[Dict[str, Any]]  # [{x, y, timestamp_ms, pressure}, ...]
    duration_ms: int
    total_points: int
    spiral_tightness: Optional[float] = None
    tremor_detected: bool = False
    deviation_score: Optional[float] = None


class WalkingTestData(BaseModel):
    """Walking test raw data (Gait)."""
    accelerometer_data: List[Dict[str, Any]]  # [{x, y, z, timestamp}, ...]
    gyroscope_data: List[Dict[str, Any]]  # [{x, y, z, timestamp}, ...]
    steps_detected: int
    duration_seconds: float
    distance_meters: Optional[float] = None
    avg_step_length: Optional[float] = None
    step_regularity: Optional[float] = None


class TurnInPlaceTestData(BaseModel):
    """Turn in place test raw data (Gait)."""
    accelerometer_data: List[Dict[str, Any]]
    gyroscope_data: List[Dict[str, Any]]
    turn_duration_seconds: float
    turn_angle_degrees: float
    stability_score: Optional[float] = None


class BalanceTestData(BaseModel):
    """Balance test raw data (Gait)."""
    accelerometer_data: List[Dict[str, Any]]
    gyroscope_data: List[Dict[str, Any]]
    duration_seconds: float
    eyes_open: bool
    sway_area: Optional[float] = None
    stability_score: Optional[float] = None


class FacialAnalysisTestData(BaseModel):
    """Facial analysis test raw data."""
    video_path: Optional[str] = None
    frames_analyzed: int
    duration_seconds: float
    landmarks: Optional[List[Dict[str, Any]]] = None
    blink_count: int
    blink_rate: float  # blinks per minute
    smile_events: List[Dict[str, Any]] = []  # [{start_ms, end_ms, intensity}, ...]
    expression_timeline: List[Dict[str, Any]] = []


# ============== REQUEST SCHEMAS ==============

class TestItemCreate(BaseModel):
    """Create a single test item - generic structure."""
    item_name: str = Field(..., description="Mini-test name: stroop, nback, word_recall, spiral, etc.")
    item_type: Optional[str] = Field(None, description="Type: cognitive, audio, motor, sensor, video")
    raw_data: Dict[str, Any] = Field(..., description="Test-specific data structure")
    raw_value: Optional[str] = None
    processed_value: Optional[float] = None
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None


class TestItemBatchCreate(BaseModel):
    """Create multiple test items at once."""
    items: List[TestItemCreate]


# ============== RESPONSE SCHEMAS ==============

class TestItemResponse(BaseModel):
    """Test item response."""
    id: int
    session_id: int
    item_name: str
    item_type: Optional[str] = None
    raw_data: Optional[Dict[str, Any]] = None
    raw_value: Optional[str] = None
    processed_value: Optional[float] = None
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class TestItemListResponse(BaseModel):
    """List of test items."""
    items: List[TestItemResponse]
    total: int
