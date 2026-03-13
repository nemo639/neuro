"""
Clinical Interpretation Engine – generates human-readable explanations.

Maps numeric features and risk scores to clinically meaningful text
following neuropsychological assessment reporting standards.
"""

from typing import Any, Dict, List


# ------------------------------------------------------------------ #
# Clinical reference ranges                                           #
# ------------------------------------------------------------------ #
CLINICAL_RANGES = {
    # Cognitive (app-based)
    "stroop_accuracy": {"normal": (0.85, 1.0), "mild": (0.70, 0.85), "label": "Stroop Test Accuracy"},
    "stroop_interference": {"normal": (0, 20), "mild": (20, 40), "label": "Stroop Interference"},
    "nback_accuracy": {"normal": (0.75, 1.0), "mild": (0.55, 0.75), "label": "N-Back Accuracy"},
    "nback_dprime": {"normal": (1.5, 5.0), "mild": (0.5, 1.5), "label": "Signal Detection (d')"},
    "recall_accuracy": {"normal": (0.70, 1.0), "mild": (0.45, 0.70), "label": "Word Recall Accuracy"},
    "cognitive_composite": {"normal": (0.75, 1.0), "mild": (0.50, 0.75), "label": "Cognitive Composite"},

    # TMT (Trail Making Test)
    "tmt_a_time": {"normal": (20, 60), "mild": (60, 120), "label": "TMT-A Time (sec)"},
    "tmt_b_time": {"normal": (40, 120), "mild": (120, 240), "label": "TMT-B Time (sec)"},
    "errors_b": {"normal": (0, 1), "mild": (1, 3), "label": "TMT-B Errors"},
    "path_efficiency": {"normal": (0.7, 1.0), "mild": (0.5, 0.7), "label": "Path Efficiency"},
    "pen_lifts": {"normal": (0, 5), "mild": (5, 15), "label": "Pen Lifts"},

    # CDT (Clock Drawing Test)
    "shulman_score": {"normal": (4, 5), "mild": (2, 4), "label": "Clock Drawing Score (Shulman)"},
    "number_accuracy": {"normal": (0.9, 1.0), "mild": (0.7, 0.9), "label": "Number Placement Accuracy"},

    # Speech
    "speech_rate": {"normal": (100, 160), "mild": (80, 100), "label": "Speech Rate (wpm)"},
    "story_recall_accuracy": {"normal": (0.70, 1.0), "mild": (0.45, 0.70), "label": "Story Recall"},
    "vowel_stability": {"normal": (0.6, 1.0), "mild": (0.35, 0.6), "label": "Voice Stability"},
    "jitter": {"normal": (0, 0.01), "mild": (0.01, 0.02), "label": "Voice Jitter"},
    "shimmer": {"normal": (0, 0.03), "mild": (0.03, 0.05), "label": "Voice Shimmer"},

    # Motor
    "tapping_rate": {"normal": (4.5, 8.0), "mild": (3.0, 4.5), "label": "Tapping Speed (taps/s)"},
    "tapping_regularity": {"normal": (0.7, 1.0), "mild": (0.5, 0.7), "label": "Tapping Regularity"},
    "tapping_fatigue": {"normal": (0, 0.2), "mild": (0.2, 0.4), "label": "Motor Fatigue Index"},
    "spiral_tremor": {"normal": (0, 0.3), "mild": (0.3, 0.6), "label": "Spiral Tremor"},
    "meander_tremor": {"normal": (0, 0.3), "mild": (0.3, 0.6), "label": "Meander Tremor"},
    "spiral_deviation": {"normal": (0, 0.3), "mild": (0.3, 0.5), "label": "Spiral Deviation"},
    "meander_deviation": {"normal": (0, 0.3), "mild": (0.3, 0.5), "label": "Meander Deviation"},

    # Gait
    "step_regularity": {"normal": (0.7, 1.0), "mild": (0.5, 0.7), "label": "Step Regularity"},
    "gait_speed": {"normal": (0.9, 1.5), "mild": (0.6, 0.9), "label": "Gait Speed (m/s)"},
    "balance_stability": {"normal": (0.7, 1.0), "mild": (0.5, 0.7), "label": "Balance Control"},

    # Facial
    "blink_rate": {"normal": (12, 22), "mild": (8, 12), "label": "Blink Rate (/min)"},
}


