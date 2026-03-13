"""
NeuroVerse Comprehensive Multi-Model Fusion Engine
====================================================

Tests ALL fusion strategies across ALL model combinations:

  ▸ 3 Fusion Methods:
    1. Weighted Average   (AUC-proportional)
    2. Bayesian Sequential (likelihood-ratio updates with prevalence priors)
    3. Dempster-Shafer    (evidence theory with explicit uncertainty)

  ▸ All Combination Levels:
    • Individual  (each model alone)
    • Pairs       (every combination of 2)
    • Triples     (every combination of 3)
    • All         (all available models)

  ▸ Automatic Best-Method Selection:
    Compares all combos, picks the most robust by confidence + agreement.

Models:
  AD detectors:  CDT (AUC 0.989), TMT (AUC 0.857), Speech-AD (AUC 0.967)
  PD detectors:  Spiral (AUC 0.955), Meander (AUC 0.971), Speech-PD (AUC 0.922)

Usage:
    engine = NeuroVerseFusionEngine()
    result = engine.fuse({
        "cdt_ad": 0.72, "tmt_ad": 0.45, "speech_ad": 0.60,
        "spiral_pd": 0.80, "meander_pd": 0.75, "speech_pd": 0.35,
    })
    # result.best  →  FusionResult with the most robust combo
    # result.all_combinations  →  full breakdown
"""

from __future__ import annotations

import json
import logging
import math
from dataclasses import dataclass, field
from itertools import combinations
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np

logger = logging.getLogger(__name__)

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Real AUCs from held-out test sets
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

MODEL_AUCS: Dict[str, Dict[str, float]] = {
    "ad": {
        "cdt":    0.989,
        "tmt":    0.857,
        "speech": 0.967,
    },
    "pd": {
        "spiral":  0.955,
        "meander": 0.971,
        "speech":  0.922,
    },
}

# Epidemiological prevalence priors (used by Bayesian method)
#   AD: ~10% prevalence in 65+ population (Alzheimer's Association, 2023)
#   PD: ~1-2% prevalence in 60+ population (GBD 2019)
PRIOR_AD = 0.10
PRIOR_PD = 0.015


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Data Classes
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

@dataclass
class FusionResult:
    """Single fusion computation result."""
    risk: float                          # 0→1 fused risk
    classification: str                  # "Positive" or "Healthy"
    confidence: float                    # 0→1
    method: str                          # "weighted_avg" | "bayesian" | "dempster_shafer"
    models_used: List[str]               # e.g. ["cdt", "tmt"]
    combo_level: str                     # "individual" | "pair" | "triple" | "all"
    contributions: Dict[str, float]      # per-model contribution
    weights: Dict[str, float]            # per-model weight used


@dataclass
class TaskFusionResult:
    """Fusion results for one task (AD or PD) across all methods & combos."""
    task: str                            # "ad" or "pd"
    best: FusionResult                   # most robust result
    best_reason: str                     # why this was chosen
    all_combinations: List[FusionResult] # every combo tested
    method_agreement: Dict[str, float]   # agreement score per method
    combo_agreement: Dict[str, float]    # agreement score per combo level


@dataclass
class ComprehensiveFusionResult:
    """Complete fusion output for a patient."""
    ad: TaskFusionResult
    pd: TaskFusionResult
    final_classification: str            # "AD", "PD", "Healthy"
    final_confidence: float
    final_ad_risk: float                 # from best AD combo
    final_pd_risk: float                 # from best PD combo
    models_available: List[str]
    disclaimer: str = (
        "SCREENING TOOL ONLY — does not constitute a medical diagnosis. "
        "Consult a qualified healthcare professional for clinical assessment."
    )


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Fusion Methods
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def _weighted_average(
    scores: Dict[str, float],
    aucs: Dict[str, float],
) -> Tuple[float, Dict[str, float], Dict[str, float]]:
    """
    Method 1: AUC-proportional weighted average.

    w_i = max(AUC_i - 0.5, 0) / Σ max(AUC_j - 0.5, 0)
    Risk = Σ w_i * p_i

    Returns (fused_risk, contributions, weights).
    """
    avail = {k: v for k, v in scores.items() if k in aucs}
    if not avail:
        return 0.5, {}, {}

    raw_w = {k: max(aucs[k] - 0.5, 0.0) for k in avail}
    total = sum(raw_w.values())
    if total == 0:
        norm = {k: 1.0 / len(raw_w) for k in raw_w}
    else:
        norm = {k: w / total for k, w in raw_w.items()}

    risk = sum(norm[k] * avail[k] for k in avail)
    contribs = {k: round(norm[k] * avail[k], 4) for k in avail}
    norm = {k: round(v, 4) for k, v in norm.items()}
    return float(np.clip(risk, 0, 1)), contribs, norm


