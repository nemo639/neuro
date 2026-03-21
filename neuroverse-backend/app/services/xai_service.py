"""
XAI Service – Explainable AI explanation generation.

Orchestrates six XAI modules:
  1. SHAPExplainer          → feature attribution values (SHAP-style)
  2. SaliencyGenerator      → visual saliency (GradCAM heatmaps, feature bars)
  3. InterpretationEngine   → human-readable clinical interpretations
  4. LIMEExplainer          → local interpretable explanations
  5. IntegratedGradients    → path-integrated attributions
  6. CounterfactualExplainer→ "what-if" scenario analysis
  7. AttentionVisualizer    → model attention pattern visualization

Output structure matches Flutter XAI.dart requirements.
"""

import logging
from typing import Any, Dict, List, Optional

from app.schemas.test_result import (
    ShapValue, FeatureImportance, Interpretation, SaliencyData,
)
from app.ml.xai.shap_explainer import SHAPExplainer
from app.ml.xai.saliency_generator import SaliencyGenerator
from app.ml.xai.interpretation import InterpretationEngine
from app.ml.xai.lime_explainer import LIMEExplainer
from app.ml.xai.integrated_gradients import IntegratedGradientsExplainer
from app.ml.xai.counterfactual_explainer import CounterfactualExplainer
from app.ml.xai.attention_visualizer import AttentionVisualizer

logger = logging.getLogger(__name__)