class InterpretationEngine:
    """Generate structured clinical interpretations from features and risk scores."""

    def interpret(
        self,
        category: str,
        features: Dict[str, Any],
        risk_scores: Dict[str, Any],
        predictions: Dict[str, Any] = None,
    ) -> List[Dict[str, Any]]:
        """
        Return a list of interpretation dicts:
            {"title", "description", "severity", "recommendation", "related_features"}
        """
        interpretations: List[Dict[str, Any]] = []

        # 1. Overall risk interpretation
        interpretations.extend(self._risk_interpretation(category, risk_scores))

        # 2. Per-feature clinical flags
        interpretations.extend(self._feature_flags(features))

        # 3. Category-specific patterns
        interpretations.extend(self._category_patterns(category, features))

        # 4. Positive findings
        interpretations.extend(self._positive_findings(category, features, risk_scores))

        return interpretations

    # ------------------------------------------------------------------ #
    # Overall risk                                                       #
    # ------------------------------------------------------------------ #
    def _risk_interpretation(self, category: str, risk: dict) -> List[Dict[str, Any]]:
        result = []
        ad = risk.get("ad_risk", 0)
        pd = risk.get("pd_risk", 0)

        if ad > 50:
            result.append({
                "title": "Elevated Alzheimer's Risk",
                "description": (
                    f"Your {category} assessment yields an AD risk estimate of {ad:.0f}%. "
                    "This suggests patterns consistent with early cognitive decline. "
                    "A comprehensive neuropsychological evaluation is recommended."
                ),
                "severity": "warning",
                "recommendation": "Schedule a follow-up with a neurologist for detailed cognitive assessment.",
                "related_features": ["recall_accuracy", "story_recall_accuracy", "stroop_accuracy"],
            })
        elif ad > 25:
            result.append({
                "title": "Moderate AD Risk Indicators",
                "description": (
                    f"Your {category} assessment shows some patterns ({ad:.0f}% risk) "
                    "that warrant monitoring over time."
                ),
                "severity": "info",
                "recommendation": "Continue regular assessments to track any changes.",
                "related_features": ["cognitive_composite"],
            })

        if pd > 50:
            result.append({
                "title": "Elevated Parkinson's Risk",
                "description": (
                    f"Your {category} assessment yields a PD risk estimate of {pd:.0f}%. "
                    "Motor patterns suggest possible early parkinsonian features."
                ),
                "severity": "warning",
                "recommendation": "Consult a movement disorder specialist.",
                "related_features": ["tapping_regularity", "spiral_tremor", "vowel_stability"],
            })
        elif pd > 25:
            result.append({
                "title": "Moderate PD Risk Indicators",
                "description": (
                    f"Some motor/speech patterns ({pd:.0f}% risk) may warrant monitoring."
                ),
                "severity": "info",
                "recommendation": "Monitor motor function and voice quality over time.",
                "related_features": ["tapping_rate", "spiral_deviation"],
            })

        return result

    # ------------------------------------------------------------------ #
    # Feature-level flags                                                #
    # ------------------------------------------------------------------ #
    def _feature_flags(self, features: dict) -> List[Dict[str, Any]]:
        flags = []
        for key, val in features.items():
            if not isinstance(val, (int, float)):
                continue
            ref = CLINICAL_RANGES.get(key)
            if ref is None:
                continue

            lo_n, hi_n = ref["normal"]
            lo_m, hi_m = ref["mild"]
            label = ref["label"]

            # Check if outside normal range (accounting for direction)
            if lo_n <= hi_n:
                # Higher is better (accuracy, regularity, speed)
                if val < lo_m:
                    flags.append({
                        "title": f"{label} – Below Expected",
                        "description": f"{label} is {val:.2f}, significantly below the normal range ({lo_n}–{hi_n}).",
                        "severity": "warning",
                        "recommendation": f"This {label.lower()} result warrants clinical attention.",
                        "related_features": [key],
                    })
                elif val < lo_n:
                    flags.append({
                        "title": f"{label} – Mildly Reduced",
                        "description": f"{label} is {val:.2f}, slightly below normal ({lo_n}–{hi_n}).",
                        "severity": "info",
                        "recommendation": f"Monitor {label.lower()} in future assessments.",
                        "related_features": [key],
                    })
            else:
                # Lower is better (interference, fatigue, tremor)
                if val > hi_m:
                    flags.append({
                        "title": f"{label} – Elevated",
                        "description": f"{label} is {val:.2f}, above the expected range.",
                        "severity": "warning",
                        "recommendation": f"Elevated {label.lower()} may indicate motor or cognitive concerns.",
                        "related_features": [key],
                    })

        return flags[:6]  # Limit to top 6 flags

    # ------------------------------------------------------------------ #
    # Category patterns                                                  #
    # ------------------------------------------------------------------ #
    def _category_patterns(self, category: str, features: dict) -> List[Dict[str, Any]]:
        patterns = []

        if category == "cognitive":
            # Memory-executive dissociation
            recall = features.get("recall_accuracy", 0.5)
            stroop = features.get("stroop_accuracy", 0.5)
            if recall < 0.5 and stroop > 0.8:
                patterns.append({
                    "title": "Memory-Executive Dissociation",
                    "description": "Memory performance is impaired while executive function is preserved – pattern consistent with early AD.",
                    "severity": "info",
                    "recommendation": "Amnestic profile detected; monitor closely.",
                    "related_features": ["recall_accuracy", "stroop_accuracy"],
                })

            # TMT B/A ratio pattern (executive dysfunction)
            tmt_a = features.get("tmt_a_time", 0)
            tmt_b = features.get("tmt_b_time", 0)
            if tmt_a > 0 and tmt_b > 0:
                ba_ratio = tmt_b / tmt_a
                if ba_ratio > 3.5:
                    patterns.append({
                        "title": "Executive Dysfunction Pattern",
                        "description": f"TMT B/A ratio ({ba_ratio:.1f}) is elevated, suggesting difficulty with cognitive flexibility and set-shifting.",
                        "severity": "warning",
                        "recommendation": "Comprehensive neuropsychological evaluation recommended.",
                        "related_features": ["tmt_a_time", "tmt_b_time"],
                    })

            # CDT visuospatial deficit
            shulman = features.get("shulman_score", 5)
            if 0 < shulman <= 2:
                patterns.append({
                    "title": "Visuospatial-Constructional Deficit",
                    "description": f"Clock drawing score ({shulman}/5) indicates significant visuospatial impairment, commonly seen in AD and vascular dementia.",
                    "severity": "warning",
                    "recommendation": "Neuroimaging and detailed cognitive assessment warranted.",
                    "related_features": ["shulman_score", "number_accuracy"],
                })

            # TMT motor slowing (high pen lifts + slow velocity)
            pen_lifts = features.get("pen_lifts", 0)
            vel = features.get("velocity_mean", 0)
            if pen_lifts > 15 and vel > 0 and vel < 50:
                patterns.append({
                    "title": "Psychomotor Slowing",
                    "description": "Frequent pen lifts with slow drawing velocity suggest psychomotor slowing.",
                    "severity": "info",
                    "recommendation": "May indicate subcortical involvement; monitor progression.",
                    "related_features": ["pen_lifts", "velocity_mean"],
                })

        elif category == "speech":
            # Pause pattern
            pc = features.get("pause_count", 0)
            sr = features.get("speech_rate", 130)
            if pc > 12 and sr < 100:
                patterns.append({
                    "title": "Anomic Speech Pattern",
                    "description": "High pause frequency with reduced speech rate may indicate word-finding difficulties.",
                    "severity": "info",
                    "recommendation": "Speech-language evaluation may be beneficial.",
                    "related_features": ["pause_count", "speech_rate"],
                })

            # Voice quality (PD indicator)
            jitter = features.get("jitter", 0)
            shimmer = features.get("shimmer", 0)
            if jitter > 0.02 and shimmer > 0.05:
                patterns.append({
                    "title": "Dysarthric Voice Pattern",
                    "description": "Elevated jitter and shimmer suggest motor speech involvement consistent with hypokinetic dysarthria.",
                    "severity": "info",
                    "recommendation": "Voice therapy and PD motor assessment recommended.",
                    "related_features": ["jitter", "shimmer"],
                })

        elif category == "motor":
            # Bradykinesia pattern
            rate = features.get("tapping_rate", 5)
            fatigue = features.get("tapping_fatigue", 0)
            if rate < 4 and fatigue > 0.3:
                patterns.append({
                    "title": "Bradykinesia Pattern",
                    "description": "Slow tapping with progressive fatigue is consistent with parkinsonian bradykinesia.",
                    "severity": "warning",
                    "recommendation": "Movement disorder evaluation recommended.",
                    "related_features": ["tapping_rate", "tapping_fatigue"],
                })

            # Multi-drawing tremor (spiral + meander both show tremor)
            spiral_tremor = features.get("spiral_tremor", 0)
            meander_tremor = features.get("meander_tremor", 0)
            if spiral_tremor > 0.4 and meander_tremor > 0.4:
                patterns.append({
                    "title": "Consistent Tremor Across Drawings",
                    "description": "Tremor detected in both spiral and meander drawings, increasing confidence in motor dysfunction.",
                    "severity": "warning",
                    "recommendation": "Consistent tremor pattern warrants neurological evaluation.",
                    "related_features": ["spiral_tremor", "meander_tremor"],
                })

            # Drawing deviation pattern
            spiral_dev = features.get("spiral_deviation", 0)
            meander_dev = features.get("meander_deviation", 0)
            if spiral_dev > 0.5 or meander_dev > 0.5:
                patterns.append({
                    "title": "Motor Control Impairment",
                    "description": "Significant deviation from target path in drawing tasks suggests fine motor control difficulty.",
                    "severity": "info",
                    "recommendation": "Occupational therapy assessment may be helpful.",
                    "related_features": ["spiral_deviation", "meander_deviation"],
                })

        return patterns

    # ------------------------------------------------------------------ #
    # Positive findings                                                  #
    # ------------------------------------------------------------------ #
    def _positive_findings(self, category: str, features: dict, risk: dict) -> List[Dict[str, Any]]:
        score = risk.get("category_score", 50)
        if score >= 75:
            return [{
                "title": "Healthy Performance",
                "description": f"Your {category} assessment shows patterns within the normal range (score: {score:.0f}/100).",
                "severity": "positive",
                "recommendation": "Continue maintaining your cognitive and physical health.",
                "related_features": [],
            }]
        return []
