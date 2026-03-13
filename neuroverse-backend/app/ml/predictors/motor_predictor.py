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

        # Try spiral image prediction
        spiral_result = await self._try_image_prediction(
            features, "spiral_image_base64", self._spiral_model, self._spiral_loaded, "spiral"
        )
        if spiral_result:
            results.append(spiral_result)

        # Try meander image prediction
        meander_result = await self._try_image_prediction(
            features, "meander_image_base64", self._meander_model, self._meander_loaded, "meander"
        )
        if meander_result:
            results.append(meander_result)

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
            pd_risk = float(out["risk"].item())
            logits = out["logits"].squeeze(0)
            probs = torch.softmax(logits, dim=-1)
            healthy_p = float(probs[0].item())
            pd_p = float(probs[1].item())

            return {
                "ad_risk": round(min(pd_risk * 5, 10.0), 2),
                "pd_risk": round(pd_risk * 100, 2),
                "confidence": round(max(healthy_p, pd_p), 3),
                "classification": "PD" if pd_p > healthy_p else "Healthy",
                "class_probabilities": {"Healthy": round(healthy_p, 3), "PD": round(pd_p, 3)},
                "source": f"{source_tag}_model",
                "input_tensor": tensor,  # Keep for GradCAM XAI
                "model_ref": source_tag,
            }

        logger.info("Motor %s model not loaded; no image prediction available.", source_tag)
        return None

    @staticmethod
    def _merge_motor_results(results: list) -> Dict[str, Any]:
        """Merge predictions from spiral and meander models."""
        if len(results) == 1:
            r = results[0]
            r.pop("input_tensor", None)
            r.pop("model_ref", None)
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

        return {
            "ad_risk": round(merged_ad, 2),
            "pd_risk": round(merged_pd, 2),
            "confidence": round(merged_conf, 3),
            "classification": classification,
            "source": "+".join(sources),
            "individual_results": {
                r.get("model_ref", f"model_{i}"): {
                    "pd_risk": r["pd_risk"], "confidence": r["confidence"]
                }
                for i, r in enumerate(results)
            },
        }

    @staticmethod
    def _heuristic_from_features(features: dict) -> Dict[str, Any]:
        """Rule-based PD risk from tapping + drawing numeric features."""
        pd_risk = 5.0

        rate = features.get("tapping_rate", 5.0)
        if rate < 3.0:
            pd_risk += 20
        elif rate < 4.0:
            pd_risk += 10

        regularity = features.get("tapping_regularity", 0.7)
        if regularity < 0.4:
            pd_risk += 18
        elif regularity < 0.6:
            pd_risk += 8

        fatigue = features.get("tapping_fatigue", 0.1)
        if fatigue > 0.5:
            pd_risk += 12
        elif fatigue > 0.3:
            pd_risk += 5

        # Spiral features
        tremor = features.get("spiral_tremor", 0.0)
        if tremor > 0.5:
            pd_risk += 20

        deviation = features.get("spiral_deviation", 0.0)
        if deviation > 0.6:
            pd_risk += 10

        tremor_score = features.get("spiral_tremor_score", features.get("drawing_tremor_score", 0.0))
        if tremor_score > 0.5:
            pd_risk += 12

        speed_var = features.get("spiral_speed_variability", features.get("drawing_speed_variability", 0.0))
        if speed_var > 1.0:
            pd_risk += 8

        # Meander features
        meander_tremor = features.get("meander_tremor", 0.0)
        if meander_tremor > 0.5:
            pd_risk += 15

        meander_dev = features.get("meander_deviation", 0.0)
        if meander_dev > 0.6:
            pd_risk += 8

        pd_risk = min(max(pd_risk, 0.0), 100.0)
        return {
            "ad_risk": round(min(pd_risk * 0.05, 5.0), 2),
            "pd_risk": round(pd_risk, 2),
            "confidence": 0.45,
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
