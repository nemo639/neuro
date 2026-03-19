"""
Motor Predictor – loads separate MotorNet models for spiral and meander.

MotorNet architecture (from motor_spiral_training / motor_meander_training notebooks):
  - EfficientNet-B0 backbone (blocks 5-6 fine-tuned)
  - Classification head: 1280→256→64→2 (Healthy/PD)
  - PD risk head: 2→16→1 (sigmoid)
  Input: 3×224×224 spiral or meander image

Models:
  - spiral_model.pt (or motor_model.pt): 95.5% acc, AUC 0.955
  - meander_model.pt: 91.4% acc, AUC 0.971
"""

import logging
from typing import Any, Dict, Optional

import numpy as np
import torch
import torch.nn as nn

from app.ml.predictors.base_predictor import BasePredictor, MODELS_DIR, torch_available, _import_torch
from app.ml.extractors.motor_extractor import MotorExtractor, IMAGENET_MEAN, IMAGENET_STD
from app.ml.extractors.phone_image_adapter import calibrate_phone_risk

logger = logging.getLogger(__name__)


# ------------------------------------------------------------------ #
# MotorNet architecture (exact copy from training notebooks)          #
# ------------------------------------------------------------------ #

class MotorNet(nn.Module):
    """EfficientNet-B0 based motor dysfunction detector (timm).

    Used for both spiral and meander drawing classification.
    Binary: Healthy (0) vs PD (1).
    """

    def __init__(self, num_classes: int = 2, pretrained: bool = False, dropout: float = 0.5):
        super().__init__()
        import timm
        self.backbone = timm.create_model(
            "efficientnet_b0", pretrained=pretrained, num_classes=0,
        )
        in_features = self.backbone.num_features  # 1280

        self.classifier = nn.Sequential(
            nn.Dropout(dropout),
            nn.Linear(in_features, 256),
            nn.ReLU(),
            nn.BatchNorm1d(256),
            nn.Dropout(dropout * 0.6),
            nn.Linear(256, 64),
            nn.ReLU(),
            nn.BatchNorm1d(64),
            nn.Linear(64, num_classes),
        )
        self.risk_head = nn.Sequential(
            nn.Linear(num_classes, 16),
            nn.ReLU(),
            nn.Linear(16, 1),
            nn.Sigmoid(),
        )

    def forward(self, x):
        features = self.backbone(x)
        logits = self.classifier(features)
        risk = self.risk_head(logits).squeeze(-1)
        return {"logits": logits, "risk": risk, "features": features}


# ------------------------------------------------------------------ #
# Predictor                                                           #
# ------------------------------------------------------------------ #

