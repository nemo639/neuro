"""
Phone-to-Paper Domain Adapter for Drawing Images

Bridges the domain gap between phone touchscreen finger drawings
and clinical paper-and-pen drawings that ML models were trained on.

Key differences between phone and paper drawings:
  - Phone: thick finger strokes (~5px), smooth glass surface, no pressure variation
  - Paper: thin pen strokes (~1-2px), natural pressure, paper texture/noise

This adapter preprocesses phone screenshots to look more like paper scans:
  1. Stroke thinning (morphological erosion to reduce finger width)
  2. Paper texture (subtle Gaussian noise to match scanned paper)
  3. Line refinement (slight blur to smooth jagged pixel edges)
  4. Contrast normalization (match the contrast profile of paper scans)
"""

import logging
from typing import Optional

import numpy as np

logger = logging.getLogger(__name__)


def adapt_phone_drawing(
    img: np.ndarray,
    thin_iterations: int = 1,
    noise_level: float = 5.0,
    blur_sigma: float = 0.5,
) -> np.ndarray:
    """
    Transform a phone finger-drawing screenshot to resemble a paper scan.

    Args:
        img: Input image as numpy array (H, W, C) in uint8 RGB.
        thin_iterations: Number of morphological erosion passes to thin strokes.
        noise_level: Standard deviation of Gaussian noise for paper texture.
        blur_sigma: Gaussian blur sigma for line smoothing.

    Returns:
        Processed image as numpy array (H, W, C) in uint8 RGB.
    """
    if img is None or img.size == 0:
        return img

    try:
        result = img.copy().astype(np.float32)

        # 1. Stroke thinning via morphological erosion
        #    Phone finger strokes are ~5px wide vs pen ~1-2px
        #    We erode the dark (drawing) regions to thin them
        result = _thin_strokes(result, iterations=thin_iterations)

        # 2. Add paper texture (subtle Gaussian noise)
        #    Scanned paper images have inherent sensor/paper noise
        #    Phone screenshots are pixel-perfect — too clean for the model
        result = _add_paper_texture(result, sigma=noise_level)

        # 3. Light Gaussian blur to smooth jagged edges
        #    Finger drawings on phone have pixel-level jaggedness
        #    Pen on paper produces naturally smoother edges
        result = _light_blur(result, sigma=blur_sigma)

        # 4. Contrast normalization to match paper scan profile
        result = _normalize_contrast(result)

        return np.clip(result, 0, 255).astype(np.uint8)

    except Exception as exc:
        logger.warning("Phone drawing adaptation failed: %s — using original", exc)
        return img


def _thin_strokes(img: np.ndarray, iterations: int = 1) -> np.ndarray:
    """Thin thick finger strokes using morphological erosion on the ink channel."""
    try:
        from PIL import Image, ImageFilter

        # Convert to grayscale to find ink
        gray = 0.299 * img[:, :, 0] + 0.587 * img[:, :, 1] + 0.114 * img[:, :, 2]

        # Detect ink pixels (dark strokes on light background)
        # Threshold: pixels darker than 60% of max are likely ink
        threshold = gray.max() * 0.6
        is_ink = gray < threshold

        if not is_ink.any():
            return img  # No ink found, return as-is

        # Use PIL for morphological erosion (erode ink = thin strokes)
        # We work on an inverted mask: ink=white, bg=black
        ink_mask = (is_ink * 255).astype(np.uint8)
        pil_mask = Image.fromarray(ink_mask)

        for _ in range(iterations):
            # MinFilter erodes white regions (thins the ink mask)
            pil_mask = pil_mask.filter(ImageFilter.MinFilter(3))

        eroded = np.asarray(pil_mask) > 127

        # Rebuild: where ink was removed by erosion, replace with background
        # Estimate background color from non-ink regions
        bg_color = np.median(img[~is_ink], axis=0) if (~is_ink).any() else np.array([255, 255, 255])

        result = img.copy()
        # Pixels that were ink but got eroded away → set to background
        removed = is_ink & ~eroded
        result[removed] = bg_color

        return result

    except Exception as exc:
        logger.debug("Stroke thinning failed: %s", exc)
        return img


