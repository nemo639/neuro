"""
Predictor registry – singleton instances for each modality.
Call ``get_predictor(category)`` to obtain a (lazily-loaded) predictor.

All ML-heavy imports are deferred so the server starts even without torch/numpy.
"""

import logging

logger = logging.getLogger(__name__)

_PREDICTORS = {}
_initialized = False


def _init_predictors():
    global _PREDICTORS, _initialized
    if _initialized:
        return
    _initialized = True

    try:
        from app.ml.predictors.speech_predictor import SpeechPredictor
        from app.ml.predictors.cognitive_predictor import CognitivePredictor
        from app.ml.predictors.motor_predictor import MotorPredictor
        from app.ml.predictors.facial_predictor import FacialPredictor
        from app.ml.predictors.gait_predictor import GaitPredictor

        _PREDICTORS.update({
            "speech": SpeechPredictor(),
            "cognitive": CognitivePredictor(),
            "motor": MotorPredictor(),
            "facial": FacialPredictor(),
            "gait": GaitPredictor(),
        })

        # Attempt to load model weights
        for name, pred in _PREDICTORS.items():
            pred.load()

    except ImportError as exc:
        logger.warning("ML predictors unavailable (missing dependency: %s). Using heuristic-only mode.", exc)


class _HeuristicFallback:
    """Minimal fallback when ML packages are not installed."""
    is_loaded = False

    async def predict(self, features):
        return {"ad_risk": 15.0, "pd_risk": 10.0, "confidence": 0.2, "source": "unavailable"}


def get_predictor(category: str):
    """Return the singleton predictor for *category*."""
    _init_predictors()
    pred = _PREDICTORS.get(category)
    if pred is None:
        logger.warning("No predictor for category '%s' – using fallback.", category)
        return _HeuristicFallback()
    return pred
