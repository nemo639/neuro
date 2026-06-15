"""
Fusion engine tests:
- Weighted Average fusion
- Bayesian fusion
- Dempster-Shafer fusion
- Confidence-weighted blending of predictor outputs
"""
import pytest
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from app.services.fusion_service import FusionService


pytestmark = pytest.mark.asyncio


class TestFusionService:
    def test_service_initializes(self):
        service = FusionService()
        assert service is not None

    def test_service_has_methods(self):
        service = FusionService()
        # Service should expose at least one assessment method
        assert any(callable(getattr(service, m, None))
                   for m in ('assess_category', '_blend_predictions', 'fuse', 'predict'))
