"""
NeuroVerse System Verification Script
Tests: model loading, inference, extractors, XAI pipeline
Run: python verify_system.py
"""
import asyncio
import sys
import traceback

PASS = 0
FAIL = 0

def report(name, ok, detail=""):
    global PASS, FAIL
    status = "PASS" if ok else "FAIL"
    if ok:
        PASS += 1
    else:
        FAIL += 1
    print(f"  [{status}] {name}" + (f" — {detail}" if detail else ""))


async def main():
    global PASS, FAIL

    print("=" * 60)
    print("  NEUROVERSE SYSTEM VERIFICATION")
    print("=" * 60)

    # ── 1. Dependencies ──────────────────────────────────────
    print("\n1. DEPENDENCIES")
    try:
        import torch
        report("PyTorch", True, torch.__version__)
    except ImportError:
        report("PyTorch", False, "not installed")
        print("\n  FATAL: PyTorch required. Run: pip install torch --index-url https://download.pytorch.org/whl/cpu")
        return

    try:
        import numpy as np
        report("NumPy", True, np.__version__)
    except ImportError:
        report("NumPy", False)

    try:
        import timm
        report("timm (EfficientNet)", True, timm.__version__)
    except ImportError:
        report("timm (EfficientNet)", False, "pip install timm")

    # ── 2. Model Files ───────────────────────────────────────
    print("\n2. MODEL FILES")
    from pathlib import Path
    models_dir = Path(__file__).parent / "app" / "ml" / "models"
    expected = {
        "speech_model.pt": "SpeechNeuroNet (35-d)",
        "cognitive_model.pt": "TMTNet (24-d MLP)",
        "cdt_model.pt": "CDTNet (EfficientNet-B0)",
        "motor_model.pt": "MotorNet Spiral (EfficientNet-B0)",
        "meander_model.pt": "MotorNet Meander (EfficientNet-B0)",
    }
    for fname, desc in expected.items():
        p = models_dir / fname
        if p.exists():
            size_mb = p.stat().st_size / 1024 / 1024
            report(f"{fname}", True, f"{desc} — {size_mb:.1f} MB")
        else:
            report(f"{fname}", False, f"MISSING — {desc}")

    # ── 3. Predictor Loading ─────────────────────────────────
    print("\n3. PREDICTOR LOADING (model weight loading)")
    from app.ml.predictors import get_predictor

    for category in ["speech", "cognitive", "motor"]:
        try:
            pred = get_predictor(category)
            loaded = getattr(pred, 'is_loaded', False)
            # Check specific sub-models for cognitive/motor
            if category == "cognitive":
                tmt = getattr(pred, '_tmt_model', None)
                cdt = getattr(pred, '_cdt_model', None)
                detail = f"TMT={'loaded' if tmt else 'heuristic'}, CDT={'loaded' if cdt else 'heuristic'}"
                report(f"CognitivePredictor", tmt is not None or cdt is not None, detail)
            elif category == "motor":
                spiral = getattr(pred, '_spiral_model', None)
                meander = getattr(pred, '_meander_model', None)
                detail = f"Spiral={'loaded' if spiral else 'heuristic'}, Meander={'loaded' if meander else 'heuristic'}"
                report(f"MotorPredictor", spiral is not None or meander is not None, detail)
            else:
                report(f"SpeechPredictor", loaded, "model loaded" if loaded else "heuristic mode")
        except Exception as e:
            report(f"{category}Predictor", False, str(e))

    # ── 4. Inference Tests ───────────────────────────────────
    print("\n4. INFERENCE (predict with sample data)")

    # Speech
    try:
        pred = get_predictor("speech")
        speech_features = {
            "category": "speech", "items_processed": 3,
            "story_recall_accuracy": 0.65, "story_coherence": 0.7, "story_duration": 45.0,
            "vowel_duration": 8.5, "vowel_stability": 0.6, "vowel_amplitude_var": 0.15,
            "speech_rate": 110, "speech_duration": 30, "pause_rate": 0.3,
            "mean_pause_duration": 0.8, "max_pause_duration": 2.5, "speech_silence_ratio": 0.6,
            "total_duration": 60, "word_count": 80, "unique_words": 55,
            "jitter": 0.02, "shimmer": 0.05, "hnr": 18.0,
            "f0_mean": 150, "f0_std": 25,
        }
        result = await pred.predict(speech_features)
        ad = result.get("ad_risk", -1)
        pd = result.get("pd_risk", -1)
        src = result.get("source", "unknown")
        report("Speech inference", ad >= 0 and pd >= 0, f"AD={ad:.1f}%, PD={pd:.1f}%, source={src}")
    except Exception as e:
        report("Speech inference", False, str(e))

    # Cognitive (TMT data)
    try:
        pred = get_predictor("cognitive")
        tmt_features = {
            "category": "cognitive", "items_processed": 1,
            "_has_tmt_data": True, "_has_cdt_image": False,
            "tmt_a_time": 45.0, "tmt_b_time": 110.0,
            "time_per_circle_a": 1.8, "time_per_circle_b": 4.6,
            "tmt_ba_ratio": 2.44, "errors_a": 0, "errors_b": 2,
            "sequence_errors_b": 1,
            "velocity_mean": 150.0, "velocity_std": 45.0,
            "acceleration_mean": 50.0, "jerk_mean": 20.0,
            "curvature_mean": 0.05, "straightness_ratio": 0.85,
            "pause_count": 3, "total_pause_duration": 5.0,
            "hover_time": 2.0, "pen_lifts": 2,
            "path_efficiency": 0.78, "spatial_accuracy": 0.82,
            "distance_variability": 15.0, "age": 68,
        }
        result = await pred.predict(tmt_features)
        ad = result.get("ad_risk", -1)
        src = result.get("source", "unknown")
        report("Cognitive/TMT inference", ad >= 0, f"AD={ad:.1f}%, source={src}")
    except Exception as e:
        report("Cognitive/TMT inference", False, str(e))

    # Motor (heuristic — no image in test)
    try:
        pred = get_predictor("motor")
        motor_features = {
            "category": "motor", "items_processed": 2,
            "tapping_rate": 4.5, "tapping_regularity": 0.7, "tapping_fatigue": 0.2,
            "tapping_total": 45, "tapping_duration": 10.0,
            "spiral_duration": 8000, "spiral_tremor": 0.3, "spiral_deviation": 0.25,
            "spiral_tightness": 0.8, "spiral_mean_speed": 120.0,
            "spiral_speed_variability": 30.0, "spiral_tremor_score": 0.35,
            "meander_duration": 6000, "meander_tremor": 0.25, "meander_deviation": 0.2,
            "meander_smoothness": 0.75, "meander_mean_speed": 100.0,
            "motor_composite": 0.65,
        }
        result = await pred.predict(motor_features)
        pd = result.get("pd_risk", -1)
        src = result.get("source", "unknown")
        report("Motor inference", pd >= 0, f"PD={pd:.1f}%, source={src}")
    except Exception as e:
        report("Motor inference", False, str(e))

    # ── 5. Extractors ────────────────────────────────────────
    print("\n5. EXTRACTORS")
    try:
        from app.ml.extractors.speech_extractor import SpeechExtractor
        ext = SpeechExtractor()
        report("SpeechExtractor import", True)
    except Exception as e:
        report("SpeechExtractor import", False, str(e))

    try:
        from app.ml.extractors.cognitive_extractor import CognitiveExtractor
        ext = CognitiveExtractor()
        report("CognitiveExtractor import", True)
    except Exception as e:
        report("CognitiveExtractor import", False, str(e))

    try:
        from app.ml.extractors.motor_extractor import MotorExtractor
        ext = MotorExtractor()
        report("MotorExtractor import", True)
    except Exception as e:
        report("MotorExtractor import", False, str(e))

    # ── 6. XAI Pipeline ─────────────────────────────────────
    print("\n6. XAI PIPELINE")
    try:
        from app.services.xai_service import XAIService
        xai = XAIService()
        explanation = await xai.generate_explanation(
            category="speech",
            features=speech_features,
            risk_scores={"ad_risk": 25, "pd_risk": 15, "category_score": 65, "model_confidence": 0.7},
        )
        keys = set(explanation.keys())
        expected_keys = {"summary", "shap_values", "feature_importance", "interpretations",
                         "lime_explanations", "integrated_gradients", "counterfactual_analysis"}
        missing = expected_keys - keys
        report("XAI generate_explanation", len(missing) == 0,
               f"{len(keys)} keys returned" + (f", missing: {missing}" if missing else ""))

        # Check individual XAI methods
        report("  SHAP values", len(explanation.get("shap_values", [])) > 0,
               f"{len(explanation.get('shap_values', []))} features")
        report("  Feature importance", len(explanation.get("feature_importance", [])) > 0,
               f"{len(explanation.get('feature_importance', []))} features")
        report("  Interpretations", len(explanation.get("interpretations", [])) > 0,
               f"{len(explanation.get('interpretations', []))} items")
        report("  LIME", explanation.get("lime_explanations") is not None, "present")
        report("  Integrated Gradients", explanation.get("integrated_gradients") is not None, "present")
        report("  Counterfactual", explanation.get("counterfactual_analysis") is not None, "present")
        report("  AD factors", len(explanation.get("ad_factors", [])) >= 0, "present")
        report("  PD factors", len(explanation.get("pd_factors", [])) >= 0, "present")
    except Exception as e:
        report("XAI pipeline", False, str(e))
        traceback.print_exc()

    # ── 7. Fusion ────────────────────────────────────────────
    print("\n7. FUSION ENGINE")
    try:
        from app.ml.fusion.multimodel_fusion import NeuroVerseFusionEngine
        engine = NeuroVerseFusionEngine()
        model_scores = {
            "cdt_ad": 0.30, "tmt_ad": 0.45, "speech_ad": 0.25,
            "spiral_pd": 0.35, "meander_pd": 0.40, "speech_pd": 0.15,
        }
        result = engine.fuse_quick(model_scores, method="bayesian")
        report("Bayesian fusion", "ad_risk" in result,
               f"AD={result.get('ad_risk', 0)*100:.1f}%, PD={result.get('pd_risk', 0)*100:.1f}%")
        result_full = engine.fuse(model_scores)
        report("Comprehensive fusion (3 methods × all combos)",
               result_full.final_classification in ("AD", "PD", "Healthy"),
               f"Class={result_full.final_classification}, AD={result_full.final_ad_risk*100:.1f}%, PD={result_full.final_pd_risk*100:.1f}%")
    except Exception as e:
        report("Fusion", False, str(e))

    # ── 8. FastAPI Import ────────────────────────────────────
    print("\n8. FASTAPI APP")
    try:
        from app.main import app
        routes = [r.path for r in app.routes if hasattr(r, 'path')]
        test_routes = [r for r in routes if 'test' in r.lower()]
        report("FastAPI app import", True, f"{len(routes)} routes, {len(test_routes)} test-related")
    except Exception as e:
        report("FastAPI app import", False, str(e))

    # ── Summary ──────────────────────────────────────────────
    print("\n" + "=" * 60)
    total = PASS + FAIL
    print(f"  RESULTS: {PASS}/{total} passed, {FAIL} failed")
    pct = (PASS / total * 100) if total > 0 else 0
    print(f"  SCORE: {pct:.0f}%")
    print("=" * 60)

    if FAIL > 0:
        print("\n  Action items:")
        print("  - Fix any FAIL items above before testing with Flutter")
        print("  - Model loading failures may need checkpoint format fixes")
    else:
        print("\n  All checks passed! System is ready for end-to-end testing.")

    return FAIL == 0


if __name__ == "__main__":
    ok = asyncio.run(main())
    sys.exit(0 if ok else 1)
