"""
Facial Predictor – ShallowANN for PD detection from facial expression features.

Architecture from UFNet (AAAI 2025):
  - ShallowANN: Linear(n_features → 1) + Dropout + Sigmoid
  - Trained on smile task AU features from UFNet facial_dataset.csv
  - Binary: PD (1) vs Non-PD (0)
  - Input: ~42 facial AU features (mean, var, entropy per AU + landmarks)
  - MC Dropout for uncertainty estimation at inference

Model file: facial_model.pt
Falls back to clinical heuristics when model weights are unavailable.
"""

import logging
import pickle
from pathlib import Path
from typing import Any, Dict, Optional

import numpy as np
import torch
import torch.nn as nn

from app.ml.predictors.base_predictor import BasePredictor, MODELS_DIR, torch_available, _import_torch

logger = logging.getLogger(__name__)

# Feature order must match training exactly (from facial_model_info.txt).
# These are the 42 smile task AU features from UFNet training.
FACIAL_FEATURE_KEYS = [
    "smile_AU01_mean", "smile_AU01_var", "smile_AU01_entropy",
    "smile_AU06_mean", "smile_AU06_var", "smile_AU06_entropy",
    "smile_AU12_mean", "smile_AU12_var", "smile_AU12_entropy",
    "smile_AU14_mean", "smile_AU14_var", "smile_AU14_entropy",
    "smile_AU25_mean", "smile_AU25_var", "smile_AU25_entropy",
    "smile_AU26_mean", "smile_AU26_var", "smile_AU26_entropy",
    "smile_AU45_mean", "smile_AU45_var", "smile_AU45_entropy",
    "smile_eye-open-right_mean", "smile_eye-open-right_var", "smile_eye-open-right_entropy",
    "smile_eye-open-left_mean", "smile_eye-open-left_var", "smile_eye-open-left_entropy",
    "smile_eye-raise-right_mean", "smile_eye-raise-right_var", "smile_eye-raise-right_entropy",
    "smile_eye-raise-left_mean", "smile_eye-raise-left_var", "smile_eye-raise-left_entropy",
    "smile_mouth-open_mean", "smile_mouth-open_var", "smile_mouth-open_entropy",
    "smile_mouth-width_mean", "smile_mouth-width_var", "smile_mouth-width_entropy",
    "smile_jaw-open_mean", "smile_jaw-open_var", "smile_jaw-open_entropy",
]

# Mapping from extractor feature names to training feature names
_EXTRACTOR_TO_TRAINING = {
    "au01_mean": "smile_AU01_mean", "au01_var": "smile_AU01_var", "au01_entropy": "smile_AU01_entropy",
    "au06_mean": "smile_AU06_mean", "au06_var": "smile_AU06_var", "au06_entropy": "smile_AU06_entropy",
    "au12_mean": "smile_AU12_mean", "au12_var": "smile_AU12_var", "au12_entropy": "smile_AU12_entropy",
    "au25_mean": "smile_AU25_mean", "au25_var": "smile_AU25_var", "au25_entropy": "smile_AU25_entropy",
    "au45_mean": "smile_AU45_mean", "au45_var": "smile_AU45_var", "au45_entropy": "smile_AU45_entropy",
    "eye_open_mean": "smile_eye-open-right_mean",
    "eye_raise_mean": "smile_eye-raise-right_mean",
    "mouth_open_mean": "smile_mouth-open_mean",
    "mouth_width_mean": "smile_mouth-width_mean",
    "jaw_open_mean": "smile_jaw-open_mean",
}


class ShallowANN(nn.Module):
    """ShallowANN from UFNet – single linear layer + dropout + sigmoid.

    Matches the architecture in unimodal_smile_baal.py:
      Linear(n_features → 1) → Dropout → Sigmoid
    """

    def __init__(self, n_features: int, drop_prob: float = 0.1):
        super().__init__()
        self.fc = nn.Linear(in_features=n_features, out_features=1, bias=True)
        self.drop = nn.Dropout(p=drop_prob)
        self.sig = nn.Sigmoid()

    def forward(self, x):
        y = self.fc(x)
        y = self.drop(y)
        y = self.sig(y)
        return y


