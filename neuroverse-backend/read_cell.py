import json, sys
sys.stdout.reconfigure(encoding='utf-8')

NB = r'd:\neuroverse\notebooks\cognitive_tmt_training.ipynb'
with open(NB, 'r', encoding='utf-8') as f:
    nb = json.load(f)

# List all cells with IDs
for i, cell in enumerate(nb['cells']):
    cid = cell.get('id', 'NO_ID')
    src = ''.join(cell.get('source', []))
    lines = cell.get('source', [])
    preview = src[:90].replace('\n', ' ').strip()
    print(f"[{i:2d}] {cell['cell_type']:8s} id={cid:20s} lines={len(lines):3d}  {preview}")
