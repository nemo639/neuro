"""
Run REAL binary classification evaluation of the trained speech model on a
stratified held-out test split (20%) of all_audio_features_final.csv.

Loads:
  - G:/My Drive/NeuroVerse_Models/speech/speech_model_best.pt
  - G:/My Drive/NeuroVerse_Models/speech/speech_scaler.json

The SpeechNeuroNet outputs a regression value in [0,1] for AD risk; we threshold
at 0.5 to obtain binary predictions and compute accuracy / AUC / F1 / precision /
recall against the ground-truth diagnostic label (HC=0, AD=1).

Usage:
    python ablation/eval_speech_only.py
"""
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import torch
from sklearn.metrics import (
    accuracy_score, roc_auc_score, f1_score, precision_score, recall_score
)
from sklearn.model_selection import train_test_split

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from app.ml.predictors.speech_predictor import SpeechNeuroNet

MODELS = Path(r"G:\My Drive\NeuroVerse_Models\speech")
DATA_CSV = MODELS / "data" / "all_audio_features_final.csv"
WEIGHTS  = MODELS / "speech_model_best.pt"
SCALER   = MODELS / "speech_scaler.json"

FEATURE_COLS = [
    "speech_rate", "pause_count", "mean_pause_duration", "max_pause_duration",
    "pause_rate", "speech_silence_ratio", "total_duration",
    *[f"mfcc_{i+1}_mean" for i in range(13)],
    "jitter", "shimmer", "hnr", "f0_mean", "f0_std",
    "f1_mean", "f2_mean", "f3_mean", "f1_std", "f2_std", "f3_std",
    "zcr_mean", "spectral_centroid_mean", "spectral_rolloff_mean", "energy_std",
]
assert len(FEATURE_COLS) == 35


def load_test_split(seed: int = 42):
    df = pd.read_csv(DATA_CSV, low_memory=False)
    df = df[df["group"].isin(["HC", "AD"])].copy()
    df["label"] = (df["group"] == "AD").astype(int)
    df = df.dropna(subset=FEATURE_COLS)
    X = df[FEATURE_COLS].values.astype(np.float32)
    y = df["label"].values.astype(int)

    _, X_test, _, y_test = train_test_split(
        X, y, test_size=0.20, random_state=seed, stratify=y
    )
    print(f"Loaded {len(df)} rows -> test set: {len(X_test)} ({int(y_test.sum())} AD, {len(y_test)-int(y_test.sum())} HC)")
    return X_test, y_test


def load_scaler():
    if not SCALER.exists():
        return None
    obj = json.loads(SCALER.read_text())
    mean = np.array(obj.get("mean", []), dtype=np.float32)
    std  = np.array(obj.get("std",  []), dtype=np.float32)
    if mean.size == 0 or std.size == 0:
        return None
    return mean, std


def load_model() -> SpeechNeuroNet:
    model = SpeechNeuroNet(input_dim=35)
    ckpt = torch.load(WEIGHTS, map_location="cpu", weights_only=False)
    state = ckpt.get("model_state_dict", ckpt) if isinstance(ckpt, dict) else ckpt
    model.load_state_dict(state, strict=False)
    model.eval()
    return model


def main():
    print(f"Loading data:    {DATA_CSV}")
    X_test, y_test = load_test_split()

    scaler = load_scaler()
    if scaler is not None:
        mean, std = scaler
        std_safe = np.where(std == 0, 1.0, std)
        X_test = (X_test - mean) / std_safe
        print(f"Applied scaler ({len(mean)}-D)")

    print(f"Loading weights: {WEIGHTS}")
    model = load_model()

    with torch.no_grad():
        x = torch.from_numpy(X_test).float()
        out = model(x)
        # SpeechNeuroNet returns a dict with 'ad_risk', 'pd_risk', 'attention'
        if isinstance(out, dict):
            ad_scores = out["ad_risk"].squeeze().cpu().numpy()
        elif isinstance(out, (tuple, list)):
            ad_scores = out[0].squeeze().cpu().numpy()
        else:
            ad_scores = out.squeeze().cpu().numpy()

    ad_scores = np.asarray(ad_scores).flatten().astype(float)
    # Some checkpoints may output sigmoid already in [0,1]; clip just in case
    ad_scores = np.clip(ad_scores, 0.0, 1.0)
    preds = (ad_scores > 0.5).astype(int)

    acc = accuracy_score(y_test, preds)
    try:
        auc = roc_auc_score(y_test, ad_scores)
    except ValueError:
        auc = float("nan")
    f1 = f1_score(y_test, preds, zero_division=0)
    prec = precision_score(y_test, preds, zero_division=0)
    rec = recall_score(y_test, preds, zero_division=0)
    mae = float(np.mean(np.abs(ad_scores - y_test)))

    print("\n" + "=" * 60)
    print("Speech model — Real Binary Classification (held-out 20% test)")
    print("=" * 60)
    print(f"  N             : {len(y_test)}")
    print(f"  Accuracy      : {acc:.4f}")
    print(f"  AUC           : {auc:.4f}")
    print(f"  F1            : {f1:.4f}")
    print(f"  Precision     : {prec:.4f}")
    print(f"  Recall        : {rec:.4f}")
    print(f"  Regression MAE: {mae:.4f}")
    print("=" * 60)

    # Save JSON
    out_path = ROOT / "ablation" / "results" / "speech_binary_eval.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps({
        "config": "Speech only (binary)",
        "n": int(len(y_test)),
        "accuracy": round(acc, 4),
        "auc": round(auc, 4) if not np.isnan(auc) else None,
        "f1": round(f1, 4),
        "precision": round(prec, 4),
        "recall": round(rec, 4),
        "regression_mae": round(mae, 4),
    }, indent=2))
    print(f"Saved: {out_path}")


if __name__ == "__main__":
    main()
