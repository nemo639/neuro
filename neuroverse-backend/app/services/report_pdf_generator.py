"""
Comprehensive Report PDF Generator

Renders full clinical reports with:
  - Patient info & risk summary
  - Per-category breakdown with extracted features
  - XAI visualizations: SHAP bars, LIME, GradCAM overlays, radar charts
  - Original user drawings (spiral, meander, clock) with GradCAM heatmap overlay
  - Clinical interpretations & highlights
  - Doctor notes & recommendations
  - Fusion breakdown

Uses fpdf2 for PDF layout and Pillow for chart/image rendering.
"""

import base64
import io
import logging
import math
import os
import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple

from PIL import Image, ImageDraw, ImageFont

logger = logging.getLogger(__name__)


def _safe_text(text: str) -> str:
    """Replace Unicode characters unsupported by Helvetica with ASCII equivalents."""
    replacements = {
        "\u2014": "-",   # em dash —
        "\u2013": "-",   # en dash –
        "\u2018": "'",   # left single quote '
        "\u2019": "'",   # right single quote '
        "\u201c": '"',   # left double quote "
        "\u201d": '"',   # right double quote "
        "\u2022": "*",   # bullet •
        "\u2026": "...", # ellipsis …
        "\u00b0": " deg",  # degree °
        "\u2265": ">=",  # ≥
        "\u2264": "<=",  # ≤
    }
    for char, replacement in replacements.items():
        text = text.replace(char, replacement)
    return text

# ─── Colour palette ───
CLR_BRAND = (198, 233, 75)
CLR_DARK = (30, 30, 30)
CLR_WHITE = (255, 255, 255)
CLR_GREY_BG = (245, 246, 250)
CLR_GREY_TEXT = (100, 100, 100)
CLR_GREEN = (16, 185, 129)
CLR_YELLOW = (245, 158, 11)
CLR_RED = (239, 68, 68)
CLR_BLUE = (59, 130, 246)
CLR_PURPLE = (139, 92, 246)


# ═══════════════════════════════════════════════════════════════════════
# Chart Renderers (Pillow-based — no matplotlib dependency)
# ═══════════════════════════════════════════════════════════════════════

def _risk_color(value: float) -> Tuple[int, int, int]:
    """Return RGB colour based on risk level."""
    if value >= 70:
        return CLR_RED
    if value >= 40:
        return CLR_YELLOW
    return CLR_GREEN


def _health_color(value: float) -> Tuple[int, int, int]:
    """Return RGB colour based on health score (inverse of risk)."""
    if value >= 70:
        return CLR_GREEN
    if value >= 40:
        return CLR_YELLOW
    return CLR_RED


