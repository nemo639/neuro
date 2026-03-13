"""
Attention Visualizer – Visualize model attention weights and patterns.

Methods:
  - SpeechNeuroNet attention: 35-d feature attention weights
  - EfficientNet attention: Spatial attention from backbone features
  - Self-attention patterns: For transformer-based models (future)

Produces structured data for frontend visualization.
"""

import logging
from typing import Any, Dict, List, Optional

logger = logging.getLogger(__name__)


class AttentionVisualizer:
    """
    Visualize and interpret model attention patterns.

    Output types:
      - "feature_attention": Bar chart of feature attention weights
      - "spatial_attention": 2D heatmap from image model attention
      - "attention_flow": Attention flow diagram (multi-head attention)
    """

    def visualize_feature_attention(
        self,
        attention_weights: Dict[str, float],
        features: Dict[str, Any],
        category: str = "",
    ) -> Dict[str, Any]:
        """
        Visualize feature-level attention (e.g., SpeechNeuroNet attention head).

        Returns structured data for frontend bar chart / radar visualization.
        """
        if not attention_weights:
            return {"type": "feature_attention", "data": [], "summary": "No attention data available"}

        # Sort by absolute attention weight
        sorted_attn = sorted(
            attention_weights.items(),
            key=lambda x: abs(x[1]),
            reverse=True,
        )

        # Compute statistics
        total = sum(abs(v) for _, v in sorted_attn) or 1.0
        mean_attn = total / len(sorted_attn) if sorted_attn else 0

        attention_bars = []
        for feat_name, weight in sorted_attn[:20]:
            feat_val = features.get(feat_name, 0.0)
            if not isinstance(feat_val, (int, float)):
                feat_val = 0.0

            relative_importance = abs(weight) / total
            attention_bars.append({
                "feature": feat_name,
                "attention_weight": round(float(weight), 4),
                "feature_value": round(float(feat_val), 4),
                "relative_importance": round(float(relative_importance), 4),
                "activated": abs(weight) > mean_attn,
                "contribution": round(float(weight * feat_val), 4),
                "category": self._classify_feature(feat_name),
            })

        # Group by feature category
        groups = {}
        for bar in attention_bars:
            cat = bar["category"]
            if cat not in groups:
                groups[cat] = {"total_attention": 0, "features": []}
            groups[cat]["total_attention"] += abs(bar["attention_weight"])
            groups[cat]["features"].append(bar["feature"])

        # Top attended features summary
        top3 = [b["feature"] for b in attention_bars[:3]]
        summary = f"Model focuses most on: {', '.join(top3)}"

        return {
            "type": "feature_attention",
            "data": attention_bars,
            "groups": groups,
            "summary": summary,
            "statistics": {
                "total_features": len(sorted_attn),
                "mean_attention": round(float(mean_attn), 4),
                "top_feature": sorted_attn[0][0] if sorted_attn else None,
                "attention_entropy": round(self._entropy(sorted_attn), 4),
            },
        }

    def visualize_spatial_attention(
        self,
        model=None,
        input_tensor=None,
        method: str = "gap",
    ) -> Optional[Dict[str, Any]]:
        """
        Extract spatial attention from image models (EfficientNet-B0).

        Methods:
          - "gap": Global Average Pooling activation map
          - "cam": Class Activation Map
        """
        if model is None or input_tensor is None:
            return None

        try:
            import torch

            model.eval()
            activations = []

            def hook_fn(module, inp, out):
                activations.append(out)

            # Find the last conv layer
            target_layer = None
            if hasattr(model, "backbone"):
                for name, layer in model.backbone.named_children():
                    if name in ("conv_head", "features"):
                        target_layer = layer
                        break

            if target_layer is None:
                return None

            handle = target_layer.register_forward_hook(hook_fn)

            with torch.no_grad():
                model(input_tensor)

            handle.remove()

            if not activations:
                return None

            act = activations[0]  # (B, C, H, W)

            # Global average across channels → spatial attention
            if act.dim() == 4:
                spatial = act.mean(dim=1).squeeze().detach().cpu().numpy()  # (H, W)

                # Normalize to [0, 1]
                s_min, s_max = spatial.min(), spatial.max()
                if s_max - s_min > 1e-8:
                    spatial = (spatial - s_min) / (s_max - s_min)

                # Resize to 7x7 for consistency
                import torch.nn.functional as F
                spatial_t = torch.tensor(spatial).unsqueeze(0).unsqueeze(0).float()
                spatial_7x7 = F.interpolate(spatial_t, size=(7, 7), mode="bilinear", align_corners=False)
                heatmap = spatial_7x7.squeeze().numpy().tolist()

                # Find hot spots
                hotspots = []
                for i in range(7):
                    for j in range(7):
                        if heatmap[i][j] > 0.7:
                            hotspots.append({"row": i, "col": j, "intensity": round(heatmap[i][j], 3)})

                return {
                    "type": "spatial_attention",
                    "heatmap": heatmap,
                    "hotspots": hotspots,
                    "method": method,
                    "resolution": "7x7",
                }

            return None

        except Exception as exc:
            logger.warning("Spatial attention visualization failed: %s", exc)
            return None

    def generate_attention_summary(
        self,
        category: str,
        attention_data: Dict[str, Any],
        predictions: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        Generate a human-readable attention analysis summary.
        """
        data = attention_data.get("data", [])
        if not data:
            return {
                "narrative": "Attention analysis not available for this prediction.",
                "key_findings": [],
            }

        findings = []

        # Find dominant feature groups
        groups = attention_data.get("groups", {})
        if groups:
            top_group = max(groups.items(), key=lambda x: x[1]["total_attention"])
            findings.append({
                "finding": f"The model paid most attention to {top_group[0]} features",
                "significance": "high",
            })

        # Check for concentrated vs distributed attention
        stats = attention_data.get("statistics", {})
        entropy = stats.get("attention_entropy", 0)
        if entropy < 1.0:
            findings.append({
                "finding": "Attention is highly concentrated on a few features",
                "significance": "medium",
            })
        elif entropy > 2.5:
            findings.append({
                "finding": "Attention is distributed across many features",
                "significance": "low",
            })

        # Top feature analysis
        top_features = data[:3]
        for feat in top_features:
            if feat.get("activated") and abs(feat.get("contribution", 0)) > 0.1:
                direction = "increases" if feat["contribution"] > 0 else "decreases"
                findings.append({
                    "finding": f"{feat['feature']} strongly {direction} the risk estimate",
                    "significance": "high",
                })

        ad_risk = (predictions or {}).get("ad_risk", 0)
        pd_risk = (predictions or {}).get("pd_risk", 0)

        narrative = (
            f"For this {category} assessment, the model's attention mechanism "
            f"focused primarily on {stats.get('top_feature', 'multiple')} features. "
        )
        if ad_risk > pd_risk:
            narrative += "The attention pattern is consistent with AD-related biomarker emphasis."
        elif pd_risk > ad_risk:
            narrative += "The attention pattern is consistent with PD-related motor/voice emphasis."
        else:
            narrative += "The attention is balanced across AD and PD indicators."

        return {
            "narrative": narrative,
            "key_findings": findings,
            "attention_type": attention_data.get("type", "unknown"),
        }

    @staticmethod
    def _classify_feature(name: str) -> str:
        """Classify a feature into a domain category."""
        if any(k in name for k in ("stroop", "nback", "recall", "cognitive", "processing", "tmt", "path", "error")):
            return "cognitive"
        elif any(k in name for k in ("speech", "pause", "story", "word", "mfcc", "f0", "zcr", "spectral", "energy")):
            return "speech"
        elif any(k in name for k in ("jitter", "shimmer", "hnr", "vowel", "f1", "f2", "f3")):
            return "voice_quality"
        elif any(k in name for k in ("tapping", "spiral", "meander", "motor", "drawing", "tremor")):
            return "motor"
        elif any(k in name for k in ("step", "gait", "balance", "sway", "turn")):
            return "gait"
        elif any(k in name for k in ("blink", "smile", "facial")):
            return "facial"
        return "other"

    @staticmethod
    def _entropy(items: list) -> float:
        """Compute attention distribution entropy."""
        import math
        total = sum(abs(v) for _, v in items) or 1.0
        entropy = 0.0
        for _, v in items:
            p = abs(v) / total
            if p > 1e-10:
                entropy -= p * math.log2(p)
        return entropy
