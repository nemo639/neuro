import json, sys
sys.stdout.reconfigure(encoding='utf-8')
with open(r'd:\neuroverse\notebooks\cognitive_tmt_training.ipynb', 'r', encoding='utf-8') as f:
    nb = json.load(f)
for i, c in enumerate(nb['cells']):
    src = ''.join(c.get('source', []))[:80].replace('\n', ' ')
    cid = c.get('id', 'N/A')
    ct = c['cell_type']
    print(f"{i:2d}  {ct:8s}  id={cid:30s}  {src}")
