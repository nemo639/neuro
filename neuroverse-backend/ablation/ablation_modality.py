"""
Modality Ablation Study for NeuroVerse AD Detection Paper.

Tests 7 modality combinations (2^3 - 1) on a synthetic / clinical test set:
    Speech only | CDT only | TMT only
    Speech+CDT | Speech+TMT | CDT+TMT
    Full (all 3)

For each config, runs inference with only the selected modalities active,
computes accuracy / AUC / F1, and saves results to CSV + bar chart.

Usage:
    python ablation/ablation_modality.py [--samples 100] [--seed 42]
"""
import argparse
import asyncio
import csv
import os
import sys
import random
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
from sklearn.metrics import accuracy_score, roc_auc_score, f1_score, precision_score, recall_score

# Add backend root to path
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from app.services.fusion_service import FusionService
from app.ml.predictors import get_predictor

OUTPUT_DIR = ROOT / "ablation" / "results"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# ==================== Synthetic Test Set ====================
# Each sample contains features for all 3 modalities + the true label.
# Replace these with real test data when available.

def generate_synthetic_sample(label: int, seed: int) -> Dict:
    """
    Generate one synthetic test sample using the SAME feature names the
    NeuroVerse extractors/predictors produce in production.
    label: 0 = Healthy, 1 = AD/MCI
    """
    rng = np.random.default_rng(seed)

    # ============== SPEECH (35-D acoustic features) ==============
    speech = {
        "speech_rate":  float(rng.normal(3.5 if label == 0 else 2.3, 0.4)),
        "pause_rate":   float(rng.normal(0.10 if label == 0 else 0.28, 0.05)),
        "pause_count":  int(rng.normal(8 if label == 0 else 20, 3)),
        "jitter":       float(rng.normal(0.008 if label == 0 else 0.020, 0.003)),
        "shimmer":      float(rng.normal(0.03 if label == 0 else 0.07, 0.01)),
        "hnr":          float(rng.normal(20.0 if label == 0 else 13.0, 2.0)),
        "f0_mean":      float(rng.normal(130.0, 15.0)),
        "f0_std":       float(rng.normal(25.0 if label == 0 else 16.0, 5.0)),
        "energy_std":   float(rng.normal(0.5, 0.1)),
        "zcr":          float(rng.normal(0.1, 0.02)),
        "spectral_centroid": float(rng.normal(2000, 300)),
        # Formants
        "f1_mean": float(rng.normal(500, 80)), "f1_std": float(rng.normal(60, 10)),
        "f2_mean": float(rng.normal(1500, 200)), "f2_std": float(rng.normal(120, 20)),
        "f3_mean": float(rng.normal(2500, 300)), "f3_std": float(rng.normal(150, 25)),
    }
    for i in range(13):
        speech[f"mfcc_{i+1}_mean"] = float(rng.normal(0.0, 1.0))
        speech[f"mfcc_{i+1}_std"] = float(abs(rng.normal(0.5, 0.1)))

    # ============== COGNITIVE (CDT + supporting cognitive tests) ==============
    # Healthy -> Shulman 4-5 (good); AD -> Shulman 0-2 (impaired)
    cdt_features = {
        "cdt_score":     int(rng.integers(4, 6) if label == 0 else rng.integers(0, 3)),
        "cdt_max_score": 5,
        # Add supporting cognitive features so heuristic actually computes a risk
        "stroop_accuracy":         float(rng.normal(0.92 if label == 0 else 0.65, 0.06)),
        "stroop_interference":     float(rng.normal(80 if label == 0 else 220, 30)),
        "stroop_avg_rt":           float(rng.normal(650 if label == 0 else 1100, 100)),
        "stroop_congruent_accuracy":   float(rng.normal(0.96 if label == 0 else 0.85, 0.03)),
        "stroop_incongruent_accuracy": float(rng.normal(0.90 if label == 0 else 0.60, 0.05)),
        "recall_accuracy":         float(rng.normal(0.85 if label == 0 else 0.45, 0.10)),
        "recognition_accuracy":    float(rng.normal(0.90 if label == 0 else 0.60, 0.08)),
        "nback_accuracy":          float(rng.normal(0.85 if label == 0 else 0.55, 0.08)),
        "nback_dprime":            float(rng.normal(2.2 if label == 0 else 1.0, 0.4)),
        "nback_level": 2,
        "total_words": 10,
    }

    # ============== TMT (presented as cognitive features) ==============
    tmt_a = float(rng.normal(30 if label == 0 else 65, 8))
    tmt_b = float(rng.normal(70 if label == 0 else 180, 25))
    tmt_features = {
        # Mark CDT as not present (so heuristic uses TMT-only)
        "cdt_score": 0,
        # TMT-related fields  (TMT timing roughly maps to Stroop RT in heuristic)
        "stroop_accuracy":         float(rng.normal(0.88 if label == 0 else 0.70, 0.05)),
        "stroop_interference":     float(tmt_b - tmt_a),
        "stroop_avg_rt":           float(tmt_b * 10),  # convert s -> ms-like scale
        "stroop_congruent_accuracy":   float(rng.normal(0.95 if label == 0 else 0.80, 0.04)),
        "stroop_incongruent_accuracy": float(rng.normal(0.85 if label == 0 else 0.55, 0.06)),
        "tmt_a_time": tmt_a,
        "tmt_b_time": tmt_b,
        "tmt_b_over_a": tmt_b / max(tmt_a, 1.0),
        "tmt_errors_b": int(rng.normal(1 if label == 0 else 4, 1.5)),
        "recall_accuracy":         float(rng.normal(0.75 if label == 0 else 0.50, 0.10)),
        "recognition_accuracy":    float(rng.normal(0.80 if label == 0 else 0.55, 0.08)),
        "nback_accuracy":          float(rng.normal(0.80 if label == 0 else 0.55, 0.06)),
        "nback_dprime":            float(rng.normal(2.0 if label == 0 else 1.0, 0.4)),
        "nback_level": 2,
        "total_words": 10,
    }

    return {
        "label": label,
        "speech": speech,
        "cdt": cdt_features,
        "tmt": tmt_features,
    }


