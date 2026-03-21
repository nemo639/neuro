"""
Cognitive Predictor – loads TMTNet (tabular) and CDTNet (image) models.

TMTNet architecture (from cognitive_tmt_training_Final notebook):
  - MLP: 24→128 (residual)→64→32→3 classes (Normal/MCI/AD)
  Input: 24 TMT kinematic features (timing, errors, kinematics, pen dynamics, path quality, demographics)

CDTNet architecture (from cognitive_cdt_training notebook):
  - EfficientNet-B0 backbone → 1280-d → 512→128→6 classes (Shulman 0-5)
  - AD risk head: 6→32→1 (sigmoid)
  Input: 3×224×224 clock drawing image

For app-based cognitive tests (Stroop, N-Back, Word Recall) we use a
feature-based approach with the app-cognitive MLP or heuristic scoring.
"""

import logging
from typing import Any, Dict, Optional

import numpy as np
import torch
import torch.nn as nn

from app.ml.predictors.base_predictor import BasePredictor
from app.ml.extractors.cognitive_extractor import (
    TMT_FEATURE_KEYS, APP_COGNITIVE_KEYS, CognitiveExtractor,
)
from app.ml.extractors.phone_image_adapter import calibrate_phone_risk

logger = logging.getLogger(__name__)


# ------------------------------------------------------------------ #
# TMTNet architecture (exact from cognitive_tmt_training_Final)        #
# ------------------------------------------------------------------ #

class _ResBlock(nn.Module):
    def __init__(self, dim: int, dropout: float = 0.3):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(dim, dim),
            nn.BatchNorm1d(dim),
            nn.GELU(),
            nn.Dropout(dropout),
            nn.Linear(dim, dim),
            nn.BatchNorm1d(dim),
        )
        self.activation = nn.GELU()

    def forward(self, x):
        return self.activation(self.net(x) + x)


class TMTNet(nn.Module):
    """Trail-Making-Test classifier: Normal / MCI / AD.

    Trained on 20 engineered features from ADNI+NACC dataset.
    """

    def __init__(
        self,
        input_dim: int = 20,
        hidden_dims: list = None,
        n_classes: int = 3,
        dropout: float = 0.3,
    ):
        super().__init__()
        self.input_dim = input_dim
        self.n_classes = n_classes
        if hidden_dims is None:
            hidden_dims = [256, 128, 64]

        self.input_layer = nn.Sequential(
            nn.Linear(input_dim, hidden_dims[0]),
            nn.BatchNorm1d(hidden_dims[0]),
            nn.GELU(),
            nn.Dropout(dropout),
        )
        self.res_block = _ResBlock(hidden_dims[0], dropout)

        layers = []
        for i in range(len(hidden_dims) - 1):
            layers += [
                nn.Linear(hidden_dims[i], hidden_dims[i + 1]),
                nn.BatchNorm1d(hidden_dims[i + 1]),
                nn.GELU(),
                nn.Dropout(dropout),
            ]
        self.hidden = nn.Sequential(*layers)
        self.output = nn.Linear(hidden_dims[-1], n_classes)
        self.features_out = None

    def forward(self, x):
        h = self.input_layer(x)
        h = self.res_block(h)
        h = self.hidden(h)
        self.features_out = h
        return self.output(h)  # logits (no softmax)


# ------------------------------------------------------------------ #
# AppCognitiveNet – for Stroop/N-Back/Word Recall features             #
# ------------------------------------------------------------------ #

class AppCognitiveNet(nn.Module):
    """MLP for app-based cognitive tests (Stroop, N-Back, Word Recall).

    Same architecture pattern as TMTNet but with 18 input features.
    """

    def __init__(self, input_dim: int = 18, n_classes: int = 3, dropout: float = 0.3):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(input_dim, 128),
            nn.BatchNorm1d(128),
            nn.GELU(),
            nn.Dropout(dropout),
            nn.Linear(128, 64),
            nn.BatchNorm1d(64),
            nn.GELU(),
            nn.Dropout(dropout),
            nn.Linear(64, 32),
            nn.BatchNorm1d(32),
            nn.GELU(),
            nn.Linear(32, n_classes),
        )

    def forward(self, x):
        return self.net(x)


# ------------------------------------------------------------------ #
# CDTNet architecture (exact from cognitive_cdt_training notebook)     #
# ------------------------------------------------------------------ #

