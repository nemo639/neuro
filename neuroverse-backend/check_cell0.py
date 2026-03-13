import json, sys
sys.stdout.reconfigure(encoding='utf-8')

NB = r'd:\neuroverse\notebooks\cognitive_tmt_training.ipynb'
with open(NB, 'r', encoding='utf-8') as f:
    nb = json.load(f)

c = nb['cells'][0]
print(f"Cell 0 type: {c['cell_type']}")
print(f"First line: {c['source'][0][:60]}")
