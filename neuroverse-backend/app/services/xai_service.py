"""
XAI Service - Explainable AI explanation generation
Generates SHAP values, feature importance, and human-readable interpretations
Output structure matches Flutter XAI.dart requirements
"""

from typing import Dict, Any, List
from app.schemas.test_result import (
    XAIExplanation, ShapValue, FeatureImportance, 
    Interpretation, SaliencyData
)


class XAIService:
    """
    Explainable AI Service for generating interpretable explanations.
    
    This is a placeholder implementation. In production, this will:
    1. Use SHAP library for actual SHAP value calculation
    2. Generate saliency maps for visual data
    3. Use NLP for human-readable explanations
    """
    
    # Feature display names
    FEATURE_NAMES = {
        # Cognitive
        "stroop_accuracy": "Stroop Test Accuracy",
        "stroop_interference": "Stroop Interference Score",
        "stroop_avg_rt": "Stroop Response Time",
        "nback_accuracy": "N-Back Accuracy",
        "nback_level": "N-Back Level Achieved",
        "recall_accuracy": "Word Recall Accuracy",
        "recall_intrusions": "Recall Intrusions",
        
        # Speech
        "story_recall_accuracy": "Story Recall Accuracy",
        "story_coherence": "Narrative Coherence",
        "vowel_duration": "Sustained Vowel Duration",
        "vowel_stability": "Voice Stability",
        "speech_rate": "Speech Rate",
        "pause_count": "Speech Pauses",
        "word_count": "Word Count",
        
        # Motor
        "tapping_rate": "Tapping Speed",
        "tapping_regularity": "Tapping Regularity",
        "tapping_fatigue": "Motor Fatigue",
        "spiral_tremor": "Tremor Detection",
        "spiral_deviation": "Drawing Accuracy",
        
        # Gait
        "step_regularity": "Step Regularity",
        "gait_speed": "Walking Speed",
        "turn_stability": "Turn Stability",
        "balance_stability": "Balance Control",
        "balance_sway": "Body Sway",
        
        # Facial
        "blink_rate": "Blink Rate",
        "smile_intensity": "Expression Intensity",
    }
    
    # Feature interpretations based on value ranges
    INTERPRETATIONS = {
        "stroop_accuracy": {
            "high": "Excellent selective attention and cognitive control",
            "medium": "Adequate attention but some interference effects",
            "low": "Difficulty filtering irrelevant information"
        },
        "nback_accuracy": {
            "high": "Strong working memory capacity",
            "medium": "Average working memory performance",
            "low": "Working memory challenges detected"
        },
        "recall_accuracy": {
            "high": "Good episodic memory retention",
            "medium": "Some memory consolidation difficulties",
            "low": "Significant memory retrieval challenges"
        },
        "speech_rate": {
            "high": "Rapid speech may indicate anxiety or mania",
            "medium": "Normal speech rate",
            "low": "Slowed speech may indicate cognitive or motor issues"
        },
        "tapping_regularity": {
            "high": "Good motor timing and coordination",
            "medium": "Mild motor timing variability",
            "low": "Motor timing irregularities detected"
        },
        "spiral_tremor": {
            "high": "Significant tremor detected during drawing",
            "medium": "Mild tremor present",
            "low": "No significant tremor detected"
        },
        "step_regularity": {
            "high": "Consistent, regular gait pattern",
            "medium": "Some gait variability present",
            "low": "Irregular gait pattern detected"
        },
        "blink_rate": {
            "high": "Elevated blink rate (may indicate dopamine issues)",
            "medium": "Normal blink rate",
            "low": "Reduced blink rate (hypomimia indicator)"
        },
    }
    
    def __init__(self):
        # TODO: Load SHAP explainer models
        pass
    
    async def generate_explanation(
        self,
        category: str,
        features: Dict[str, Any],
        risk_scores: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Generate complete XAI explanation for test results.
        
        Returns dict matching XAIExplanation schema for frontend XAI.dart
        """
        # Generate SHAP values
        shap_values = self._generate_shap_values(features, risk_scores)
        
        # Calculate feature importance
        feature_importance = self._calculate_feature_importance(features, category)
        
        # Generate human-readable interpretations
        interpretations = self._generate_interpretations(features, risk_scores, category)
        
        # Generate AD/PD specific factors
        ad_factors = self._get_ad_factors(features, shap_values)
        pd_factors = self._get_pd_factors(features, shap_values)
        
        # Create summary
        summary = self._generate_summary(risk_scores, category)
        
        return {
            "summary": summary,
            "confidence": 0.85,  # Placeholder confidence
            "shap_values": [sv.model_dump() for sv in shap_values],
            "feature_importance": [fi.model_dump() for fi in feature_importance],
            "interpretations": [i.model_dump() for i in interpretations],
            "saliency_data": None,  # TODO: Add for visual tests
            "category_explanations": {
                category: f"Analysis based on {features.get('items_processed', 0)} tests"
            },
            "ad_factors": [f.model_dump() for f in ad_factors],
            "pd_factors": [f.model_dump() for f in pd_factors],
            "comparison_with_baseline": None,
            "trend_analysis": None,
        }
    
    def _generate_shap_values(
        self, 
        features: Dict[str, Any],
        risk_scores: Dict[str, Any]
    ) -> List[ShapValue]:
        """
        Generate SHAP values for features.
        In production, this will use actual SHAP library.
        """
        shap_values = []
        
        # Skip metadata fields
        skip_fields = ["category", "items_processed"]
        
        for key, value in features.items():
            if key in skip_fields or not isinstance(value, (int, float)):
                continue
            
            display_name = self.FEATURE_NAMES.get(key, key.replace("_", " ").title())
            
            # Calculate simulated SHAP contribution
            # In production, this comes from actual SHAP computation
            normalized_value = self._normalize_value(key, value)
            contribution = self._calculate_contribution(key, normalized_value)
            
            # Determine level
            level = self._value_to_level(normalized_value)
            
            # Determine direction
            direction = "positive" if contribution > 0 else "negative" if contribution < 0 else "neutral"
            
            shap_values.append(ShapValue(
                name=display_name,
                value=round(contribution, 3),
                contribution=abs(round(contribution * 100, 1)),
                level=level,
                description=self._get_feature_description(key, level),
                direction=direction,
            ))
        
        # Sort by absolute contribution
        shap_values.sort(key=lambda x: abs(x.value), reverse=True)
        
        return shap_values[:10]  # Return top 10 factors
    
    def _calculate_feature_importance(
        self, 
        features: Dict[str, Any],
        category: str
    ) -> List[FeatureImportance]:
        """Calculate feature importance ranking."""
        importance_list = []
        skip_fields = ["category", "items_processed"]
        
        # Importance weights by category
        category_weights = {
            "cognitive": {
                "stroop_accuracy": 0.3, "nback_accuracy": 0.3, "recall_accuracy": 0.25,
                "stroop_interference": 0.15
            },
            "speech": {
                "story_recall_accuracy": 0.25, "speech_rate": 0.2, "vowel_stability": 0.2,
                "pause_count": 0.15, "story_coherence": 0.2
            },
            "motor": {
                "tapping_regularity": 0.3, "spiral_tremor": 0.35, "tapping_fatigue": 0.2,
                "spiral_deviation": 0.15
            },
            "gait": {
                "step_regularity": 0.3, "balance_stability": 0.25, "gait_speed": 0.25,
                "turn_stability": 0.2
            },
            "facial": {
                "blink_rate": 0.5, "smile_intensity": 0.5
            },
        }
        
        weights = category_weights.get(category, {})
        
        for key, value in features.items():
            if key in skip_fields or not isinstance(value, (int, float)):
                continue
            
            display_name = self.FEATURE_NAMES.get(key, key.replace("_", " ").title())
            importance = weights.get(key, 0.1)
            
            importance_list.append(FeatureImportance(
                name=display_name,
                value=round(importance, 2),
                category=category,
                rank=0  # Will be set after sorting
            ))
        
        # Sort and assign ranks
        importance_list.sort(key=lambda x: x.value, reverse=True)
        for i, item in enumerate(importance_list):
            item.rank = i + 1
        
        return importance_list
    
    def _generate_interpretations(
        self,
        features: Dict[str, Any],
        risk_scores: Dict[str, Any],
        category: str
    ) -> List[Interpretation]:
        """Generate human-readable interpretations."""
        interpretations = []
        
        # Overall risk interpretation
        ad_risk = risk_scores.get("ad_risk", 0)
        pd_risk = risk_scores.get("pd_risk", 0)
        
        if ad_risk > pd_risk and ad_risk > 30:
            interpretations.append(Interpretation(
                title="Alzheimer's Risk Indicators",
                description=f"Your {category} assessment shows patterns that contribute {ad_risk:.0f}% to AD risk estimation. Key areas to monitor include memory and cognitive performance.",
                severity="warning" if ad_risk > 50 else "info",
                recommendation="Consider follow-up cognitive assessments and consult with a healthcare provider.",
                related_features=["recall_accuracy", "stroop_accuracy", "story_recall_accuracy"],
            ))
        
        if pd_risk > ad_risk and pd_risk > 30:
            interpretations.append(Interpretation(
                title="Parkinson's Risk Indicators",
                description=f"Your {category} assessment shows patterns that contribute {pd_risk:.0f}% to PD risk estimation. Motor and movement patterns are key factors.",
                severity="warning" if pd_risk > 50 else "info",
                recommendation="Consider motor function follow-up and consult with a neurologist.",
                related_features=["tapping_regularity", "spiral_tremor", "step_regularity"],
            ))
        
        # Category-specific interpretations
        if category == "cognitive":
            interpretations.extend(self._cognitive_interpretations(features))
        elif category == "speech":
            interpretations.extend(self._speech_interpretations(features))
        elif category == "motor":
            interpretations.extend(self._motor_interpretations(features))
        elif category == "gait":
            interpretations.extend(self._gait_interpretations(features))
        elif category == "facial":
            interpretations.extend(self._facial_interpretations(features))
        
        # Positive interpretation if scores are good
        category_score = risk_scores.get("category_score", 50)
        if category_score >= 80:
            interpretations.append(Interpretation(
                title="Strong Performance",
                description=f"Your {category} assessment shows healthy patterns with a score of {category_score:.0f}/100.",
                severity="positive",
                recommendation="Continue maintaining your cognitive and physical health through regular exercise and mental activities.",
                related_features=[],
            ))
        
        return interpretations
    
    def _cognitive_interpretations(self, features: Dict[str, Any]) -> List[Interpretation]:
        """Generate cognitive-specific interpretations."""
        interps = []
        
        stroop_acc = features.get("stroop_accuracy", 0.5)
        if stroop_acc < 0.7:
            interps.append(Interpretation(
                title="Attention Control",
                description="The Stroop test revealed some difficulty in selective attention and inhibitory control.",
                severity="info",
                recommendation="Practice mindfulness exercises and attention-training games.",
                related_features=["stroop_accuracy", "stroop_interference"],
            ))
        
        recall_acc = features.get("recall_accuracy", 0.5)
        if recall_acc < 0.6:
            interps.append(Interpretation(
                title="Memory Encoding",
                description="Word recall performance suggests potential challenges in memory formation or retrieval.",
                severity="warning",
                recommendation="Try memory techniques like chunking and spaced repetition.",
                related_features=["recall_accuracy", "recall_intrusions"],
            ))
        
        return interps
    
    def _speech_interpretations(self, features: Dict[str, Any]) -> List[Interpretation]:
        """Generate speech-specific interpretations."""
        interps = []
        
        pause_count = features.get("pause_count", 0)
        if pause_count > 10:
            interps.append(Interpretation(
                title="Speech Fluency",
                description="Increased pauses detected during speech tasks may indicate word-finding difficulties.",
                severity="info",
                recommendation="Regular reading aloud and word games can help maintain speech fluency.",
                related_features=["pause_count", "speech_rate"],
            ))
        
        vowel_stability = features.get("vowel_stability", 0.5)
        if vowel_stability < 0.5:
            interps.append(Interpretation(
                title="Voice Control",
                description="Voice stability measurements show some variability that may warrant monitoring.",
                severity="info",
                recommendation="Voice exercises and breathing techniques may help improve vocal control.",
                related_features=["vowel_stability", "vowel_duration"],
            ))
        
        return interps
    
    def _motor_interpretations(self, features: Dict[str, Any]) -> List[Interpretation]:
        """Generate motor-specific interpretations."""
        interps = []
        
        tremor = features.get("spiral_tremor", 0)
        if tremor > 0.5:
            interps.append(Interpretation(
                title="Tremor Detection",
                description="The spiral drawing task detected some tremor patterns that should be monitored.",
                severity="warning",
                recommendation="Consult with a neurologist if tremor is noticeable in daily activities.",
                related_features=["spiral_tremor", "spiral_deviation"],
            ))
        
        fatigue = features.get("tapping_fatigue", 0)
        if fatigue > 0.4:
            interps.append(Interpretation(
                title="Motor Fatigue",
                description="Finger tapping showed declining performance over time, indicating motor fatigue.",
                severity="info",
                recommendation="Regular hand exercises and adequate rest can help maintain motor endurance.",
                related_features=["tapping_fatigue", "tapping_regularity"],
            ))
        
        return interps
    
    def _gait_interpretations(self, features: Dict[str, Any]) -> List[Interpretation]:
        """Generate gait-specific interpretations."""
        interps = []
        
        step_reg = features.get("step_regularity", 0.5)
        if step_reg < 0.6:
            interps.append(Interpretation(
                title="Gait Variability",
                description="Walking pattern shows some irregularity that may increase fall risk.",
                severity="warning",
                recommendation="Consider balance exercises and consult a physical therapist.",
                related_features=["step_regularity", "gait_speed"],
            ))
        
        balance = features.get("balance_stability", 0.5)
        if balance < 0.5:
            interps.append(Interpretation(
                title="Balance Control",
                description="Balance assessment indicates some stability concerns.",
                severity="warning",
                recommendation="Practice standing balance exercises and consider tai chi or yoga.",
                related_features=["balance_stability", "balance_sway"],
            ))
        
        return interps
    
    def _facial_interpretations(self, features: Dict[str, Any]) -> List[Interpretation]:
        """Generate facial-specific interpretations."""
        interps = []
        
        blink_rate = features.get("blink_rate", 15)
        if blink_rate < 10:
            interps.append(Interpretation(
                title="Facial Expression",
                description="Reduced blink rate detected, which can be an early indicator of facial masking.",
                severity="info",
                recommendation="Practice facial exercises and expressions regularly.",
                related_features=["blink_rate"],
            ))
        elif blink_rate > 25:
            interps.append(Interpretation(
                title="Blink Rate",
                description="Elevated blink rate detected, which may indicate stress or eye strain.",
                severity="info",
                recommendation="Ensure adequate rest and reduce screen time if applicable.",
                related_features=["blink_rate"],
            ))
        
        return interps
    
    def _get_ad_factors(
        self, 
        features: Dict[str, Any],
        shap_values: List[ShapValue]
    ) -> List[ShapValue]:
        """Get factors most relevant to AD risk."""
        ad_relevant = ["stroop", "nback", "recall", "story", "coherence"]
        return [sv for sv in shap_values if any(r in sv.name.lower() for r in ad_relevant)][:5]
    
    def _get_pd_factors(
        self, 
        features: Dict[str, Any],
        shap_values: List[ShapValue]
    ) -> List[ShapValue]:
        """Get factors most relevant to PD risk."""
        pd_relevant = ["tapping", "tremor", "spiral", "gait", "balance", "blink"]
        return [sv for sv in shap_values if any(r in sv.name.lower() for r in pd_relevant)][:5]
    
    def _generate_summary(self, risk_scores: Dict[str, Any], category: str) -> str:
        """Generate overall summary text."""
        ad = risk_scores.get("ad_risk", 0)
        pd = risk_scores.get("pd_risk", 0)
        score = risk_scores.get("category_score", 50)
        
        if score >= 80:
            return f"Your {category} assessment shows healthy patterns. Continue maintaining your current lifestyle."
        elif score >= 60:
            return f"Your {category} assessment shows mostly normal patterns with some areas to monitor."
        elif score >= 40:
            return f"Your {category} assessment indicates some areas of concern that warrant follow-up."
        else:
            return f"Your {category} assessment shows patterns that should be discussed with a healthcare provider."
    
    def _normalize_value(self, key: str, value: float) -> float:
        """Normalize feature value to 0-1 range."""
        # Simple normalization - production will use proper scaling
        ranges = {
            "stroop_accuracy": (0, 1),
            "nback_accuracy": (0, 1),
            "recall_accuracy": (0, 1),
            "speech_rate": (60, 200),
            "tapping_rate": (0, 8),
            "blink_rate": (5, 30),
        }
        
        if key in ranges:
            low, high = ranges[key]
            return max(0, min(1, (value - low) / (high - low)))
        
        return min(1, max(0, value))
    
    def _calculate_contribution(self, key: str, normalized: float) -> float:
        """Calculate simulated SHAP contribution."""
        # Simplified contribution calculation
        # Positive = increases risk, Negative = decreases risk
        
        # Features where higher is better (decreases risk)
        inverse_features = ["accuracy", "regularity", "stability", "coherence"]
        
        if any(f in key for f in inverse_features):
            return -(normalized - 0.5) * 0.5  # Higher value = lower risk
        else:
            return (normalized - 0.5) * 0.5  # Higher value = higher risk
    
    def _value_to_level(self, normalized: float) -> str:
        """Convert normalized value to level string."""
        if normalized >= 0.7:
            return "High"
        elif normalized >= 0.4:
            return "Medium"
        else:
            return "Low"
    
    def _get_feature_description(self, key: str, level: str) -> str:
        """Get description for feature based on level."""
        interp = self.INTERPRETATIONS.get(key, {})
        return interp.get(level.lower(), f"{level} level detected")
