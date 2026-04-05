"""
Saliency Generator – GradCAM, Integrated Gradients for image/tabular models.

Methods used (from training notebooks):
  - GradCAM / GradCAM++: target_layer = model.backbone.conv_head (MotorNet, CDTNet)
  - Integrated Gradients: 50-step integration (Captum-based)
  - LIME: superpixel explanations for images

For tabular data (speech, cognitive) we generate feature-bar saliency.
For image data (motor spiral/meander, CDT clock drawing) we generate heatmaps.
"""

import logging
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)


class SaliencyGenerator:
    """
    Generate saliency maps and visual explanations.

    Output types:
      - "feature_bars":  Bar chart data for tabular features
      - "heatmap":       2D heatmap overlaid on drawing/image
      - "audio_waveform": Highlighted regions on audio spectrogram
      - "spiral_path":   Highlighted stroke segments on spiral drawing
    """

    def generate(
        self,
        category: str,
        features: Dict[str, Any],
        predictions: Optional[Dict[str, Any]] = None,
        model=None,
        input_tensor=None,
    ) -> Optional[Dict[str, Any]]:
        """
        Generate saliency data appropriate for the test category.

        Returns a dict matching the SaliencyData schema:
            {"type": str, "data": dict, "highlights": list}
        """
        if category == "speech":
            return self._speech_saliency(features, predictions)
        elif category == "cognitive":
            return self._cognitive_saliency(features, predictions)
        elif category == "motor":
            return self._motor_saliency(features, predictions, model, input_tensor)
        elif category == "facial":
            return self._facial_saliency(features, predictions)
        return None

    # ------------------------------------------------------------------ #
    # Speech saliency (audio waveform + feature bars)                    #
    # ------------------------------------------------------------------ #
    def _speech_saliency(self, features: dict, predictions: Optional[dict]) -> Dict[str, Any]:
        attn = (predictions or {}).get("attention_weights", {})

        # Top contributing features from attention weights
        feature_bars = []
        for feat, val in sorted(attn.items(), key=lambda x: abs(x[1]), reverse=True)[:10]:
            feature_bars.append({
                "feature": feat,
                "weight": round(float(val), 4),
                "value": round(float(features.get(feat, 0)), 4),
                "direction": "risk" if val > 0.5 else "protective",
            })

        # Fallback: if no attention weights, build bars from key speech features
        if not feature_bars:
            speech_metrics = {
                "Speech Rate": features.get("speech_rate", 0),
                "Pause Count": features.get("pause_count", 0),
                "Pause Rate": features.get("pause_rate", 0),
                "Voice Jitter": features.get("jitter", 0),
                "Voice Shimmer": features.get("shimmer", 0),
                "HNR": features.get("hnr", 0),
                "Pitch (F0)": features.get("f0_mean", 0),
                "Pitch Variation": features.get("f0_std", 0),
                "Voice Stability": features.get("vowel_stability", 0),
                "Story Recall": features.get("story_recall_accuracy", 0),
            }
            for name, val in speech_metrics.items():
                if val != 0:
                    feature_bars.append({"feature": name, "weight": round(float(val), 4)})

        highlights = []
        # Highlight pauses (AD indicator)
        if features.get("pause_count", 0) > 10:
            highlights.append({
                "type": "pause_regions",
                "description": "Excessive pauses detected – potential word-finding difficulty",
                "severity": "warning",
            })
        # Highlight voice quality (PD indicator)
        if features.get("jitter", 0) > 0.02 or features.get("shimmer", 0) > 0.05:
            highlights.append({
                "type": "voice_quality",
                "description": "Voice irregularity detected – potential motor speech issue",
                "severity": "info",
            })
        # Highlight low HNR (PD indicator)
        if 0 < features.get("hnr", 20) < 10:
            highlights.append({
                "type": "low_hnr",
                "description": "Low harmonics-to-noise ratio suggests breathy or hoarse voice",
                "severity": "info",
            })
        # Highlight reduced pitch variation (PD monotone speech)
        if 0 < features.get("f0_std", 30) < 10:
            highlights.append({
                "type": "monotone_speech",
                "description": "Reduced pitch variation – possible monotone speech pattern",
                "severity": "info",
            })

        return {
            "type": "audio_waveform",
            "data": {"feature_bars": feature_bars, "attention_weights": attn},
            "highlights": highlights,
        }

    # ------------------------------------------------------------------ #
    # Cognitive saliency (domain breakdown)                              #
    # ------------------------------------------------------------------ #
    def _cognitive_saliency(self, features: dict, predictions: Optional[dict]) -> Dict[str, Any]:
        domains = {
            "Attention": features.get("stroop_accuracy", 0),
            "Executive Function": 1.0 - min(features.get("stroop_interference", 0) / 500, 1.0),
            "Working Memory": features.get("nback_accuracy", 0),
            "Episodic Memory": features.get("recall_accuracy", 0),
            "Processing Speed": 1.0 - min(features.get("processing_speed_ms", 800) / 2000, 1.0),
        }

        # TMT-based domains
        if features.get("_has_tmt_data"):
            tmt_b = features.get("tmt_b_time", 0)
            domains["Trail Making (B)"] = max(0, 1.0 - min(tmt_b / 300, 1.0))
            tmt_a = features.get("tmt_a_time", 0)
            if tmt_a > 0 and tmt_b > 0:
                domains["Executive Flexibility"] = max(0, 1.0 - min((tmt_b / tmt_a) / 5.0, 1.0))
            domains["Motor Planning"] = features.get("path_efficiency", 0.5)

        # CDT-based domains
        if features.get("_has_cdt_image") or features.get("shulman_score", 0) > 0:
            shulman = features.get("shulman_score", 3)
            domains["Visuospatial"] = min(shulman / 5.0, 1.0)
            domains["Clock Drawing"] = features.get("number_accuracy", 0.8)

        feature_bars = []
        for domain, score in sorted(domains.items(), key=lambda x: x[1]):
            feature_bars.append({
                "feature": domain,
                "weight": round(score, 3),
                "status": "normal" if score >= 0.7 else "warning" if score >= 0.5 else "concern",
            })

        highlights = []
        composite = features.get("cognitive_composite", 0.5)
        if composite < 0.5:
            highlights.append({
                "type": "cognitive_decline",
                "description": "Overall cognitive composite below expected range",
                "severity": "warning",
            })

        # TMT highlights
        tmt_b = features.get("tmt_b_time", 0)
        if tmt_b > 180:
            highlights.append({
                "type": "tmt_slow",
                "description": f"TMT-B time ({tmt_b:.0f}s) exceeds normal range",
                "severity": "warning",
            })
        if features.get("errors_b", 0) > 3:
            highlights.append({
                "type": "tmt_errors",
                "description": "Elevated TMT-B errors suggest difficulty with set-shifting",
                "severity": "info",
            })

        # CDT highlights
        shulman = features.get("shulman_score", 5)
        if 0 < shulman <= 2:
            highlights.append({
                "type": "cdt_impaired",
                "description": f"Clock Drawing score ({shulman}/5) indicates visuospatial impairment",
                "severity": "warning",
            })

        return {
            "type": "cognitive_radar",
            "data": {"domain_scores": domains, "feature_bars": feature_bars},
            "highlights": highlights,
        }

    # ------------------------------------------------------------------ #
    # Motor saliency (spiral path + GradCAM placeholder)                 #
    # ------------------------------------------------------------------ #
    def _motor_saliency(
        self, features: dict, predictions: Optional[dict],
        model=None, input_tensor=None,
    ) -> Dict[str, Any]:
        # If we have a loaded model + image tensor, attempt GradCAM
        heatmap = None
        if model is not None and input_tensor is not None:
            heatmap = self._try_gradcam(model, input_tensor)

        feature_bars = []
        motor_features = {
            "Tremor Amplitude": features.get("tremor_amplitude", 0),
            "Spiral Tremor": features.get("spiral_tremor", 0),
            "Meander Tremor": features.get("meander_tremor", 0),
            "Spiral Deviation": features.get("spiral_deviation", 0),
            "Meander Deviation": features.get("meander_deviation", 0),
            "Spiral Tightness": features.get("spiral_tightness", 0),
            "Meander Smoothness": features.get("meander_smoothness", 0),
            "Tapping Rate": features.get("tapping_rate", 0),
            "Tapping Regularity": features.get("tapping_regularity", 0),
            "Motor Fatigue": features.get("tapping_fatigue", 0),
        }
        for name, val in motor_features.items():
            feature_bars.append({"feature": name, "weight": round(float(val), 4)})

        highlights = []
        if features.get("spiral_tremor", 0) > 0.5:
            highlights.append({
                "type": "tremor_detected",
                "description": "Tremor pattern identified in spiral drawing",
                "severity": "warning",
            })
        if features.get("meander_tremor", 0) > 0.5:
            highlights.append({
                "type": "meander_tremor",
                "description": "Tremor pattern identified in meander drawing",
                "severity": "warning",
            })
        if features.get("tremor_amplitude", 0) > 0.5:
            highlights.append({
                "type": "resting_tremor",
                "description": "Elevated resting tremor detected from accelerometer",
                "severity": "warning",
            })
        if features.get("tremor_pd_freq_match", 0) > 0.5:
            highlights.append({
                "type": "pd_frequency",
                "description": "Tremor frequency (4-6 Hz) matches Parkinsonian pattern",
                "severity": "warning",
            })
        if features.get("tapping_fatigue", 0) > 0.4:
            highlights.append({
                "type": "motor_fatigue",
                "description": "Progressive slowing detected in tapping sequence",
                "severity": "info",
            })

        data: Dict[str, Any] = {"feature_bars": feature_bars}
        if heatmap is not None:
            data["gradcam_heatmap"] = heatmap

        return {
            "type": "spiral_path",
            "data": data,
            "highlights": highlights,
        }

    # ------------------------------------------------------------------ #
    # Gait saliency                                                      #
    # ------------------------------------------------------------------ #
    def _gait_saliency(self, features: dict, predictions: Optional[dict]) -> Dict[str, Any]:
        metrics = {
            "Step Regularity": features.get("step_regularity", 0),
            "Gait Speed": features.get("gait_speed", 0),
            "Turn Stability": features.get("turn_stability", 0),
            "Balance": features.get("balance_stability", 0),
        }
        feature_bars = [{"feature": k, "weight": round(v, 4)} for k, v in metrics.items()]
        highlights = []
        if features.get("step_regularity", 1) < 0.5:
            highlights.append({
                "type": "gait_irregularity",
                "description": "Irregular walking pattern detected",
                "severity": "warning",
            })
        return {"type": "gait_pattern", "data": {"feature_bars": feature_bars}, "highlights": highlights}

    # ------------------------------------------------------------------ #
    # Facial saliency                                                    #
    # ------------------------------------------------------------------ #
    def _facial_saliency(self, features: dict, predictions: Optional[dict]) -> Dict[str, Any]:
        metrics = {
            "Blink Rate": features.get("blink_rate", 15),
            "Smile Speed": features.get("smile_velocity", 0.5),
            "Smile Intensity": features.get("smile_intensity", 0.5),
            "Expression Range": features.get("expression_range", 70),
            "Facial Masking": features.get("hypomimia_score", 30),
            "Facial Symmetry": features.get("facial_symmetry", 90),
            "Expressivity": features.get("facial_expressivity", 60),
            "Smile Symmetry": features.get("smile_symmetry", 85),
        }
        feature_bars = [{"feature": k, "weight": round(float(v), 4)} for k, v in metrics.items()]
        highlights = []
        if features.get("blink_rate", 15) < 10:
            highlights.append({
                "type": "hypomimia",
                "description": "Reduced blink rate may indicate facial masking (hypomimia)",
                "severity": "warning",
            })
        if features.get("smile_velocity", 0.5) < 0.3:
            highlights.append({
                "type": "bradykinesia",
                "description": "Slow smile movement may indicate facial bradykinesia",
                "severity": "warning",
            })
        if features.get("expression_range", 70) < 40:
            highlights.append({
                "type": "reduced_expression",
                "description": "Limited facial expression range detected",
                "severity": "info",
            })
        if features.get("hypomimia_score", 30) > 60:
            highlights.append({
                "type": "facial_masking",
                "description": "High facial masking score — reduced spontaneous expression",
                "severity": "warning",
            })
        if features.get("facial_symmetry", 90) < 70:
            highlights.append({
                "type": "asymmetry",
                "description": "Facial asymmetry detected — may indicate unilateral motor involvement",
                "severity": "info",
            })
        return {"type": "facial_regions", "data": {"feature_bars": feature_bars}, "highlights": highlights}

    # ------------------------------------------------------------------ #
    # GradCAM (when model + input are available)                         #
    # ------------------------------------------------------------------ #
    @staticmethod
    def _try_gradcam(model, input_tensor) -> Optional[List[List[float]]]:
        """
        Attempt GradCAM computation.
        Returns a 7×7 heatmap as nested list, or None on failure.
        """
        try:
            import torch

            # Find the target layer (conv_head for EfficientNet-based models)
            target_layer = None
            if hasattr(model, "backbone"):
                for name, layer in model.backbone.named_children():
                    if name == "conv_head" or name == "features":
                        target_layer = layer
                        break
            if target_layer is None:
                return None

            activations = []
            gradients = []

            def fwd_hook(module, inp, out):
                activations.append(out)

            def bwd_hook(module, grad_in, grad_out):
                gradients.append(grad_out[0])

            fwd_handle = target_layer.register_forward_hook(fwd_hook)
            bwd_handle = target_layer.register_full_backward_hook(bwd_hook)

            model.eval()
            input_tensor.requires_grad_(True)
            output = model(input_tensor)

            # Use risk output as target
            if isinstance(output, dict):
                target = output.get("risk", output.get("logits", None))
                if target is None:
                    target = list(output.values())[0]
            else:
                target = output

            if target.dim() > 1:
                target = target.sum(dim=-1)

            model.zero_grad()
            target.backward(torch.ones_like(target))

            fwd_handle.remove()
            bwd_handle.remove()

            if not activations or not gradients:
                return None

            act = activations[0]
            grad = gradients[0]

            # Global average pooling of gradients
            weights = grad.mean(dim=[2, 3], keepdim=True) if grad.dim() == 4 else grad.mean(dim=-1, keepdim=True)
            cam = (weights * act).sum(dim=1, keepdim=True)
            cam = torch.relu(cam)

            # Resize to 7x7
            if cam.dim() == 4:
                cam = torch.nn.functional.interpolate(cam, size=(7, 7), mode="bilinear", align_corners=False)
                cam = cam.squeeze().detach().cpu().numpy()
            else:
                cam = cam.squeeze().detach().cpu().numpy()

            # Normalize to [0, 1]
            cam_min, cam_max = cam.min(), cam.max()
            if cam_max - cam_min > 1e-8:
                cam = (cam - cam_min) / (cam_max - cam_min)

            return cam.tolist()

        except Exception as exc:
            logger.warning("GradCAM computation failed: %s", exc)
            return None
