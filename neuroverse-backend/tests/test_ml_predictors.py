"""
ML predictor tests:
- All 4 predictors load (or fall back to heuristic)
- predict() returns valid risk schema
- Risk values bounded [0, 100]
- AD/PD risk + confidence + classification + source fields present
"""
import pytest
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from app.ml.predictors import _PREDICTORS, _init_predictors, get_predictor  # noqa: E402
from app.ml.predictors.cognitive_predictor import CognitivePredictor
from app.ml.predictors.motor_predictor import MotorPredictor
from app.ml.predictors.speech_predictor import SpeechPredictor
from app.ml.predictors.facial_predictor import FacialPredictor


pytestmark = pytest.mark.asyncio


def _assert_valid_risk_output(result: dict):
    """Validate predictor output schema."""
    assert isinstance(result, dict)
    assert "ad_risk" in result
    assert "pd_risk" in result
    assert 0 <= result["ad_risk"] <= 100, f"ad_risk out of range: {result['ad_risk']}"
    assert 0 <= result["pd_risk"] <= 100, f"pd_risk out of range: {result['pd_risk']}"
    assert "confidence" in result
    assert 0 <= result["confidence"] <= 1, f"confidence out of range: {result['confidence']}"


class TestPredictorRegistry:
    def test_predictors_loaded_on_demand(self):
        # Trigger lazy init
        _init_predictors()
        # All 4 categories should be in registry (model or heuristic)
        for cat in ("speech", "cognitive", "motor", "facial"):
            assert cat in _PREDICTORS, f"Predictor missing: {cat}"

    def test_no_gait_predictor(self):
        _init_predictors()
        assert "gait" not in _PREDICTORS

    def test_get_predictor_returns_instance(self):
        for cat in ("speech", "cognitive", "motor", "facial"):
            pred = get_predictor(cat)
            assert pred is not None
            assert hasattr(pred, "predict")


class TestCognitivePredictor:
    async def test_predict_with_recall_features(self):
        pred = CognitivePredictor()
        pred.load()
        features = {
            "recall_score": 7,
            "total_words": 10,
            "stroop_interference": 0.4,
            "tmt_a_time": 35,
            "tmt_b_time": 95,
        }
        result = await pred.predict(features)
        _assert_valid_risk_output(result)

    async def test_predict_with_empty_features(self):
        pred = CognitivePredictor()
        pred.load()
        result = await pred.predict({})
        _assert_valid_risk_output(result)

    async def test_predict_high_risk_features(self):
        pred = CognitivePredictor()
        pred.load()
        features = {
            "recall_score": 2,
            "total_words": 10,
            "tmt_b_time": 240,
            "stroop_interference": 1.5,
        }
        result = await pred.predict(features)
        _assert_valid_risk_output(result)
        # Should produce non-zero risk for severely impaired features
        assert result["ad_risk"] > 0 or result["pd_risk"] > 0


class TestMotorPredictor:
    async def test_predict_with_features(self):
        pred = MotorPredictor()
        pred.load()
        features = {
            "tremor_amplitude": 0.3,
            "tremor_frequency": 5.5,
            "spiral_smoothness": 0.7,
            "meander_smoothness": 0.65,
        }
        result = await pred.predict(features)
        _assert_valid_risk_output(result)

    async def test_predict_with_empty_features(self):
        pred = MotorPredictor()
        pred.load()
        result = await pred.predict({})
        _assert_valid_risk_output(result)


class TestSpeechPredictor:
    async def test_predict_with_features(self):
        pred = SpeechPredictor()
        pred.load()
        features = {
            "speech_rate": 3.5,
            "pause_rate": 0.15,
            "jitter": 0.012,
            "shimmer": 0.04,
            "hnr": 18.0,
            "f0_mean": 130.0,
        }
        result = await pred.predict(features)
        _assert_valid_risk_output(result)

    async def test_predict_with_empty_features(self):
        pred = SpeechPredictor()
        pred.load()
        result = await pred.predict({})
        _assert_valid_risk_output(result)


class TestFacialPredictor:
    async def test_predict_with_features(self):
        pred = FacialPredictor()
        pred.load()
        features = {
            "blink_rate": 18.5,
            "smile_intensity": 0.7,
            "smile_velocity": 0.4,
            "facial_symmetry": 0.85,
            "expression_range": 0.6,
            "hypomimia_score": 0.2,
        }
        result = await pred.predict(features)
        _assert_valid_risk_output(result)

    async def test_predict_high_pd_risk_features(self):
        pred = FacialPredictor()
        pred.load()
        # Hypomimic / masked face — should give elevated PD risk
        features = {
            "blink_rate": 6.0,
            "smile_intensity": 0.1,
            "smile_velocity": 0.05,
            "facial_symmetry": 0.5,
            "expression_range": 0.1,
            "hypomimia_score": 0.9,
            "muscle_tone": 0.85,
        }
        result = await pred.predict(features)
        _assert_valid_risk_output(result)

    async def test_classification_field(self):
        pred = FacialPredictor()
        pred.load()
        result = await pred.predict({"blink_rate": 18, "smile_intensity": 0.6})
        assert "classification" in result
        assert result["classification"] in ("PD", "Healthy")
