"""
ML feature extractor tests:
- Speech extractor (35-d acoustic features)
- Cognitive extractor (TMT 24 kinematic + CDT image + Recall + Stroop)
- Motor extractor (spiral + meander + tremor)
- Facial extractor (42 features: AU + smile + eye + symmetry)
"""
import pytest
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from app.ml.extractors.cognitive_extractor import CognitiveExtractor
from app.ml.extractors.motor_extractor import MotorExtractor
from app.ml.extractors.speech_extractor import SpeechExtractor
from app.ml.extractors.facial_extractor import FacialExtractor


pytestmark = pytest.mark.asyncio


class _MockItem:
    """Mock TestSessionItem for extractor testing."""
    def __init__(self, item_name, payload=None, file_path=None, value=None):
        self.item_name = item_name
        self.payload = payload or {}
        self.file_path = file_path
        self.value = value


class TestCognitiveExtractor:
    async def test_extractor_initializes(self):
        ext = CognitiveExtractor()
        assert ext.category == "cognitive"

    async def test_extracts_empty_items(self):
        ext = CognitiveExtractor()
        features = await ext.extract([])
        assert isinstance(features, dict)

    async def test_extracts_recall_score(self):
        ext = CognitiveExtractor()
        items = [_MockItem("recall_immediate", payload={"recall_score": 8, "total_words": 10})]
        features = await ext.extract(items)
        assert isinstance(features, dict)

    async def test_extracts_stroop(self):
        ext = CognitiveExtractor()
        items = [_MockItem("stroop", payload={
            "congruent_time": 1.2,
            "incongruent_time": 1.8,
            "errors": 2,
        })]
        features = await ext.extract(items)
        assert isinstance(features, dict)

    async def test_extracts_tmt(self):
        ext = CognitiveExtractor()
        items = [_MockItem("tmt_a", payload={"completion_time": 35.5, "errors": 0})]
        features = await ext.extract(items)
        assert isinstance(features, dict)


class TestMotorExtractor:
    async def test_extractor_initializes(self):
        ext = MotorExtractor()
        assert ext.category == "motor"

    async def test_extracts_empty_items(self):
        ext = MotorExtractor()
        features = await ext.extract([])
        assert isinstance(features, dict)

    async def test_extracts_resting_tremor(self):
        ext = MotorExtractor()
        items = [_MockItem("resting_tremor", payload={
            "accelerometer_data": [[0.1, 0.2, 0.05]] * 100,
        })]
        features = await ext.extract(items)
        assert isinstance(features, dict)


class TestSpeechExtractor:
    async def test_extractor_initializes(self):
        ext = SpeechExtractor()
        assert ext.category == "speech"

    async def test_extracts_empty_items(self):
        ext = SpeechExtractor()
        features = await ext.extract([])
        assert isinstance(features, dict)


class TestFacialExtractor:
    async def test_extractor_initializes(self):
        ext = FacialExtractor()
        assert ext.category == "facial"

    async def test_extracts_empty_items(self):
        ext = FacialExtractor()
        features = await ext.extract([])
        assert isinstance(features, dict)

    async def test_extracts_facial_metrics(self):
        ext = FacialExtractor()
        items = [_MockItem("smile_video", payload={
            "blink_rate": 18.5,
            "smile_intensity": 0.7,
            "smile_velocity": 0.4,
            "facial_symmetry": 0.85,
        })]
        features = await ext.extract(items)
        assert isinstance(features, dict)
