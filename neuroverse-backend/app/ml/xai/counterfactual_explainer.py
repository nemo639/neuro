"""
Counterfactual Explainer – "What-if" analysis for NeuroVerse predictions.

Generates hypothetical scenarios showing what feature changes would
move a patient from high-risk to low-risk (or vice versa).

Methods:
  - Feature-delta counterfactuals: Find minimal changes to flip prediction
  - Clinical guideline counterfactuals: Map features to clinical thresholds
"""

import logging
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)


# Clinical target ranges (healthy thresholds)
HEALTHY_TARGETS = {
    # Cognitive
    "stroop_accuracy": {"target": 0.90, "direction": "higher_better", "label": "Stroop Accuracy"},
    "nback_accuracy": {"target": 0.80, "direction": "higher_better", "label": "N-Back Accuracy"},
    "recall_accuracy": {"target": 0.75, "direction": "higher_better", "label": "Word Recall"},
    "cognitive_composite": {"target": 0.80, "direction": "higher_better", "label": "Cognitive Composite"},
    "processing_speed_ms": {"target": 800, "direction": "lower_better", "label": "Processing Speed"},
    "stroop_interference": {"target": 20, "direction": "lower_better", "label": "Stroop Interference"},

    # Cognitive extended
    "recall_delayed_accuracy": {"target": 0.70, "direction": "higher_better", "label": "Delayed Recall"},
    "recall_retention_rate": {"target": 0.80, "direction": "higher_better", "label": "Retention Rate"},
    "nback_dprime": {"target": 2.0, "direction": "higher_better", "label": "Signal Detection (d')"},

    # TMT
    "tmt_a_time": {"target": 40, "direction": "lower_better", "label": "TMT-A Time"},
    "tmt_b_time": {"target": 90, "direction": "lower_better", "label": "TMT-B Time"},
    "errors_b": {"target": 1, "direction": "lower_better", "label": "TMT-B Errors"},
    "path_efficiency": {"target": 0.80, "direction": "higher_better", "label": "Path Efficiency"},
    "pen_lifts": {"target": 3, "direction": "lower_better", "label": "Pen Lifts"},
    "spatial_accuracy": {"target": 0.85, "direction": "higher_better", "label": "Spatial Accuracy"},

    # CDT
    "shulman_score": {"target": 4, "direction": "higher_better", "label": "Clock Drawing Score"},
    "number_accuracy": {"target": 0.95, "direction": "higher_better", "label": "Number Placement"},

    # Speech
    "speech_rate": {"target": 130, "direction": "higher_better", "label": "Speech Rate"},
    "pause_count": {"target": 5, "direction": "lower_better", "label": "Speech Pauses"},
    "pause_rate": {"target": 0.2, "direction": "lower_better", "label": "Pause Rate"},
    "story_recall_accuracy": {"target": 0.75, "direction": "higher_better", "label": "Story Recall"},
    "story_coherence": {"target": 0.80, "direction": "higher_better", "label": "Story Coherence"},
    "vowel_stability": {"target": 0.70, "direction": "higher_better", "label": "Voice Stability"},
    "jitter": {"target": 0.01, "direction": "lower_better", "label": "Voice Jitter"},
    "shimmer": {"target": 0.03, "direction": "lower_better", "label": "Voice Shimmer"},
    "word_count": {"target": 100, "direction": "higher_better", "label": "Word Count"},
    "unique_words": {"target": 60, "direction": "higher_better", "label": "Unique Words"},

    # Motor
    "tapping_rate": {"target": 5.5, "direction": "higher_better", "label": "Tapping Speed"},
    "tapping_regularity": {"target": 0.80, "direction": "higher_better", "label": "Tapping Regularity"},
    "tapping_fatigue": {"target": 0.15, "direction": "lower_better", "label": "Motor Fatigue"},
    "spiral_tremor": {"target": 0.10, "direction": "lower_better", "label": "Tremor Score"},
    "spiral_deviation": {"target": 0.20, "direction": "lower_better", "label": "Drawing Deviation"},

    # Motor (meander)
    "meander_tremor": {"target": 0.10, "direction": "lower_better", "label": "Meander Tremor"},
    "meander_deviation": {"target": 0.20, "direction": "lower_better", "label": "Meander Deviation"},
    "meander_smoothness": {"target": 0.80, "direction": "higher_better", "label": "Meander Smoothness"},
    "spiral_tightness": {"target": 0.80, "direction": "higher_better", "label": "Spiral Tightness"},
    "tremor_amplitude": {"target": 0.05, "direction": "lower_better", "label": "Tremor Amplitude"},

    # Speech (acoustic)
    "hnr": {"target": 20.0, "direction": "higher_better", "label": "Harmonics-to-Noise"},
    "f0_mean": {"target": 150.0, "direction": "higher_better", "label": "Pitch (F0)"},
    "f0_std": {"target": 30.0, "direction": "higher_better", "label": "Pitch Variation"},

    # Facial
    "blink_rate": {"target": 17, "direction": "higher_better", "label": "Blink Rate"},
    "smile_velocity": {"target": 0.6, "direction": "higher_better", "label": "Smile Speed"},
    "smile_intensity": {"target": 0.7, "direction": "higher_better", "label": "Smile Intensity"},
    "expression_range": {"target": 70, "direction": "higher_better", "label": "Expression Range"},
    "hypomimia_score": {"target": 20, "direction": "lower_better", "label": "Facial Masking"},
    "facial_symmetry": {"target": 90, "direction": "higher_better", "label": "Facial Symmetry"},
    "facial_expressivity": {"target": 70, "direction": "higher_better", "label": "Facial Expressivity"},
    "smile_symmetry": {"target": 85, "direction": "higher_better", "label": "Smile Symmetry"},
    "symmetry_composite": {"target": 87, "direction": "higher_better", "label": "Symmetry Composite"},
}