class CDTNet(nn.Module):
    """Clock Drawing Test classifier using EfficientNet-B0 (timm).

    6-class Shulman scoring (0-5) + AD risk regression head.
    """

    def __init__(self, num_classes: int = 6, pretrained: bool = False, dropout: float = 0.3):
        super().__init__()
        import timm
        self.backbone = timm.create_model(
            "efficientnet_b0", pretrained=pretrained, num_classes=0,
        )
        in_features = self.backbone.num_features  # 1280

        self.classifier = nn.Sequential(
            nn.Dropout(dropout),
            nn.Linear(in_features, 512),
            nn.ReLU(),
            nn.BatchNorm1d(512),
            nn.Dropout(dropout * 0.67),
            nn.Linear(512, 128),
            nn.ReLU(),
            nn.BatchNorm1d(128),
            nn.Linear(128, num_classes),
        )
        self.risk_head = nn.Sequential(
            nn.Linear(num_classes, 32),
            nn.ReLU(),
            nn.Linear(32, 1),
            nn.Sigmoid(),
        )

    def forward(self, x):
        features = self.backbone(x)  # (B, 1280)
        logits = self.classifier(features)  # (B, 6)
        risk = self.risk_head(logits).squeeze(-1)  # (B,)
        return {"logits": logits, "risk": risk, "features": features}


# ------------------------------------------------------------------ #
# Predictor                                                           #
# ------------------------------------------------------------------ #

SHULMAN_LABELS = ["0 - Severe", "1 - Major errors", "2 - Moderate errors",
                  "3 - Minor spatial", "4 - Minor errors", "5 - Perfect"]