def build_test_set(n_samples: int, seed: int) -> List[Dict]:
    """Build a balanced synthetic test set."""
    rng = random.Random(seed)
    samples = []
    for i in range(n_samples):
        label = i % 2  # alternate healthy / AD
        samples.append(generate_synthetic_sample(label, seed + i))
    rng.shuffle(samples)
    return samples


# ==================== Inference ====================

async def predict_modality(category: str, features: Dict) -> Tuple[float, float]:
    """
    Run a single modality's prediction.
    Returns (ad_risk, confidence) both in [0, 100] / [0, 1].
    """
    try:
        predictor = get_predictor(category)
        ml_pred = await predictor.predict(features)
    except Exception as e:
        print(f"  [warn] {category} predictor failed: {e}; using clinical only.")
        ml_pred = None

    fusion = FusionService()
    result = await fusion.calculate_risk_scores(
        category=category,
        features=features,
        predictions=ml_pred,
    )
    # FusionService returns ad_risk / pd_risk in [0, 100]
    ad_risk = result.get("ad_risk", result.get("ad_risk_score", 0.0))
    confidence = result.get("confidence", 0.5)
    return float(ad_risk), float(confidence)


async def fuse_modalities(
    sample: Dict,
    use_speech: bool,
    use_cdt: bool,
    use_tmt: bool,
) -> float:
    """
    Run inference with only the selected modalities active and
    fuse them with confidence-weighted average.
    Returns AD risk in [0, 100].
    """
    risks: List[float] = []
    weights: List[float] = []

    if use_speech:
        r, c = await predict_modality("speech", sample["speech"])
        risks.append(r); weights.append(c)

    if use_cdt:
        # CDT is part of "cognitive" category in the codebase
        r, c = await predict_modality("cognitive", sample["cdt"])
        risks.append(r); weights.append(c)

    if use_tmt:
        # TMT is also part of "cognitive" category but uses different feature set
        r, c = await predict_modality("cognitive", sample["tmt"])
        risks.append(r); weights.append(c)

    if not risks:
        return 0.0

    weights_arr = np.array(weights)
    weights_arr = weights_arr / max(weights_arr.sum(), 1e-9)
    return float(np.dot(risks, weights_arr))