class CounterfactualExplainer:
    """
    Generate counterfactual explanations showing what changes
    would alter a patient's risk prediction.

    Output types:
      - "actionable": Changes the patient could realistically make
      - "diagnostic": Changes that indicate what's driving the prediction
    """

    def generate_counterfactuals(
        self,
        features: Dict[str, Any],
        predictions: Optional[Dict[str, Any]] = None,
        category: str = "",
        top_k: int = 5,
    ) -> Dict[str, Any]:
        """
        Generate counterfactual scenarios.

        Returns:
            {
                "current_risk": {"ad": float, "pd": float},
                "counterfactuals": list of scenarios,
                "actionable_insights": list of recommendations,
            }
        """
        predictions = predictions or {}
        ad_risk = predictions.get("ad_risk", 0)
        pd_risk = predictions.get("pd_risk", 0)

        counterfactuals = self._find_counterfactuals(features, predictions, category)
        actionable = self._generate_actionable(counterfactuals, category)

        return {
            "current_risk": {"ad": ad_risk, "pd": pd_risk},
            "counterfactuals": counterfactuals[:top_k],
            "actionable_insights": actionable[:top_k],
            "method": "clinical_threshold_counterfactual",
        }

    def _find_counterfactuals(
        self,
        features: Dict[str, Any],
        predictions: Dict[str, Any],
        category: str,
    ) -> List[Dict[str, Any]]:
        """Find minimal feature changes to move toward healthy prediction."""
        ad_risk = predictions.get("ad_risk", 0)
        pd_risk = predictions.get("pd_risk", 0)
        max_risk = max(ad_risk, pd_risk)

        if max_risk < 15:
            return []  # Already low risk

        results = []
        skip = {"category", "items_processed"}

        for key, val in features.items():
            if key in skip or not isinstance(val, (int, float)) or key.startswith("_"):
                continue

            target_info = HEALTHY_TARGETS.get(key)
            if target_info is None:
                continue

            target = target_info["target"]
            direction = target_info["direction"]
            label = target_info["label"]

            # Calculate gap from healthy target
            if direction == "higher_better":
                gap = target - val
                if gap <= 0:
                    continue  # Already at/above target
                pct_change = gap / max(abs(target), 1e-8) * 100
                change_desc = f"Increase {label} from {val:.2f} to {target:.2f}"
            else:
                gap = val - target
                if gap <= 0:
                    continue  # Already at/below target
                pct_change = gap / max(abs(val), 1e-8) * 100
                change_desc = f"Reduce {label} from {val:.2f} to {target:.2f}"

            # Estimate risk reduction (proportional to gap and risk)
            risk_impact = min(gap / max(abs(target), 1e-8), 1.0) * max_risk * 0.15
            estimated_new_risk = max(max_risk - risk_impact, 0)

            results.append({
                "feature": key,
                "feature_label": label,
                "current_value": round(float(val), 3),
                "target_value": round(float(target), 3),
                "change_needed": round(float(gap), 3),
                "change_direction": "increase" if direction == "higher_better" else "decrease",
                "description": change_desc,
                "estimated_risk_reduction": round(float(risk_impact), 1),
                "estimated_new_risk": round(float(estimated_new_risk), 1),
                "feasibility": self._assess_feasibility(key),
            })

        results.sort(key=lambda x: x["estimated_risk_reduction"], reverse=True)
        return results

    def _generate_actionable(
        self, counterfactuals: List[Dict[str, Any]], category: str
    ) -> List[Dict[str, Any]]:
        """Convert counterfactuals into actionable clinical recommendations."""
        actions = []
        for cf in counterfactuals:
            if cf["feasibility"] == "not_modifiable":
                continue

            recommendation = self._get_recommendation(cf["feature"], cf["change_direction"])
            if recommendation:
                actions.append({
                    "feature": cf["feature_label"],
                    "recommendation": recommendation,
                    "priority": "high" if cf["estimated_risk_reduction"] > 10 else "medium",
                    "estimated_benefit": f"~{cf['estimated_risk_reduction']:.0f}% risk reduction",
                })

        return actions

    @staticmethod
    def _assess_feasibility(feature: str) -> str:
        """Assess whether a feature change is modifiable."""
        modifiable = {
            "speech_rate", "pause_count", "pause_rate", "story_recall_accuracy",
            "tapping_rate", "tapping_regularity", "tapping_fatigue",
            "step_regularity", "gait_speed", "balance_stability",
        }
        partially = {
            "stroop_accuracy", "nback_accuracy", "recall_accuracy",
            "cognitive_composite", "processing_speed_ms", "vowel_stability",
            "path_efficiency",
        }
        not_modifiable = {
            "tmt_a_time", "tmt_b_time", "jitter", "shimmer",
            "spiral_tremor", "spiral_deviation",
            "meander_tremor", "meander_deviation",
            "tremor_amplitude", "tremor_rms", "tremor_jerk",
        }

        if feature in modifiable:
            return "modifiable"
        elif feature in partially:
            return "partially_modifiable"
        elif feature in not_modifiable:
            return "not_modifiable"
        return "unknown"

    @staticmethod
    def _get_recommendation(feature: str, direction: str) -> Optional[str]:
        """Get clinical recommendation for a specific feature change."""
        recommendations = {
            "speech_rate": "Practice reading aloud and conversational exercises to improve speech fluency.",
            "pause_count": "Speech therapy exercises can help reduce hesitation pauses.",
            "story_recall_accuracy": "Memory training exercises and mnemonic strategies may improve recall.",
            "tapping_rate": "Regular fine motor exercises (piano, typing) can improve tapping speed.",
            "tapping_regularity": "Rhythm-based exercises can improve motor timing consistency.",
            "tapping_fatigue": "Graded exercise programs can help build motor endurance.",
            "step_regularity": "Walking exercises with a metronome or rhythmic cues can improve gait regularity.",
            "gait_speed": "Regular walking programs and balance exercises can improve gait speed.",
            "balance_stability": "Tai chi, yoga, or balance training programs are recommended.",
            "stroop_accuracy": "Cognitive training with attention exercises may help improve executive function.",
            "nback_accuracy": "Working memory training (N-back games) can improve this metric over time.",
            "recall_accuracy": "Spaced repetition and association techniques can improve word recall.",
            "processing_speed_ms": "Cognitive speed training and regular mental exercise may help.",
            "vowel_stability": "Voice exercises and speech therapy can improve vocal stability.",
        }
        return recommendations.get(feature)
