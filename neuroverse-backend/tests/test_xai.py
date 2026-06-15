"""
XAI explainer tests:
- SHAP (attention + perturbation)
- LIME (tabular + image)
- Integrated Gradients
- Counterfactual ("what-if" explanations)
- Saliency (image heatmaps + feature bars)
- Tested across all 4 categories: cognitive, speech, motor, facial
"""
import pytest
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from app.ml.xai.shap_explainer import SHAPExplainer
from app.ml.xai.lime_explainer import LIMEExplainer
from app.ml.xai.integrated_gradients import IntegratedGradientsExplainer
from app.ml.xai.counterfactual_explainer import CounterfactualExplainer
from app.ml.xai.saliency_generator import SaliencyGenerator


# ==================== Sample features per category ====================

COGNITIVE_FEATURES = {
    "recall_score": 7,
    "total_words": 10,
    "stroop_interference": 0.4,
    "tmt_a_time": 35,
    "tmt_b_time": 95,
    "cdt_score": 4,
}

SPEECH_FEATURES = {
    "speech_rate": 3.5,
    "pause_rate": 0.15,
    "jitter": 0.012,
    "shimmer": 0.04,
    "hnr": 18.0,
    "f0_mean": 130.0,
    "mfcc_1_mean": -200.0,
    "mfcc_2_mean": 80.0,
}

MOTOR_FEATURES = {
    "tremor_amplitude": 0.3,
    "tremor_frequency": 5.5,
    "spiral_smoothness": 0.7,
    "meander_smoothness": 0.65,
    "spiral_tightness": 0.8,
}

FACIAL_FEATURES = {
    "blink_rate": 18.5,
    "smile_intensity": 0.7,
    "smile_velocity": 0.4,
    "facial_symmetry": 0.85,
    "expression_range": 0.6,
    "hypomimia_score": 0.2,
    "muscle_tone": 0.5,
}

PREDICTIONS = {"ad_risk": 35.0, "pd_risk": 22.0, "confidence": 0.78}

ALL_CATEGORIES = [
    ("cognitive", COGNITIVE_FEATURES),
    ("speech", SPEECH_FEATURES),
    ("motor", MOTOR_FEATURES),
    ("facial", FACIAL_FEATURES),
]


# ==================== SHAP ====================

class TestSHAPExplainer:
    def test_initializes(self):
        assert SHAPExplainer() is not None

    @pytest.mark.parametrize("category,features", ALL_CATEGORIES)
    def test_shap_for_each_category(self, category, features):
        explainer = SHAPExplainer()
        result = explainer.compute_shap_values(features=features, predictions=PREDICTIONS)
        assert isinstance(result, list), f"SHAP must return list for {category}"
        assert len(result) > 0, f"SHAP must return non-empty values for {category}"
        for entry in result:
            assert isinstance(entry, dict)
            assert "feature" in entry or "name" in entry


# ==================== LIME ====================

class TestLIMEExplainer:
    def test_initializes(self):
        assert LIMEExplainer() is not None

    @pytest.mark.parametrize("category,features", ALL_CATEGORIES)
    def test_lime_tabular_for_each_category(self, category, features):
        explainer = LIMEExplainer()
        result = explainer.explain_tabular(features=features, predictions=PREDICTIONS)
        assert result is not None, f"LIME must return result for {category}"
        assert isinstance(result, (dict, list))


# ==================== Integrated Gradients ====================

class TestIntegratedGradientsExplainer:
    def test_initializes(self):
        assert IntegratedGradientsExplainer() is not None

    @pytest.mark.parametrize("category,features", ALL_CATEGORIES)
    def test_ig_for_each_category(self, category, features):
        explainer = IntegratedGradientsExplainer()
        result = explainer.compute_attributions(features=features, predictions=PREDICTIONS)
        assert result is not None, f"IG must return result for {category}"
        assert isinstance(result, (dict, list))


# ==================== Counterfactual ====================

class TestCounterfactualExplainer:
    def test_initializes(self):
        assert CounterfactualExplainer() is not None

    @pytest.mark.parametrize("category,features", ALL_CATEGORIES)
    def test_counterfactual_for_each_category(self, category, features):
        explainer = CounterfactualExplainer()
        result = explainer.generate_counterfactuals(
            features=features, predictions=PREDICTIONS, category=category
        )
        assert result is not None, f"Counterfactual must return result for {category}"
        assert isinstance(result, (dict, list))


# ==================== Saliency ====================

class TestSaliencyGenerator:
    def test_initializes(self):
        assert SaliencyGenerator() is not None

    @pytest.mark.parametrize("category,features", ALL_CATEGORIES)
    def test_saliency_for_each_category(self, category, features):
        gen = SaliencyGenerator()
        result = gen.generate(category=category, features=features, predictions=PREDICTIONS)
        assert result is not None, f"Saliency must return result for {category}"
        assert isinstance(result, dict)


# ==================== Cross-method consistency ====================

class TestXAICoverage:
    """Smoke test: every XAI method should produce output for every category."""

    @pytest.mark.parametrize("category,features", ALL_CATEGORIES)
    def test_all_methods_produce_output_for_category(self, category, features):
        shap_out = SHAPExplainer().compute_shap_values(features, PREDICTIONS)
        lime_out = LIMEExplainer().explain_tabular(features, PREDICTIONS)
        ig_out = IntegratedGradientsExplainer().compute_attributions(features, PREDICTIONS)
        cf_out = CounterfactualExplainer().generate_counterfactuals(features, PREDICTIONS, category=category)
        sal_out = SaliencyGenerator().generate(category=category, features=features, predictions=PREDICTIONS)

        for name, out in [("SHAP", shap_out), ("LIME", lime_out),
                          ("IG", ig_out), ("Counterfactual", cf_out), ("Saliency", sal_out)]:
            assert out is not None, f"{name} returned None for {category}"
