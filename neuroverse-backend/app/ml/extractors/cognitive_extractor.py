"""
Cognitive Feature Extractor
Handles: Stroop, N-Back, Word Recall, TMT (Trail Making Test), CDT (Clock Drawing Test).

Test types:
  - Stroop, N-Back, Word Recall: App-based cognitive mini-tests → tabular features
  - TMT: Kinematic trail-making data → 24 features for TMTNet
  - CDT: Clock drawing image → base64 image for CDTNet (EfficientNet-B0)
"""

import base64
import io
import logging
from typing import Any, Dict, List, Optional

import numpy as np

from app.ml.extractors.base_extractor import BaseExtractor

logger = logging.getLogger(__name__)


# ------------------------------------------------------------------ #
# TMT feature columns (exact match to cognitive_tmt_training_Final)   #
# ------------------------------------------------------------------ #
TMT_FEATURE_KEYS = [
    # 20 engineered features matching cognitive_model.pt checkpoint
    "b_a_total_time", "tmt_b_time", "log_tmt_b", "age_norm_tmt_b",
    "edu_norm_tmt_b", "age_x_tmt_b", "b_minus_a_time", "tmt_b_slow",
    "b_over_a_ratio", "log_tmt_a", "log_b_over_a", "tmt_a_time",
    "tmt_b_impaired", "apoe4_x_tmt_b", "errors_x_time_b", "edu_x_ratio",
    "tmt_a_impaired", "errors_b", "log_errors_b", "total_errors",
]

# App-based cognitive feature keys (Stroop, N-Back, Word Recall)
APP_COGNITIVE_KEYS = [
    "stroop_accuracy", "stroop_interference", "stroop_avg_rt",
    "stroop_congruent_rt", "stroop_incongruent_rt", "stroop_error_rate",
    "nback_level", "nback_accuracy", "nback_hits", "nback_false_alarms",
    "nback_avg_rt", "nback_dprime",
    "recall_accuracy", "recall_intrusions", "recall_first_time", "recall_total_words",
    "cognitive_composite", "processing_speed_ms",
]


