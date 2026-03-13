"""Test the updated NeuroVerse ML pipeline."""
import asyncio
import sys


async def test_pipeline():
    print("=" * 60)
    print("TESTING UPDATED NEUROVERSE ML PIPELINE")
    print("=" * 60)

    errors = []
    passed = 0

    # 1. Test extractor imports (numpy-dependent, no torch needed)
    print("\n[1] Testing extractor imports...")
    try:
        from app.ml.extractors.cognitive_extractor import (
            CognitiveExtractor, TMT_FEATURE_KEYS, APP_COGNITIVE_KEYS,
        )
        print(f"  Cognitive Extractor: OK (TMT={len(TMT_FEATURE_KEYS)} features, App={len(APP_COGNITIVE_KEYS)} features)")
        passed += 1
    except Exception as e:
        errors.append(f"CognitiveExtractor: {e}")
        print(f"  Cognitive Extractor: FAIL - {e}")

    try:
        from app.ml.extractors.motor_extractor import MotorExtractor
        print("  Motor Extractor (spiral+meander+tapping): OK")
        passed += 1
    except Exception as e:
        errors.append(f"MotorExtractor: {e}")
        print(f"  Motor Extractor: FAIL - {e}")

    try:
        from app.ml.extractors.speech_extractor import SpeechExtractor, SPEECH_FEATURE_COLS
        print(f"  Speech Extractor: OK ({len(SPEECH_FEATURE_COLS)} features)")
        passed += 1
    except Exception as e:
        errors.append(f"SpeechExtractor: {e}")
        print(f"  Speech Extractor: FAIL - {e}")

    # 2. Test XAI module imports (no torch/numpy dependency)
    print("\n[2] Testing XAI module imports...")
    try:
        from app.ml.xai import (
            SHAPExplainer, SaliencyGenerator, InterpretationEngine,
            LIMEExplainer, IntegratedGradientsExplainer,
            CounterfactualExplainer, AttentionVisualizer,
        )
        print("  All 7 XAI modules: OK")
        passed += 1
    except Exception as e:
        errors.append(f"XAI import: {e}")
        print(f"  XAI import: FAIL - {e}")

    try:
        from app.services.xai_service import XAIService
        print("  XAI Service: OK")
        passed += 1
    except Exception as e:
        errors.append(f"XAIService: {e}")
        print(f"  XAI Service: FAIL - {e}")

    # 3. Test predictor registry (handles missing torch gracefully)
    print("\n[3] Testing predictor registry (get_predictor)...")
    try:
        from app.ml.predictors import get_predictor
        for cat in ("speech", "cognitive", "motor", "facial", "gait"):
            p = get_predictor(cat)
            print(f"  {cat}: {type(p).__name__} (loaded={getattr(p, 'is_loaded', False)})")
        passed += 1
    except Exception as e:
        errors.append(f"get_predictor: {e}")
        print(f"  get_predictor: FAIL - {e}")

    # 4. Test cognitive TMT feature extraction
    print("\n[4] Testing TMT feature extraction...")
    try:
        from app.ml.extractors.cognitive_extractor import CognitiveExtractor
        ext = CognitiveExtractor()

        # Simulate TMT raw data
        class FakeItem:
            def __init__(self, name, data):
                self.item_name = name
                self.raw_data = data

        tmt_raw = {
            "tmt_a_time": 45, "tmt_b_time": 200,
            "errors_a": 0, "errors_b": 4, "sequence_errors_b": 2,
            "drawing_points": [{"x": i*10, "y": i*5, "t": i*100} for i in range(50)],
            "pen_lifts": 8, "hover_time": 3,
            "path_efficiency": 0.55, "spatial_accuracy": 0.7,
            "distance_variability": 0.3, "age": 72, "education_years": 12,
        }
        items = [FakeItem("tmt", tmt_raw)]
        features = await ext.extract(items)

        print(f"  Extracted {len(features)} features")
        print(f"  TMT data flag: {features.get('_has_tmt_data')}")
        print(f"  TMT-B time: {features.get('tmt_b_time')}s")
        print(f"  Velocity mean: {features.get('velocity_mean', 'N/A')}")
        print(f"  Errors B: {features.get('errors_b')}")
        passed += 1
    except Exception as e:
        errors.append(f"TMT extraction: {e}")
        print(f"  TMT extraction: FAIL - {e}")
        import traceback; traceback.print_exc()

    # 5. Test CDT feature extraction
    print("\n[5] Testing CDT feature extraction...")
    try:
        cdt_raw = {
            "shulman_score": 2, "numbers_correct": 8, "numbers_placed": 12,
            "hands_present": True, "center_deviation": 0.4, "drawing_time_ms": 45000,
        }
        items = [FakeItem("cdt", cdt_raw)]
        features = await ext.extract(items)
        print(f"  Extracted {len(features)} features")
        print(f"  Shulman score: {features.get('shulman_score')}")
        print(f"  Number accuracy: {features.get('number_accuracy', 'N/A')}")
        passed += 1
    except Exception as e:
        errors.append(f"CDT extraction: {e}")
        print(f"  CDT extraction: FAIL - {e}")
        import traceback; traceback.print_exc()

    # 6. Test motor extraction with meander
    print("\n[6] Testing motor extraction (spiral + meander)...")
    try:
        from app.ml.extractors.motor_extractor import MotorExtractor
        motor_ext = MotorExtractor()

        spiral_raw = {
            "duration_ms": 5000, "tremor_detected": True,
            "deviation_score": 0.4, "spiral_tightness": 0.6,
            "drawing_points": [{"x": i*3, "y": i*2, "t": i*50} for i in range(30)],
        }
        meander_raw = {
            "duration_ms": 4000, "tremor_detected": False,
            "deviation_score": 0.2, "smoothness_score": 0.7,
        }

        class FakeItem:
            def __init__(self, name, data):
                self.item_name = name
                self.raw_data = data

        items = [FakeItem("spiral_drawing", spiral_raw), FakeItem("meander_drawing", meander_raw)]
        features = await motor_ext.extract(items)
        print(f"  Extracted {len(features)} features")
        print(f"  Spiral tremor: {features.get('spiral_tremor')}")
        print(f"  Meander duration: {features.get('meander_duration')}s")
        print(f"  Meander smoothness: {features.get('meander_smoothness')}")
        print(f"  Motor composite: {features.get('motor_composite', 'N/A')}")
        passed += 1
    except Exception as e:
        errors.append(f"Motor extraction: {e}")
        print(f"  Motor extraction: FAIL - {e}")
        import traceback; traceback.print_exc()

    # 7. Test predictor via get_predictor (heuristic mode)
    print("\n[7] Testing predictions via get_predictor (heuristic mode)...")
    try:
        from app.ml.predictors import get_predictor

        # Speech prediction
        sp = get_predictor("speech")
        sr = await sp.predict({
            "speech_rate": 85, "pause_count": 18, "jitter": 0.03,
            "shimmer": 0.06, "story_recall_accuracy": 0.35,
        })
        print(f"  Speech: AD={sr['ad_risk']}% PD={sr['pd_risk']}%")

        # Cognitive prediction
        cp = get_predictor("cognitive")
        cr = await cp.predict({
            "stroop_accuracy": 0.55, "nback_accuracy": 0.45,
            "recall_accuracy": 0.35, "processing_speed_ms": 1600,
        })
        print(f"  Cognitive: AD={cr['ad_risk']}% stage={cr.get('stage', 'N/A')}")

        # Motor prediction
        mp = get_predictor("motor")
        mr = await mp.predict({
            "tapping_rate": 2.5, "tapping_regularity": 0.35,
            "tapping_fatigue": 0.6, "spiral_tremor": 0.7,
            "meander_tremor": 0.6,
        })
        print(f"  Motor: PD={mr['pd_risk']}% class={mr.get('classification', 'N/A')}")
        passed += 1
    except Exception as e:
        errors.append(f"Predictions: {e}")
        print(f"  Predictions: FAIL - {e}")
        import traceback; traceback.print_exc()

    # 8. Test full XAI pipeline
    print("\n[8] Testing full XAI pipeline (cognitive with TMT data)...")
    try:
        from app.services.xai_service import XAIService
        xai = XAIService()

        tmt_features = {
            "_has_tmt_data": True, "items_processed": 1,
            "tmt_a_time": 45, "tmt_b_time": 200,
            "errors_b": 4, "path_efficiency": 0.5,
            "pen_lifts": 12, "velocity_mean": 80,
            "age": 72, "education_years": 12,
        }
        risk_scores = {"ad_risk": 65, "pd_risk": 12, "category_score": 35}
        predictions = {"ad_risk": 65, "pd_risk": 12, "confidence": 0.45, "source": "tmt_heuristic"}

        explanation = await xai.generate_explanation("cognitive", tmt_features, risk_scores, predictions)

        print(f"  Summary: {explanation['summary'][:80]}...")
        print(f"  SHAP values: {len(explanation['shap_values'])} features")
        print(f"  Feature importance: {len(explanation['feature_importance'])} features")
        print(f"  Interpretations: {len(explanation['interpretations'])} items")
        print(f"  Saliency type: {explanation.get('saliency_data', {}).get('type') if explanation.get('saliency_data') else 'N/A'}")
        print(f"  LIME explanations: {len(explanation.get('lime_explanations', []))} features")
        print(f"  IG attributions: {len(explanation.get('integrated_gradients', []))} features")
        cf = explanation.get("counterfactual_analysis", {})
        print(f"  Counterfactuals: {len(cf.get('counterfactuals', []))} scenarios")
        print(f"  Actionable insights: {len(cf.get('actionable_insights', []))} items")
        print(f"  AD factors: {len(explanation['ad_factors'])}, PD factors: {len(explanation['pd_factors'])}")
        passed += 1
    except Exception as e:
        errors.append(f"XAI cognitive: {e}")
        print(f"  XAI cognitive: FAIL - {e}")
        import traceback; traceback.print_exc()

    # 9. Test XAI with speech attention
    print("\n[9] Testing XAI with speech + attention weights...")
    try:
        speech_features = {
            "speech_rate": 85, "pause_count": 18, "pause_rate": 0.6,
            "jitter": 0.03, "shimmer": 0.06,
            "story_recall_accuracy": 0.35, "vowel_stability": 0.25,
            "items_processed": 3,
        }
        speech_preds = {
            "ad_risk": 55, "pd_risk": 30, "confidence": 0.45,
            "attention_weights": {
                "speech_rate": 0.8, "pause_count": 0.7, "jitter": 0.6,
                "shimmer": 0.5, "story_recall_accuracy": 0.9,
            },
        }
        speech_risk = {"ad_risk": 55, "pd_risk": 30, "category_score": 30}

        explanation = await xai.generate_explanation("speech", speech_features, speech_risk, speech_preds)
        attn = explanation.get("attention_analysis")
        if attn:
            print(f"  Attention type: {attn.get('type')}")
            print(f"  Top feature: {attn['statistics']['top_feature']}")
            print(f"  Feature groups: {list(attn.get('groups', {}).keys())}")
        print(f"  Attention summary: {explanation.get('attention_summary', {}).get('narrative', 'N/A')[:80]}...")
        passed += 1
    except Exception as e:
        errors.append(f"Speech XAI: {e}")
        print(f"  Speech XAI: FAIL - {e}")
        import traceback; traceback.print_exc()

    # 10. Test counterfactual with motor data
    print("\n[10] Testing counterfactual analysis (motor)...")
    try:
        motor_features = {
            "tapping_rate": 2.5, "tapping_regularity": 0.35,
            "tapping_fatigue": 0.6, "spiral_tremor": 0.7,
            "meander_tremor": 0.6, "items_processed": 2,
        }
        motor_risk = {"ad_risk": 5, "pd_risk": 75, "category_score": 25}
        motor_preds = {"ad_risk": 5, "pd_risk": 75, "confidence": 0.45}

        explanation = await xai.generate_explanation("motor", motor_features, motor_risk, motor_preds)
        cf = explanation.get("counterfactual_analysis", {})
        print(f"  Counterfactuals: {len(cf.get('counterfactuals', []))} scenarios")
        for c in cf.get("counterfactuals", [])[:3]:
            print(f"    - {c['description']} (est. -{c['estimated_risk_reduction']:.0f}% risk)")
        print(f"  Actionable: {len(cf.get('actionable_insights', []))} items")
        for a in cf.get("actionable_insights", [])[:2]:
            print(f"    - [{a['priority']}] {a['feature']}: {a['recommendation'][:60]}...")
        passed += 1
    except Exception as e:
        errors.append(f"Motor counterfactual: {e}")
        print(f"  Motor counterfactual: FAIL - {e}")
        import traceback; traceback.print_exc()

    # Summary
    print("\n" + "=" * 60)
    total = passed + len(errors)
    if errors:
        print(f"RESULTS: {passed}/{total} PASSED, {len(errors)} FAILED")
        for e in errors:
            print(f"  FAIL: {e}")
    else:
        print(f"ALL {total} TESTS PASSED")
    print("=" * 60)

    return len(errors) == 0


if __name__ == "__main__":
    success = asyncio.run(test_pipeline())
    sys.exit(0 if success else 1)