# ==================== Evaluation ====================

CONFIGS = [
    ("Speech only",     True,  False, False),
    ("CDT only",        False, True,  False),
    ("TMT only",        False, False, True),
    ("Speech + CDT",    True,  True,  False),
    ("Speech + TMT",    True,  False, True),
    ("CDT + TMT",       False, True,  True),
    ("Full (all 3)",    True,  True,  True),
]


async def run_ablation(test_set: List[Dict], threshold: float = 50.0):
    """Run all 7 configurations and compute metrics."""
    rows = []
    for name, s, c, t in CONFIGS:
        print(f"\nRunning config: {name} ...")
        preds, scores, truths = [], [], []
        for i, sample in enumerate(test_set):
            risk = await fuse_modalities(sample, s, c, t)
            preds.append(1 if risk > threshold else 0)
            scores.append(risk / 100.0)
            truths.append(sample["label"])
            if (i + 1) % 20 == 0:
                print(f"  processed {i+1}/{len(test_set)}")

        acc = accuracy_score(truths, preds)
        try:
            auc = roc_auc_score(truths, scores)
        except ValueError:
            auc = float("nan")
        f1 = f1_score(truths, preds, zero_division=0)
        prec = precision_score(truths, preds, zero_division=0)
        rec = recall_score(truths, preds, zero_division=0)

        rows.append({
            "config": name,
            "accuracy": round(acc, 4),
            "auc": round(auc, 4) if not np.isnan(auc) else "N/A",
            "f1": round(f1, 4),
            "precision": round(prec, 4),
            "recall": round(rec, 4),
        })
        print(f"  {name}: acc={acc:.3f}  auc={auc:.3f}  f1={f1:.3f}")

    return rows


def save_csv(rows: List[Dict], path: Path):
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    print(f"\nSaved CSV: {path}")


def print_table(rows: List[Dict]):
    print("\n" + "=" * 80)
    print(f"{'Configuration':<20}{'Accuracy':>12}{'AUC':>10}{'F1':>10}{'Prec':>10}{'Recall':>10}")
    print("=" * 80)
    for r in rows:
        print(f"{r['config']:<20}{r['accuracy']:>12}{str(r['auc']):>10}{r['f1']:>10}{r['precision']:>10}{r['recall']:>10}")
    print("=" * 80)


def plot_results(rows: List[Dict], path: Path):
    try:
        import matplotlib.pyplot as plt
    except ImportError:
        print("matplotlib not installed — skipping plot")
        return

    names = [r["config"] for r in rows]
    accs = [r["accuracy"] for r in rows]
    f1s = [r["f1"] for r in rows]

    x = np.arange(len(names))
    w = 0.35
    fig, ax = plt.subplots(figsize=(11, 5))
    ax.bar(x - w/2, accs, w, label="Accuracy", color="#4A90E2")
    ax.bar(x + w/2, f1s,  w, label="F1",       color="#E67E22")
    ax.set_ylabel("Score")
    ax.set_title("Modality Ablation — NeuroVerse AD Detection")
    ax.set_xticks(x)
    ax.set_xticklabels(names, rotation=20, ha="right")
    ax.legend()
    ax.set_ylim(0, 1.05)
    ax.grid(axis="y", linestyle="--", alpha=0.4)
    fig.tight_layout()
    fig.savefig(path, dpi=200)
    print(f"Saved plot: {path}")


# ==================== Main ====================

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--samples", type=int, default=60, help="Test set size")
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--threshold", type=float, default=50.0)
    args = parser.parse_args()

    print(f"Building synthetic test set: {args.samples} samples (seed={args.seed})")
    test_set = build_test_set(args.samples, args.seed)

    rows = asyncio.run(run_ablation(test_set, threshold=args.threshold))

    print_table(rows)
    save_csv(rows, OUTPUT_DIR / "modality_ablation.csv")
    plot_results(rows, OUTPUT_DIR / "modality_ablation.png")

    print("\nDone.")


if __name__ == "__main__":
    main()
