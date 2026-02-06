"""
Test Session Schemas - Test session management
Matches Flutter: testsscreen.dart, cognitive_memory_test.dart, etc.
"""

from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum


class TestCategory(str, Enum):
    """Test categories matching frontend."""
    COGNITIVE = "cognitive"
    SPEECH = "speech"
    MOTOR = "motor"
    GAIT = "gait"
    FACIAL = "facial"


class SessionStatus(str, Enum):
    """Session status values."""
    CREATED = "created"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


# ============== REQUEST SCHEMAS ==============

class TestSessionCreate(BaseModel):
    """Create a new test session."""
    category: TestCategory


class TestSessionStart(BaseModel):
    """Start a test session."""
    pass  # Just triggers status change


class TestSessionComplete(BaseModel):
    """Complete a test session - triggers ML processing."""
    pass  # Just triggers completion


# ============== RESPONSE SCHEMAS ==============

class TestItemSummary(BaseModel):
    """Brief test item info for session response."""
    id: int
    item_name: str
    item_type: Optional[str] = None
    completed_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class TestResultSummary(BaseModel):
    """Brief test result info for session response."""
    id: int
    ad_risk_score: float = 0.0
    pd_risk_score: float = 0.0
    category_score: float = 0.0
    stage: Optional[str] = None
    severity: Optional[str] = None
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class TestSessionResponse(BaseModel):
    """Basic test session response."""
    id: int
    user_id: int
    category: str
    status: str
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    items_count: int = 0

    class Config:
        from_attributes = True


class TestSessionDetailResponse(BaseModel):
    """Detailed test session with items and result."""
    id: int
    user_id: int
    category: str
    status: str
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    
    # Related data
    test_items: List[TestItemSummary] = []
    test_result: Optional[TestResultSummary] = None

    class Config:
        from_attributes = True


class TestSessionListResponse(BaseModel):
    """List of test sessions."""
    sessions: List[TestSessionResponse]
    total: int
    page: int = 1
    page_size: int = 20


class CategoryTestInfo(BaseModel):
    """Category info for test dashboard."""
    category: str
    display_name: str
    description: str
    mini_tests: List[str]
    estimated_duration: str
    last_completed: Optional[datetime] = None
    total_completed: int = 0
    current_score: Optional[float] = None


class TestDashboardResponse(BaseModel):
    """Test dashboard data - matches Flutter testsscreen.dart."""
    user_id: int
    
    # Overall status
    total_sessions: int = 0
    completed_sessions: int = 0
    
    # Category breakdown
    categories: List[CategoryTestInfo] = []
    
    # Current/pending sessions
    in_progress_session: Optional[TestSessionResponse] = None
    
    # Recommendations
    recommended_category: Optional[str] = None
    recommendation_reason: Optional[str] = None