def render_bar_chart(
    items: List[Dict[str, Any]],
    title: str = "",
    width: int = 700,
    bar_height: int = 28,
    max_val: float = 1.0,
    value_key: str = "value",
    label_key: str = "name",
    color_mode: str = "importance",
) -> bytes:
    """
    Render a horizontal bar chart as PNG bytes.

    items: list of dicts with label_key and value_key
    color_mode: 'importance' (blue gradient), 'risk' (green/yellow/red), 'health'
    """
    if not items:
        return _empty_chart(width, 80, "No data available")

    padding = 20
    label_width = 220
    bar_area = width - label_width - padding * 3 - 60
    title_h = 36 if title else 0
    height = title_h + padding * 2 + len(items) * (bar_height + 8)

    img = Image.new("RGB", (width, height), (255, 255, 255))
    draw = ImageDraw.Draw(img)
    font = _get_font(14)
    font_sm = _get_font(12)
    font_title = _get_font(16, bold=True)

    y = padding
    if title:
        draw.text((padding, y), title, fill=CLR_DARK, font=font_title)
        y += title_h

    for item in items:
        label = str(item.get(label_key, ""))[:35]
        val = float(item.get(value_key, 0))
        pct = min(abs(val) / max_val, 1.0) if max_val > 0 else 0

        # Label
        draw.text((padding, y + 4), label, fill=CLR_DARK, font=font_sm)

        # Bar background
        bx = padding + label_width
        draw.rounded_rectangle(
            [bx, y + 2, bx + bar_area, y + bar_height - 2],
            radius=4, fill=(230, 230, 230),
        )

        # Bar fill
        if color_mode == "risk":
            bar_color = _risk_color(val)
        elif color_mode == "health":
            bar_color = _health_color(val)
        else:
            intensity = int(100 + 156 * pct)
            bar_color = (59, min(intensity, 200), 246)

        fill_w = max(int(bar_area * pct), 2)
        draw.rounded_rectangle(
            [bx, y + 2, bx + fill_w, y + bar_height - 2],
            radius=4, fill=bar_color,
        )

        # Value text
        val_str = f"{val:.1f}%" if max_val == 100 else f"{val:.3f}"
        draw.text((bx + bar_area + 8, y + 4), val_str, fill=CLR_GREY_TEXT, font=font_sm)

        y += bar_height + 8

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def render_radar_chart(
    domain_scores: Dict[str, float],
    title: str = "Cognitive Domain Profile",
    size: int = 500,
) -> bytes:
    """Render a radar/spider chart as PNG bytes."""
    if not domain_scores:
        return _empty_chart(size, size, "No domain scores")

    labels = list(domain_scores.keys())
    values = [float(v) for v in domain_scores.values()]
    n = len(labels)
    if n < 3:
        # Fall back to bar chart for < 3 domains
        items = [{"name": k, "value": v} for k, v in domain_scores.items()]
        return render_bar_chart(items, title=title, width=size, max_val=1.0)

    img = Image.new("RGB", (size, size), (255, 255, 255))
    draw = ImageDraw.Draw(img)
    font = _get_font(11)
    font_title = _get_font(14, bold=True)

    cx, cy = size // 2, size // 2 + 15
    radius = size // 2 - 70

    # Title
    draw.text((size // 2 - 80, 10), title, fill=CLR_DARK, font=font_title)

    # Draw grid circles
    for ring in [0.25, 0.5, 0.75, 1.0]:
        r = int(radius * ring)
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(220, 220, 220), width=1)

    # Draw axes and labels
    angles = [2 * math.pi * i / n - math.pi / 2 for i in range(n)]
    for i, angle in enumerate(angles):
        ex = cx + int(radius * math.cos(angle))
        ey = cy + int(radius * math.sin(angle))
        draw.line([cx, cy, ex, ey], fill=(200, 200, 200), width=1)

        # Label
        lx = cx + int((radius + 30) * math.cos(angle)) - 40
        ly = cy + int((radius + 30) * math.sin(angle)) - 8
        draw.text((lx, ly), labels[i][:18], fill=CLR_DARK, font=font)

    # Draw data polygon
    points = []
    for i, angle in enumerate(angles):
        v = min(max(values[i], 0), 1.0)
        px = cx + int(radius * v * math.cos(angle))
        py = cy + int(radius * v * math.sin(angle))
        points.append((px, py))

    # Fill polygon
    if len(points) >= 3:
        draw.polygon(points, fill=(59, 130, 246, 50), outline=CLR_BLUE)
    # Draw points
    for px, py in points:
        draw.ellipse([px - 4, py - 4, px + 4, py + 4], fill=CLR_BLUE)

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def render_gradcam_overlay(
    drawing_base64: str,
    heatmap: List[List[float]],
    size: int = 400,
) -> bytes:
    """
    Overlay a GradCAM heatmap on the original drawing image.
    Returns PNG bytes of the composite image.
    """
    try:
        # Decode original drawing
        img_bytes = base64.b64decode(drawing_base64)
        original = Image.open(io.BytesIO(img_bytes)).convert("RGBA")
        original = original.resize((size, size), Image.LANCZOS)

        # Create heatmap image
        h = len(heatmap)
        w = len(heatmap[0]) if h > 0 else 0
        if h == 0 or w == 0:
            buf = io.BytesIO()
            original.save(buf, format="PNG")
            return buf.getvalue()

        heatmap_img = Image.new("RGBA", (w, h))
        for yi in range(h):
            for xi in range(w):
                val = float(heatmap[yi][xi])
                # Blue → Green → Yellow → Red colour map
                if val < 0.25:
                    r, g, b = 0, 0, int(255 * val * 4)
                elif val < 0.5:
                    t = (val - 0.25) * 4
                    r, g, b = 0, int(255 * t), int(255 * (1 - t))
                elif val < 0.75:
                    t = (val - 0.5) * 4
                    r, g, b = int(255 * t), 255, 0
                else:
                    t = (val - 0.75) * 4
                    r, g, b = 255, int(255 * (1 - t)), 0
                alpha = int(140 * val)  # More transparent for low values
                heatmap_img.putpixel((xi, yi), (r, g, b, alpha))

        heatmap_img = heatmap_img.resize((size, size), Image.LANCZOS)

        # Composite
        composite = Image.alpha_composite(original, heatmap_img)
        composite = composite.convert("RGB")

        buf = io.BytesIO()
        composite.save(buf, format="PNG")
        return buf.getvalue()

    except Exception as e:
        logger.warning("GradCAM overlay failed: %s", e)
        return _empty_chart(size, size, "GradCAM overlay unavailable")


def render_drawing_image(drawing_base64: str, size: int = 350) -> bytes:
    """Decode and resize a base64 drawing to PNG bytes."""
    try:
        img_bytes = base64.b64decode(drawing_base64)
        img = Image.open(io.BytesIO(img_bytes)).convert("RGB")
        img = img.resize((size, size), Image.LANCZOS)
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        return buf.getvalue()
    except Exception as e:
        logger.warning("Drawing decode failed: %s", e)
        return _empty_chart(size, size, "Drawing unavailable")


def render_highlights_box(highlights: List[Dict], width: int = 700) -> bytes:
    """Render clinical highlights/warnings as a styled box."""
    if not highlights:
        return _empty_chart(width, 50, "No clinical highlights")

    padding = 16
    line_h = 28
    height = padding * 2 + len(highlights) * line_h + 10
    img = Image.new("RGB", (width, height), (255, 252, 240))
    draw = ImageDraw.Draw(img)
    font = _get_font(12)
    font_b = _get_font(12, bold=True)

    draw.rounded_rectangle([0, 0, width - 1, height - 1], radius=8, outline=(245, 200, 100))

    y = padding
    for h in highlights:
        severity = h.get("severity", "info")
        icon = "⚠️" if severity == "warning" else "ℹ️"
        color = CLR_RED if severity == "warning" else CLR_BLUE
        desc = h.get("description", "")

        draw.text((padding, y), f"{icon}", fill=color, font=font_b)
        draw.text((padding + 24, y), desc[:80], fill=CLR_DARK, font=font)
        y += line_h

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def render_fusion_breakdown(
    cat_ad_risks: Dict[str, float],
    cat_pd_risks: Dict[str, float],
    weights_ad: Dict[str, float],
    weights_pd: Dict[str, float],
    width: int = 700,
) -> bytes:
    """Render fusion weight breakdown showing how each category contributes."""
    items_ad = []
    for cat, w in weights_ad.items():
        risk = cat_ad_risks.get(cat, 0)
        contribution = risk * w
        items_ad.append({
            "name": f"{cat.title()} (w={w:.0%})",
            "value": round(contribution, 1),
        })

    items_pd = []
    for cat, w in weights_pd.items():
        risk = cat_pd_risks.get(cat, 0)
        contribution = risk * w
        items_pd.append({
            "name": f"{cat.title()} (w={w:.0%})",
            "value": round(contribution, 1),
        })

    padding = 20
    bar_h = 28
    title_h = 30
    section_gap = 20
    n_ad = len(items_ad)
    n_pd = len(items_pd)
    height = padding * 2 + title_h * 2 + (n_ad + n_pd) * (bar_h + 6) + section_gap

    img = Image.new("RGB", (width, height), (255, 255, 255))
    draw = ImageDraw.Draw(img)
    font = _get_font(12)
    font_b = _get_font(14, bold=True)

    y = padding
    draw.text((padding, y), "AD Fusion Contributions", fill=CLR_DARK, font=font_b)
    y += title_h

    label_w = 220
    bar_area = width - label_w - padding * 3 - 50
    max_contrib = max(
        max((i["value"] for i in items_ad), default=1),
        max((i["value"] for i in items_pd), default=1),
        1,
    )

    for item in items_ad:
        draw.text((padding, y + 4), item["name"], fill=CLR_DARK, font=font)
        bx = padding + label_w
        draw.rounded_rectangle([bx, y + 2, bx + bar_area, y + bar_h - 2], radius=4, fill=(230, 230, 230))
        pct = min(item["value"] / max_contrib, 1.0)
        fw = max(int(bar_area * pct), 2)
        draw.rounded_rectangle([bx, y + 2, bx + fw, y + bar_h - 2], radius=4, fill=CLR_BLUE)
        draw.text((bx + bar_area + 6, y + 4), f"{item['value']:.1f}", fill=CLR_GREY_TEXT, font=font)
        y += bar_h + 6

    y += section_gap
    draw.text((padding, y), "PD Fusion Contributions", fill=CLR_DARK, font=font_b)
    y += title_h

    for item in items_pd:
        draw.text((padding, y + 4), item["name"], fill=CLR_DARK, font=font)
        bx = padding + label_w
        draw.rounded_rectangle([bx, y + 2, bx + bar_area, y + bar_h - 2], radius=4, fill=(230, 230, 230))
        pct = min(item["value"] / max_contrib, 1.0)
        fw = max(int(bar_area * pct), 2)
        draw.rounded_rectangle([bx, y + 2, bx + fw, y + bar_h - 2], radius=4, fill=CLR_PURPLE)
        draw.text((bx + bar_area + 6, y + 4), f"{item['value']:.1f}", fill=CLR_GREY_TEXT, font=font)
        y += bar_h + 6

    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


# ─── Helpers ───

def _empty_chart(w: int, h: int, text: str) -> bytes:
    img = Image.new("RGB", (w, h), (245, 245, 245))
    draw = ImageDraw.Draw(img)
    font = _get_font(13)
    draw.text((w // 2 - 60, h // 2 - 8), text, fill=CLR_GREY_TEXT, font=font)
    buf = io.BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


def _get_font(size: int, bold: bool = False):
    """Get a PIL font, falling back to default if system fonts unavailable."""
    try:
        if bold:
            return ImageFont.truetype("arialbd.ttf", size)
        return ImageFont.truetype("arial.ttf", size)
    except (OSError, IOError):
        try:
            if bold:
                return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", size)
            return ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", size)
        except (OSError, IOError):
            return ImageFont.load_default()


# ═══════════════════════════════════════════════════════════════════════
# PDF Assembly
# ═══════════════════════════════════════════════════════════════════════

CATEGORY_DISPLAY = {
    "cognitive": "Cognitive & Memory",
    "speech": "Speech & Language",
    "motor": "Motor Functions",
    "facial": "Facial Analysis",
}


def generate_comprehensive_report(
    patient: Any,
    doctor: Any,
    sessions: list,
    test_results: Dict[str, Dict[str, Any]],
    report_type: str = "comprehensive",
    doctor_notes: str = "",
    ad_risk: float = 0,
    pd_risk: float = 0,
    ad_stage: str = "Normal",
    pd_stage: str = "Normal",
    category_scores: Dict[str, float] = None,
) -> str:
    """
    Generate a comprehensive PDF report and return the file path.

    Parameters
    ----------
    patient : User ORM object
    doctor : Doctor ORM object
    sessions : list of TestSession objects
    test_results : dict mapping category → {
        "ad_risk_score", "pd_risk_score", "category_score",
        "extracted_features", "xai_explanation", ...
    }
    doctor_notes : free-text notes from the doctor
    """
    from fpdf import FPDF
    from app.core.config import settings
    from app.services.fusion_service import CompositeFusionService

    category_scores = category_scores or {}

    # Temp dir for chart images
    tmp_dir = os.path.join(settings.UPLOAD_DIR, "tmp_charts")
    os.makedirs(tmp_dir, exist_ok=True)
    tmp_files = []  # Track for cleanup

    def _save_tmp(png_bytes: bytes, name: str) -> str:
        path = os.path.join(tmp_dir, f"{name}_{uuid.uuid4().hex[:6]}.png")
        with open(path, "wb") as f:
            f.write(png_bytes)
        tmp_files.append(path)
        return path

    # ── PDF class ──
    class NVReport(FPDF):
        def header(self):
            self.set_fill_color(*CLR_DARK)
            self.rect(0, 0, 210, 36, "F")
            self.set_text_color(*CLR_BRAND)
            self.set_font("Helvetica", "B", 18)
            self.set_xy(10, 8)
            self.cell(0, 10, "NeuroVerse", align="L")
            self.set_text_color(*CLR_WHITE)
            self.set_font("Helvetica", "", 9)
            self.set_xy(10, 20)
            self.cell(0, 8, "Comprehensive Neurodegenerative Disease Assessment Report", align="L")
            self.set_xy(140, 20)
            self.cell(60, 8, f"Generated: {datetime.utcnow().strftime('%B %d, %Y')}", align="R")
            self.ln(30)

        def footer(self):
            self.set_y(-15)
            self.set_font("Helvetica", "I", 7)
            self.set_text_color(150, 150, 150)
            self.cell(0, 10, f"NeuroVerse Confidential  |  Page {self.page_no()}/{{nb}}", align="C")

    pdf = NVReport()
    pdf.alias_nb_pages()
    pdf.set_auto_page_break(auto=True, margin=20)
    pdf.add_page()

    patient_name = f"{patient.first_name or ''} {patient.last_name or ''}".strip() or patient.email
    doctor_name = f"Dr. {doctor.first_name or ''} {doctor.last_name or ''}".strip()

    # ── Helper functions ──
    def section_title(title: str, number: int = 0):
        if pdf.get_y() > 250:
            pdf.add_page()
        prefix = f"{number}. " if number else ""
        pdf.set_font("Helvetica", "B", 13)
        pdf.set_text_color(*CLR_DARK)
        pdf.cell(0, 10, _safe_text(f"{prefix}{title}"), ln=True)
        pdf.set_draw_color(*CLR_BRAND)
        pdf.set_line_width(0.8)
        pdf.line(10, pdf.get_y(), 200, pdf.get_y())
        pdf.ln(3)

    def subsection(title: str):
        if pdf.get_y() > 255:
            pdf.add_page()
        pdf.set_font("Helvetica", "B", 11)
        pdf.set_text_color(60, 60, 60)
        pdf.cell(0, 8, _safe_text(title), ln=True)
        pdf.ln(1)

    def text_block(text: str, size: int = 9, color=CLR_GREY_TEXT):
        pdf.set_font("Helvetica", "", size)
        pdf.set_text_color(*color)
        pdf.multi_cell(0, 5, _safe_text(text))
        pdf.ln(2)

    def add_chart(png_bytes: bytes, name: str, w: int = 180):
        path = _save_tmp(png_bytes, name)
        if pdf.get_y() + 60 > 270:
            pdf.add_page()
        try:
            pdf.image(path, x=15, w=w)
        except Exception as e:
            logger.warning("Failed to embed chart %s: %s", name, e)
        pdf.ln(4)

    def score_bar(label: str, value, max_val=100):
        if value is None:
            return
        pdf.set_font("Helvetica", "", 9)
        pdf.set_text_color(60, 60, 60)
        pdf.cell(50, 7, label)
        x_start = pdf.get_x()
        y_bar = pdf.get_y() + 1.5
        bar_w = 120
        pdf.set_fill_color(230, 230, 230)
        pdf.rect(x_start, y_bar, bar_w, 4, "F")
        pct = min(value / max_val, 1.0)
        if pct >= 0.7:
            pdf.set_fill_color(*CLR_RED)
        elif pct >= 0.4:
            pdf.set_fill_color(*CLR_YELLOW)
        else:
            pdf.set_fill_color(*CLR_GREEN)
        pdf.rect(x_start, y_bar, bar_w * pct, 4, "F")
        pdf.set_xy(x_start + bar_w + 3, y_bar - 1)
        pdf.set_font("Helvetica", "B", 9)
        pdf.cell(20, 6, f"{value:.1f}%")
        pdf.ln(8)

    # ═══════════════════════════════════════════════════
    # PAGE 1: Patient Info + Risk Summary
    # ═══════════════════════════════════════════════════

    # Patient info box
    pdf.set_fill_color(*CLR_GREY_BG)
    pdf.rect(10, pdf.get_y(), 190, 28, "F")
    y0 = pdf.get_y() + 4
    pdf.set_font("Helvetica", "B", 12)
    pdf.set_text_color(*CLR_DARK)
    pdf.set_xy(14, y0)
    pdf.cell(90, 7, f"Patient: {patient_name}")
    pdf.set_font("Helvetica", "", 9)
    pdf.set_xy(14, y0 + 8)
    pdf.cell(90, 6, f"ID: {patient.id}  |  Email: {patient.email}")
    pdf.set_xy(14, y0 + 15)
    dob = str(patient.date_of_birth) if patient.date_of_birth else "N/A"
    pdf.cell(90, 6, f"DOB: {dob}  |  Gender: {patient.gender or 'N/A'}")
    pdf.set_xy(120, y0)
    pdf.set_font("Helvetica", "B", 10)
    pdf.cell(80, 7, f"Report Type: {report_type.replace('_', ' ').title()}")
    pdf.set_font("Helvetica", "", 9)
    pdf.set_xy(120, y0 + 8)
    pdf.cell(80, 6, f"Tests Completed: {len(sessions)}")
    pdf.set_xy(120, y0 + 15)
    pdf.cell(80, 6, f"Assessed by: {doctor_name}")
    pdf.ln(32)

    # 1. Overall Risk Assessment
    section_title("Overall Risk Assessment", 1)
    score_bar("Alzheimer's Disease Risk", round(ad_risk, 1))
    score_bar("Parkinson's Disease Risk", round(pd_risk, 1))
    pdf.set_font("Helvetica", "", 9)
    pdf.set_text_color(*CLR_GREY_TEXT)
    pdf.cell(0, 6, f"AD Stage: {ad_stage}  |  PD Stage: {pd_stage}", ln=True)
    pdf.ln(4)

    # 2. Category Scores
    section_title("Category-Wise Health Scores", 2)
    for cat_id, display in CATEGORY_DISPLAY.items():
        val = category_scores.get(cat_id)
        if val is not None:
            # Health score: invert colors (high = good)
            pdf.set_font("Helvetica", "", 9)
            pdf.set_text_color(60, 60, 60)
            pdf.cell(50, 7, display)
            x_start = pdf.get_x()
            y_bar = pdf.get_y() + 1.5
            bar_w = 120
            pdf.set_fill_color(230, 230, 230)
            pdf.rect(x_start, y_bar, bar_w, 4, "F")
            pct = min(val / 100, 1.0)
            c = _health_color(val)
            pdf.set_fill_color(*c)
            pdf.rect(x_start, y_bar, bar_w * pct, 4, "F")
            pdf.set_xy(x_start + bar_w + 3, y_bar - 1)
            pdf.set_font("Helvetica", "B", 9)
            pdf.cell(20, 6, f"{val:.1f}%")
            pdf.ln(8)
    pdf.ln(4)

    # 3. Fusion Breakdown
    section_title("Fusion Weight Breakdown", 3)
    text_block(
        "Shows how each test category contributes to the final AD and PD risk scores. "
        "Weights reflect clinical evidence for early detection sensitivity."
    )
    cat_ad = {}
    cat_pd = {}
    for cat, res in test_results.items():
        cat_ad[cat] = float(res.get("ad_risk_score", 0))
        cat_pd[cat] = float(res.get("pd_risk_score", 0))
    fusion_png = render_fusion_breakdown(
        cat_ad, cat_pd,
        CompositeFusionService.WEIGHTS_AD,
        CompositeFusionService.WEIGHTS_PD,
    )
    add_chart(fusion_png, "fusion_breakdown")

    # ═══════════════════════════════════════════════════
    # PER-CATEGORY DETAILED SECTIONS
    # ═══════════════════════════════════════════════════

    section_num = 4
    for cat_id in ["cognitive", "speech", "motor", "facial"]:
        if cat_id not in test_results:
            continue

        result = test_results[cat_id]
        features = result.get("extracted_features") or {}
        xai = result.get("xai_explanation") or {}
        cat_display = CATEGORY_DISPLAY.get(cat_id, cat_id.title())

        pdf.add_page()
        section_title(f"{cat_display} — Detailed Analysis", section_num)
        section_num += 1

        # Category risk summary
        pdf.set_font("Helvetica", "", 9)
        pdf.set_text_color(*CLR_GREY_TEXT)
        cat_score = result.get("category_score", 0)
        cat_ad_risk = result.get("ad_risk_score", 0)
        cat_pd_risk = result.get("pd_risk_score", 0)
        pdf.cell(0, 6, (
            f"Health Score: {cat_score:.1f}%  |  "
            f"AD Risk: {cat_ad_risk:.1f}%  |  PD Risk: {cat_pd_risk:.1f}%  |  "
            f"Stage: {result.get('stage', 'N/A')}  |  Severity: {result.get('severity', 'N/A')}"
        ), ln=True)
        pdf.ln(4)

        # ── SHAP Values ──
        shap_values = xai.get("shap_values") or []
        if shap_values:
            subsection("SHAP Feature Attribution")
            text_block(
                "SHAP values show each feature's contribution to the risk prediction. "
                "Positive values increase risk; negative values are protective."
            )
            shap_chart = render_bar_chart(
                shap_values[:12],
                title="SHAP Feature Importance",
                value_key="value",
                label_key="name",
                max_val=max(abs(s.get("value", 0)) for s in shap_values[:12]) or 1,
            )
            add_chart(shap_chart, f"shap_{cat_id}")

        # ── Feature Importance ──
        feat_importance = xai.get("feature_importance") or []
        if feat_importance:
            subsection("Feature Importance Ranking")
            fi_chart = render_bar_chart(
                feat_importance[:10],
                title="Top Features by Importance",
                value_key="value",
                label_key="name",
                max_val=max(f.get("value", 0) for f in feat_importance[:10]) or 1,
            )
            add_chart(fi_chart, f"fi_{cat_id}")

        # ── Saliency / GradCAM / Drawings ──
        saliency = xai.get("saliency_data") or {}
        sal_type = saliency.get("type", "")
        sal_data = saliency.get("data", {})

        # Cognitive radar chart
        if sal_type == "cognitive_radar" and sal_data.get("domain_scores"):
            subsection("Cognitive Domain Profile (Radar Chart)")
            text_block(
                "Scores represent performance across cognitive domains. "
                "Values closer to the outer edge indicate better performance."
            )
            radar_png = render_radar_chart(sal_data["domain_scores"])
            add_chart(radar_png, "cognitive_radar", w=120)

        # Motor drawings + GradCAM
        if cat_id == "motor":
            gradcam_heatmap = sal_data.get("gradcam_heatmap")

            # Spiral drawing
            spiral_b64 = features.get("spiral_image_base64")
            if spiral_b64:
                subsection("Spiral Drawing — Patient's Original")
                drawing_png = render_drawing_image(spiral_b64, size=300)
                add_chart(drawing_png, "spiral_original", w=80)

                if gradcam_heatmap:
                    subsection("Spiral Drawing — GradCAM Heatmap Overlay")
                    text_block(
                        "Warm regions (red/yellow) show areas the AI model focused on "
                        "most when making its prediction. Cool regions (blue) had less influence."
                    )
                    overlay_png = render_gradcam_overlay(spiral_b64, gradcam_heatmap, size=300)
                    add_chart(overlay_png, "spiral_gradcam", w=80)

            # Meander drawing
            meander_b64 = features.get("meander_image_base64")
            if meander_b64:
                subsection("Meander Drawing — Patient's Original")
                drawing_png = render_drawing_image(meander_b64, size=300)
                add_chart(drawing_png, "meander_original", w=80)

                if gradcam_heatmap:
                    subsection("Meander Drawing — GradCAM Heatmap Overlay")
                    overlay_png = render_gradcam_overlay(meander_b64, gradcam_heatmap, size=300)
                    add_chart(overlay_png, "meander_gradcam", w=80)

        # Cognitive CDT drawing + GradCAM
        if cat_id == "cognitive":
            cdt_b64 = features.get("cdt_image_base64")
            gradcam_heatmap = sal_data.get("gradcam_heatmap")
            if cdt_b64:
                subsection("Clock Drawing Test — Patient's Drawing")
                drawing_png = render_drawing_image(cdt_b64, size=300)
                add_chart(drawing_png, "cdt_original", w=80)

                if gradcam_heatmap:
                    subsection("Clock Drawing — GradCAM Heatmap Overlay")
                    text_block(
                        "Highlights the areas the AI model deemed most significant "
                        "for its visuospatial/executive function assessment."
                    )
                    overlay_png = render_gradcam_overlay(cdt_b64, gradcam_heatmap, size=300)
                    add_chart(overlay_png, "cdt_gradcam", w=80)

        # Feature bars from saliency
        sal_bars = sal_data.get("feature_bars", [])
        if sal_bars and sal_type not in ("cognitive_radar",):
            subsection("Feature Analysis Bars")
            bar_chart = render_bar_chart(
                sal_bars[:10],
                title=f"{cat_display} Features",
                value_key="weight",
                label_key="feature",
                max_val=max(abs(b.get("weight", 0)) for b in sal_bars[:10]) or 1,
            )
            add_chart(bar_chart, f"sal_bars_{cat_id}")

        # ── Clinical Highlights ──
        highlights = saliency.get("highlights", [])
        if highlights:
            subsection("Clinical Highlights")
            hl_png = render_highlights_box(highlights)
            add_chart(hl_png, f"highlights_{cat_id}")

        # ── LIME Explanation ──
        lime_data = xai.get("lime_explanations") or xai.get("lime")
        if lime_data:
            subsection("LIME — Local Interpretable Explanation")
            text_block(
                "LIME identifies which features most influenced this specific prediction "
                "by approximating the model's decision boundary locally."
            )
            lime_items = lime_data if isinstance(lime_data, list) else lime_data.get("feature_weights", lime_data.get("segments", []))
            if lime_items and isinstance(lime_items, list) and isinstance(lime_items[0], dict):
                # Determine the correct keys (LIME uses "lime_weight" or "weight")
                first = lime_items[0]
                v_key = "lime_weight" if "lime_weight" in first else "weight" if "weight" in first else "value"
                l_key = "feature" if "feature" in first else "name"
                lime_chart = render_bar_chart(
                    lime_items[:10],
                    title="LIME Feature Weights",
                    value_key=v_key,
                    label_key=l_key,
                    max_val=max(abs(l.get(v_key, 0)) for l in lime_items[:10]) or 1,
                )
                add_chart(lime_chart, f"lime_{cat_id}")

        # ── Integrated Gradients ──
        ig_data = xai.get("integrated_gradients")
        if ig_data:
            subsection("Integrated Gradients — Path-Integrated Attribution")
            text_block(
                "Shows attribution accumulated along the path from a baseline to the actual input, "
                "providing a complete picture of each feature's contribution."
            )
            ig_items = ig_data if isinstance(ig_data, list) else ig_data.get("attributions", [])
            if ig_items and isinstance(ig_items, list) and isinstance(ig_items[0], dict):
                first = ig_items[0]
                v_key = "attribution" if "attribution" in first else "value"
                l_key = "feature" if "feature" in first else "name"
                ig_chart = render_bar_chart(
                    ig_items[:10],
                    title="Integrated Gradient Attributions",
                    value_key=v_key,
                    label_key=l_key,
                    max_val=max(abs(i.get(v_key, 0)) for i in ig_items[:10]) or 1,
                )
                add_chart(ig_chart, f"ig_{cat_id}")

        # ── Counterfactual ──
        cf_data = xai.get("counterfactual_analysis") or xai.get("counterfactual")
        if cf_data:
            subsection("Counterfactual Analysis — 'What-If' Scenarios")
            scenarios = cf_data if isinstance(cf_data, list) else cf_data.get("scenarios", [])
            for sc in scenarios[:5]:
                change = sc.get("change", sc.get("description", ""))
                effect = sc.get("effect", sc.get("new_risk", ""))
                text_block(f"  - If {change} => {effect}", size=9, color=CLR_DARK)

        # ── Attention Visualization ──
        attn_data = xai.get("attention_analysis") or xai.get("attention")
        if attn_data:
            subsection("Attention Pattern Visualization")
            text_block(
                "Shows where the neural network focused its attention when processing the input data."
            )
            attn_items = attn_data if isinstance(attn_data, list) else attn_data.get("data", attn_data.get("feature_attention", []))
            if attn_items and isinstance(attn_items, list) and isinstance(attn_items[0], dict):
                first = attn_items[0]
                v_key = "attention_weight" if "attention_weight" in first else "weight" if "weight" in first else "value"
                l_key = "feature" if "feature" in first else "name"
                attn_chart = render_bar_chart(
                    attn_items[:10],
                    title="Attention Weights",
                    value_key=v_key,
                    label_key=l_key,
                    max_val=max(abs(a.get(v_key, 0)) for a in attn_items[:10]) or 1,
                )
                add_chart(attn_chart, f"attn_{cat_id}")

        # ── Clinical Interpretation (text) ──
        interpretations = xai.get("interpretations") or xai.get("interpretation") or []
        if interpretations:
            subsection("Clinical Interpretation")
            for interp in interpretations[:6]:
                title_txt = interp.get("title", "")
                desc_txt = interp.get("description", "")
                if title_txt:
                    pdf.set_font("Helvetica", "B", 9)
                    pdf.set_text_color(*CLR_DARK)
                    pdf.cell(0, 6, _safe_text(title_txt), ln=True)
                if desc_txt:
                    text_block(f"  {desc_txt}")  # text_block already calls _safe_text

    # ═══════════════════════════════════════════════════
    # TEST SESSIONS TABLE
    # ═══════════════════════════════════════════════════
    pdf.add_page()
    section_title("Test Sessions Summary", section_num)
    section_num += 1

    pdf.set_font("Helvetica", "B", 8)
    pdf.set_fill_color(240, 240, 240)
    pdf.set_text_color(*CLR_DARK)
    headers = ["#", "Category", "Status", "Date", "Score"]
    widths = [10, 50, 30, 50, 40]
    for i, h in enumerate(headers):
        pdf.cell(widths[i], 7, h, border=1, fill=True)
    pdf.ln()
    pdf.set_font("Helvetica", "", 8)
    pdf.set_text_color(50, 50, 50)
    for idx, s in enumerate(sessions[:20], 1):
        pdf.cell(widths[0], 6, str(idx), border=1)
        pdf.cell(widths[1], 6, (s.category or "N/A")[:25], border=1)
        pdf.cell(widths[2], 6, s.status or "completed", border=1)
        dt_str = s.completed_at.strftime("%Y-%m-%d") if s.completed_at else "N/A"
        pdf.cell(widths[3], 6, dt_str, border=1)
        cat_s = category_scores.get(s.category)
        pdf.cell(widths[4], 6, f"{cat_s:.1f}%" if cat_s else "-", border=1)
        pdf.ln()
    if not sessions:
        pdf.set_font("Helvetica", "I", 9)
        pdf.cell(0, 8, "No completed test sessions found.", ln=True)
    pdf.ln(6)

    # ═══════════════════════════════════════════════════
    # DOCTOR NOTES & RECOMMENDATIONS
    # ═══════════════════════════════════════════════════
    section_title("Doctor's Notes & Recommendations", section_num)
    section_num += 1

    if doctor_notes:
        subsection("Doctor's Notes")
        text_block(doctor_notes, size=10, color=CLR_DARK)
        pdf.ln(4)

    subsection("Clinical Recommendations")
    recommendations = []
    if ad_risk >= 70:
        recommendations.append("Immediate referral to neurology specialist for comprehensive AD evaluation.")
        recommendations.append("Consider advanced neuroimaging (MRI/PET amyloid) for further assessment.")
        recommendations.append("Neuropsychological testing recommended for detailed cognitive profiling.")
    elif ad_risk >= 40:
        recommendations.append("Schedule follow-up cognitive assessments within 3 months.")
        recommendations.append("Monitor for progression of memory and language difficulties.")
    elif ad_risk >= 20:
        recommendations.append("Annual cognitive screening recommended to track any changes.")

    if pd_risk >= 70:
        recommendations.append("Urgent motor function evaluation and DaTscan recommended.")
        recommendations.append("Consider dopamine transporter imaging for PD confirmation.")
        recommendations.append("Refer to movement disorder specialist.")
    elif pd_risk >= 40:
        recommendations.append("Monitor motor symptoms; repeat motor and facial assessments in 6 weeks.")
        recommendations.append("Watch for progression of tremor, rigidity, or facial masking.")
    elif pd_risk >= 20:
        recommendations.append("Periodic motor screening advised to track subtle changes.")

    if not recommendations:
        recommendations.append("Current assessment scores are within normal range.")
        recommendations.append("Continue routine monitoring and healthy lifestyle practices.")

    recommendations.append("Regular physical exercise, cognitive engagement, and social interaction are advised.")

    pdf.set_font("Helvetica", "", 9)
    pdf.set_text_color(60, 60, 60)
    for i, rec in enumerate(recommendations, 1):
        pdf.multi_cell(0, 6, _safe_text(f"  {i}. {rec}"))
        pdf.ln(1)
    pdf.ln(4)

    # ═══════════════════════════════════════════════════
    # DISCLAIMER
    # ═══════════════════════════════════════════════════
    pdf.ln(6)
    pdf.set_font("Helvetica", "I", 7)
    pdf.set_text_color(130, 130, 130)
    pdf.multi_cell(0, 4, (
        "Disclaimer: This report is generated by AI-assisted analysis and is intended as a "
        "screening tool only. It is not a definitive diagnosis. All findings should be reviewed "
        "and interpreted by a qualified healthcare professional. Clinical decisions should not "
        "be based solely on this report. NeuroVerse is a research tool and does not replace "
        "standard clinical assessment protocols."
    ))

    # ── Save PDF ──
    os.makedirs(os.path.join(settings.UPLOAD_DIR, "reports"), exist_ok=True)
    filename = f"report_{patient.id}_{uuid.uuid4().hex[:8]}.pdf"
    filepath = os.path.join(settings.UPLOAD_DIR, "reports", filename)
    pdf.output(filepath)

    # Cleanup temp chart images
    for tmp in tmp_files:
        try:
            os.remove(tmp)
        except Exception:
            pass
    try:
        os.rmdir(tmp_dir)
    except Exception:
        pass

    return filepath, filename