# Feature display names for the UI
FEATURE_DISPLAY = {
    # Cognitive (app-based)
    "stroop_accuracy": "Stroop Test Accuracy",
    "stroop_interference": "Stroop Interference Score",
    "stroop_avg_rt": "Stroop Response Time",
    "stroop_congruent_rt": "Congruent Response Time",
    "stroop_incongruent_rt": "Incongruent Response Time",
    "stroop_error_rate": "Stroop Error Rate",
    "nback_accuracy": "N-Back Accuracy",
    "nback_level": "N-Back Level Achieved",
    "nback_dprime": "Signal Detection (d')",
    "nback_hits": "N-Back Hits",
    "recall_accuracy": "Word Recall Accuracy",
    "recall_intrusions": "Recall Intrusions",
    "recall_first_time": "Time to First Recall",
    "recall_total_words": "Total Words Recalled",
    "cognitive_composite": "Cognitive Composite",
    "processing_speed_ms": "Processing Speed",
    # TMT features
    "tmt_a_time": "TMT-A Time (sec)",
    "tmt_b_time": "TMT-B Time (sec)",
    "time_per_circle_a": "Time per Circle (A)",
    "time_per_circle_b": "Time per Circle (B)",
    "tmt_ba_ratio": "TMT B/A Ratio",
    "errors_a": "TMT-A Errors",
    "errors_b": "TMT-B Errors",
    "sequence_errors_b": "TMT-B Sequence Errors",
    "velocity_mean": "Pen Velocity (mean)",
    "velocity_std": "Pen Velocity (variability)",
    "acceleration_mean": "Pen Acceleration",
    "jerk_mean": "Movement Jerk",
    "curvature_mean": "Path Curvature",
    "straightness_ratio": "Path Straightness",
    "pause_count": "Pen Pauses",
    "total_pause_duration": "Total Pause Duration",
    "hover_time": "Hover Time",
    "pen_lifts": "Pen Lifts",
    "path_efficiency": "Path Efficiency",
    "spatial_accuracy": "Spatial Accuracy",
    "distance_variability": "Distance Variability",
    # CDT features
    "shulman_score": "Clock Drawing Score (Shulman)",
    "clock_contour": "Clock Contour Quality",
    "numbers_placed": "Numbers Placed",
    "numbers_correct": "Numbers Correct",
    "number_accuracy": "Number Placement Accuracy",
    "center_deviation": "Center Deviation",
    # Speech
    "story_recall_accuracy": "Story Recall Accuracy",
    "story_coherence": "Narrative Coherence",
    "story_duration": "Story Duration",
    "vowel_duration": "Sustained Vowel Duration",
    "vowel_stability": "Voice Stability",
    "vowel_amplitude_var": "Amplitude Variation",
    "speech_rate": "Speech Rate (wpm)",
    "speech_duration": "Speech Duration",
    "pause_rate": "Pause Rate",
    "mean_pause_duration": "Mean Pause Duration",
    "max_pause_duration": "Max Pause Duration",
    "speech_silence_ratio": "Speech-Silence Ratio",
    "total_duration": "Total Duration",
    "word_count": "Word Count",
    "unique_words": "Unique Words",
    "jitter": "Voice Jitter",
    "shimmer": "Voice Shimmer",
    "hnr": "Harmonics-to-Noise",
    "f0_mean": "Fundamental Frequency",
    "f0_std": "F0 Variability",
    # Motor
    "tapping_rate": "Tapping Speed",
    "tapping_regularity": "Tapping Regularity",
    "tapping_fatigue": "Motor Fatigue",
    "tapping_total": "Total Taps",
    "tapping_duration": "Tapping Duration",
    "spiral_duration": "Spiral Drawing Duration",
    "spiral_tremor": "Spiral Tremor Detection",
    "spiral_deviation": "Spiral Drawing Accuracy",
    "spiral_tightness": "Spiral Tightness",
    "spiral_mean_speed": "Spiral Drawing Speed",
    "spiral_speed_variability": "Spiral Speed Variability",
    "spiral_tremor_score": "Spiral Tremor Score",
    "meander_duration": "Meander Drawing Duration",
    "meander_tremor": "Meander Tremor Detection",
    "meander_deviation": "Meander Drawing Accuracy",
    "meander_smoothness": "Meander Smoothness",
    "meander_mean_speed": "Meander Drawing Speed",
    "meander_speed_variability": "Meander Speed Variability",
    "meander_tremor_score": "Meander Tremor Score",
    "drawing_mean_speed": "Drawing Speed",
    "drawing_speed_variability": "Speed Variability",
    "drawing_tremor_score": "Tremor Score",
    "drawing_num_points": "Drawing Detail",
    "motor_composite": "Motor Composite",
    # Gait
    "step_regularity": "Step Regularity",
    "gait_speed": "Walking Speed",
    "turn_stability": "Turn Stability",
    "balance_stability": "Balance Control",
    "balance_sway": "Body Sway",
    # Facial
    "blink_rate": "Blink Rate",
    "blink_count": "Blink Count",
    "avg_blink_duration_ms": "Avg Blink Duration",
    "smile_intensity": "Smile Amplitude",
    "smile_velocity": "Smile Velocity",
    "smile_symmetry": "Smile Symmetry",
    "smile_count": "Smile Count",
    "facial_symmetry": "Facial Symmetry",
    "muscle_tone": "Muscle Tone",
    "expression_range": "Expression Range",
    "hypomimia_score": "Hypomimia Score",
    "facial_expressivity": "Facial Expressivity",
    "symmetry_composite": "Symmetry Composite",
    "au01_mean": "AU01 (Inner Brow Raise)",
    "au06_mean": "AU06 (Cheek Raiser)",
    "au12_mean": "AU12 (Lip Corner Puller)",
    "au25_mean": "AU25 (Lips Part)",
    "au45_mean": "AU45 (Blink)",
    "mouth_open_mean": "Mouth Opening",
    "mouth_width_mean": "Mouth Width",
    "jaw_open_mean": "Jaw Opening",
    "eye_open_mean": "Eye Opening",
    "eye_raise_mean": "Eye Raise",
    "blink_score": "Blink Score",
    "smile_score": "Smile Score",
    "expression_score": "Expression Score",
    "combined_score": "Combined Facial Score",
}

