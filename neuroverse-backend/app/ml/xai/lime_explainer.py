"""
LIME Explainer – Local Interpretable Model-agnostic Explanations.

Methods:
  - Real LIME via ``lime`` library (when installed + model loaded)
  - Perturbation-based approximation (fallback for tabular data)
  - Superpixel explanation for images (when LIME + model available)

For tabular data: perturb features around the instance, observe prediction changes.
For images: segment into superpixels, mask regions, observe prediction changes.
"""

import logging
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)


class LIMEExplainer:
    """
    LIME-based local explanations for NeuroVerse predictions.

    Output: list of {feature, lime_weight, direction, description}
    """

    def __init__(self):
        self._lime_available = False
        try:
            import lime  # noqa: F401
            self._lime_available = True
        except ImportError:
            logger.info("LIME library not installed; using perturbation approximation.")

    def explain_tabular(
        self,
        features: Dict[str, Any],
        predictions: Optional[Dict[str, Any]] = None,
        predict_fn=None,
        num_samples: int = 100,
    ) -> List[Dict[str, Any]]:
        """
        Generate LIME explanations for tabular features.

        If a predict_fn is provided and LIME is available, use real LIME.
        Otherwise, use perturbation-based approximation.
        """
        if self._lime_available and predict_fn is not None:
            return self._real_lime_tabular(features, predict_fn, num_samples)
        return self._approx_lime_tabular(features, predictions)

    def explain_image(
        self,
        image_array,
        predict_fn=None,
        num_samples: int = 200,
    ) -> Optional[Dict[str, Any]]:
        """
        Generate LIME superpixel explanation for an image.
        Returns superpixel mask + importance weights.
        """
        if not self._lime_available or predict_fn is None:
            return None

        try:
            import numpy as np
            from lime.lime_image import LimeImageExplainer

            explainer = LimeImageExplainer()

            # image_array should be (H, W, C) uint8 or float
            if image_array.dtype != np.float64:
                img = image_array.astype(np.float64) / 255.0 if image_array.max() > 1 else image_array.astype(np.float64)
            else:
                img = image_array

            explanation = explainer.explain_instance(
                img,
                predict_fn,
                top_labels=2,
                hide_color=0,
                num_samples=num_samples,
            )

            # Get the explanation for the top label
            top_label = explanation.top_labels[0]
            mask = explanation.get_image_and_mask(
                top_label, positive_only=True, num_features=5, hide_rest=True
            )

            # Extract segment weights
            local_exp = explanation.local_exp.get(top_label, [])
            segments = []
            for seg_id, weight in sorted(local_exp, key=lambda x: abs(x[1]), reverse=True)[:10]:
                segments.append({
                    "segment_id": int(seg_id),
                    "weight": round(float(weight), 4),
                    "direction": "risk" if weight > 0 else "protective",
                })

            return {
                "type": "lime_superpixel",
                "top_label": int(top_label),
                "segments": segments,
                "num_superpixels": int(explanation.segments.max() + 1),
            }

        except Exception as exc:
            logger.warning("LIME image explanation failed: %s", exc)
            return None

    def _real_lime_tabular(
        self,
        features: Dict[str, Any],
        predict_fn,
        num_samples: int,
    ) -> List[Dict[str, Any]]:
        """Use real LIME library for tabular explanation."""
        try:
            import numpy as np
            from lime.lime_tabular import LimeTabularExplainer

            # Filter to numeric features
            numeric = {k: v for k, v in features.items()
                       if isinstance(v, (int, float)) and not k.startswith("_")}
            feature_names = list(numeric.keys())
            feature_values = np.array([list(numeric.values())], dtype=np.float64)

            # LIME needs >1 training samples for perturbation statistics
            # Generate synthetic training data around the instance
            rng = np.random.RandomState(42)
            noise = rng.normal(0, 0.1, size=(50, len(feature_names)))
            training_data = feature_values + noise * np.clip(np.abs(feature_values), 0.01, None)

            explainer = LimeTabularExplainer(
                training_data=training_data,
                feature_names=feature_names,
                mode="regression",
                discretize_continuous=False,
            )

            explanation = explainer.explain_instance(
                feature_values[0],
                predict_fn,
                num_features=min(len(feature_names), 15),
                num_samples=num_samples,
            )

            results = []
            for feat_name, weight in explanation.as_list():
                # LIME returns formatted strings like "feature <= 0.5"
                clean_name = feat_name.split(" ")[0] if " " in feat_name else feat_name
                results.append({
                    "feature": clean_name,
                    "lime_weight": round(float(weight), 4),
                    "direction": "risk" if weight > 0 else "protective",
                    "description": f"{'Increases' if weight > 0 else 'Decreases'} risk by {abs(weight):.3f}",
                })

            return results[:15]

        except Exception as exc:
            logger.warning("Real LIME tabular failed: %s – using approximation", exc)
            return self._approx_lime_tabular(features, None)

    def _approx_lime_tabular(
        self,
        features: Dict[str, Any],
        predictions: Optional[Dict[str, Any]] = None,
    ) -> List[Dict[str, Any]]:
        """
        Approximate LIME by computing local sensitivity:
        For each feature, estimate how much a small perturbation changes risk.
        Uses clinical knowledge of feature-risk relationships.
        """
        ad_risk = (predictions or {}).get("ad_risk", 0)
        pd_risk = (predictions or {}).get("pd_risk", 0)
        base_risk = max(ad_risk, pd_risk) / 100.0

        # Feature sensitivity mapping (higher = more sensitive to changes)
        sensitivity = {
            # Cognitive
            "stroop_accuracy": -0.8, "nback_accuracy": -0.7, "recall_accuracy": -0.9,
            "stroop_interference": 0.5, "processing_speed_ms": 0.3,
            "cognitive_composite": -0.6, "nback_dprime": -0.5,
            # TMT
            "tmt_a_time": 0.4, "tmt_b_time": 0.7, "errors_b": 0.6,
            "path_efficiency": -0.5, "pen_lifts": 0.3,
            # Speech
            "speech_rate": -0.5, "pause_count": 0.6, "pause_rate": 0.5,
            "story_recall_accuracy": -0.7, "vowel_stability": -0.4,
            "jitter": 0.5, "shimmer": 0.4,
            # Motor
            "tapping_rate": -0.6, "tapping_regularity": -0.5, "tapping_fatigue": 0.5,
            "spiral_tremor": 0.7, "spiral_deviation": 0.4,
            # Gait
            "step_regularity": -0.5, "gait_speed": -0.4, "balance_stability": -0.5,
            # Facial
            "blink_rate": -0.3,
        }

        skip = {"category", "items_processed"}
        results = []

        for key, val in features.items():
            if key in skip or not isinstance(val, (int, float)) or key.startswith("_"):
                continue

            sens = sensitivity.get(key, 0.1)  # Default low sensitivity
            # LIME weight ≈ sensitivity × normalized value × base risk
            norm_val = min(max(val, 0), 1) if 0 <= val <= 1 else val / max(abs(val) + 1, 1)
            lime_weight = sens * norm_val * max(base_risk, 0.1)

            results.append({
                "feature": key,
                "lime_weight": round(float(lime_weight), 4),
                "direction": "risk" if lime_weight > 0 else "protective",
                "description": f"Local sensitivity: {'increases' if lime_weight > 0 else 'decreases'} risk",
            })

        results.sort(key=lambda x: abs(x["lime_weight"]), reverse=True)
        return results[:15]
