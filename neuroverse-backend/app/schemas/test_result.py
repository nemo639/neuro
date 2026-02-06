"""
Test Result Schemas - ML results with XAI explanations
Matches Flutter: XAI.dart structure for explainable AI display
"""

from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime


# ============== XAI STRUCTURE (matches XAI.dart) ==============

class ShapValue(BaseModel):
    """SHAP value for a single feature - matches XAI.dart _buildFactorCard."""
    name: str  # Feature name displayed
    value: float  # SHAP value (-1 to 1 typically)
    contribution: float  # Percentage contribution to prediction
    level: str  # "Low", "Medium", "High"
    description: Optional[str] = None
    direction: str = "neutral"  # "positive", "negative", "neutral"


class FeatureImportance(BaseModel):
    """Feature importance for visualization - matches XAI.dart bar charts."""
    name: str
    value: float  # 0-1 importance score
    category: str  # Which test category this feature belongs to
    rank: int  # Importance rank (1 = most important)


class Interpretation(BaseModel):
    """Human-readable interpretation - matches XAI.dart _buildInsightCard."""
    title: str
    description: str
    severity: str  # "info", "warning", "concern", "positive"
    recommendation: Optional[str] = None
    related_features: List[str] = []


class SaliencyData(BaseModel):
    """Saliency visualization data - for heatmaps/highlights."""
    type: str  # "audio_waveform", "spiral_path", "gait_pattern", "facial_regions"
    data: Dict[str, Any]  # Type-specific saliency data
    highlights: List[Dict[str, Any]] = []  # Regions of interest


class XAIExplanation(BaseModel):
    """Complete XAI explanation - matches XAI.dart _NeuroXAIPageState."""
    # Overall summary
    summary: str
    confidence: float  # Model confidence 0-1
    
    # SHAP values for feature attribution
    shap_values: List[ShapValue] = []
    
    # Feature importance ranking
    feature_importance: List[FeatureImportance] = []
    
    # Human-readable insights
    interpretations: List[Interpretation] = []
    
    # Visual saliency data (optional)
    saliency_data: Optional[SaliencyData] = None
    
    # Category-specific explanations
    category_explanations: Dict[str, str] = {}
    
    # Risk factor breakdown
    ad_factors: List[ShapValue] = []  # Factors contributing to AD risk
    pd_factors: List[ShapValue] = []  # Factors contributing to PD risk
    
    # Comparison with baseline
    comparison_with_baseline: Optional[Dict[str, Any]] = None
    
    # Temporal trends (if applicable)
    trend_analysis: Optional[Dict[str, Any]] = None


# ============== RESPONSE SCHEMAS ==============

class TestResultResponse(BaseModel):
    """Basic test result response."""
    id: int
    session_id: int
    
    # Scores
    ad_risk_score: float = 0.0
    pd_risk_score: float = 0.0
    category_score: float = 0.0
    
    # Classification
    stage: Optional[str] = None
    severity: Optional[str] = None
    
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class TestResultDetailResponse(BaseModel):
    """Detailed test result with XAI - returned after session completion."""
    id: int
    session_id: int
    
    # Scores
    ad_risk_score: float = 0.0
    pd_risk_score: float = 0.0
    category_score: float = 0.0
    
    # Classification
    stage: Optional[str] = None
    severity: Optional[str] = None
    
    # Extracted features from ML
    extracted_features: Optional[Dict[str, Any]] = None
    
    # XAI Explanation (full structure)
    xai_explanation: Optional[XAIExplanation] = None
    
    # Session info
    category: Optional[str] = None
    items_processed: int = 0
    
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class TestResultWithSessionResponse(BaseModel):
    """Test result with parent session info."""
    result: TestResultDetailResponse
    session: Dict[str, Any]  # Basic session info


class CategoryResultSummary(BaseModel):
    """Summary of results for a category."""
    category: str
    latest_score: float
    latest_ad_contribution: float
    latest_pd_contribution: float
    tests_count: int
    trend: str  # "improving", "stable", "declining"
    last_tested: Optional[datetime] = None