# Category-specific importance weights (from clinical literature)
CATEGORY_WEIGHTS = {
    "cognitive": {
        "stroop_accuracy": 0.15, "stroop_interference": 0.08, "stroop_avg_rt": 0.05,
        "nback_accuracy": 0.15, "nback_dprime": 0.08, "recall_accuracy": 0.18,
        "recall_intrusions": 0.05, "cognitive_composite": 0.04, "processing_speed_ms": 0.03,
        # TMT features
        "tmt_a_time": 0.06, "tmt_b_time": 0.10, "tmt_ba_ratio": 0.08,
        "errors_b": 0.07, "velocity_mean": 0.03, "path_efficiency": 0.05,
        "pen_lifts": 0.03, "jerk_mean": 0.02,
        # CDT features
        "shulman_score": 0.12, "number_accuracy": 0.06, "clock_contour": 0.04,
    },
    "speech": {
        "story_recall_accuracy": 0.18, "speech_rate": 0.12, "pause_count": 0.10,
        "pause_rate": 0.08, "vowel_stability": 0.12, "jitter": 0.10,
        "shimmer": 0.08, "f0_std": 0.06, "story_coherence": 0.10, "hnr": 0.06,
    },
    "motor": {
        "tapping_regularity": 0.16, "spiral_tremor": 0.18, "tapping_fatigue": 0.12,
        "tapping_rate": 0.10, "spiral_deviation": 0.08, "spiral_tremor_score": 0.08,
        "spiral_speed_variability": 0.06,
        "meander_tremor": 0.08, "meander_deviation": 0.06, "meander_tremor_score": 0.08,
    },
    "gait": {
        "step_regularity": 0.30, "balance_stability": 0.25, "gait_speed": 0.25,
        "turn_stability": 0.20,
    },
    "facial": {
        "blink_rate": 0.12, "blink_count": 0.05, "avg_blink_duration_ms": 0.04,
        "smile_velocity": 0.10, "smile_symmetry": 0.08, "smile_intensity": 0.10,
        "facial_symmetry": 0.08, "expression_range": 0.10, "hypomimia_score": 0.12,
        "facial_expressivity": 0.08, "symmetry_composite": 0.05,
        "au12_mean": 0.04, "au06_mean": 0.02, "au45_mean": 0.02,
    },
}