class FacialPredictor(BasePredictor):
    model_filename = "facial_model.pt"

    def __init__(self):
        super().__init__()
        self._scaler = None
        self._n_features = len(FACIAL_FEATURE_KEYS)

    def _build_model(self) -> nn.Module:
        return ShallowANN(n_features=self._n_features, drop_prob=0.1)

    def load(self) -> bool:
        """Load facial model and optional scaler."""
        if not torch_available():
            logger.warning("PyTorch not installed – FacialPredictor will use heuristic fallback.")
            return False

        torch_mod = _import_torch()
        model_path = MODELS_DIR / self.model_filename

        if not model_path.exists() or model_path.stat().st_size == 0:
            logger.warning("Facial model file missing or empty: %s – using heuristic fallback.", model_path)
            return False

        try:
            self._model = self._build_model()
            checkpoint = torch_mod.load(model_path, map_location=self._device, weights_only=False)

            # Handle different checkpoint formats
            if isinstance(checkpoint, dict):
                if "model_state_dict" in checkpoint:
                    state = checkpoint["model_state_dict"]
                elif "state_dict" in checkpoint:
                    state = checkpoint["state_dict"]
                else:
                    state = checkpoint

                # Detect n_features from saved weights
                fc_weight_key = next((k for k in state if "fc.weight" in k), None)
                if fc_weight_key and state[fc_weight_key].shape[1] != self._n_features:
                    saved_n = state[fc_weight_key].shape[1]
                    logger.info("Rebuilding ShallowANN with n_features=%d (from checkpoint)", saved_n)
                    self._n_features = saved_n
                    self._model = ShallowANN(n_features=saved_n, drop_prob=0.1)

                self._model.load_state_dict(state)
            else:
                # Direct state dict
                self._model.load_state_dict(checkpoint)

            self._model.to(self._device)
            self._model.eval()
            self._loaded = True
            logger.info("Loaded facial model (ShallowANN, %d features)", self._n_features)

            # Try loading scaler
            scaler_path = MODELS_DIR / "facial_scaler.pkl"
            if scaler_path.exists():
                with open(scaler_path, "rb") as f:
                    self._scaler = pickle.load(f)
                logger.info("Loaded facial feature scaler")

            return True
        except Exception as exc:
            logger.error("Failed to load facial model: %s", exc)
            return False

    def _prepare_features(self, features: dict) -> np.ndarray:
        """Convert feature dict to numpy array in correct order.

        Maps extractor feature names to training feature names,
        and mirrors single-side values to left/right where needed.
        """
        # First, remap extractor keys to training keys
        mapped = {}
        for ext_key, train_key in _EXTRACTOR_TO_TRAINING.items():
            if ext_key in features:
                mapped[train_key] = features[ext_key]

        # Mirror right→left for eye features (app doesn't distinguish sides)
        for side_pair in [
            ("smile_eye-open-right_", "smile_eye-open-left_"),
            ("smile_eye-raise-right_", "smile_eye-raise-left_"),
        ]:
            for suffix in ("mean", "var", "entropy"):
                r_key = side_pair[0] + suffix
                l_key = side_pair[1] + suffix
                if r_key in mapped and l_key not in mapped:
                    mapped[l_key] = mapped[r_key]

        # Fill variance/entropy for mouth/jaw from extractor if available
        for base in ("mouth_open", "mouth_width", "jaw_open"):
            ext_var = features.get(f"{base}_var", features.get(f"au25_var", 0.0))
            ext_ent = features.get(f"{base}_entropy", features.get(f"au25_entropy", 0.0))
            train_base = f"smile_{base.replace('_', '-')}"
            if f"{train_base}_var" not in mapped:
                mapped[f"{train_base}_var"] = float(ext_var)
            if f"{train_base}_entropy" not in mapped:
                mapped[f"{train_base}_entropy"] = float(ext_ent)

        # AU14 (dimpler) ≈ smile symmetry inverse, AU26 (jaw drop) ≈ jaw_open
        if "smile_AU14_mean" not in mapped:
            sym = features.get("smile_symmetry", 85.0)
            mapped["smile_AU14_mean"] = max(0, (100.0 - float(sym)) / 100.0)
            mapped["smile_AU14_var"] = mapped.get("smile_AU12_var", 0.0)
            mapped["smile_AU14_entropy"] = mapped.get("smile_AU12_entropy", 0.0)
        if "smile_AU26_mean" not in mapped:
            mapped["smile_AU26_mean"] = features.get("jaw_open_mean", mapped.get("smile_jaw-open_mean", 0.0))
            mapped["smile_AU26_var"] = mapped.get("smile_jaw-open_var", 0.0)
            mapped["smile_AU26_entropy"] = mapped.get("smile_jaw-open_entropy", 0.0)

        # Build final array
        arr = np.zeros(self._n_features, dtype=np.float32)
        for i, key in enumerate(FACIAL_FEATURE_KEYS[:self._n_features]):
            arr[i] = float(mapped.get(key, features.get(key, 0.0)))

        # Apply scaler if available
        if self._scaler is not None:
            arr = self._scaler.transform(arr.reshape(1, -1)).flatten()

        return arr

    async def predict(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """Predict PD risk from facial analysis features.

        The ShallowANN was trained on real Action Unit data from UFNet.
        Flutter sends simplified metrics (blink_rate, smile_velocity, etc.)
        which are approximated to AU format.  We use clinical heuristics
        calibrated for the Flutter feature ranges, then blend with the
        ML model output to get a more reliable prediction.
        """
        heuristic_result = self._heuristic(features)

        if self._loaded and self._model is not None:
            ml_result = self._model_predict(features)
            # Blend: 70% heuristic (calibrated for Flutter) + 30% ML model
            blended_pd = heuristic_result["pd_risk"] * 0.7 + ml_result["pd_risk"] * 0.3
            blended_ad = heuristic_result["ad_risk"] * 0.7 + ml_result["ad_risk"] * 0.3
            return {
                "ad_risk": round(blended_ad, 2),
                "pd_risk": round(blended_pd, 2),
                "confidence": round(ml_result["confidence"] * 0.6 + heuristic_result["confidence"] * 0.4, 3),
                "classification": "PD" if blended_pd > 50 else "Healthy",
                "class_probabilities": ml_result.get("class_probabilities", {}),
                "source": "facial_model",
                "model_ref": "facial",
                "_xai_tensor": ml_result.get("_xai_tensor"),
            }
        return heuristic_result

    def _model_predict(self, features: dict) -> Dict[str, Any]:
        """Run ShallowANN inference."""
        torch_mod = _import_torch()

        arr = self._prepare_features(features)
        tensor = torch_mod.tensor(arr, dtype=torch_mod.float32).unsqueeze(0).to(self._device)

        with torch_mod.no_grad():
            self._model.eval()
            output = self._model(tensor)

        pd_prob = float(output.item())
        pd_risk = pd_prob * 100.0

        # Confidence from how far from 0.5 the prediction is
        confidence = abs(pd_prob - 0.5) * 2.0
        confidence = max(confidence, 0.50)  # Minimum confidence floor

        classification = "PD" if pd_risk > 50 else "Healthy"

        return {
            "ad_risk": round(min(pd_risk * 0.03, 3.0), 2),  # Facial is PD-specific
            "pd_risk": round(pd_risk, 2),
            "confidence": round(confidence, 3),
            "classification": classification,
            "class_probabilities": {
                "Healthy": round(1.0 - pd_prob, 3),
                "PD": round(pd_prob, 3),
            },
            "source": "facial_model",
            "model_ref": "facial",
            "_xai_tensor": tensor,  # For XAI
        }

    @staticmethod
    def _heuristic(features: dict) -> Dict[str, Any]:
        """Rule-based PD risk from facial expression features."""
        pd_risk = 5.0
        ad_risk = 3.0

        # Blink rate: normal 15-20/min, <10 = PD indicator (hypomimia)
        blink = features.get("blink_rate", 15)
        if blink < 8:
            pd_risk += 25
        elif blink < 12:
            pd_risk += 12

        # Smile intensity: reduced = facial masking (PD)
        smile = features.get("smile_intensity", 0.5)
        if smile < 0.2:
            pd_risk += 18
        elif smile < 0.4:
            pd_risk += 8

        # Smile velocity: slower = PD
        smile_vel = features.get("smile_velocity", 0.5)
        if smile_vel < 0.3:
            pd_risk += 12
        elif smile_vel < 0.5:
            pd_risk += 5

        # Expression range: reduced = hypomimia
        expr_range = features.get("expression_range", 70)
        if expr_range < 30:
            pd_risk += 20
        elif expr_range < 50:
            pd_risk += 10

        # Hypomimia score: higher = more facial masking
        hypomimia = features.get("hypomimia_score", 50)
        if hypomimia > 70:
            pd_risk += 15
        elif hypomimia > 50:
            pd_risk += 8

        # Facial symmetry: asymmetry suggests unilateral onset
        symmetry = features.get("facial_symmetry", 90)
        if symmetry < 70:
            pd_risk += 10
        elif symmetry < 80:
            pd_risk += 5

        # Smile count
        smile_count = features.get("smile_count", 0)
        if smile_count == 0:
            pd_risk += 10

        pd_risk = min(max(pd_risk, 0.0), 100.0)
        ad_risk = min(max(ad_risk, 0.0), 100.0)

        return {
            "ad_risk": round(ad_risk, 2),
            "pd_risk": round(pd_risk, 2),
            "confidence": 0.40,
            "source": "heuristic",
        }