class CognitiveExtractor(BaseExtractor):
    category = "cognitive"

    async def _extract_item(self, item_name: str, raw: Dict[str, Any]) -> Dict[str, Any]:
        dispatch = {
            "stroop": self._stroop,
            "stroop_test": self._stroop,           # Flutter: 'Stroop Test'
            "nback": self._nback,
            "n-back_memory": self._nback,           # Flutter: 'N-Back Memory'
            "n_back_memory": self._nback,
            "word_recall": self._word_recall,
            "word_list_recall": self._word_recall,  # Flutter: 'Word List Recall'
            "tmt": self._tmt,
            "tmt_a": self._tmt,
            "tmt_b": self._tmt,
            "trail_making": self._tmt,
            "cdt": self._cdt,
            "clock_drawing": self._cdt,
        }
        handler = dispatch.get(item_name)
        if handler is None:
            return {}
        return handler(raw)

    # ------------------------------------------------------------------ #
    # Stroop Test                                                         #
    # ------------------------------------------------------------------ #
    def _stroop(self, raw: dict) -> dict:
        # Flutter sends: correct, errors, accuracy, avg_reaction_time_ms,
        #   avg_congruent_rt_ms, avg_incongruent_rt_ms, stroop_interference_ms
        total_correct = self.safe_get(raw, "correct", self.safe_get(raw, "total_correct"))
        total_errors = self.safe_get(raw, "errors", self.safe_get(raw, "total_errors"))
        total = total_correct + total_errors

        # RT fields: Flutter uses avg_congruent_rt_ms / avg_incongruent_rt_ms
        congruent_rt = self.safe_get(raw, "avg_congruent_rt_ms",
                        self.safe_get(raw, "congruent_avg_ms"))
        incongruent_rt = self.safe_get(raw, "avg_incongruent_rt_ms",
                          self.safe_get(raw, "incongruent_avg_ms"))

        # Interference in ms: Flutter sends stroop_interference_ms
        interference = self.safe_get(raw, "stroop_interference_ms",
                        self.safe_get(raw, "interference_score"))
        if interference == 0 and congruent_rt > 0:
            interference = incongruent_rt - congruent_rt

        # Accuracy: Flutter sends pre-computed 'accuracy' as decimal
        accuracy = self.safe_get(raw, "accuracy")
        if accuracy == 0 and total > 0:
            accuracy = self.safe_ratio(total_correct, max(total, 1))

        avg_rt = self.safe_get(raw, "avg_reaction_time_ms",
                  self.safe_get(raw, "avg_response_time_ms"))

        return {
            "stroop_accuracy": float(accuracy),
            "stroop_interference": float(interference),  # in ms
            "stroop_avg_rt": float(avg_rt),
            "stroop_congruent_rt": float(congruent_rt),
            "stroop_incongruent_rt": float(incongruent_rt),
            "stroop_error_rate": self.safe_ratio(total_errors, max(total, 1)),
        }

    # ------------------------------------------------------------------ #
    # N-Back Test                                                         #
    # ------------------------------------------------------------------ #
    def _nback(self, raw: dict) -> dict:
        hits = self.safe_get(raw, "hits")
        false_alarms = self.safe_get(raw, "false_alarms")
        misses = self.safe_get(raw, "misses")
        total_targets = hits + misses if misses > 0 else max(self.safe_get(raw, "total_targets", 1), 1)

        return {
            "nback_level": self.safe_get(raw, "level", 1),
            "nback_accuracy": self.safe_get(raw, "accuracy"),
            "nback_hits": hits,
            "nback_false_alarms": false_alarms,
            "nback_avg_rt": self.safe_get(raw, "avg_response_time_ms"),
            "nback_dprime": self._compute_dprime(hits / max(total_targets, 1),
                                                  false_alarms / max(total_targets, 1)),
        }

    # ------------------------------------------------------------------ #
    # Word Recall Test                                                    #
    # ------------------------------------------------------------------ #
    def _word_recall(self, raw: dict) -> dict:
        words_shown = raw.get("words_shown", [])
        total_words = len(words_shown) if isinstance(words_shown, list) else self.safe_get(raw, "total_words", 1)

        # Flutter sends nested: immediate_recall.correct_count, delayed_recall, recognition
        imm = raw.get("immediate_recall", {})
        delayed = raw.get("delayed_recall", {})
        recognition = raw.get("recognition", {})

        # correct_recalls: try flat key first, then nested
        correct = self.safe_get(raw, "correct_recalls")
        if correct == 0 and isinstance(imm, dict):
            correct = imm.get("correct_count", 0)

        # intrusions: try flat key first, then nested
        intrusions = self.safe_get(raw, "intrusions")
        if intrusions == 0 and isinstance(imm, dict):
            intrusions = imm.get("intrusion_count", 0)

        # Recall accuracy: prefer pre-computed, else compute
        recall_acc = self.safe_get(raw, "recall_accuracy")
        if recall_acc == 0 and isinstance(imm, dict) and imm.get("accuracy"):
            recall_acc = imm["accuracy"]
        elif recall_acc == 0 and correct > 0:
            recall_acc = self.safe_ratio(correct, max(total_words, 1))

        # Delayed recall accuracy
        delayed_acc = 0.0
        if isinstance(delayed, dict):
            delayed_acc = delayed.get("accuracy", 0.0)

        # Recognition discriminability
        recog_disc = 0.0
        if isinstance(recognition, dict):
            recog_disc = recognition.get("discriminability", 0.0)

        return {
            "recall_accuracy": recall_acc,
            "recall_intrusions": float(intrusions),
            "recall_first_time": self.safe_get(raw, "time_to_first_recall_ms"),
            "recall_total_words": float(total_words),
            "recall_delayed_accuracy": delayed_acc,
            "recall_recognition_discriminability": recog_disc,
            "recall_retention_rate": self.safe_get(raw, "retention_rate"),
        }

    # ------------------------------------------------------------------ #
    # TMT (Trail Making Test) – 24 kinematic features for TMTNet         #
    # ------------------------------------------------------------------ #
    def _tmt(self, raw: dict) -> dict:
        """
        Extract TMT features from trail-making test kinematic data.

        Expected raw data from Flutter app:
          - Timing: tmt_a_time, tmt_b_time (seconds)
          - Errors: errors_a, errors_b, sequence_errors_b
          - Pen trajectory: drawing_points [{x, y, t, pressure}]
          - Demographics: age, education_years
        """
        features: Dict[str, Any] = {}

        # Timing features
        tmt_a_time = self.safe_get(raw, "tmt_a_time", self.safe_get(raw, "time_a"))
        tmt_b_time = self.safe_get(raw, "tmt_b_time", self.safe_get(raw, "time_b"))
        circles_a = max(self.safe_get(raw, "circles_a", 25), 1)
        circles_b = max(self.safe_get(raw, "circles_b", 25), 1)

        features["tmt_a_time"] = tmt_a_time
        features["tmt_b_time"] = tmt_b_time
        features["time_per_circle_a"] = tmt_a_time / circles_a if tmt_a_time > 0 else 0
        features["time_per_circle_b"] = tmt_b_time / circles_b if tmt_b_time > 0 else 0

        # Error features
        features["errors_a"] = self.safe_get(raw, "errors_a")
        features["errors_b"] = self.safe_get(raw, "errors_b")
        features["sequence_errors_b"] = self.safe_get(raw, "sequence_errors_b",
                                                       self.safe_get(raw, "sequence_errors"))

        # Kinematic features from pen trajectory
        points = raw.get("drawing_points", raw.get("trail_points", []))
        if isinstance(points, list) and len(points) >= 5:
            kinematics = self._compute_tmt_kinematics(points)
            features.update(kinematics)
        else:
            # Use pre-computed values if available
            features["velocity_mean"] = self.safe_get(raw, "velocity_mean")
            features["velocity_std"] = self.safe_get(raw, "velocity_std")
            features["acceleration_mean"] = self.safe_get(raw, "acceleration_mean")
            features["acceleration_std"] = self.safe_get(raw, "acceleration_std")
            features["jerk_mean"] = self.safe_get(raw, "jerk_mean")
            features["curvature_mean"] = self.safe_get(raw, "curvature_mean")
            features["curvature_std"] = self.safe_get(raw, "curvature_std")
            features["straightness_ratio"] = self.safe_get(raw, "straightness_ratio")

        # Pen dynamics
        features["pause_count"] = self.safe_get(raw, "pause_count", self.safe_get(raw, "pen_pauses"))
        features["total_pause_duration"] = self.safe_get(raw, "total_pause_duration")
        features["hover_time"] = self.safe_get(raw, "hover_time")
        features["pen_lifts"] = self.safe_get(raw, "pen_lifts")

        # Path quality
        features["path_efficiency"] = self.safe_get(raw, "path_efficiency")
        features["spatial_accuracy"] = self.safe_get(raw, "spatial_accuracy")
        features["distance_variability"] = self.safe_get(raw, "distance_variability")

        # Demographics
        features["age"] = self.safe_get(raw, "age")
        features["education_years"] = self.safe_get(raw, "education_years")

        # Flag that TMT data is present (for predictor routing)
        features["_has_tmt_data"] = True

        return features

    def _compute_tmt_kinematics(self, points: list) -> dict:
        """Compute kinematic features from raw TMT pen trajectory points."""
        try:
            xs = np.array([p.get("x", 0) for p in points], dtype=np.float64)
            ys = np.array([p.get("y", 0) for p in points], dtype=np.float64)
            ts = np.array([p.get("t", i * 16) for i, p in enumerate(points)], dtype=np.float64)

            dt = np.diff(ts) / 1000.0  # ms → seconds
            dt = np.clip(dt, 0.001, None)

            dx = np.diff(xs)
            dy = np.diff(ys)
            dist = np.sqrt(dx**2 + dy**2)

            # Velocity
            velocity = dist / dt
            velocity_mean = float(np.mean(velocity))
            velocity_std = float(np.std(velocity))

            # Acceleration
            if len(velocity) > 1:
                dv = np.diff(velocity)
                dt2 = dt[1:]
                acceleration = dv / dt2
                acceleration_mean = float(np.mean(np.abs(acceleration)))
                acceleration_std = float(np.std(acceleration))
            else:
                acceleration_mean = 0.0
                acceleration_std = 0.0

            # Jerk (derivative of acceleration)
            if len(velocity) > 2:
                dv = np.diff(velocity)
                dt2 = dt[1:]
                acceleration = dv / dt2
                if len(acceleration) > 1:
                    da = np.diff(acceleration)
                    dt3 = dt2[1:]
                    jerk = da / dt3
                    jerk_mean = float(np.mean(np.abs(jerk)))
                else:
                    jerk_mean = 0.0
            else:
                jerk_mean = 0.0

            # Curvature
            if len(dx) > 1:
                ddx = np.diff(dx)
                ddy = np.diff(dy)
                num = np.abs(dx[:-1] * ddy - dy[:-1] * ddx)
                den = (dx[:-1]**2 + dy[:-1]**2)**1.5 + 1e-8
                curvature = num / den
                curvature_mean = float(np.mean(curvature))
                curvature_std = float(np.std(curvature))
            else:
                curvature_mean = 0.0
                curvature_std = 0.0

            # Straightness ratio (direct distance / path distance)
            total_path = float(np.sum(dist))
            direct_dist = float(np.sqrt((xs[-1] - xs[0])**2 + (ys[-1] - ys[0])**2))
            straightness_ratio = direct_dist / max(total_path, 1e-8)

            return {
                "velocity_mean": velocity_mean,
                "velocity_std": velocity_std,
                "acceleration_mean": acceleration_mean,
                "acceleration_std": acceleration_std,
                "jerk_mean": jerk_mean,
                "curvature_mean": curvature_mean,
                "curvature_std": curvature_std,
                "straightness_ratio": min(straightness_ratio, 1.0),
            }
        except Exception as exc:
            logger.warning("TMT kinematics computation failed: %s", exc)
            return {k: 0.0 for k in [
                "velocity_mean", "velocity_std", "acceleration_mean", "acceleration_std",
                "jerk_mean", "curvature_mean", "curvature_std", "straightness_ratio",
            ]}

    # ------------------------------------------------------------------ #
    # CDT (Clock Drawing Test) – image for CDTNet                         #
    # ------------------------------------------------------------------ #
    def _cdt(self, raw: dict) -> dict:
        """
        Extract CDT features from clock drawing test data.

        Expected raw data from Flutter app:
          - clock_image_base64: Base64-encoded clock drawing image
          - Optional pre-scored: shulman_score, clock_contour, numbers_placed, etc.
        """
        features: Dict[str, Any] = {}

        # Pass through the base64 image for CDTNet
        # Check all possible locations where Flutter might put the image
        b64 = None
        search_keys = ("clock_image_base64", "image_base64", "drawing_base64")

        # 1. Top-level keys
        for key in search_keys:
            val = raw.get(key)
            if val and isinstance(val, str) and len(val) > 100:
                b64 = val
                break

        # 2. Inside nested drawing_data dict
        if not b64:
            drawing_data = raw.get("drawing_data", {})
            if isinstance(drawing_data, dict):
                for key in search_keys:
                    val = drawing_data.get(key)
                    if val and isinstance(val, str) and len(val) > 100:
                        b64 = val
                        break

        if b64:
            features["clock_image_base64"] = b64
            features["_has_cdt_image"] = True
            logger.info("CDT image found (%d chars)", len(b64))
        else:
            logger.warning("CDT image NOT found in raw_data keys: %s",
                          [k for k in raw.keys()])

        # Pre-scored features (if clinician/app has scored the clock)
        # Flutter nests calculated results inside drawing_data
        dd = raw.get("drawing_data", {})
        if not isinstance(dd, dict):
            dd = {}

        features["shulman_score"] = self.safe_get(raw, "shulman_score", self.safe_get(dd, "shulman_score"))
        features["clock_contour"] = self.safe_get(raw, "clock_contour",
                                     self.safe_get(dd, "circle_quality", 1.0))
        features["numbers_placed"] = self.safe_get(raw, "numbers_placed",
                                      self.safe_get(dd, "numbers_placed", 12))
        features["numbers_correct"] = self.safe_get(raw, "numbers_correct",
                                       self.safe_get(dd, "numbers_correct", 12))
        features["hands_present"] = 1.0 if raw.get("hands_present", dd.get("hands_present", True)) else 0.0
        features["center_deviation"] = self.safe_get(raw, "center_deviation",
                                        self.safe_get(dd, "center_deviation"))
        features["drawing_time"] = self.safe_get(raw, "drawing_time_ms",
                                    self.safe_get(raw, "duration_ms",
                                    self.safe_get(dd, "drawing_duration_ms")))

        # CDT-derived scoring features
        if features["numbers_placed"] > 0:
            features["number_accuracy"] = features["numbers_correct"] / features["numbers_placed"]
        else:
            features["number_accuracy"] = 0.0

        return features

    # ------------------------------------------------------------------ #
    # CDT image preprocessing (for CDTNet EfficientNet-B0)                #
    # ------------------------------------------------------------------ #
    @staticmethod
    def decode_cdt_image(b64_str: str) -> Optional[np.ndarray]:
        """Decode a base64-encoded CDT image to numpy array (H,W,C)."""
        try:
            from PIL import Image
            img_bytes = base64.b64decode(b64_str)
            img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
            return np.asarray(img)
        except Exception as exc:
            logger.warning("CDT image decode failed: %s", exc)
            return None

    @staticmethod
    def preprocess_cdt_image(
        img: np.ndarray,
        target_size: int = 224,
        phone_input: bool = True,
    ) -> np.ndarray:
        """Resize + ImageNet-normalize CDT image to (C, H, W) float32.

        When phone_input=True, applies domain adaptation to bridge the gap
        between phone finger drawings and the paper scans the model was trained on.
        """
        from PIL import Image
        from app.ml.extractors.phone_image_adapter import adapt_phone_drawing

        # Phone domain adaptation: make finger drawing look like paper scan
        if phone_input:
            img = adapt_phone_drawing(img, thin_iterations=1, noise_level=5.0, blur_sigma=0.5)

        mean = np.array([0.485, 0.456, 0.406], dtype=np.float32).reshape(1, 1, 3)
        std = np.array([0.229, 0.224, 0.225], dtype=np.float32).reshape(1, 1, 3)

        pil_img = Image.fromarray(img).resize((target_size, target_size), Image.BILINEAR)
        arr = np.asarray(pil_img, dtype=np.float32) / 255.0
        arr = (arr - mean) / (std + 1e-8)
        return arr.transpose(2, 0, 1)  # HWC → CHW

    @staticmethod
    def build_tmt_feature_vector(features: dict) -> np.ndarray:
        """Build the 20-d engineered TMT feature vector for TMTNet inference.

        Computes derived features from raw tmt_a_time, tmt_b_time, errors_b,
        age, education_years to match the checkpoint's training features.
        """
        import math

        tmt_a = max(float(features.get("tmt_a_time", 30)), 1.0)
        tmt_b = max(float(features.get("tmt_b_time", 60)), 1.0)
        errors_b = float(features.get("errors_b", 0))
        errors_a = float(features.get("errors_a", 0))
        age = float(features.get("age", 65))
        edu = max(float(features.get("education_years", 12)), 1.0)

        # In clinical TMT, Part B always takes longer than Part A (switching cost).
        # Our app can produce B ≤ A due to spatial learning from Part A.
        # Floor B/A to 1.5 (healthy lower bound) so the model doesn't misinterpret
        # a fast B as severe executive dysfunction.
        b_over_a_raw = tmt_b / tmt_a
        b_over_a = max(b_over_a_raw, 1.5)
        # Also floor b_minus_a to a small positive value
        b_minus_a_raw = tmt_b - tmt_a
        b_minus_a = max(b_minus_a_raw, tmt_a * 0.5)  # at least 50% of A time

        b_a_total = tmt_a + tmt_b
        log_tmt_b = math.log1p(tmt_b)
        log_tmt_a = math.log1p(tmt_a)
        log_b_over_a = math.log1p(b_over_a)
        tmt_b_slow = 1.0 if tmt_b > 180 else 0.0
        tmt_b_impaired = 1.0 if tmt_b > 300 else 0.0
        tmt_a_impaired = 1.0 if tmt_a > 78 else 0.0
        age_norm_tmt_b = tmt_b / max(age, 1.0)
        edu_norm_tmt_b = tmt_b / edu
        age_x_tmt_b = age * tmt_b
        apoe4_x_tmt_b = 0.0  # APOE4 not available from app
        errors_x_time_b = errors_b * tmt_b
        edu_x_ratio = edu * b_over_a
        total_errors = errors_a + errors_b
        log_errors_b = math.log1p(errors_b)

        engineered = {
            "b_a_total_time": b_a_total,
            "tmt_b_time": tmt_b,
            "log_tmt_b": log_tmt_b,
            "age_norm_tmt_b": age_norm_tmt_b,
            "edu_norm_tmt_b": edu_norm_tmt_b,
            "age_x_tmt_b": age_x_tmt_b,
            "b_minus_a_time": b_minus_a,
            "tmt_b_slow": tmt_b_slow,
            "b_over_a_ratio": b_over_a,
            "log_tmt_a": log_tmt_a,
            "log_b_over_a": log_b_over_a,
            "tmt_a_time": tmt_a,
            "tmt_b_impaired": tmt_b_impaired,
            "apoe4_x_tmt_b": apoe4_x_tmt_b,
            "errors_x_time_b": errors_x_time_b,
            "edu_x_ratio": edu_x_ratio,
            "tmt_a_impaired": tmt_a_impaired,
            "errors_b": errors_b,
            "log_errors_b": log_errors_b,
            "total_errors": total_errors,
        }

        vec = np.zeros(len(TMT_FEATURE_KEYS), dtype=np.float32)
        for i, key in enumerate(TMT_FEATURE_KEYS):
            vec[i] = float(engineered.get(key, 0.0))
        return vec

    @staticmethod
    def build_app_feature_vector(features: dict) -> np.ndarray:
        """Build feature vector from app-based tests (Stroop/N-Back/Word Recall)."""
        vec = np.zeros(len(APP_COGNITIVE_KEYS), dtype=np.float32)
        for i, key in enumerate(APP_COGNITIVE_KEYS):
            vec[i] = float(features.get(key, 0.0))
        return vec

    # ------------------------------------------------------------------ #
    # Derived features (cross-item)                                       #
    # ------------------------------------------------------------------ #
    async def _derive_features(self, features: Dict[str, Any]) -> Dict[str, Any]:
        derived: Dict[str, Any] = {}

        # Composite cognitive index (0-1)
        scores = []
        if "stroop_accuracy" in features:
            scores.append(features["stroop_accuracy"])
        if "nback_accuracy" in features:
            scores.append(features["nback_accuracy"])
        if "recall_accuracy" in features:
            scores.append(features["recall_accuracy"])
        if scores:
            derived["cognitive_composite"] = sum(scores) / len(scores)

        # Processing speed composite (ms)
        rts = []
        if features.get("stroop_avg_rt", 0) > 0:
            rts.append(features["stroop_avg_rt"])
        if features.get("nback_avg_rt", 0) > 0:
            rts.append(features["nback_avg_rt"])
        if rts:
            derived["processing_speed_ms"] = sum(rts) / len(rts)

        # TMT-derived: B/A ratio (classic AD indicator)
        # Floor at 1.5 — app can produce B ≤ A due to spatial learning
        tmt_a = features.get("tmt_a_time", 0)
        tmt_b = features.get("tmt_b_time", 0)
        if tmt_a > 0 and tmt_b > 0:
            derived["tmt_ba_ratio"] = max(tmt_b / tmt_a, 1.5)

        return derived

    # ------------------------------------------------------------------ #
    # Helpers                                                             #
    # ------------------------------------------------------------------ #
    @staticmethod
    def _compute_dprime(hit_rate: float, fa_rate: float) -> float:
        """Signal-detection d' (clipped to avoid inf)."""
        import math
        try:
            from scipy.stats import norm
        except ImportError:
            # Fallback approximation without scipy
            def _approx_ppf(p: float) -> float:
                p = max(min(p, 0.99), 0.01)
                t = math.sqrt(-2 * math.log(min(p, 1 - p)))
                c0, c1, c2 = 2.515517, 0.802853, 0.010328
                d1, d2, d3 = 1.432788, 0.189269, 0.001308
                val = t - (c0 + c1 * t + c2 * t * t) / (1 + d1 * t + d2 * t * t + d3 * t * t * t)
                return val if p > 0.5 else -val

            hr = max(min(hit_rate, 0.99), 0.01)
            far = max(min(fa_rate, 0.99), 0.01)
            return _approx_ppf(hr) - _approx_ppf(far)

        hr = max(min(hit_rate, 0.99), 0.01)
        far = max(min(fa_rate, 0.99), 0.01)
        try:
            return float(norm.ppf(hr) - norm.ppf(far))
        except Exception:
            return 0.0
