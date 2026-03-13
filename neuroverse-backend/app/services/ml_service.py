"""
ML Service – Feature extraction + model inference pipeline.

Wires together:
  - Extractors (speech, cognitive, motor, gait, facial) → numeric features
  - Predictors (SpeechNeuroNet, TMTNet, MotorNet, etc.) → risk scores

This is the single entry-point called by TestService.complete_session().
"""

import logging
from typing import Any, Dict, List

from app.models.test_item import TestItem

# Predictors (lazy-loaded to handle missing torch/numpy gracefully)
from app.ml.predictors import get_predictor

logger = logging.getLogger(__name__)

# Singleton extractor instances (lazy-loaded)
_EXTRACTORS: Dict[str, Any] = {}
_extractors_init = False


def _init_extractors():
    global _EXTRACTORS, _extractors_init
    if _extractors_init:
        return
    _extractors_init = True
    try:
        from app.ml.extractors.speech_extractor import SpeechExtractor
        from app.ml.extractors.cognitive_extractor import CognitiveExtractor
        from app.ml.extractors.motor_extractor import MotorExtractor
        _EXTRACTORS.update({
            "speech": SpeechExtractor(),
            "cognitive": CognitiveExtractor(),
            "motor": MotorExtractor(),
        })
    except ImportError as exc:
        logger.warning("Extractors unavailable (%s). Using generic extraction.", exc)


class MLService:
    """
    Machine Learning Service — feature extraction + model inference.

    Usage:
        svc = MLService()
        features = await svc.extract_features("speech", test_items)
        predictions = await svc.predict("speech", features)
    """

    async def extract_features(
        self,
        category: str,
        test_items: List[TestItem],
    ) -> Dict[str, Any]:
        """
        Extract numeric features from raw test items.

        For categories with a dedicated extractor (speech, cognitive, motor)
        we delegate to the extractor class.  For gait/facial (no trained
        extractor yet) we do a lightweight pass-through of raw data.
        """
        _init_extractors()
        extractor = _EXTRACTORS.get(category)
        if extractor is not None:
            features = await extractor.extract(test_items)
        else:
            features = await self._generic_extract(category, test_items)

        logger.info(
            "Extracted %d features for category=%s from %d items",
            len(features), category, len(test_items),
        )
        return features

    async def predict(
        self,
        category: str,
        features: Dict[str, Any],
    ) -> Dict[str, Any]:
        """
        Run model inference and return risk scores.

        Returns at minimum:
            {"ad_risk": float, "pd_risk": float, "confidence": float}
        """
        predictor = get_predictor(category)
        result = await predictor.predict(features)
        logger.info(
            "Prediction for %s: AD=%.1f%% PD=%.1f%% (confidence=%.2f, source=%s)",
            category,
            result.get("ad_risk", 0),
            result.get("pd_risk", 0),
            result.get("confidence", 0),
            result.get("source", "model" if predictor.is_loaded else "heuristic"),
        )
        return result

    # ------------------------------------------------------------------ #
    # Generic extraction for categories without a dedicated extractor     #
    # ------------------------------------------------------------------ #
    async def _generic_extract(
        self, category: str, items: List[TestItem]
    ) -> Dict[str, Any]:
        """Pass-through extraction for gait / facial."""
        features: Dict[str, Any] = {
            "category": category,
            "items_processed": len(items),
        }

        for item in items:
            raw = item.raw_data or {}
            for key, val in raw.items():
                if isinstance(val, (int, float)):
                    features[key] = val
                elif isinstance(val, list) and val and isinstance(val[0], (int, float)):
                    features[key] = val

        return features
