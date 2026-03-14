"""
Speech Predictor – loads SpeechNeuroNet and runs AD/PD risk inference.

Model architecture (from speech_model_training_Final.ipynb):
  - Input: 35-d acoustic feature vector
  - Shared encoder: ResidualBlocks [512→256→128]
  - AD head: 128→64→32→1 (sigmoid)
  - PD head: 128→64→32→1 (sigmoid)
  - Feature attention: 35→35 (sigmoid)

Checkpoint key: "model_state_dict"
"""

import logging
from typing import Any, Dict

import numpy as np
import torch
import torch.nn as nn

from app.ml.predictors.base_predictor import BasePredictor
from app.ml.extractors.speech_extractor import SPEECH_FEATURE_COLS, SpeechExtractor

logger = logging.getLogger(__name__)


# ------------------------------------------------------------------ #
# Model architecture (exact copy from training notebook)              #
# ------------------------------------------------------------------ #

class ResidualBlock(nn.Module):
    """Residual block with optional down-projection."""

    def __init__(self, in_dim: int, out_dim: int, dropout: float = 0.3):
        super().__init__()
        self.block = nn.Sequential(
            nn.Linear(in_dim, out_dim),
            nn.BatchNorm1d(out_dim),
            nn.GELU(),
            nn.Dropout(dropout),
            nn.Linear(out_dim, out_dim),
            nn.BatchNorm1d(out_dim),
        )
        self.shortcut = nn.Linear(in_dim, out_dim) if in_dim != out_dim else nn.Identity()
        self.activation = nn.GELU()

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.activation(self.block(x) + self.shortcut(x))


class SpeechNeuroNet(nn.Module):
    """Dual-head speech model for simultaneous AD & PD risk estimation."""

    def __init__(
        self,
        input_dim: int = 35,
        hidden_dims: list = None,
        head_dim: int = 64,
        dropout: float = 0.3,
    ):
        super().__init__()
        if hidden_dims is None:
            hidden_dims = [512, 256, 128]

        # Feature attention
        self.feature_attention = nn.Sequential(
            nn.Linear(input_dim, input_dim),
            nn.Sigmoid(),
        )

        # Input projection (Linear + BatchNorm + GELU + Dropout)
        self.input_proj = nn.Sequential(
            nn.Linear(input_dim, hidden_dims[0]),
            nn.BatchNorm1d(hidden_dims[0]),
            nn.GELU(),
            nn.Dropout(dropout),
        )

        # Shared encoder
        encoder_layers = []
        for i in range(len(hidden_dims) - 1):
            encoder_layers.append(ResidualBlock(hidden_dims[i], hidden_dims[i + 1], dropout))
        self.shared_encoder = nn.Sequential(*encoder_layers)

        enc_out = hidden_dims[-1]

        # AD head: Linear→BN→GELU→Dropout→Linear→Sigmoid
        self.ad_head = nn.Sequential(
            nn.Linear(enc_out, head_dim),
            nn.BatchNorm1d(head_dim),
            nn.GELU(),
            nn.Dropout(dropout * 0.5),
            nn.Linear(head_dim, head_dim // 2),
            nn.GELU(),
            nn.Linear(head_dim // 2, 1),
            nn.Sigmoid(),
        )

        # PD head: Linear→BN→GELU→Dropout→Linear→Sigmoid
        self.pd_head = nn.Sequential(
            nn.Linear(enc_out, head_dim),
            nn.BatchNorm1d(head_dim),
            nn.GELU(),
            nn.Dropout(dropout * 0.5),
            nn.Linear(head_dim, head_dim // 2),
            nn.GELU(),
            nn.Linear(head_dim // 2, 1),
            nn.Sigmoid(),
        )

    def forward(self, x: torch.Tensor):
        attn = self.feature_attention(x)
        x_att = x * attn
        h = self.input_proj(x_att)
        h = self.shared_encoder(h)
        ad_risk = self.ad_head(h).squeeze(-1)
        pd_risk = self.pd_head(h).squeeze(-1)
        return {"ad_risk": ad_risk, "pd_risk": pd_risk, "attention": attn}


# ------------------------------------------------------------------ #
# Predictor                                                           #
# ------------------------------------------------------------------ #

class SpeechPredictor(BasePredictor):
    model_filename = "speech_model.pt"

    def _build_model(self) -> nn.Module:
        return SpeechNeuroNet(input_dim=35)

    async def predict(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """
        Run speech model inference.

        ``features`` is the dict returned by SpeechExtractor.extract().
        Returns {"ad_risk", "pd_risk", "confidence", "attention_weights"}.
        """
        vec = SpeechExtractor.build_feature_vector(features)
        tensor = self._to_tensor(vec)

        if self.is_loaded:
            out = self._forward(tensor)
            ad = float(out["ad_risk"].item())
            pd_ = float(out["pd_risk"].item())
            attn = out["attention"].detach().cpu().numpy().flatten().tolist()
            confidence = 0.85
        else:
            ad, pd_, attn, confidence = self._heuristic_fallback(features)

        return {
            "ad_risk": round(ad * 100, 2),
            "pd_risk": round(pd_ * 100, 2),
            "confidence": confidence,
            "attention_weights": dict(zip(SPEECH_FEATURE_COLS, attn)) if len(attn) == 35 else {},
            "_xai_model": self._model if self.is_loaded else None,
            "_xai_tensor": tensor if self.is_loaded else None,
        }

    @staticmethod
    def _heuristic_fallback(features: dict):
        """Rule-based risk estimation when model weights are unavailable."""
        ad_risk = 0.10
        pd_risk = 0.05

        sr = features.get("speech_rate", 130)
        if sr < 90:
            ad_risk += 0.15
        elif sr < 110:
            ad_risk += 0.05

        pc = features.get("pause_count", 0)
        if pc > 15:
            ad_risk += 0.10

        pr = features.get("pause_rate", 0)
        if pr > 0.5:
            ad_risk += 0.08

        vs = features.get("vowel_stability", 0.5)
        if vs < 0.3:
            pd_risk += 0.15

        jitter = features.get("jitter", 0)
        if jitter > 0.02:
            pd_risk += 0.10

        shimmer = features.get("shimmer", 0)
        if shimmer > 0.05:
            pd_risk += 0.08

        sra = features.get("story_recall_accuracy", 0.5)
        if sra < 0.4:
            ad_risk += 0.12

        ad_risk = min(max(ad_risk, 0.0), 1.0)
        pd_risk = min(max(pd_risk, 0.0), 1.0)
        attn = [1.0 / 35] * 35
        return ad_risk, pd_risk, attn, 0.45
