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

    # Load each predictor independently so one failure doesn't break others
    _predictor_imports = {
        "speech": ("app.ml.predictors.speech_predictor", "SpeechPredictor"),
        "cognitive": ("app.ml.predictors.cognitive_predictor", "CognitivePredictor"),
        "motor": ("app.ml.predictors.motor_predictor", "MotorPredictor"),
        "facial": ("app.ml.predictors.facial_predictor", "FacialPredictor"),
        "gait": ("app.ml.predictors.gait_predictor", "GaitPredictor"),
    }

    for category, (module_path, class_name) in _predictor_imports.items():
        try:
            import importlib
            module = importlib.import_module(module_path)
            predictor_class = getattr(module, class_name)
            pred = predictor_class()
            pred.load()
            _PREDICTORS[category] = pred
        except Exception as exc:
            logger.warning("Predictor '%s' unavailable: %s. Heuristic fallback will be used.", category, exc)


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