class MotorPredictor(BasePredictor):
    model_filename = "motor_model.pt"

    def __init__(self):
        super().__init__()
        self._spiral_model = None
        self._meander_model = None
        self._spiral_loaded = False
        self._meander_loaded = False

    def _build_model(self) -> nn.Module:
        return MotorNet(num_classes=2, pretrained=False)

    def load(self) -> bool:
        """Load spiral and meander models separately."""
        if not torch_available():
            logger.warning("PyTorch not installed – MotorPredictor will use heuristic fallback.")
            return False

        torch_mod = _import_torch()

        # Load spiral model (try spiral_model.pt first, then motor_model.pt)
        for spiral_name in ("spiral_model.pt", "motor_model.pt"):
            spiral_path = MODELS_DIR / spiral_name
            if spiral_path.exists() and spiral_path.stat().st_size > 0:
                try:
                    self._spiral_model = MotorNet(num_classes=2, pretrained=False)
                    ckpt = torch_mod.load(spiral_path, map_location=self._device, weights_only=False)
                    state = ckpt.get("model_state_dict", ckpt.get("state_dict", ckpt))
                    self._spiral_model.load_state_dict(state)
                    self._spiral_model.to(self._device)
                    self._spiral_model.eval()
                    self._spiral_loaded = True
                    logger.info("Loaded spiral model (%s)", spiral_name)
                    break
                except Exception as exc:
                    logger.warning("Failed to load spiral model %s: %s", spiral_name, exc)

        # Load meander model
        meander_path = MODELS_DIR / "meander_model.pt"
        if meander_path.exists() and meander_path.stat().st_size > 0:
            try:
                self._meander_model = MotorNet(num_classes=2, pretrained=False)
                ckpt = torch_mod.load(meander_path, map_location=self._device, weights_only=False)
                state = ckpt.get("model_state_dict", ckpt.get("state_dict", ckpt))
                self._meander_model.load_state_dict(state)
                self._meander_model.to(self._device)
                self._meander_model.eval()
                self._meander_loaded = True
                logger.info("Loaded meander model (meander_model.pt)")
            except Exception as exc:
                logger.warning("Failed to load meander model: %s", exc)

        self._loaded = self._spiral_loaded or self._meander_loaded
        return self._loaded

    async def predict(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """
        Predict PD risk from motor test data.
        Tries image-based predictions for spiral and meander, then falls back to heuristics.
        """
        results = []

        # Log available image keys for debugging
        img_keys = [k for k in features if "image" in k.lower() or "base64" in k.lower()]
        logger.info("Motor predict: image-related keys in features: %s", img_keys)

        # Try spiral image prediction
        spiral_result = await self._try_image_prediction(
            features, "spiral_image_base64", self._spiral_model, self._spiral_loaded, "spiral"
        )
        if spiral_result:
            results.append(spiral_result)
        else:
            logger.warning("Spiral image prediction failed (key present: %s, model loaded: %s)",
                          "spiral_image_base64" in features, self._spiral_loaded)

        # Try meander image prediction
        meander_result = await self._try_image_prediction(
            features, "meander_image_base64", self._meander_model, self._meander_loaded, "meander"
        )
        if meander_result:
            results.append(meander_result)
        else:
            logger.warning("Meander image prediction failed (key present: %s, model loaded: %s)",
                          "meander_image_base64" in features, self._meander_loaded)

        # Also check generic drawing key
        if not results:
            generic = await self._try_image_prediction(
                features, "drawing_image_base64", self._spiral_model, self._spiral_loaded, "drawing"
            )
            if generic:
                results.append(generic)

        # Merge results from multiple models
        if results:
            return self._merge_motor_results(results)

        # Fallback to numeric feature heuristic
        return self._heuristic_from_features(features)

    async def _try_image_prediction(
        self, features: dict, image_key: str,
        model: Optional[nn.Module], model_loaded: bool, source_tag: str,
    ) -> Optional[Dict[str, Any]]:
        """Attempt image-based prediction for a specific drawing type."""
        b64 = features.get(image_key)
        if not b64:
            return None

        img = MotorExtractor.decode_image_base64(b64)
        if img is None:
            return None

        preprocessed = MotorExtractor.preprocess_image(img, target_size=224)
        tensor = self._to_tensor(preprocessed)

        if model_loaded and model is not None:
            with torch.no_grad():
                out = model(tensor)
            raw_pd_risk = float(out["risk"].item()) * 100
            logits = out["logits"].squeeze(0)
            probs = torch.softmax(logits, dim=-1)
            healthy_p = float(probs[0].item())
            pd_p = float(probs[1].item())
            confidence = max(healthy_p, pd_p)

            # Phone calibration: model trained on paper pen drawings
            # overestimates PD risk for phone finger drawings because:
            # - Finger on glass = unnaturally smooth (no pen tremor)
            # - Thick finger strokes look different from thin pen lines
            modality = f"motor_{source_tag}"
            pd_risk = calibrate_phone_risk(raw_pd_risk, modality=modality, confidence=confidence)
            logger.info("Motor %s: raw_risk=%.1f%%, calibrated=%.1f%% (conf=%.3f)",
                       source_tag, raw_pd_risk, pd_risk, confidence)

            return {
                "ad_risk": round(min(pd_risk * 0.05, 5.0), 2),
                "pd_risk": round(pd_risk, 2),
                "confidence": round(confidence, 3),
                "classification": "PD" if pd_risk > 50 else "Healthy",
                "raw_model_risk": round(raw_pd_risk, 2),
                "class_probabilities": {"Healthy": round(healthy_p, 3), "PD": round(pd_p, 3)},
                "source": f"{source_tag}_model",
                "input_tensor": tensor,  # Keep for GradCAM XAI
                "model_ref": source_tag,
            }

        logger.info("Motor %s model not loaded; no image prediction available.", source_tag)
        return None

    def _merge_motor_results(self, results: list) -> Dict[str, Any]:
        """Merge predictions from spiral and meander models."""
        # Pick best model+tensor for XAI (highest confidence)
        best = max(results, key=lambda r: r.get("confidence", 0))
        xai_model = best.pop("input_tensor", None)
        xai_ref = best.get("model_ref")
        # Resolve model object for XAI
        xai_model_obj = None
        if xai_ref == "spiral" and self._spiral_loaded:
            xai_model_obj = self._spiral_model
        elif xai_ref == "meander" and self._meander_loaded:
            xai_model_obj = self._meander_model

        if len(results) == 1:
            r = results[0]
            r.pop("input_tensor", None)
            r.pop("model_ref", None)
            r["_xai_model"] = xai_model_obj
            r["_xai_tensor"] = xai_model
            return r

        # Average risks weighted by confidence
        total_conf = sum(r["confidence"] for r in results)
        if total_conf == 0:
            total_conf = 1.0

        merged_pd = sum(r["pd_risk"] * r["confidence"] for r in results) / total_conf
        merged_ad = sum(r["ad_risk"] * r["confidence"] for r in results) / total_conf
        merged_conf = max(r["confidence"] for r in results)

        classification = "PD" if merged_pd > 50 else "Healthy"
        sources = [r.get("source", "unknown") for r in results]

        # Clean sub-results
        for r in results:
            r.pop("input_tensor", None)
            r.pop("model_ref", None)

        return {
            "ad_risk": round(merged_ad, 2),
            "pd_risk": round(merged_pd, 2),
            "confidence": round(merged_conf, 3),
            "classification": classification,
            "source": "+".join(sources),
            "individual_results": {
                r.get("source", f"model_{i}"): {
                    "pd_risk": r["pd_risk"], "confidence": r["confidence"]
                }
                for i, r in enumerate(results)
            },
            "_xai_model": xai_model_obj,
            "_xai_tensor": xai_model,
        }

    @staticmethod
    def _heuristic_from_features(features: dict) -> Dict[str, Any]:
        """Rule-based PD risk from tremor + drawing numeric features.

        Phone-aware thresholds:
        - spiral_tremor on phone is INVERTED: high = smooth finger (normal)
          so we only penalize very LOW tremor_score (> 0.9 means smooth = phone artifact)
        - deviation thresholds relaxed (finger imprecision on glass)
        - tremor_score from drawing point analysis is more reliable than
          the raw Flutter tremor_score (which measures smoothness)
        """
        pd_risk = 3.0  # Lower baseline

        # Resting tremor features (accelerometer — NOT affected by phone drawing)
        tremor_amp = features.get("tremor_amplitude", 0.0)
        if tremor_amp > 0:
            # Accelerometer tremor is reliable regardless of input device
            if tremor_amp > 1.0:
                pd_risk += 25
            elif tremor_amp > 0.5:
                pd_risk += 15
            elif tremor_amp > 0.2:
                pd_risk += 5

            # PD-characteristic frequency (4-7 Hz)
            pd_freq = features.get("tremor_pd_freq_match", 0.0)
            if pd_freq > 0:
                pd_risk += 10

        # Spiral features — phone-recalibrated
        # On phone, spiral_tremor is a Flutter-computed score where HIGH = smooth
        # This is the OPPOSITE of clinical tremor (high tremor = bad)
        # Only penalize if we have drawing-point-derived tremor_score
        drawing_tremor = features.get("spiral_tremor_score", features.get("drawing_tremor_score", 0.0))
        if drawing_tremor > 1.5:  # Point-analysis tremor (acceleration std)
            pd_risk += 12
        elif drawing_tremor > 0.8:
            pd_risk += 5

        deviation = features.get("spiral_deviation", 0.0)
        if deviation > 0.8:  # Relaxed from 0.6 (phone finger = less precise)
            pd_risk += 8
        elif deviation > 0.5:
            pd_risk += 3

        speed_var = features.get("spiral_speed_variability", features.get("drawing_speed_variability", 0.0))
        if speed_var > 2.0:  # Relaxed from 1.0 (phone finger movement is more variable)
            pd_risk += 5

        # Meander features — phone-recalibrated
        meander_tremor = features.get("meander_tremor_score", 0.0)
        if meander_tremor > 1.5:
            pd_risk += 10
        elif meander_tremor > 0.8:
            pd_risk += 4

        meander_dev = features.get("meander_deviation", 0.0)
        if meander_dev > 0.8:  # Relaxed from 0.6
            pd_risk += 5

        pd_risk = min(max(pd_risk, 0.0), 100.0)
        return {
            "ad_risk": round(min(pd_risk * 0.05, 5.0), 2),
            "pd_risk": round(pd_risk, 2),
            "confidence": 0.40,
            "classification": "PD" if pd_risk > 50 else "Healthy",
            "source": "heuristic",
        }

    def get_model_for_gradcam(self, drawing_type: str = "spiral"):
        """Return the appropriate model for GradCAM visualization."""
        if drawing_type == "meander" and self._meander_model is not None:
            return self._meander_model
        if self._spiral_model is not None:
            return self._spiral_model
        return None
