"""
Integrated Gradients – Attribution via path integration from baseline to input.

Method (Sundararajan et al., 2017):
  1. Choose a baseline (zero vector for tabular, black image for vision)
  2. Interpolate from baseline to input in N steps
  3. Compute gradients at each step
  4. Average gradients × (input - baseline) = attributions

Used for:
  - SpeechNeuroNet (35-d tabular) → per-feature attributions
  - MotorNet / CDTNet (224×224 image) → pixel-level attributions
"""

import logging
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)


class IntegratedGradientsExplainer:
    """
    Compute Integrated Gradients attributions for NeuroVerse models.

    When PyTorch model is available: real IG computation.
    When not: approximation using feature importance × gradient direction.
    """

    def compute_attributions(
        self,
        features: Dict[str, Any],
        predictions: Optional[Dict[str, Any]] = None,
        model=None,
        input_tensor=None,
        target_output: str = "ad_risk",
        n_steps: int = 50,
    ) -> List[Dict[str, Any]]:
        """
        Compute IG attributions for tabular input.

        Returns list of {feature, attribution, importance, direction}.
        """
        if model is not None and input_tensor is not None:
            return self._real_ig_tabular(model, input_tensor, features, target_output, n_steps)
        return self._approx_ig(features, predictions, target_output)

    def compute_image_attributions(
        self,
        model,
        input_tensor,
        target_output: str = "risk",
        n_steps: int = 50,
    ) -> Optional[List[List[float]]]:
        """
        Compute IG attributions for image input.
        Returns a heatmap as nested list (7×7), or None on failure.
        """
        try:
            import torch
            import torch.nn.functional as F

            model.eval()

            # Baseline: black image (zeros)
            baseline = torch.zeros_like(input_tensor)

            # Interpolation: baseline + alpha * (input - baseline)
            alphas = torch.linspace(0, 1, n_steps + 1, device=input_tensor.device)
            delta = input_tensor - baseline

            all_grads = []
            for alpha in alphas:
                interp = baseline + alpha * delta
                interp = interp.detach().requires_grad_(True)

                output = model(interp)
                if isinstance(output, dict):
                    target = output.get(target_output, output.get("risk", list(output.values())[0]))
                else:
                    target = output

                if target.dim() > 1:
                    target = target.sum(dim=-1)

                model.zero_grad()
                target.backward(torch.ones_like(target), retain_graph=False)

                if interp.grad is not None:
                    all_grads.append(interp.grad.detach().clone())
                interp.grad = None

            if not all_grads:
                return None

            # Average gradients
            avg_grads = torch.stack(all_grads).mean(dim=0)

            # IG attribution = (input - baseline) × avg_gradients
            attributions = delta * avg_grads

            # Sum across channels, take absolute value
            if attributions.dim() == 4:  # (B, C, H, W)
                attr_map = attributions.abs().sum(dim=1, keepdim=True)  # (B, 1, H, W)
                attr_map = F.interpolate(attr_map, size=(7, 7), mode="bilinear", align_corners=False)
                attr_map = attr_map.squeeze().detach().cpu().numpy()
            else:
                attr_map = attributions.abs().squeeze().detach().cpu().numpy()

            # Normalize to [0, 1]
            a_min, a_max = attr_map.min(), attr_map.max()
            if a_max - a_min > 1e-8:
                attr_map = (attr_map - a_min) / (a_max - a_min)

            return attr_map.tolist()

        except Exception as exc:
            logger.warning("Integrated Gradients image computation failed: %s", exc)
            return None

    def _real_ig_tabular(
        self,
        model,
        input_tensor,
        features: Dict[str, Any],
        target_output: str,
        n_steps: int,
    ) -> List[Dict[str, Any]]:
        """Compute real IG for tabular model (e.g., SpeechNeuroNet, TMTNet)."""
        try:
            import torch

            model.eval()
            baseline = torch.zeros_like(input_tensor)
            delta = input_tensor - baseline

            alphas = torch.linspace(0, 1, n_steps + 1, device=input_tensor.device)

            all_grads = []
            for alpha in alphas:
                interp = baseline + alpha * delta
                interp = interp.detach().requires_grad_(True)

                output = model(interp)
                if isinstance(output, dict):
                    target = output.get(target_output, output.get("ad_risk", list(output.values())[0]))
                else:
                    target = output

                if target.dim() > 1:
                    target = target.sum(dim=-1)
                elif target.dim() == 0:
                    target = target.unsqueeze(0)

                model.zero_grad()
                target.backward(torch.ones_like(target), retain_graph=False)

                if interp.grad is not None:
                    all_grads.append(interp.grad.detach().clone())
                interp.grad = None

            if not all_grads:
                return self._approx_ig(features, None, target_output)

            avg_grads = torch.stack(all_grads).mean(dim=0)
            attributions = (delta * avg_grads).squeeze().detach().cpu().numpy()

            # Map back to feature names
            feature_names = [k for k in features.keys()
                             if isinstance(features[k], (int, float)) and not k.startswith("_")]

            results = []
            for i, name in enumerate(feature_names):
                if i >= len(attributions):
                    break
                attr = float(attributions[i])
                results.append({
                    "feature": name,
                    "attribution": round(attr, 4),
                    "importance": round(abs(attr), 4),
                    "direction": "risk" if attr > 0 else "protective",
                })

            results.sort(key=lambda x: x["importance"], reverse=True)
            return results[:15]

        except Exception as exc:
            logger.warning("Real IG tabular computation failed: %s", exc)
            return self._approx_ig(features, None, target_output)

    def _approx_ig(
        self,
        features: Dict[str, Any],
        predictions: Optional[Dict[str, Any]] = None,
        target_output: str = "ad_risk",
    ) -> List[Dict[str, Any]]:
        """
        Approximate IG using feature magnitude and clinical direction.
        IG ≈ feature_value × direction_weight (from baseline of 0).
        """
        risk = (predictions or {}).get(target_output, (predictions or {}).get("ad_risk", 0))
        risk_scale = risk / 100.0 if risk > 1 else risk

        # Direction weights (positive = increases risk, negative = protective)
        directions = {
            # Cognitive
            "stroop_accuracy": -1.0, "nback_accuracy": -1.0, "recall_accuracy": -1.0,
            "cognitive_composite": -1.0, "story_recall_accuracy": -1.0,
            "stroop_interference": 1.0, "processing_speed_ms": 0.5,
            "stroop_avg_rt": 0.5, "stroop_error_rate": 0.6,
            "stroop_congruent_rt": 0.3, "stroop_incongruent_rt": 0.4,
            "nback_dprime": -0.7, "nback_hits": -0.5, "nback_false_alarms": 0.5,
            "recall_delayed_accuracy": -0.8, "recall_retention_rate": -0.7,
            "recall_intrusions": 0.6,
            # TMT
            "tmt_a_time": 0.5, "tmt_b_time": 0.6, "tmt_ba_ratio": 0.6,
            "errors_a": 0.3, "errors_b": 0.7, "sequence_errors_b": 0.5,
            "velocity_mean": -0.4, "velocity_std": 0.3, "path_efficiency": -0.5,
            "acceleration_mean": -0.3, "acceleration_std": 0.3,
            "jerk_mean": 0.3, "curvature_mean": -0.3, "curvature_std": 0.3,
            "straightness_ratio": -0.4, "spatial_accuracy": -0.4,
            "pen_lifts": 0.4, "hover_time": 0.3,
            "total_pause_duration": 0.4, "distance_variability": 0.3,
            # CDT
            "shulman_score": -0.8, "number_accuracy": -0.6,
            "center_deviation": 0.4, "drawing_time": 0.3,
            "clock_contour": -0.3, "numbers_correct": -0.5,
            # Speech
            "speech_rate": -0.5, "pause_count": 0.8, "pause_rate": 0.7,
            "mean_pause_duration": 0.5, "max_pause_duration": 0.4,
            "jitter": 0.8, "shimmer": 0.7, "vowel_stability": -0.6,
            "hnr": -0.5, "f0_mean": -0.3, "f0_std": -0.4,
            "story_coherence": -0.5, "word_count": -0.3, "unique_words": -0.3,
            "zcr_mean": 0.2, "energy_std": 0.2,
            "vowel_duration": -0.3, "vowel_amplitude_var": 0.3,
            "f1_mean": -0.2, "f2_mean": -0.2, "f3_mean": -0.2,
            # Motor
            "tapping_rate": -0.7, "tapping_regularity": -0.6, "tapping_fatigue": 0.7,
            "spiral_tremor": 0.9, "spiral_deviation": 0.5,
            "meander_tremor": 0.9, "meander_deviation": 0.5, "meander_smoothness": -0.6,
            "spiral_tightness": -0.5, "tremor_amplitude": 0.9, "tremor_rms": 0.7,
            "tremor_jerk": 0.6, "tremor_gyro_rms": 0.6, "tremor_frequency": 0.4,
            "tremor_pd_freq_match": 0.9, "tremor_asymmetry": 0.5,
            "spiral_tremor_score": 0.8, "meander_tremor_score": 0.8,
            "tapping_asymmetry": 0.5,
            "drawing_tremor_score": 0.7, "drawing_speed_variability": 0.5,
            # Facial
            "blink_rate": -0.4, "smile_velocity": -0.5, "smile_intensity": -0.5,
            "smile_symmetry": -0.3, "expression_range": -0.5,
            "hypomimia_score": 0.6, "facial_symmetry": -0.3,
            "facial_expressivity": -0.5, "symmetry_composite": -0.3,
            "muscle_tone": 0.3,
        }

        skip = {"category", "items_processed"}
        results = []

        for key, val in features.items():
            if key in skip or not isinstance(val, (int, float)) or key.startswith("_"):
                continue

            direction = directions.get(key, 0.1)
            # Approximate IG: value × direction × risk_scale
            norm = min(max(val, -1), 1) if -1 <= val <= 1 else val / max(abs(val) + 1, 1)
            attr = norm * direction * max(risk_scale, 0.1)

            results.append({
                "feature": key,
                "attribution": round(float(attr), 4),
                "importance": round(abs(float(attr)), 4),
                "direction": "risk" if attr > 0 else "protective",
            })

        results.sort(key=lambda x: x["importance"], reverse=True)
        return results[:15]