class CognitivePredictor(BasePredictor):
    model_filename = "cognitive_model.pt"

    def __init__(self):
        super().__init__()
        self._tmt_model = None
        self._cdt_model = None
        self._tmt_loaded = False
        self._cdt_loaded = False

    def _build_model(self) -> nn.Module:
        return TMTNet(input_dim=20, hidden_dims=[256, 128, 64], n_classes=3)

    def load(self) -> bool:
        """Load TMT and CDT models separately."""
        from app.ml.predictors.base_predictor import MODELS_DIR, torch_available, _import_torch

        if not torch_available():
            logger.warning("PyTorch not installed – CognitivePredictor will use heuristic fallback.")
            return False

        torch_mod = _import_torch()

        # Load TMT model
        tmt_path = MODELS_DIR / "cognitive_model.pt"
        if tmt_path.exists() and tmt_path.stat().st_size > 0:
            try:
                self._tmt_model = TMTNet(input_dim=20, hidden_dims=[256, 128, 64], n_classes=3)
                ckpt = torch_mod.load(tmt_path, map_location=self._device, weights_only=False)
                state = ckpt.get("model_state_dict", ckpt.get("state_dict", ckpt))
                self._tmt_model.load_state_dict(state)
                self._tmt_model.to(self._device)
                self._tmt_model.eval()
                self._tmt_loaded = True
                logger.info("Loaded TMT model (cognitive_model.pt)")
            except Exception as exc:
                logger.warning("Failed to load TMT model: %s", exc)

        # Load CDT model
        cdt_path = MODELS_DIR / "cdt_model.pt"
        if cdt_path.exists() and cdt_path.stat().st_size > 0:
            try:
                self._cdt_model = CDTNet(num_classes=6, pretrained=False)
                ckpt = torch_mod.load(cdt_path, map_location=self._device, weights_only=False)
                state = ckpt.get("model_state_dict", ckpt.get("state_dict", ckpt))
                self._cdt_model.load_state_dict(state)
                self._cdt_model.to(self._device)
                self._cdt_model.eval()
                self._cdt_loaded = True
                logger.info("Loaded CDT model (cdt_model.pt)")
            except Exception as exc:
                logger.warning("Failed to load CDT model: %s", exc)

        self._loaded = self._tmt_loaded or self._cdt_loaded
        return self._loaded

    async def predict(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """
        Route prediction based on available data:
          1. CDT image → CDTNet (if image present)
          2. TMT kinematic data → TMTNet (if TMT features present)
          3. App-based Stroop/N-Back/Word Recall → heuristic scoring
        """
        results: Dict[str, Any] = {}

        # Try CDT image prediction
        if features.get("_has_cdt_image"):
            cdt_result = await self._predict_cdt(features)
            if cdt_result:
                results.update(cdt_result)
                results["source"] = "cdt_model" if self._cdt_loaded else "cdt_heuristic"

        # Try TMT prediction
        if features.get("_has_tmt_data"):
            tmt_result = await self._predict_tmt(features)
            if tmt_result:
                if results:
                    # Merge CDT + TMT results (average risks)
                    results["ad_risk"] = round((results["ad_risk"] + tmt_result["ad_risk"]) / 2, 2)
                    results["confidence"] = round(max(results["confidence"], tmt_result["confidence"]), 3)
                    results["tmt_stage"] = tmt_result.get("stage")
                else:
                    results.update(tmt_result)
                    results["source"] = "tmt_model" if self._tmt_loaded else "tmt_heuristic"

        # Fallback to app-based heuristic
        if not results:
            ad_risk, confidence, stage = self._heuristic_fallback(features)
            results = {
                "ad_risk": round(ad_risk, 2),
                "pd_risk": round(min(ad_risk * 0.1, 15.0), 2),
                "confidence": confidence,
                "stage": stage,
                "source": "app_heuristic",
            }

        # Ensure required keys
        results.setdefault("pd_risk", round(min(results.get("ad_risk", 0) * 0.1, 15.0), 2))
        results.setdefault("confidence", 0.45)
        results.setdefault("stage", "Normal")

        # Attach model + tensor for XAI (prefer CDT image model for GradCAM)
        if self._cdt_loaded and self._cdt_model is not None and features.get("_has_cdt_image"):
            b64 = features.get("clock_image_base64")
            if b64:
                img = CognitiveExtractor.decode_cdt_image(b64)
                if img is not None:
                    preprocessed = CognitiveExtractor.preprocess_cdt_image(img)
                    results["_xai_model"] = self._cdt_model
                    results["_xai_tensor"] = self._to_tensor(preprocessed)
        elif self._tmt_loaded and self._tmt_model is not None and features.get("_has_tmt_data"):
            vec = CognitiveExtractor.build_tmt_feature_vector(features)
            results["_xai_model"] = self._tmt_model
            results["_xai_tensor"] = self._to_tensor(vec)

        return results

    # ------------------------------------------------------------------ #
    # CDT image prediction                                                #
    # ------------------------------------------------------------------ #
    async def _predict_cdt(self, features: dict) -> Optional[Dict[str, Any]]:
        b64 = features.get("clock_image_base64")
        if not b64:
            return self._cdt_heuristic(features)

        img = CognitiveExtractor.decode_cdt_image(b64)
        if img is None:
            return self._cdt_heuristic(features)

        preprocessed = CognitiveExtractor.preprocess_cdt_image(img)
        tensor = self._to_tensor(preprocessed)

        if self._cdt_loaded and self._cdt_model is not None:
            with torch.no_grad():
                out = self._cdt_model(tensor)
            logits = out["logits"].squeeze(0)
            raw_risk = float(out["risk"].item()) * 100
            probs = torch.softmax(logits, dim=-1)
            shulman_class = int(probs.argmax().item())
            confidence = float(probs.max().item())

            # Phone calibration: model trained on paper scans overestimates
            # risk for phone finger drawings (thick strokes, low circle quality)
            ad_risk = calibrate_phone_risk(raw_risk, modality="cdt", confidence=confidence)
            logger.info("CDT model: raw_risk=%.1f%%, calibrated=%.1f%% (shulman=%d, conf=%.3f)",
                       raw_risk, ad_risk, shulman_class, confidence)

            # Also calibrate Shulman interpretation for phone:
            # Phone drawings look worse → model may predict lower Shulman
            # A phone Shulman 3 (minor spatial) is likely 4-5 on paper
            phone_shulman = min(shulman_class + 1, 5) if shulman_class >= 2 else shulman_class

            return {
                "ad_risk": round(ad_risk, 2),
                "confidence": round(confidence, 3),
                "shulman_score": phone_shulman,
                "shulman_label": SHULMAN_LABELS[phone_shulman],
                "raw_model_risk": round(raw_risk, 2),
                "class_probabilities": {
                    SHULMAN_LABELS[i]: round(float(probs[i].item()), 3)
                    for i in range(6)
                },
                "stage": "AD" if phone_shulman <= 1 else "MCI" if phone_shulman <= 3 else "Normal",
            }

        return self._cdt_heuristic(features)

    @staticmethod
    def _cdt_heuristic(features: dict) -> Dict[str, Any]:
        """Heuristic CDT scoring from pre-scored features.

        Phone-aware thresholds:
        - circle_quality >= 30 is HEALTHY on phone (finger on glass is imprecise)
        - Fewer numbers_correct is expected (small screen, finger precision)
        - More strokes are normal (finger lifts vs continuous pen)
        """
        ad_risk = 5.0  # Lower baseline for phone

        # Circle quality: phone-specific thresholds
        # Paper: 80+ normal. Phone: 30+ normal (finger imprecision)
        circle_quality = features.get("clock_contour", 1.0)
        if isinstance(circle_quality, (int, float)) and circle_quality > 1:
            # circle_quality is 0-100 scale from Flutter
            if circle_quality < 15:
                ad_risk += 15  # Very poor even for phone
            elif circle_quality < 30:
                ad_risk += 5   # Below phone-normal but not alarming
            # >= 30 is healthy on phone — no penalty

        numbers_correct = features.get("numbers_correct", 12)
        if numbers_correct < 6:
            ad_risk += 20  # Severe — even on phone, should get 6+
        elif numbers_correct < 8:
            ad_risk += 10  # Mild concern
        # 8+ is fine for phone (small screen makes precision harder)

        if not features.get("hands_present", True):
            ad_risk += 15  # Still meaningful but lower weight

        center_dev = features.get("center_deviation", 0)
        if center_dev > 0.5:  # Relaxed from 0.3 (phone is less precise)
            ad_risk += 5

        shulman = features.get("shulman_score", 5)
        if shulman <= 1:
            ad_risk += 20
        elif shulman <= 2:
            ad_risk += 8

        ad_risk = min(max(ad_risk, 0), 100)
        stage = "AD" if ad_risk > 70 else "MCI" if ad_risk > 40 else "Normal"
        return {
            "ad_risk": round(ad_risk, 2),
            "confidence": 0.40,
            "stage": stage,
            "shulman_score": int(shulman),
        }

    # ------------------------------------------------------------------ #
    # TMT tabular prediction                                              #
    # ------------------------------------------------------------------ #
    async def _predict_tmt(self, features: dict) -> Optional[Dict[str, Any]]:
        tmt_a = float(features.get("tmt_a_time", 0))
        tmt_b = float(features.get("tmt_b_time", 0))
        errors_a = float(features.get("errors_a", 0))
        errors_b = float(features.get("errors_b", 0))

        # ---- App performance sanity check ----
        # TMT model was trained on clinical data (elderly, 60-300s per part).
        # App users (young, healthy) complete in 15-45s — totally out of
        # distribution.  Fast + accurate = definitionally healthy.
        # Override the model when performance is clearly normal.
        is_clearly_healthy = (
            tmt_a > 0 and tmt_b > 0
            and tmt_a < 50 and tmt_b < 70      # fast completion
            and errors_a <= 1 and errors_b <= 2  # very few errors
        )

        vec = CognitiveExtractor.build_tmt_feature_vector(features)
        tensor = self._to_tensor(vec)

        if self._tmt_loaded and self._tmt_model is not None:
            with torch.no_grad():
                logits = self._tmt_model(tensor)
            probs = torch.softmax(logits, dim=-1).squeeze(0)
            ad_prob = float(probs[0].item())
            mci_prob = float(probs[1].item())
            normal_prob = float(probs[2].item())

            raw_risk = ad_prob * 100 + mci_prob * 40
            raw_risk = min(raw_risk, 100.0)
            confidence = float(probs.max().item())

            # If clearly healthy performance, override model confusion
            if is_clearly_healthy:
                logger.info(
                    "TMT override: fast+accurate (A=%.1fs, B=%.1fs, err=%d+%d) "
                    "→ model gave %.1f%%, overriding to healthy",
                    tmt_a, tmt_b, errors_a, errors_b, raw_risk,
                )
                return {
                    "ad_risk": round(min(raw_risk * 0.15, 8.0), 2),  # Cap at 8%
                    "confidence": 0.75,  # High confidence in override
                    "stage": "Normal",
                    "raw_model_risk": round(raw_risk, 2),
                    "override_reason": "fast_accurate_performance",
                    "class_probabilities": {
                        "AD": round(ad_prob, 3),
                        "MCI": round(mci_prob, 3),
                        "Normal": round(normal_prob, 3),
                    },
                }

            # For non-obvious cases, apply moderate calibration
            # TMT model (63% acc) is the weakest — discount its predictions
            calibrated_risk = calibrate_phone_risk(raw_risk, modality="cdt", confidence=confidence)
            logger.info("TMT model: raw=%.1f%%, calibrated=%.1f%% (conf=%.3f)",
                       raw_risk, calibrated_risk, confidence)

            stage = "Normal"
            if ad_prob > mci_prob and ad_prob > normal_prob:
                stage = "AD"
            elif mci_prob > normal_prob:
                stage = "MCI"

            return {
                "ad_risk": round(calibrated_risk, 2),
                "confidence": round(confidence, 3),
                "stage": stage,
                "raw_model_risk": round(raw_risk, 2),
                "class_probabilities": {
                    "AD": round(ad_prob, 3),
                    "MCI": round(mci_prob, 3),
                    "Normal": round(normal_prob, 3),
                },
            }

        return self._tmt_heuristic(features)

    @staticmethod
    def _tmt_heuristic(features: dict) -> Dict[str, Any]:
        """Heuristic TMT scoring from kinematic features (phone-aware)."""
        tmt_a = features.get("tmt_a_time", 0)
        tmt_b = features.get("tmt_b_time", 0)

        # Fast + accurate = healthy, don't penalize
        errors_a = features.get("errors_a", 0)
        errors_b = features.get("errors_b", 0)
        if tmt_a > 0 and tmt_b > 0 and tmt_a < 50 and tmt_b < 70 and errors_a <= 1 and errors_b <= 2:
            return {
                "ad_risk": 3.0,
                "confidence": 0.50,
                "stage": "Normal",
            }

        ad_risk = 5.0  # Lower baseline

        # TMT-B time: >300s is concerning for AD
        if tmt_b > 300:
            ad_risk += 25
        elif tmt_b > 180:
            ad_risk += 15
        elif tmt_b > 120:
            ad_risk += 5

        # B/A ratio: use floored value (min 1.5) to avoid phone artifact
        if tmt_a > 0 and tmt_b > 0:
            ba_ratio = max(tmt_b / tmt_a, 1.5)
            if ba_ratio > 4.0:
                ad_risk += 20
            elif ba_ratio > 3.0:
                ad_risk += 10

        # Errors
        errors_b = features.get("errors_b", 0)
        if errors_b > 5:
            ad_risk += 15
        elif errors_b > 2:
            ad_risk += 8

        # Path efficiency: low = more wandering
        path_eff = features.get("path_efficiency", 0.8)
        if path_eff < 0.4:
            ad_risk += 12
        elif path_eff < 0.6:
            ad_risk += 5

        # Pen lifts: excessive = hesitation
        pen_lifts = features.get("pen_lifts", 0)
        if pen_lifts > 20:
            ad_risk += 8

        ad_risk = min(max(ad_risk, 0), 100)
        stage = "AD" if ad_risk > 70 else "MCI" if ad_risk > 40 else "Normal"
        return {
            "ad_risk": round(ad_risk, 2),
            "confidence": 0.42,
            "stage": stage,
        }

    # ------------------------------------------------------------------ #
    # App-based heuristic (Stroop, N-Back, Word Recall)                   #
    # ------------------------------------------------------------------ #
    @staticmethod
    def _heuristic_fallback(features: dict):
        """Clinically-grounded heuristic scoring for app-based tests.

        Only penalises tests that were actually taken (value > 0).
        Defaults are neutral (no risk contribution) so untested domains
        do not artificially inflate the risk score.
        """
        ad_risk = 5.0  # low baseline
        tests_evaluated = 0

        # Stroop — only score if actually taken
        stroop_acc = features.get("stroop_accuracy", 0)
        if stroop_acc > 0:
            tests_evaluated += 1
            if stroop_acc < 0.6:
                ad_risk += 25
            elif stroop_acc < 0.75:
                ad_risk += 12

            interference = features.get("stroop_interference", 0)
            if interference > 300:  # ms
                ad_risk += 10

        # N-Back — only score if actually taken
        nback_acc = features.get("nback_accuracy", 0)
        if nback_acc > 0:
            tests_evaluated += 1
            if nback_acc < 0.5:
                ad_risk += 20
            elif nback_acc < 0.65:
                ad_risk += 10

            dprime = features.get("nback_dprime", 0)
            if 0 < dprime < 0.5:
                ad_risk += 12

        # Word Recall — only score if actually taken
        recall_acc = features.get("recall_accuracy", 0)
        if recall_acc > 0:
            tests_evaluated += 1
            if recall_acc < 0.4:
                ad_risk += 25
            elif recall_acc < 0.6:
                ad_risk += 12

            intrusions = features.get("recall_intrusions", 0)
            if intrusions > 3:
                ad_risk += 8

        # Processing speed — only if measured
        ps = features.get("processing_speed_ms", 0)
        if ps > 1500:
            ad_risk += 10
        elif ps > 1200:
            ad_risk += 5

        # If no tests were evaluated, return low-confidence neutral
        if tests_evaluated == 0:
            return 5.0, 0.20, "Normal"

        ad_risk = min(max(ad_risk, 0.0), 100.0)
        stage = "Normal"
        if ad_risk > 60:
            stage = "AD"
        elif ad_risk > 35:
            stage = "MCI"

        return ad_risk, 0.45, stage
