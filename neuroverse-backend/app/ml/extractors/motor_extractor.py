"""
Motor Feature Extractor
Handles: Finger Tapping, Spiral Drawing, Meander Drawing mini-tests.
Produces features for MotorNet (spiral/meander) predictors.

Models (from training notebooks):
  - Spiral: EfficientNet-B0, 224×224 RGB, binary Healthy/PD (95.5% acc)
  - Meander: EfficientNet-B0, 224×224 RGB, binary Healthy/PD (91.4% acc)
"""

import base64
import io
import logging
from typing import Any, Dict, List, Optional

import numpy as np

from app.ml.extractors.base_extractor import BaseExtractor

logger = logging.getLogger(__name__)

IMAGENET_MEAN = [0.485, 0.456, 0.406]
IMAGENET_STD = [0.229, 0.224, 0.225]


class MotorExtractor(BaseExtractor):
    category = "motor"

    async def _extract_item(self, item_name: str, raw: Dict[str, Any]) -> Dict[str, Any]:
        dispatch = {
            "finger_tapping": self._finger_tapping,
            "resting_tremor": self._resting_tremor,
            "spiral_drawing": self._spiral_drawing,
            "meander_drawing": self._meander_drawing,
            "wave_drawing": self._meander_drawing,
        }
        handler = dispatch.get(item_name)
        if handler is None:
            return {}
        return handler(raw)

    # ------------------------------------------------------------------ #
    # Finger Tapping                                                      #
    # ------------------------------------------------------------------ #
    def _finger_tapping(self, raw: dict) -> dict:
        # Flutter sends nested: left_hand={tap_count, taps_per_second, intervals, ...}
        #                        right_hand={...}, asymmetry_index, test_duration_seconds
        left = raw.get("left_hand", {})
        right = raw.get("right_hand", {})

        # Combine both hands' tap counts
        left_taps = left.get("tap_count", 0) if isinstance(left, dict) else 0
        right_taps = right.get("tap_count", 0) if isinstance(right, dict) else 0
        total_taps = self.safe_get(raw, "total_taps", left_taps + right_taps)

        duration = self.safe_get(raw, "duration_seconds",
                                  self.safe_get(raw, "test_duration_seconds", 10))

        # Tapping rate: use dominant hand or average
        left_rate = left.get("taps_per_second", 0) if isinstance(left, dict) else 0
        right_rate = right.get("taps_per_second", 0) if isinstance(right, dict) else 0
        tapping_rate = self.safe_get(raw, "tapping_rate")
        if tapping_rate == 0:
            tapping_rate = max(left_rate, right_rate)  # use better hand
        if tapping_rate == 0 and total_taps > 0 and duration > 0:
            tapping_rate = total_taps / duration

        # Intervals: try flat key, then nested
        intervals = raw.get("tap_intervals_ms", [])
        if not intervals and isinstance(right, dict):
            intervals = right.get("intervals", [])
        if not intervals and isinstance(left, dict):
            intervals = left.get("intervals", [])

        # Regularity from intervals or pre-computed
        regularity = self.safe_get(raw, "regularity_score", 0.5)
        left_var = left.get("interval_variability", 0) if isinstance(left, dict) else 0
        right_var = right.get("interval_variability", 0) if isinstance(right, dict) else 0
        if regularity == 0.5 and (left_var or right_var):
            # interval_variability is std/mean; regularity = 1 - variability
            avg_var = (left_var + right_var) / max(sum(1 for v in [left_var, right_var] if v), 1)
            regularity = max(0.0, 1.0 - avg_var)

        fatigue = self.safe_get(raw, "fatigue_index")

        if isinstance(intervals, list) and len(intervals) >= 4:
            arr = np.asarray(intervals, dtype=np.float32)
            regularity = float(1.0 - min(float(arr.std() / max(arr.mean(), 1)), 1.0))
            mid = len(arr) // 2
            first_rate = float(1000.0 / max(arr[:mid].mean(), 1))
            second_rate = float(1000.0 / max(arr[mid:].mean(), 1))
            fatigue = float(max(0.0, (first_rate - second_rate) / max(first_rate, 1)))

        # Asymmetry index
        asymmetry = self.safe_get(raw, "asymmetry_index")

        return {
            "tapping_rate": float(tapping_rate) if tapping_rate else 0.0,
            "tapping_regularity": float(regularity) if regularity else 0.5,
            "tapping_fatigue": float(fatigue) if fatigue else 0.0,
            "tapping_total": int(total_taps),
            "tapping_duration": float(duration),
            "tapping_asymmetry": float(asymmetry) if asymmetry else 0.0,
        }

    # ------------------------------------------------------------------ #
    # Resting Tremor (accelerometer/gyroscope)                            #
    # ------------------------------------------------------------------ #
    def _resting_tremor(self, raw: dict) -> dict:
        left = raw.get("left_hand", {})
        right = raw.get("right_hand", {})
        if not isinstance(left, dict):
            left = {}
        if not isinstance(right, dict):
            right = {}

        # Extract per-hand metrics
        left_amp = float(left.get("tremor_amplitude", 0))
        right_amp = float(right.get("tremor_amplitude", 0))
        left_freq = float(left.get("tremor_frequency", 0))
        right_freq = float(right.get("tremor_frequency", 0))
        left_rms = float(left.get("rms_acceleration", 0))
        right_rms = float(right.get("rms_acceleration", 0))
        left_jerk = float(left.get("jerk_mean", 0))
        right_jerk = float(right.get("jerk_mean", 0))
        left_gyro = float(left.get("gyro_rms", 0))
        right_gyro = float(right.get("gyro_rms", 0))

        # Use dominant (worse) hand for primary features
        tremor_amplitude = max(left_amp, right_amp)
        tremor_frequency = left_freq if left_amp >= right_amp else right_freq
        rms_accel = max(left_rms, right_rms)
        jerk = max(left_jerk, right_jerk)
        gyro_rms = max(left_gyro, right_gyro)

        # Asymmetry
        asymmetry = float(raw.get("asymmetry_index", 0))

        # PD characteristic: resting tremor 4-6 Hz
        pd_freq_match = 1.0 if 4.0 <= tremor_frequency <= 7.0 else 0.0

        return {
            "tremor_amplitude": tremor_amplitude,
            "tremor_frequency": tremor_frequency,
            "tremor_rms": rms_accel,
            "tremor_jerk": jerk,
            "tremor_gyro_rms": gyro_rms,
            "tremor_asymmetry": asymmetry,
            "tremor_pd_freq_match": pd_freq_match,
            "tremor_left_amplitude": left_amp,
            "tremor_right_amplitude": right_amp,
        }

    # ------------------------------------------------------------------ #
    # Spiral Drawing                                                      #
    # ------------------------------------------------------------------ #
    def _spiral_drawing(self, raw: dict) -> dict:
        # Flutter sends nested: left_hand={drawing_duration_ms, tremor_score, accuracy_score, avg_deviation}
        #                        right_hand={...}
        # Use dominant (right) hand first, fall back to left, then flat keys
        hand = raw.get("right_hand", raw.get("left_hand", {}))
        if not isinstance(hand, dict):
            hand = {}

        duration_ms = self.safe_get(raw, "duration_ms",
                                     hand.get("drawing_duration_ms", 0))
        tremor = hand.get("tremor_score", 0.0)
        deviation = hand.get("avg_deviation", self.safe_get(raw, "deviation_score"))
        accuracy = hand.get("accuracy_score", self.safe_get(raw, "spiral_tightness", 0.5))

        features: dict = {
            "spiral_duration": duration_ms / 1000.0,
            "spiral_tremor": float(tremor) if tremor else (1.0 if raw.get("tremor_detected", False) else 0.0),
            "spiral_deviation": float(deviation),
            "spiral_tightness": float(accuracy),
        }

        # Base64 image for MotorNet
        b64 = raw.get("image_base64", raw.get("drawing_base64"))
        if b64:
            features["spiral_image_base64"] = b64

        # Drawing points analysis
        points = raw.get("drawing_points", [])
        if isinstance(points, list) and len(points) >= 10:
            features.update(self._analyse_drawing(points, prefix="spiral"))

        return features

    # ------------------------------------------------------------------ #
    # Meander (Wave) Drawing                                              #
    # ------------------------------------------------------------------ #
    def _meander_drawing(self, raw: dict) -> dict:
        # Flutter sends nested: left_hand={drawing_duration_ms, tremor_score, smoothness_score, avg_deviation, mean_speed}
        hand = raw.get("right_hand", raw.get("left_hand", {}))
        if not isinstance(hand, dict):
            hand = {}

        duration_ms = self.safe_get(raw, "duration_ms",
                                     hand.get("drawing_duration_ms", 0))
        tremor = hand.get("tremor_score", 0.0)
        deviation = hand.get("avg_deviation", self.safe_get(raw, "deviation_score"))
        smoothness = hand.get("smoothness_score", self.safe_get(raw, "smoothness_score", 0.5))

        features: dict = {
            "meander_duration": duration_ms / 1000.0,
            "meander_tremor": float(tremor) if tremor else (1.0 if raw.get("tremor_detected", False) else 0.0),
            "meander_deviation": float(deviation),
            "meander_smoothness": float(smoothness),
        }

        # Base64 image for MotorNet (meander)
        b64 = raw.get("image_base64", raw.get("drawing_base64"))
        if b64:
            features["meander_image_base64"] = b64

        # Drawing points analysis
        points = raw.get("drawing_points", [])
        if isinstance(points, list) and len(points) >= 10:
            features.update(self._analyse_drawing(points, prefix="meander"))

        return features

    # ------------------------------------------------------------------ #
    # Drawing analysis helpers                                            #
    # ------------------------------------------------------------------ #
    def _analyse_drawing(self, points: List[dict], prefix: str = "drawing") -> dict:
        """Compute tremor/speed features from raw drawing point data."""
        try:
            xs = np.array([p.get("x", 0) for p in points], dtype=np.float32)
            ys = np.array([p.get("y", 0) for p in points], dtype=np.float32)
            ts = np.array([p.get("t", i * 10) for i, p in enumerate(points)], dtype=np.float32)

            dx = np.diff(xs)
            dy = np.diff(ys)
            dt = np.diff(ts)
            dt = np.clip(dt, 1, None)

            speed = np.sqrt(dx ** 2 + dy ** 2) / dt
            mean_speed = float(speed.mean()) if len(speed) > 0 else 0.0

            if len(speed) > 1:
                accel = np.abs(np.diff(speed))
                tremor_score = float(accel.std())
            else:
                tremor_score = 0.0

            return {
                f"{prefix}_mean_speed": mean_speed,
                f"{prefix}_speed_variability": float(speed.std()) if len(speed) > 1 else 0.0,
                f"{prefix}_tremor_score": tremor_score,
                f"{prefix}_num_points": float(len(points)),
            }
        except Exception as exc:
            logger.warning("Drawing analysis failed: %s", exc)
            return {}

    # ------------------------------------------------------------------ #
    # Image helpers (for when Flutter sends base64 encoded image)         #
    # ------------------------------------------------------------------ #
    @staticmethod
    def decode_image_base64(b64_str: str) -> Optional[np.ndarray]:
        """Decode a base64-encoded image to a numpy array (H,W,C)."""
        try:
            from PIL import Image
            img_bytes = base64.b64decode(b64_str)
            img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
            return np.asarray(img)
        except Exception as exc:
            logger.warning("Image decode failed: %s", exc)
            return None

    @staticmethod
    def preprocess_image(
        img: np.ndarray,
        target_size: int = 224,
        mean: Optional[List[float]] = None,
        std: Optional[List[float]] = None,
    ) -> np.ndarray:
        """Resize + normalise an image to (C, H, W) float32 for EfficientNet-B0."""
        from PIL import Image

        if mean is None:
            mean = IMAGENET_MEAN
        if std is None:
            std = IMAGENET_STD

        pil_img = Image.fromarray(img).resize(
            (target_size, target_size), Image.BILINEAR
        )
        arr = np.asarray(pil_img, dtype=np.float32) / 255.0

        m = np.array(mean, dtype=np.float32).reshape(1, 1, 3)
        s = np.array(std, dtype=np.float32).reshape(1, 1, 3)
        arr = (arr - m) / (s + 1e-8)

        return arr.transpose(2, 0, 1)  # HWC → CHW

    # ------------------------------------------------------------------ #
    # Derived features                                                    #
    # ------------------------------------------------------------------ #
    async def _derive_features(self, features: Dict[str, Any]) -> Dict[str, Any]:
        derived: dict = {}

        # Motor composite index
        scores: List[float] = []
        if features.get("tapping_regularity", 0) > 0:
            scores.append(features["tapping_regularity"])
        if features.get("tremor_amplitude") is not None:
            # Lower tremor = healthier → invert for composite (1 - normalized amplitude)
            tremor_score = max(0.0, 1.0 - min(features["tremor_amplitude"] / 2.0, 1.0))
            scores.append(tremor_score)
        if features.get("spiral_tightness", 0) > 0:
            scores.append(features["spiral_tightness"])
        if features.get("meander_smoothness", 0) > 0:
            scores.append(features["meander_smoothness"])
        if scores:
            derived["motor_composite"] = sum(scores) / len(scores)

        return derived
