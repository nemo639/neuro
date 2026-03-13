"""
Gait Predictor – heuristic-only (model not yet trained).

When gait_model.pt is trained and placed in models/, this predictor
will load it automatically. Until then, uses clinical heuristics based
on step regularity, gait speed, and balance metrics.
"""

import logging
from typing import Any, Dict

import torch.nn as nn

from app.ml.predictors.base_predictor import BasePredictor

logger = logging.getLogger(__name__)


class GaitPredictor(BasePredictor):
    model_filename = "gait_model.pt"

    def _build_model(self) -> nn.Module:
        return nn.Identity()

    async def predict(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """Predict PD risk from gait analysis features."""
        return self._heuristic(features)

    @staticmethod
    def _heuristic(features: dict) -> Dict[str, Any]:
        pd_risk = 5.0
        ad_risk = 3.0

        # Step regularity: <0.5 is concerning
        step_reg = features.get("step_regularity", 0.7)
        if step_reg < 0.4:
            pd_risk += 25
        elif step_reg < 0.6:
            pd_risk += 12

        # Gait speed: <0.8 m/s is concerning (age-adjusted)
        speed = features.get("gait_speed", 1.0)
        if speed < 0.6:
            pd_risk += 20
            ad_risk += 10
        elif speed < 0.8:
            pd_risk += 10
            ad_risk += 5

        # Turn stability
        turn = features.get("turn_stability", 0.7)
        if turn < 0.4:
            pd_risk += 18
        elif turn < 0.6:
            pd_risk += 8

        # Balance
        balance = features.get("balance_stability", 0.7)
        if balance < 0.4:
            pd_risk += 15
        elif balance < 0.6:
            pd_risk += 8

        # Sway
        sway = features.get("balance_sway", 0)
        if sway > 0.8:
            pd_risk += 12

        pd_risk = min(max(pd_risk, 0.0), 100.0)
        ad_risk = min(max(ad_risk, 0.0), 100.0)

        return {
            "ad_risk": round(ad_risk, 2),
            "pd_risk": round(pd_risk, 2),
            "confidence": 0.35,
            "source": "heuristic",
        }
