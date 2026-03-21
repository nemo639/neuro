"""
Facial Extractor – Extracts facial expression features from Flutter test data.

Maps Flutter facial analysis raw data (blink rate, smile metrics, expression range,
hypomimia score) to the feature format expected by FacialPredictor (ShallowANN).

The predictor model is trained on UFNet's smile task dataset which uses
Action Unit (AU) features. Since the Flutter app collects simplified facial
metrics (not raw AUs), this extractor maps them to equivalent AU-like features.

Flutter raw_data keys (from facial_analysis_test.dart):
  resting:     {facial_symmetry, muscle_tone}
  blinking:    {blink_count, blink_rate_per_min, avg_blink_duration_ms}
  smiling:     {smile_velocity, smile_symmetry, max_smile_amplitude}
  expressions: {expression_range, hypomimia_score, expressions_completed}
"""

import logging
from typing import Any, Dict

from app.ml.extractors.base_extractor import BaseExtractor

logger = logging.getLogger(__name__)


class FacialExtractor(BaseExtractor):
    category = "facial"

    async def _extract_item(self, item_name: str, raw: Dict[str, Any]) -> Dict[str, Any]:
        """Extract features from a single facial test item."""
        dispatch = {
            "facial_analysis": self._facial_analysis,
        }
        handler = dispatch.get(item_name)
        if handler is None:
            # Try extracting from combined data (Flutter sends all phases in one item)
            if raw.get("test_type") == "facial_analysis":
                return self._facial_analysis(raw)
            return {}
        return handler(raw)

    def _facial_analysis(self, raw: Dict[str, Any]) -> Dict[str, Any]:
        """Extract features from the full facial analysis test."""
        features: Dict[str, Any] = {}

        # --- Blinking phase ---
        blinking = raw.get("blinking", {})
        blink_rate = blinking.get("blink_rate_per_min", raw.get("blink_rate_per_min", 15.0))
        blink_count = blinking.get("blink_count", raw.get("blink_count", 0))
        avg_blink_dur = blinking.get("avg_blink_duration_ms", 200.0)

        features["blink_rate"] = float(blink_rate)
        features["blink_count"] = int(blink_count)
        features["avg_blink_duration_ms"] = float(avg_blink_dur)

        # --- Resting phase ---
        resting = raw.get("resting", {})
        features["facial_symmetry"] = float(resting.get("facial_symmetry", 90.0))
        features["muscle_tone"] = float(resting.get("muscle_tone", 80.0))

        # --- Smiling phase ---
        smiling = raw.get("smiling", {})
        smile_vel = smiling.get("smile_velocity", raw.get("smile_velocity", 0.5))
        smile_sym = smiling.get("smile_symmetry", 85.0)
        smile_amp = smiling.get("max_smile_amplitude", 0.7)

        features["smile_velocity"] = float(smile_vel)
        features["smile_symmetry"] = float(smile_sym)
        features["smile_intensity"] = float(smile_amp)
        features["smile_count"] = 1 if smile_vel > 0 else 0

        # --- Expression phase ---
        expressions = raw.get("expressions", {})
        expr_range = expressions.get("expression_range", raw.get("expression_range", 70.0))
        hypomimia = expressions.get("hypomimia_score", raw.get("hypomimia_score", 50.0))

        features["expression_range"] = float(expr_range)
        features["hypomimia_score"] = float(hypomimia)
        features["expressions_completed"] = int(expressions.get("expressions_completed", 5))

        # --- Derived AU-like features ---
        # Map Flutter metrics to Action Unit equivalents for the ShallowANN model.
        # UFNet smile model uses: AU01, AU06, AU12, AU14, AU25, AU26, AU45
        # + eye/mouth/jaw landmark features (mean, var, entropy per feature)
        #
        # We approximate these from the simplified Flutter data:
        # AU12 (lip corner puller) ≈ smile_velocity / amplitude
        # AU06 (cheek raiser) ≈ smile_symmetry indicator
        # AU45 (blink) ≈ blink_rate
        # AU25 (lips part) ≈ expression_range
        # AU01 (inner brow raise) ≈ hypomimia inverse

        features["au12_mean"] = float(smile_vel) * 2.0  # Lip corner puller
        features["au06_mean"] = float(smile_sym) / 50.0  # Cheek raiser
        features["au45_mean"] = min(float(blink_rate) / 20.0, 1.0)  # Blink
        features["au25_mean"] = float(expr_range) / 100.0  # Lips part
        features["au01_mean"] = max(0, (100.0 - float(hypomimia)) / 100.0)  # Inner brow raise

        # Variance approximations (lower variance = more PD-like masking)
        features["au12_var"] = float(smile_vel) * 0.5
        features["au06_var"] = (float(smile_sym) - 50) / 100.0 if smile_sym > 50 else 0.01
        features["au45_var"] = float(avg_blink_dur) / 1000.0
        features["au25_var"] = float(expr_range) / 200.0
        features["au01_var"] = max(0, (100.0 - float(hypomimia)) / 200.0)

        # Entropy approximations (lower entropy = less variation = PD-like)
        features["au12_entropy"] = min(float(smile_vel) * 5.0, 5.0)
        features["au06_entropy"] = min(float(smile_sym) / 20.0, 5.0)
        features["au45_entropy"] = min(float(blink_rate) / 5.0, 5.0)
        features["au25_entropy"] = min(float(expr_range) / 20.0, 5.0)
        features["au01_entropy"] = min((100.0 - float(hypomimia)) / 20.0, 5.0)

        # Mouth/eye/jaw landmark approximations
        features["mouth_open_mean"] = float(expr_range) / 100.0
        features["mouth_width_mean"] = float(smile_amp)
        features["jaw_open_mean"] = float(expr_range) / 150.0
        features["eye_open_mean"] = min(float(blink_rate) / 15.0, 1.0)
        features["eye_raise_mean"] = max(0, (100 - float(hypomimia)) / 100.0)

        # Overall scores from Flutter
        scores = raw.get("overall_scores", {})
        if scores:
            features["blink_score"] = float(scores.get("blink_score", 50))
            features["smile_score"] = float(scores.get("smile_score", 50))
            features["expression_score"] = float(scores.get("expression_score", 50))
            features["combined_score"] = float(scores.get("combined_score", 50))

        return features

    async def _derive_features(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """Compute derived cross-phase features."""
        derived = {}

        # Hypomimia composite: lower = more facial masking (PD indicator)
        smile_vel = features.get("smile_velocity", 0.5)
        expr_range = features.get("expression_range", 70)
        blink_rate = features.get("blink_rate", 15)

        # Facial expressivity score (0-100, lower = more PD-like)
        expressivity = (
            (smile_vel * 30) +
            (expr_range * 0.4) +
            (min(blink_rate, 20) * 1.5)
        )
        derived["facial_expressivity"] = round(min(max(expressivity, 0), 100), 2)

        # Symmetry composite
        facial_sym = features.get("facial_symmetry", 90)
        smile_sym = features.get("smile_symmetry", 85)
        derived["symmetry_composite"] = round((facial_sym + smile_sym) / 2, 2)

        return derived
