"""
Base Predictor - Abstract base for all modality-specific predictors.
Handles model loading, device selection, and common inference logic.

All ML imports (torch, numpy) are lazy so the server starts even
when those packages are not installed.
"""

import abc
import logging
from pathlib import Path
from typing import Any, Dict, Optional

logger = logging.getLogger(__name__)

# Directory where .pt model files live
MODELS_DIR = Path(__file__).resolve().parent.parent / "models"

# Lazy-loaded globals
_torch = None
_np = None


def _import_torch():
    global _torch
    if _torch is None:
        import torch
        _torch = torch
    return _torch


def _import_numpy():
    global _np
    if _np is None:
        import numpy as np
        _np = np
    return _np


def torch_available() -> bool:
    try:
        _import_torch()
        return True
    except ImportError:
        return False


class BasePredictor(abc.ABC):
    """
    Abstract predictor that loads a PyTorch model and runs inference.

    Subclasses must implement:
      - ``_build_model()``  → return an ``nn.Module``
      - ``predict(features)`` → return risk dict
    """

    model_filename: str = ""
    _model = None
    _device = None
    _loaded: bool = False

    def __init__(self):
        if torch_available():
            torch = _import_torch()
            self._device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    def load(self) -> bool:
        """Load model weights from disk.  Returns True on success."""
        if self._loaded:
            return True

        if not torch_available():
            logger.warning("PyTorch not installed – %s will use heuristic fallback.", self.__class__.__name__)
            return False

        model_path = MODELS_DIR / self.model_filename
        if not model_path.exists() or model_path.stat().st_size == 0:
            logger.warning("Model file missing or empty: %s – using heuristic fallback.", model_path)
            return False

        try:
            torch = _import_torch()
            self._model = self._build_model()
            checkpoint = torch.load(model_path, map_location=self._device, weights_only=False)

            if isinstance(checkpoint, dict) and "model_state_dict" in checkpoint:
                self._model.load_state_dict(checkpoint["model_state_dict"])
            elif isinstance(checkpoint, dict) and "state_dict" in checkpoint:
                self._model.load_state_dict(checkpoint["state_dict"])
            else:
                self._model.load_state_dict(checkpoint)

            self._model.to(self._device)
            self._model.eval()
            self._loaded = True
            logger.info("Loaded model %s on %s", self.model_filename, self._device)
            return True
        except Exception as exc:
            logger.error("Failed to load %s: %s", self.model_filename, exc)
            return False

    @property
    def is_loaded(self) -> bool:
        return self._loaded

    @abc.abstractmethod
    def _build_model(self):
        """Return an un-initialised nn.Module matching the trained architecture."""
        ...

    @abc.abstractmethod
    async def predict(self, features: Dict[str, Any]) -> Dict[str, Any]:
        """Run inference. Returns at minimum: ad_risk, pd_risk, confidence."""
        ...

    def _to_tensor(self, arr):
        """Numpy array → batched float32 tensor on correct device.

        Always returns a tensor with a leading batch dimension:
          1-D (features,)        → (1, features)
          2-D (H, W)             → (1, H, W)        (unlikely)
          3-D (C, H, W)          → (1, C, H, W)     (image)
          4-D already batched    → unchanged
        """
        torch = _import_torch()
        t = torch.from_numpy(arr).float()
        if t.dim() < 4 and t.dim() >= 1:
            t = t.unsqueeze(0)
        return t.to(self._device)

    def _forward(self, tensor):
        """Run a forward pass (no_grad, eval mode)."""
        torch = _import_torch()
        if self._model is None:
            raise RuntimeError("Model not loaded")
        with torch.no_grad():
            return self._model(tensor)
