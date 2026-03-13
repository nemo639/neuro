"""Quick test of the comprehensive fusion engine."""
import sys, ast

# 1. Syntax check
with open('app/ml/fusion/multimodel_fusion.py', encoding='utf-8') as f:
    ast.parse(f.read())
print("Syntax OK")

# 2. Functional test
sys.path.insert(0, '.')
from app.ml.fusion.multimodel_fusion import NeuroVerseFusionEngine

engine = NeuroVerseFusionEngine()

scores = {
    'cdt_ad': 0.72, 'tmt_ad': 0.45, 'speech_ad': 0.60,
    'spiral_pd': 0.80, 'meander_pd': 0.75, 'speech_pd': 0.35,
}

result = engine.fuse(scores)
d = NeuroVerseFusionEngine.result_to_dict(result)

print(f"\nFinal: {d['final_classification']} (conf={d['final_confidence']})")
print(f"AD risk: {d['final_ad_risk']}, PD risk: {d['final_pd_risk']}")

print(f"\n--- AD Best ---")
b = d['ad']['best']
print(f"  Method: {b['method']}, Models: {b['models_used']}, Risk: {b['risk']}, Level: {b['combo_level']}")
print(f"  Reason: {d['ad']['best_reason']}")
print(f"  Method agreement: {d['ad']['method_agreement']}")

print(f"\n--- PD Best ---")
b = d['pd']['best']
print(f"  Method: {b['method']}, Models: {b['models_used']}, Risk: {b['risk']}, Level: {b['combo_level']}")
print(f"  Reason: {d['pd']['best_reason']}")

print(f"\n--- All AD combos ({len(d['ad']['all_combinations'])}) ---")
for c in d['ad']['all_combinations']:
    print(f"  {c['method']:18s} | {str(c['models_used']):30s} | {c['combo_level']:12s} | risk={c['risk']}")

print(f"\n--- All PD combos ({len(d['pd']['all_combinations'])}) ---")
for c in d['pd']['all_combinations']:
    print(f"  {c['method']:18s} | {str(c['models_used']):30s} | {c['combo_level']:12s} | risk={c['risk']}")

# Quick test
q = engine.fuse_quick(scores, method='bayesian')
print(f"\nQuick Bayesian: AD={q['ad_risk']}, PD={q['pd_risk']}, class={q['classification']}")

q2 = engine.fuse_quick(scores, method='weighted_avg')
print(f"Quick WeightedAvg: AD={q2['ad_risk']}, PD={q2['pd_risk']}, class={q2['classification']}")

q3 = engine.fuse_quick(scores, method='dempster_shafer')
print(f"Quick D-S: AD={q3['ad_risk']}, PD={q3['pd_risk']}, class={q3['classification']}")

# Partial test (only 1 model)
partial = engine.fuse({'cdt_ad': 0.85})
pd2 = NeuroVerseFusionEngine.result_to_dict(partial)
print(f"\nPartial (CDT only): AD={pd2['final_ad_risk']}, class={pd2['final_classification']}")

print("\nAll tests passed!")