class XAIService:
    """Orchestrator for explainable AI across all modalities."""

    def __init__(self):
        self.shap = SHAPExplainer()
        self.saliency = SaliencyGenerator()
        self.interpreter = InterpretationEngine()
        self.lime = LIMEExplainer()
        self.ig = IntegratedGradientsExplainer()
        self.counterfactual = CounterfactualExplainer()
        self.attention = AttentionVisualizer()

    async def generate_explanation(
        self,
        category: str,
        features: Dict[str, Any],
        risk_scores: Dict[str, Any],
        predictions: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Generate complete XAI explanation for test results.
        Returns dict matching XAIExplanation schema for frontend XAI.dart.
        """
        predictions = predictions or {}

        # Extract model + tensor passed from predictor for real XAI computation
        xai_model = predictions.pop("_xai_model", None)
        xai_tensor = predictions.pop("_xai_tensor", None)

        # Build a predict_fn for LIME/SHAP when model is available
        predict_fn = None
        if xai_model is not None and xai_tensor is not None:
            predict_fn = self._make_predict_fn(xai_model, features)

        # 1. SHAP values (feature attributions)
        raw_shap = self.shap.compute_shap_values(features, predictions)
        shap_values = self._to_shap_schema(raw_shap)

        # 2. Feature importance ranking
        feature_importance = self._compute_importance(features, category)

        # 3. Human-readable interpretations
        raw_interps = self.interpreter.interpret(category, features, risk_scores, predictions)
        interpretations = [Interpretation(**i) for i in raw_interps]

        # 4. Saliency / visual data (GradCAM) — pass model+tensor for real heatmaps
        raw_saliency = self.saliency.generate(
            category, features, predictions,
            model=xai_model, input_tensor=xai_tensor,
        )
        saliency_data = SaliencyData(**raw_saliency) if raw_saliency else None

        # 5. LIME explanations
        # For image models (CDT, motor), skip real LIME tabular since the model
        # expects 4D image tensors, not 2D feature vectors.  Use approximation.
        is_image_model = category in ("motor",) or features.get("_has_cdt_image")
        lime_predict_fn = None if is_image_model else predict_fn
        lime_data = self.lime.explain_tabular(features, predictions, predict_fn=lime_predict_fn)

        # 6. Integrated Gradients
        # For image models, use image IG (pixel-level); for tabular, use feature IG
        if is_image_model and xai_model is not None and xai_tensor is not None:
            ig_heatmap = self.ig.compute_image_attributions(
                xai_model, xai_tensor, target_output="risk",
            )
            # Convert image IG heatmap to feature-level format for consistent output
            if ig_heatmap is not None:
                ig_data = [{
                    "feature": "image_attribution",
                    "attribution": 1.0,
                    "importance": 1.0,
                    "direction": "risk",
                    "heatmap": ig_heatmap,
                }]
            else:
                ig_data = self.ig._approx_ig(features, predictions)
        else:
            ig_data = self.ig.compute_attributions(
                features, predictions,
                model=xai_model, input_tensor=xai_tensor,
            )

        # 7. Counterfactual analysis
        cf_data = self.counterfactual.generate_counterfactuals(
            features, predictions, category
        )

        # 8. Attention visualization — use real weights + spatial attention from model
        attn_weights = predictions.get("attention_weights", {})
        attn_data = self.attention.visualize_feature_attention(
            attn_weights, features, category
        ) if attn_weights else None

        # Try spatial attention from image model if no feature attention
        if attn_data is None and xai_model is not None and xai_tensor is not None:
            spatial = self.attention.visualize_spatial_attention(
                model=xai_model, input_tensor=xai_tensor,
            )
            if spatial:
                attn_data = spatial

        attn_summary = self.attention.generate_attention_summary(
            category, attn_data or {}, predictions
        ) if attn_data else None

        # 9. AD/PD factor split
        ad_factors = self._split_factors(shap_values, "ad")
        pd_factors = self._split_factors(shap_values, "pd")

        # 10. Summary
        summary = self._generate_summary(risk_scores, category)

        # 11. Confidence (from model or heuristic)
        confidence = predictions.get("confidence", risk_scores.get("model_confidence", 0.5))

        return {
            "summary": summary,
            "confidence": round(confidence, 3),
            "shap_values": [sv.model_dump() for sv in shap_values],
            "feature_importance": [fi.model_dump() for fi in feature_importance],
            "interpretations": [i.model_dump() for i in interpretations],
            "saliency_data": saliency_data.model_dump() if saliency_data else None,
            "category_explanations": {
                category: f"Analysis based on {features.get('items_processed', 0)} test(s) "
                          f"using {'neural network model' if predictions.get('source', '').endswith('_model') else 'clinical heuristics'}"
            },
            "ad_factors": [f.model_dump() for f in ad_factors],
            "pd_factors": [f.model_dump() for f in pd_factors],
            # New XAI methods
            "lime_explanations": lime_data,
            "integrated_gradients": ig_data,
            "counterfactual_analysis": cf_data,
            "attention_analysis": attn_data,
            "attention_summary": attn_summary,
            # Existing placeholders
            "comparison_with_baseline": None,
            "trend_analysis": None,
        }

    # ------------------------------------------------------------------ #
    # Helpers                                                             #
    # ------------------------------------------------------------------ #

    def _to_shap_schema(self, raw: List[Dict[str, Any]]) -> List[ShapValue]:
        """Convert raw SHAP dicts to ShapValue schema objects."""
        result = []
        for item in raw:
            feat = item.get("feature", "")
            shap_val = item.get("shap_value", 0)
            importance = item.get("importance", 0)
            display = FEATURE_DISPLAY.get(feat, feat.replace("_", " ").title())

            direction = "positive" if shap_val > 0.01 else "negative" if shap_val < -0.01 else "neutral"
            level = "High" if importance > 0.15 else "Medium" if importance > 0.05 else "Low"

            result.append(ShapValue(
                name=display,
                value=round(shap_val, 4),
                contribution=round(abs(shap_val) * 100, 1),
                level=level,
                description=self._feature_description(feat, shap_val),
                direction=direction,
            ))
        return result[:10]

    def _compute_importance(self, features: dict, category: str) -> List[FeatureImportance]:
        """Compute weighted feature importance for the category."""
        weights = CATEGORY_WEIGHTS.get(category, {})
        skip = {"category", "items_processed"}
        items = []

        for key, val in features.items():
            if key in skip or not isinstance(val, (int, float)) or key.startswith("_"):
                continue
            w = weights.get(key, 0.03)
            display = FEATURE_DISPLAY.get(key, key.replace("_", " ").title())
            items.append(FeatureImportance(name=display, value=round(w, 3), category=category, rank=0))

        items.sort(key=lambda x: x.value, reverse=True)
        for i, item in enumerate(items):
            item.rank = i + 1
        return items

    @staticmethod
    def _split_factors(shap_values: List[ShapValue], disease: str) -> List[ShapValue]:
        """Filter SHAP values by disease relevance."""
        ad_keys = {"stroop", "nback", "recall", "story", "coherence", "memory",
                    "cognitive", "processing", "word", "pause", "speech rate",
                    "tmt", "clock", "shulman", "number", "trail"}
        pd_keys = {"tapping", "tremor", "spiral", "meander", "motor", "gait", "balance",
                    "blink", "step", "fatigue", "jitter", "shimmer", "drawing",
                    "vowel", "stability", "sway", "wave", "smile", "facial", "hypomimia",
                    "expression", "au01", "au06", "au12", "au25", "au45", "mouth", "jaw"}

        target = ad_keys if disease == "ad" else pd_keys
        return [sv for sv in shap_values if any(k in sv.name.lower() for k in target)][:5]

    @staticmethod
    def _generate_summary(risk_scores: dict, category: str) -> str:
        ad = risk_scores.get("ad_risk", 0)
        pd = risk_scores.get("pd_risk", 0)
        score = risk_scores.get("category_score", 50)

        if score >= 80:
            return f"Your {category} assessment shows healthy patterns. Continue maintaining your current lifestyle."
        elif score >= 60:
            return f"Your {category} assessment shows mostly normal patterns with some areas to monitor."
        elif score >= 40:
            return f"Your {category} assessment indicates some areas of concern (AD risk: {ad:.0f}%, PD risk: {pd:.0f}%). Follow-up recommended."
        else:
            return f"Your {category} assessment shows patterns that should be discussed with a healthcare provider (AD risk: {ad:.0f}%, PD risk: {pd:.0f}%)."

    @staticmethod
    def _make_predict_fn(model, features: dict):
        """
        Build a callable predict_fn(X) for LIME/SHAP.
        X is a numpy array of shape (n_samples, n_features).
        Returns numpy array of shape (n_samples,) with risk scores.

        The function handles dimension mismatches by padding/truncating
        to match the model's expected input size.
        """
        try:
            import torch
            import numpy as np

            model.eval()

            # Detect expected input dim from model's first linear layer
            expected_dim = None
            for name, param in model.named_parameters():
                if "weight" in name and param.dim() == 2:
                    expected_dim = param.shape[1]
                    break

            def predict_fn(X):
                if not isinstance(X, np.ndarray):
                    X = np.array(X, dtype=np.float64)
                X = X.astype(np.float32)
                if X.ndim == 1:
                    X = X.reshape(1, -1)

                # Match model input dimension
                if expected_dim is not None and X.shape[1] != expected_dim:
                    if X.shape[1] > expected_dim:
                        X = X[:, :expected_dim]
                    else:
                        pad = np.zeros((X.shape[0], expected_dim - X.shape[1]), dtype=np.float32)
                        X = np.concatenate([X, pad], axis=1)

                t = torch.from_numpy(X).float()
                with torch.no_grad():
                    out = model(t)
                if isinstance(out, dict):
                    risk = out.get("risk", out.get("ad_risk", None))
                    if risk is not None:
                        return risk.detach().cpu().numpy().flatten()
                    logits = out.get("logits", None)
                    if logits is not None:
                        return torch.softmax(logits, dim=-1)[:, 0].detach().cpu().numpy()
                    # Fallback: first scalar output
                    for v in out.values():
                        if hasattr(v, 'detach'):
                            arr = v.detach().cpu().numpy()
                            return arr[:, 0] if arr.ndim == 2 else arr.flatten()
                # Raw tensor output (e.g. TMTNet logits)
                arr = out.detach().cpu().numpy()
                if arr.ndim == 2:
                    # Multi-class: return risk class probability (class 0 = AD)
                    probs = torch.softmax(out, dim=-1).detach().cpu().numpy()
                    return probs[:, 0]
                return arr.flatten()

            return predict_fn
        except Exception as exc:
            logger.warning("Failed to create predict_fn for XAI: %s", exc)
            return None

    @staticmethod
    def _feature_description(feat: str, shap_val: float) -> str:
        direction = "increases" if shap_val > 0 else "decreases"
        display = FEATURE_DISPLAY.get(feat, feat.replace("_", " "))
        if abs(shap_val) > 0.15:
            return f"{display} strongly {direction} risk estimation"
        elif abs(shap_val) > 0.05:
            return f"{display} moderately {direction} risk estimation"
        else:
            return f"{display} has minor influence on risk estimation"