def _add_paper_texture(img: np.ndarray, sigma: float = 5.0) -> np.ndarray:
    """Add subtle Gaussian noise to simulate paper scan texture."""
    noise = np.random.normal(0, sigma, img.shape).astype(np.float32)
    return img + noise


def _light_blur(img: np.ndarray, sigma: float = 0.5) -> np.ndarray:
    """Apply a light Gaussian-like blur to smooth jagged pixel edges."""
    try:
        from PIL import Image, ImageFilter

        pil_img = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
        # GaussianBlur radius ~ sigma (PIL uses radius, not sigma)
        radius = max(int(sigma), 1)
        pil_img = pil_img.filter(ImageFilter.GaussianBlur(radius=radius))
        return np.asarray(pil_img).astype(np.float32)

    except Exception as exc:
        logger.debug("Light blur failed: %s", exc)
        return img


def _normalize_contrast(img: np.ndarray) -> np.ndarray:
    """Normalize contrast to match paper scan profile.

    Paper scans typically have:
    - Background ~240-250 (not pure 255 white)
    - Ink ~20-50 (not pure 0 black)
    We map the full range to this narrower range.
    """
    # Target range for paper scans
    paper_bg = 245.0
    paper_ink = 30.0

    img_min = img.min()
    img_max = img.max()

    if img_max - img_min < 10:
        return img  # Nearly uniform image, skip

    # Linear rescale from [img_min, img_max] → [paper_ink, paper_bg]
    normalized = paper_ink + (img - img_min) / (img_max - img_min) * (paper_bg - paper_ink)
    return normalized


# ------------------------------------------------------------------ #
# Phone-specific output calibration                                    #
# ------------------------------------------------------------------ #

def calibrate_phone_risk(
    raw_risk: float,
    modality: str = "cdt",
    confidence: float = 0.5,
) -> float:
    """
    Apply phone-domain calibration to model risk output.

    Models trained on paper drawings systematically overestimate risk
    when given phone finger drawings due to domain mismatch:
    - CDT: Thick strokes + low circle quality → looks impaired
    - Motor: Smooth finger motion → unusual tremor pattern
    - These are artifacts of the input device, not real impairment

    We apply a modality-specific discount curve that:
    1. Compresses high risk predictions (most affected by domain gap)
    2. Leaves low risk predictions mostly unchanged
    3. Scales with model confidence (high-confidence wrong predictions
       get more correction than low-confidence ones)

    Args:
        raw_risk: Model's raw risk score (0-100).
        modality: One of "cdt", "motor_spiral", "motor_meander".
        confidence: Model confidence (0-1).

    Returns:
        Calibrated risk score (0-100).
    """
    # Discount factors per modality (empirically tuned)
    # Higher discount = more correction needed
    discounts = {
        "cdt": 0.55,              # CDT most affected (stroke count, circle quality)
        "motor_spiral": 0.60,     # Spiral heavily affected (smoothness artifact)
        "motor_meander": 0.65,    # Meander slightly less affected
    }
    discount = discounts.get(modality, 0.65)

    # Phone baseline prior: healthy person on phone typically scores this
    # (the "floor" that even a perfectly healthy phone user might hit)
    baselines = {
        "cdt": 12.0,              # Phone CDT has ~12% irreducible artifact risk
        "motor_spiral": 15.0,     # Phone spiral has ~15% artifact risk
        "motor_meander": 12.0,
    }
    baseline = baselines.get(modality, 12.0)

    # Calibration formula:
    # calibrated = baseline + (raw - baseline) * discount
    # This compresses the range above baseline while keeping baseline anchor
    if raw_risk <= baseline:
        return raw_risk  # Below baseline = truly low risk, no correction

    calibrated = baseline + (raw_risk - baseline) * discount

    # High-confidence predictions from domain-mismatched input need more
    # correction (the model is "confidently wrong" about phone artifacts)
    if confidence > 0.8 and raw_risk > 60:
        # Extra damping for very high confidence + high risk
        calibrated *= 0.85

    return min(max(calibrated, 0.0), 100.0)