def _bayesian_fusion(
    scores: Dict[str, float],
    aucs: Dict[str, float],
    prior: float,
) -> Tuple[float, Dict[str, float], Dict[str, float]]:
    """
    Method 2: Bayesian Sequential Update.

    Start with epidemiological prior P(Disease).
    For each model i, compute the reliability-weighted likelihood ratio:

        LR_i = p_i / (1 - p_i)
        LR_i_weighted = LR_i ^ w_i    where w_i = (AUC_i - 0.5) normalised

    Then sequential Bayes update:
        posterior_odds = prior_odds × Π LR_i_weighted
        P(Disease | models) = posterior_odds / (1 + posterior_odds)

    Returns (posterior_risk, contributions, weights).
    """
    avail = {k: v for k, v in scores.items() if k in aucs}
    if not avail:
        return prior, {}, {}

    # Reliability weights
    raw_w = {k: max(aucs[k] - 0.5, 0.0) for k in avail}
    total = sum(raw_w.values())
    if total == 0:
        norm = {k: 1.0 / len(raw_w) for k in raw_w}
    else:
        norm = {k: w / total for k, w in raw_w.items()}

    # Start with prior odds
    prior_odds = prior / max(1.0 - prior, 1e-10)
    log_odds = math.log(max(prior_odds, 1e-10))

    contribs: Dict[str, float] = {}
    for model, prob in avail.items():
        # Clip to avoid log(0)
        p = float(np.clip(prob, 0.01, 0.99))
        lr = p / (1.0 - p)
        w = norm[model]

        # Weighted log-likelihood ratio
        weighted_log_lr = w * math.log(max(lr, 1e-10))
        log_odds += weighted_log_lr

        contribs[model] = round(weighted_log_lr, 4)

    # Convert log-odds back to probability (logistic function)
    posterior = 1.0 / (1.0 + math.exp(-log_odds))
    posterior = float(np.clip(posterior, 0, 1))

    norm = {k: round(v, 4) for k, v in norm.items()}
    return posterior, contribs, norm


def _dempster_shafer(
    scores: Dict[str, float],
    aucs: Dict[str, float],
) -> Tuple[float, Dict[str, float], Dict[str, float]]:
    """
    Method 3: Dempster-Shafer Evidence Theory.

    Each model provides a basic probability assignment (BPA):
        m_i(Disease)  = p_i × r_i         (evidence FOR)
        m_i(Healthy)  = (1-p_i) × r_i     (evidence AGAINST)
        m_i(Θ)        = 1 - r_i           (uncertainty)

    where r_i = AUC_i - 0.5 (0→0.5 reliability scale).

    Combine using Dempster's rule of combination.

    Returns (belief_disease, contributions, weights).
    """
    avail = {k: v for k, v in scores.items() if k in aucs}
    if not avail:
        return 0.5, {}, {}

    # Compute per-model BPAs
    bpas = []
    contribs: Dict[str, float] = {}
    for model, prob in avail.items():
        r = min(aucs[model] - 0.5, 0.5)  # reliability 0→0.5
        r = max(r, 0.01)
        p = float(np.clip(prob, 0.01, 0.99))

        m_disease = p * r
        m_healthy = (1.0 - p) * r
        m_theta = 1.0 - r  # uncertainty

        bpas.append({
            "disease": m_disease,
            "healthy": m_healthy,
            "theta": m_theta,
        })
        contribs[model] = round(m_disease, 4)

    # Combine BPAs using Dempster's rule iteratively
    combined = bpas[0].copy()
    for i in range(1, len(bpas)):
        combined = _combine_dempster(combined, bpas[i])

    belief_disease = combined["disease"]
    # Plausibility = belief + uncertainty
    plausibility = combined["disease"] + combined["theta"]

    # Use pignistic probability (midpoint of belief interval)
    risk = (belief_disease + plausibility) / 2.0
    risk = float(np.clip(risk, 0, 1))

    # Weights are just AUC-proportional for display
    raw_w = {k: max(aucs[k] - 0.5, 0.0) for k in avail}
    total = sum(raw_w.values())
    norm = {k: round(w / max(total, 1e-10), 4) for k, w in raw_w.items()}

    return risk, contribs, norm


