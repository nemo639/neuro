"""
Base Feature Extractor
Abstract base class for all modality-specific feature extractors.
"""

import abc
import logging
from typing import Any, Dict, List, Optional

import numpy as np

logger = logging.getLogger(__name__)


class BaseExtractor(abc.ABC):
    """
    Abstract base class for feature extraction from raw test data.

    Each concrete extractor handles one test category and converts
    raw test-item payloads (JSON dicts from the Flutter app) into
    a flat numeric feature dictionary suitable for model inference.
    """

    category: str = ""  # override in subclass

    # ------------------------------------------------------------------ #
    # Public API                                                          #
    # ------------------------------------------------------------------ #
    async def extract(self, test_items: List[Any]) -> Dict[str, Any]:
        """
        Extract features from a list of TestItem ORM objects.

        Returns:
            Dict with ``"category"``, ``"items_processed"`` and all
            numeric feature key/value pairs.
        """
        features: Dict[str, Any] = {
            "category": self.category,
            "items_processed": len(test_items),
        }

        for item in test_items:
            raw: dict = getattr(item, "raw_data", None) or {}
            item_name: str = getattr(item, "item_name", "") or ""
            try:
                item_features = await self._extract_item(item_name, raw)
                features.update(item_features)
            except Exception as exc:  # noqa: BLE001
                logger.warning(
                    "Extractor %s failed on item %s: %s",
                    self.category, item_name, exc,
                )

        # Derived / cross-item features
        try:
            derived = await self._derive_features(features)
            features.update(derived)
        except Exception as exc:  # noqa: BLE001
            logger.warning("Derived feature computation failed: %s", exc)

        return features

    # ------------------------------------------------------------------ #
    # Abstract hooks                                                      #
    # ------------------------------------------------------------------ #
    @abc.abstractmethod
    async def _extract_item(
        self, item_name: str, raw: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Return features for a single test item."""
        ...

    async def _derive_features(
        self, features: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Optional hook – compute cross-item derived features."""
        return {}

    # ------------------------------------------------------------------ #
    # Helpers                                                             #
    # ------------------------------------------------------------------ #
    @staticmethod
    def safe_get(raw: dict, key: str, default: float = 0.0) -> float:
        """Safely extract a numeric value from raw data dict."""
        val = raw.get(key, default)
        if val is None:
            return default
        try:
            return float(val)
        except (TypeError, ValueError):
            return default

    @staticmethod
    def safe_ratio(numerator: float, denominator: float, default: float = 0.0) -> float:
        """Compute a safe division, avoiding ZeroDivisionError."""
        if denominator == 0:
            return default
        return numerator / denominator

    @staticmethod
    def normalize_signal(signal: List[float]) -> Optional[np.ndarray]:
        """Z-score normalise a 1-D signal. Returns None if too short."""
        if not signal or len(signal) < 2:
            return None
        arr = np.asarray(signal, dtype=np.float32)
        std = arr.std()
        if std < 1e-8:
            return arr - arr.mean()
        return (arr - arr.mean()) / std
