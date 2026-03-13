"""
Facial Predictor – heuristic-only (model not yet trained).

When facial_model.pt is trained and placed in models/, this predictor
will load it automatically. Until then, uses clinical heuristics based
on blink rate, smile velocity, and hypomimia indicators.
"""

import logging
from typing import Any, Dict

import torch.nn as nn

from app.ml.predictors.base_predictor import BasePredictor

logger = logging.getLogger(__name__)


class FacialPredictor(BasePredictor):
    model_filename = "facial_model.pt"

    def _build_model(self) -> nn.Module:
        # Placeholder – will be replaced when facial model is trained
        return nn.Identity()

    async def predict(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """Predict PD risk from facial analysis features."""
        # Model not yet trained – use heuristic
        return self._heuristic(features)

    @staticmethod
    def _heuristic(features: dict) -> Dict[str, Any]:
        pd_risk = 5.0
        ad_risk = 3.0

        # Blink rate: normal 15-20/min, <10 = hypomimia (PD), >25 = stress
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

        # Smile count
        smile_count = features.get("smile_count", 0)
        if smile_count == 0:
            pd_risk += 10

        pd_risk = min(max(pd_risk, 0.0), 100.0)
        ad_risk = min(max(ad_risk, 0.0), 100.0)

        return {
            "ad_risk": round(ad_risk, 2),
            "pd_risk": round(pd_risk, 2),
            "confidence": 0.35,
            "source": "heuristic",
        }