def _combine_dempster(m1: dict, m2: dict) -> dict:
    """Combine two BPAs using Dempster's rule."""
    keys = ["disease", "healthy", "theta"]

    products: Dict[str, float] = {"disease": 0, "healthy": 0, "theta": 0}
    conflict = 0.0

    for k1 in keys:
        for k2 in keys:
            product = m1[k1] * m2[k2]
            if k1 == k2:
                products[k1] += product
            elif k1 == "theta":
                products[k2] += product
            elif k2 == "theta":
                products[k1] += product
            else:
                # disease ∩ healthy = ∅ → conflict
                conflict += product

    # Normalise (Dempster's rule)
    norm_factor = 1.0 - conflict
    if norm_factor < 1e-10:
        return {"disease": 0.0, "healthy": 0.0, "theta": 1.0}

    return {
        "disease": products["disease"] / norm_factor,
        "healthy": products["healthy"] / norm_factor,
        "theta": products["theta"] / norm_factor,
    }


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Combination Generator
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def _generate_combinations(
    available_models: List[str],
) -> List[Tuple[str, List[str]]]:
    """
    Generate all combinations at every level:
      individual (1), pairs (2), triples (3), ... up to all.
    """
    combos: List[Tuple[str, List[str]]] = []
    n = len(available_models)

    level_names = {1: "individual", 2: "pair", 3: "triple"}

    for r in range(1, n + 1):
        level = level_names.get(r, f"group_{r}")
        if r == n and n > 1:
            level = "all"
        for combo in combinations(available_models, r):
            combos.append((level, list(combo)))

    return combos


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Robustness Scorer
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def _score_robustness(
    results: List[FusionResult],
    task: str,
) -> Tuple[FusionResult, str, Dict[str, float], Dict[str, float]]:
    """
    Score each combination for robustness and pick the best.

    Criteria (weighted):
      1. Confidence (30%)          — higher is better
      2. Method agreement (30%)    — if all 3 methods agree, more robust
      3. Number of models (20%)    — more evidence = more robust
      4. AUC quality (20%)         — higher combined AUC = more reliable
    """
    if not results:
        neutral = FusionResult(
            risk=0.5, classification="Healthy", confidence=0.0,
            method="none", models_used=[], combo_level="none",
            contributions={}, weights={},
        )
        return neutral, "No models available", {}, {}

    aucs = MODEL_AUCS.get(task, {})

    # Group by combo (same models) to compute cross-method agreement
    combo_groups: Dict[str, List[FusionResult]] = {}
    for r in results:
        key = ",".join(sorted(r.models_used))
        combo_groups.setdefault(key, []).append(r)

    scored: List[Tuple[float, FusionResult, str]] = []

    for r in results:
        combo_key = ",".join(sorted(r.models_used))
        group = combo_groups[combo_key]

        # 1. Confidence
        conf_score = r.confidence

        # 2. Method agreement
        if len(group) > 1:
            risks = [g.risk for g in group]
            spread = max(risks) - min(risks)
            agree_score = 1.0 - min(spread, 1.0)
        else:
            agree_score = 0.5

        # 3. Number of models
        n_models = len(r.models_used)
        max_models = len(aucs)
        model_score = n_models / max(max_models, 1)

        # 4. AUC quality
        used_aucs = [aucs.get(m, 0.5) for m in r.models_used]
        auc_score = (np.mean(used_aucs) - 0.5) * 2

        total = (
            0.30 * conf_score +
            0.30 * agree_score +
            0.20 * model_score +
            0.20 * auc_score
        )

        reason_parts = []
        if conf_score > 0.6:
            reason_parts.append(f"high confidence ({r.confidence:.2f})")
        if agree_score > 0.8:
            reason_parts.append("strong method agreement")
        if n_models == max_models:
            reason_parts.append("all models used")
        elif n_models > 1:
            reason_parts.append(f"{n_models} models combined")

        reason = "; ".join(reason_parts) if reason_parts else "default selection"
        scored.append((total, r, reason))

    scored.sort(key=lambda x: x[0], reverse=True)
    best_score, best_result, best_reason = scored[0]

    # Method agreement summary
    method_risks: Dict[str, List[float]] = {}
    for r in results:
        method_risks.setdefault(r.method, []).append(r.risk)

    method_agreement = {}
    if len(method_risks) > 1:
        method_means = {m: np.mean(rs) for m, rs in method_risks.items()}
        all_means = list(method_means.values())
        overall_spread = max(all_means) - min(all_means)
        for m in method_means:
            method_agreement[m] = round(1.0 - overall_spread, 3)
    else:
        for m in method_risks:
            method_agreement[m] = 1.0

    # Combo level agreement
    level_risks: Dict[str, List[float]] = {}
    for r in results:
        level_risks.setdefault(r.combo_level, []).append(r.risk)

    combo_agreement = {}
    for lvl, risks in level_risks.items():
        if len(risks) > 1:
            combo_agreement[lvl] = round(1.0 - (max(risks) - min(risks)), 3)
        else:
            combo_agreement[lvl] = 1.0

    return best_result, best_reason, method_agreement, combo_agreement


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Main Engine
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class NeuroVerseFusionEngine:
    """
    Comprehensive multi-model fusion engine.

    Tests 3 methods × all combinations, picks the most robust.
    """

    METHODS = {
        "weighted_avg":    "Weighted Average (AUC-proportional)",
        "bayesian":        "Bayesian Sequential Update",
        "dempster_shafer": "Dempster-Shafer Evidence Theory",
    }

    def __init__(
        self,
        config_path: Optional[str] = None,
        ad_threshold: float = 0.5,
        pd_threshold: float = 0.5,
    ):
        self.ad_threshold = ad_threshold
        self.pd_threshold = pd_threshold

        if config_path and Path(config_path).exists():
            self._load_config(config_path)
        else:
            self.model_aucs = MODEL_AUCS
            self.prior_ad = PRIOR_AD
            self.prior_pd = PRIOR_PD

    def _load_config(self, config_path: str) -> None:
        """Load config from JSON (exported by evaluation notebook)."""
        try:
            with open(config_path) as f:
                cfg = json.load(f)
            self.model_aucs = cfg.get("model_aucs", MODEL_AUCS)
            self.prior_ad = cfg.get("prior_ad", PRIOR_AD)
            self.prior_pd = cfg.get("prior_pd", PRIOR_PD)
            self.ad_threshold = cfg.get("ad_threshold", self.ad_threshold)
            self.pd_threshold = cfg.get("pd_threshold", self.pd_threshold)
            logger.info("Fusion config loaded from %s", config_path)
        except Exception as e:
            logger.warning("Config load failed (%s), using defaults", e)
            self.model_aucs = MODEL_AUCS
            self.prior_ad = PRIOR_AD
            self.prior_pd = PRIOR_PD

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    #  Main API
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    def fuse(
        self,
        model_scores: Dict[str, float],
    ) -> ComprehensiveFusionResult:
        """
        Run comprehensive fusion across all methods and combinations.

        Parameters
        ----------
        model_scores : dict
            Keys: "<model>_<task>" e.g. "cdt_ad", "spiral_pd", "speech_ad"
            Values: risk probabilities 0→1

        Returns
        -------
        ComprehensiveFusionResult with the best combination selected.
        """
        ad_scores: Dict[str, float] = {}
        pd_scores: Dict[str, float] = {}

        for key, score in model_scores.items():
            parts = key.rsplit("_", 1)
            if len(parts) != 2:
                continue
            model_name, task = parts
            s = float(np.clip(score, 0.0, 1.0))
            if task == "ad":
                ad_scores[model_name] = s
            elif task == "pd":
                pd_scores[model_name] = s

        ad_result = self._fuse_task("ad", ad_scores)
        pd_result = self._fuse_task("pd", pd_scores)

        ad_risk = ad_result.best.risk
        pd_risk = pd_result.best.risk
        final_class = self._classify(ad_risk, pd_risk)
        final_conf = max(ad_result.best.confidence, pd_result.best.confidence)

        all_models = sorted(set(list(ad_scores.keys()) + list(pd_scores.keys())))

        return ComprehensiveFusionResult(
            ad=ad_result,
            pd=pd_result,
            final_classification=final_class,
            final_confidence=round(final_conf, 4),
            final_ad_risk=round(ad_risk, 4),
            final_pd_risk=round(pd_risk, 4),
            models_available=all_models,
        )

    def fuse_quick(
        self,
        model_scores: Dict[str, float],
        method: str = "bayesian",
    ) -> Dict[str, Any]:
        """
        Quick fusion using a single method with all available models.
        Returns a simple dict for API responses.
        """
        ad_scores: Dict[str, float] = {}
        pd_scores: Dict[str, float] = {}

        for key, score in model_scores.items():
            parts = key.rsplit("_", 1)
            if len(parts) != 2:
                continue
            model_name, task = parts
            s = float(np.clip(score, 0.0, 1.0))
            if task == "ad":
                ad_scores[model_name] = s
            elif task == "pd":
                pd_scores[model_name] = s

        ad_aucs = self.model_aucs.get("ad", {})
        pd_aucs = self.model_aucs.get("pd", {})

        if method == "bayesian":
            ad_risk, ad_c, ad_w = _bayesian_fusion(ad_scores, ad_aucs, self.prior_ad)
            pd_risk, pd_c, pd_w = _bayesian_fusion(pd_scores, pd_aucs, self.prior_pd)
        elif method == "dempster_shafer":
            ad_risk, ad_c, ad_w = _dempster_shafer(ad_scores, ad_aucs)
            pd_risk, pd_c, pd_w = _dempster_shafer(pd_scores, pd_aucs)
        else:
            ad_risk, ad_c, ad_w = _weighted_average(ad_scores, ad_aucs)
            pd_risk, pd_c, pd_w = _weighted_average(pd_scores, pd_aucs)

        classification = self._classify(ad_risk, pd_risk)

        return {
            "ad_risk": round(ad_risk, 4),
            "pd_risk": round(pd_risk, 4),
            "classification": classification,
            "confidence": round(self._compute_confidence(ad_risk, pd_risk), 4),
            "method": method,
            "ad_contributions": ad_c,
            "pd_contributions": pd_c,
            "ad_weights": ad_w,
            "pd_weights": pd_w,
            "models_used": sorted(set(list(ad_scores.keys()) + list(pd_scores.keys()))),
        }

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    #  Internal: per-task fusion
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    def _fuse_task(
        self,
        task: str,
        scores: Dict[str, float],
    ) -> TaskFusionResult:
        """Run all 3 methods across all combinations for one task."""
        aucs = self.model_aucs.get(task, {})
        prior = self.prior_ad if task == "ad" else self.prior_pd
        threshold = self.ad_threshold if task == "ad" else self.pd_threshold

        available_models = [m for m in scores if m in aucs]
        all_combos = _generate_combinations(available_models)

        all_results: List[FusionResult] = []

        for combo_level, models in all_combos:
            subset = {m: scores[m] for m in models}
            subset_aucs = {m: aucs[m] for m in models}

            # ── Method 1: Weighted Average ──
            risk_wa, contrib_wa, weights_wa = _weighted_average(subset, subset_aucs)
            all_results.append(FusionResult(
                risk=round(risk_wa, 4),
                classification="Positive" if risk_wa >= threshold else "Healthy",
                confidence=round(self._compute_confidence_single(risk_wa), 4),
                method="weighted_avg",
                models_used=models,
                combo_level=combo_level,
                contributions=contrib_wa,
                weights=weights_wa,
            ))

            # ── Method 2: Bayesian ──
            risk_bay, contrib_bay, weights_bay = _bayesian_fusion(
                subset, subset_aucs, prior
            )
            all_results.append(FusionResult(
                risk=round(risk_bay, 4),
                classification="Positive" if risk_bay >= threshold else "Healthy",
                confidence=round(self._compute_confidence_single(risk_bay), 4),
                method="bayesian",
                models_used=models,
                combo_level=combo_level,
                contributions=contrib_bay,
                weights=weights_bay,
            ))

            # ── Method 3: Dempster-Shafer ──
            risk_ds, contrib_ds, weights_ds = _dempster_shafer(
                subset, subset_aucs
            )
            all_results.append(FusionResult(
                risk=round(risk_ds, 4),
                classification="Positive" if risk_ds >= threshold else "Healthy",
                confidence=round(self._compute_confidence_single(risk_ds), 4),
                method="dempster_shafer",
                models_used=models,
                combo_level=combo_level,
                contributions=contrib_ds,
                weights=weights_ds,
            ))

        best, reason, method_agree, combo_agree = _score_robustness(
            all_results, task
        )

        return TaskFusionResult(
            task=task,
            best=best,
            best_reason=reason,
            all_combinations=all_results,
            method_agreement=method_agree,
            combo_agreement=combo_agree,
        )

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    #  Classification helpers
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    def _classify(self, ad_risk: float, pd_risk: float) -> str:
        """Three-way classification."""
        if ad_risk >= self.ad_threshold and ad_risk >= pd_risk:
            return "AD"
        elif pd_risk >= self.pd_threshold and pd_risk > ad_risk:
            return "PD"
        return "Healthy"

    @staticmethod
    def _compute_confidence(ad_risk: float, pd_risk: float) -> float:
        """Confidence based on separation from decision boundary."""
        max_risk = max(ad_risk, pd_risk)
        margin = abs(max_risk - 0.5)
        return min(1.0, margin * 2)

    @staticmethod
    def _compute_confidence_single(risk: float) -> float:
        """Confidence for a single-task risk score."""
        return min(1.0, abs(risk - 0.5) * 2)

    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    #  Update & Serialization
    # ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    def update_aucs(self, new_aucs: Dict[str, Dict[str, float]]) -> None:
        """Update model AUCs after retraining."""
        for task in ("ad", "pd"):
            if task in new_aucs:
                self.model_aucs.setdefault(task, {}).update(new_aucs[task])
        logger.info("Model AUCs updated: %s", self.model_aucs)

    def to_dict(self) -> Dict[str, Any]:
        """Export engine configuration."""
        return {
            "model_aucs": self.model_aucs,
            "prior_ad": self.prior_ad,
            "prior_pd": self.prior_pd,
            "ad_threshold": self.ad_threshold,
            "pd_threshold": self.pd_threshold,
            "methods": list(self.METHODS.keys()),
        }

    @staticmethod
    def result_to_dict(result: ComprehensiveFusionResult) -> Dict[str, Any]:
        """Serialise ComprehensiveFusionResult to JSON-safe dict."""
        def _fr(r: FusionResult) -> dict:
            return {
                "risk": r.risk,
                "classification": r.classification,
                "confidence": r.confidence,
                "method": r.method,
                "models_used": r.models_used,
                "combo_level": r.combo_level,
                "contributions": r.contributions,
                "weights": r.weights,
            }

        def _tfr(tr: TaskFusionResult) -> dict:
            return {
                "task": tr.task,
                "best": _fr(tr.best),
                "best_reason": tr.best_reason,
                "all_combinations": [_fr(r) for r in tr.all_combinations],
                "method_agreement": tr.method_agreement,
                "combo_agreement": tr.combo_agreement,
            }

        return {
            "ad": _tfr(result.ad),
            "pd": _tfr(result.pd),
            "final_classification": result.final_classification,
            "final_confidence": result.final_confidence,
            "final_ad_risk": result.final_ad_risk,
            "final_pd_risk": result.final_pd_risk,
            "models_available": result.models_available,
            "disclaimer": result.disclaimer,
        }


# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  Singleton
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

_engine: Optional[NeuroVerseFusionEngine] = None


def get_fusion_engine(
    config_path: Optional[str] = None,
) -> NeuroVerseFusionEngine:
    """Get or create the singleton fusion engine."""
    global _engine
    if _engine is None:
        _engine = NeuroVerseFusionEngine(config_path=config_path)
    return _engine
