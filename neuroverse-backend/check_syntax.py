import json, ast, sys
sys.stdout.reconfigure(encoding='utf-8')

with open(r'd:\neuroverse\notebooks\cognitive_tmt_training.ipynb', 'r', encoding='utf-8') as f:
    nb = json.load(f)

errors = 0
for idx, cell in enumerate(nb['cells']):
    if cell['cell_type'] != 'code':
        continue
    src = ''.join(cell['source'])
    if not src.strip():
        continue
    # Skip cells with Colab magic commands (!pip etc)
    if src.strip().startswith('!') or '\n!' in src:
        print(f'Cell {idx}: SKIP (Colab magic commands)')
        continue
    try:
        ast.parse(src)
        print(f'Cell {idx}: OK ({len(cell["source"])} lines)')
    except SyntaxError as e:
        errors += 1
        print(f'Cell {idx}: SYNTAX ERROR at line {e.lineno}: {e.msg}')
        lines = src.split('\n')
        start = max(0, e.lineno - 4)
        end = min(len(lines), e.lineno + 3)
        for j in range(start, end):
            marker = '>>>' if j == e.lineno - 1 else '   '
            print(f'  {marker} L{j+1}: {lines[j]}')

print(f'\n{"ALL CELLS OK" if errors == 0 else f"{errors} ERRORS FOUND"}')
