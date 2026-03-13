"""
TMT Notebook Fix Script — v2
Fixes:
1. NACC TMT column candidates: add TRAILA/TRAILB (the correct time columns)
2. NACC TMT error candidates: add TRAILARR/TRAILBRR 
3. ADNI APOE parsing: handle GENOTYPE column ("3/4" format)
4. Remove ALL duplicate APOE blocks (loading, row building, feature engineering)
5. Fix NACC shuffle alignment bug
6. Prioritize written TMT over Oral TMT in fallback scanning
"""
import json, sys
sys.stdout.reconfigure(encoding='utf-8')

NB_PATH = r'd:\neuroverse\notebooks\cognitive_tmt_training.ipynb'

with open(NB_PATH, 'r', encoding='utf-8') as f:
    nb = json.load(f)

def find_cell_idx(keyword, cell_type='code'):
    for i, cell in enumerate(nb['cells']):
        src = ''.join(cell.get('source', []))
        if keyword in src and cell['cell_type'] == cell_type:
            return i
    return None

def get_source(idx):
    return ''.join(nb['cells'][idx].get('source', []))

def set_source(idx, text):
    lines = text.split('\n')
    nb_lines = []
    for j, line in enumerate(lines):
        nb_lines.append(line + '\n' if j < len(lines) - 1 else line)
    nb['cells'][idx]['source'] = nb_lines

changes = []

# DEBUG: dump first 200 chars of each cell to see raw format
for i, cell in enumerate(nb['cells'][:10]):
    src = ''.join(cell.get('source', []))
    print(f"[{i}] {cell['cell_type']:8s} {repr(src[:100])}")

# Also dump the NACC TMT candidates area
nacc_test = find_cell_idx('NACC Data Integration')
if nacc_test is not None:
    s = get_source(nacc_test)
    # Find TMT_A_CANDIDATES
    idx_a = s.find('TMT_A_CANDIDATES')
    if idx_a >= 0:
        print(f"\n--- TMT_A_CANDIDATES context (pos {idx_a}) ---")
        print(repr(s[idx_a:idx_a+200]))
    # Find APOE extract
    idx_apoe = s.find('APOE4 (strongest')
    if idx_apoe >= 0:
        print(f"\n--- APOE4 extract context (pos {idx_apoe}) ---")
        count = s.count('APOE4 (strongest')
        print(f"Occurrences: {count}")
        print(repr(s[idx_apoe:idx_apoe+200]))

# ADNI APOE detect area  
adni_test = find_cell_idx('Cell 4 · Load ADNI Data')
if adni_test is not None:
    s = get_source(adni_test)
    idx_det = s.find('Detect APOE4')
    if idx_det >= 0:
        print(f"\n--- ADNI APOE detect context ---")
        print(repr(s[idx_det:idx_det+300]))
    # Check duplicates
    for marker, name in [
        ("Step 1c': Load APOE", "APOE loading"),
        ('row["apoe4"]', "APOE row"),
        ("APOE4 genetic risk features", "APOE feat eng"),
        ('"apoe4": float(np.nan)', "APOE NaN"),
    ]:
        count = s.count(marker)
        print(f"  {name}: {count} occurrences")

sys.exit(0)  # stop before actual patching

# ═══════════════════════════════════════════════════════════════
# FIX 1: ADNI Cell — Remove duplicate APOE blocks + fix GENOTYPE parsing
# ═══════════════════════════════════════════════════════════════
adni_idx = find_cell_idx('Cell 4 · Load ADNI Data')
if adni_idx is not None:
    src = get_source(adni_idx)
    
    # Count occurrences of duplicate markers
    apoe_loading_count = src.count("# ── Step 1c': Load APOE genotype")
    apoe_row_count = src.count('# ── APOE4 genotype (0/1/2')
    apoe_feat_count = src.count('# ── APOE4 genetic risk features')
    apoe_nan_count = src.count('"apoe4": float(np.nan),')
    
    print(f"ADNI cell duplicates: APOE loading={apoe_loading_count}, "
          f"APOE row={apoe_row_count}, APOE feat={apoe_feat_count}, "
          f"APOE nan={apoe_nan_count}")
    
    # --- Remove 2nd APOE loading block ---
    marker = "\n# ── Step 1c': Load APOE genotype"
    first_pos = src.find(marker)
    if first_pos >= 0:
        second_pos = src.find(marker, first_pos + 1)
        if second_pos >= 0:
            # Find end of 2nd block (next "# ── Step 1d" or next section)
            end_marker = "# ── Step 1d: Load NEUROBAT CSV"
            end_pos = src.find(end_marker, second_pos)
            if end_pos >= 0:
                src = src[:second_pos] + '\n' + src[end_pos:]
                changes.append("Removed duplicate APOE loading block from ADNI cell")
    
    # --- Remove 2nd APOE row building ---
    marker2 = "        # ── APOE4 genotype (0/1/2"
    first_pos = src.find(marker2)
    if first_pos >= 0:
        second_pos = src.find(marker2, first_pos + 1)
        if second_pos >= 0:
            # Find end: next line starting with "        rows.append" or blank line
            end_search = src[second_pos:]
            # The duplicate block is: comment + rid_int + row["apoe4"] = 3 lines
            lines_from = end_search.split('\n')
            # Count how many lines to remove (comment + 2 code lines)
            remove_lines = []
            for k, line in enumerate(lines_from[:5]):
                if k == 0 or 'rid_int' in line or 'row["apoe4"]' in line:
                    remove_lines.append(line)
                else:
                    break
            remove_text = '\n'.join(remove_lines)
            src = src[:second_pos] + src[second_pos + len(remove_text):]
            changes.append("Removed duplicate APOE4 row building from ADNI cell")
    
    # --- Remove 2nd apoe4: float(np.nan) in synthetic fallback ---
    dup_nan = '                "apoe4": float(np.nan),\n                "apoe4": float(np.nan),'
    single_nan = '                "apoe4": float(np.nan),'
    if dup_nan in src:
        src = src.replace(dup_nan, single_nan)
        changes.append("Removed duplicate apoe4 NaN in synthetic fallback")
    
    # --- Remove 2nd APOE feature engineering block ---
    marker3 = "# ── APOE4 genetic risk features"
    first_pos = src.find(marker3)
    if first_pos >= 0:
        second_pos = src.find(marker3, first_pos + 1)
        if second_pos >= 0:
            # Find end of second APOE feat block (next "# ── Safety:" section)
            end_marker3 = "# ── Safety: drop any constant"
            end_pos3 = src.find(end_marker3, second_pos)
            if end_pos3 >= 0:
                src = src[:second_pos] + src[end_pos3:]
                changes.append("Removed duplicate APOE feature engineering from ADNI cell")
    
    # --- Fix APOE GENOTYPE parsing ---
    # The current code checks for APOE4/APGEN1/APOE4BIN columns.
    # APOERES.rda has 'GENOTYPE' column (single column with values like "3/3", "3/4", "4/4")
    old_apoe_detect = '''            # Detect APOE4 allele count column
            apoe4_col = next((c for c in ["APOE4", "APGEN1", "APOE4BIN"]
                              if c in apoe_df.columns), None)

            if apoe4_col:
                for _, row in apoe_df.iterrows():
                    rid = row.get("RID")
                    val = pd.to_numeric(row.get(apoe4_col), errors="coerce")
                    if pd.notna(rid) and pd.notna(val):
                        apoe_dict[int(rid)] = int(np.clip(val, 0, 2))
            else:
                # Try to compute from APGEN1/APGEN2 (3/3, 3/4, 4/4 etc.)
                gen1 = next((c for c in ["APGEN1", "GENOTYPE1"] if c in apoe_df.columns), None)
                gen2 = next((c for c in ["APGEN2", "GENOTYPE2"] if c in apoe_df.columns), None)
                if gen1 and gen2:
                    for _, row in apoe_df.iterrows():
                        rid = row.get("RID")
                        if pd.notna(rid):
                            a1 = str(row.get(gen1, ""))
                            a2 = str(row.get(gen2, ""))
                            n_e4 = (1 if "4" in a1 else 0) + (1 if "4" in a2 else 0)
                            apoe_dict[int(rid)] = n_e4'''
    
    new_apoe_detect = '''            # Detect APOE4 allele count column
            apoe4_col = next((c for c in ["APOE4", "APOE4BIN", "NACCNE4S"]
                              if c in apoe_df.columns), None)

            if apoe4_col:
                for _, row in apoe_df.iterrows():
                    rid = row.get("RID")
                    val = pd.to_numeric(row.get(apoe4_col), errors="coerce")
                    if pd.notna(rid) and pd.notna(val):
                        apoe_dict[int(rid)] = int(np.clip(val, 0, 2))
            else:
                # Try GENOTYPE column (APOERES.rda format: single column "3/4", "4/4" etc.)
                geno_col = next((c for c in ["GENOTYPE", "APGENOTYPE"]
                                 if c in apoe_df.columns), None)
                if geno_col:
                    print(f"   Parsing APOE from {geno_col} column (e.g. '3/4' format)...")
                    for _, row in apoe_df.iterrows():
                        rid = row.get("RID")
                        geno = str(row.get(geno_col, ""))
                        if pd.notna(rid) and "/" in geno:
                            try:
                                alleles = geno.strip().split("/")
                                n_e4 = sum(1 for a in alleles if a.strip() == "4")
                                apoe_dict[int(rid)] = n_e4
                            except (ValueError, TypeError):
                                pass
                else:
                    # Try APGEN1/APGEN2 (two separate allele columns)
                    gen1 = next((c for c in ["APGEN1", "GENOTYPE1"] if c in apoe_df.columns), None)
                    gen2 = next((c for c in ["APGEN2", "GENOTYPE2"] if c in apoe_df.columns), None)
                    if gen1 and gen2:
                        for _, row in apoe_df.iterrows():
                            rid = row.get("RID")
                            if pd.notna(rid):
                                a1 = str(row.get(gen1, ""))
                                a2 = str(row.get(gen2, ""))
                                n_e4 = (1 if "4" in a1 else 0) + (1 if "4" in a2 else 0)
                                apoe_dict[int(rid)] = n_e4'''
    
    if old_apoe_detect in src:
        src = src.replace(old_apoe_detect, new_apoe_detect)
        changes.append("Fixed APOE GENOTYPE parsing (handles '3/4' format from APOERES.rda)")
    else:
        print("  ⚠️ Could not find old APOE detect block — trying with relaxed matching")
        # Try to find just the key signature
        if 'apoe4_col = next((c for c in ["APOE4", "APGEN1"' in src:
            src = src.replace(
                'apoe4_col = next((c for c in ["APOE4", "APGEN1", "APOE4BIN"]',
                'apoe4_col = next((c for c in ["APOE4", "APOE4BIN", "NACCNE4S"]'
            )
            changes.append("Updated APOE4 column candidates")
    
    set_source(adni_idx, src)
    print(f"  ✅ ADNI cell patched ({len([c for c in changes if 'ADNI' in c or 'APOE' in c or 'apoe' in c or 'duplicate' in c.lower()])} changes)")
else:
    print("  ❌ ADNI cell not found!")

# ═══════════════════════════════════════════════════════════════
# FIX 2: NACC Cell — Fix TMT column candidates + remove duplicate APOE + fix shuffle
# ═══════════════════════════════════════════════════════════════
nacc_idx = find_cell_idx('NACC Data Integration')
if nacc_idx is not None:
    src = get_source(nacc_idx)
    
    # --- Fix TMT column candidates ---
    # Add TRAILA/TRAILB which are the ACTUAL NACC UDS TMT time columns
    old_tmt_a = '''    TMT_A_CANDIDATES = ["TRTEFFA", "TRATEFFI", "TRAILSA", "TRAASCOR",
                        "TMTASEC", "TRAILATI", "TRLA"]'''
    new_tmt_a = '''    # NACC UDS3: TRAILA (Part A time, seconds), TRAILB (Part B time, seconds)
    # NACC UDS1/2: TRAILSA, TRAILSB
    # ADNI: TRAASCOR, TRABSCOR
    TMT_A_CANDIDATES = ["TRAILA", "TRAILSA", "TRTEFFA", "TRAASCOR",
                        "TMTASEC", "TRAILATI", "TRLA"]'''
    
    old_tmt_b = '''    TMT_B_CANDIDATES = ["TRTEFFB", "TRTEFFI", "TRAILSB", "TRABSCOR",
                        "TMTBSEC", "TRAILBTI", "TRLB"]'''
    new_tmt_b = '''    TMT_B_CANDIDATES = ["TRAILB", "TRAILSB", "TRTEFFB", "TRABSCOR",
                        "TMTBSEC", "TRAILBTI", "TRLB"]'''
    
    old_tmt_a_err = '''    TMT_A_ERR_CANDIDATES = ["TRATEERR", "TRTEFAE", "TRAILAE", "TMTAERR"]'''
    new_tmt_a_err = '''    TMT_A_ERR_CANDIDATES = ["TRAILARR", "TRATEERR", "TRTEFAE", "TRAILAE", "TMTAERR"]'''
    
    old_tmt_b_err = '''    TMT_B_ERR_CANDIDATES = ["TRTEERR", "TRTEFFBE", "TRAILBE", "TMTBERR"]'''
    new_tmt_b_err = '''    TMT_B_ERR_CANDIDATES = ["TRAILBRR", "TRTEERR", "TRTEFFBE", "TRAILBE", "TMTBERR"]'''
    
    for old, new, name in [
        (old_tmt_a, new_tmt_a, "TMT-A candidates"),
        (old_tmt_b, new_tmt_b, "TMT-B candidates"),
        (old_tmt_a_err, new_tmt_a_err, "TMT-A error candidates"),
        (old_tmt_b_err, new_tmt_b_err, "TMT-B error candidates"),
    ]:
        if old in src:
            src = src.replace(old, new)
            changes.append(f"Fixed NACC {name} (added TRAILA/TRAILB)")
        else:
            print(f"  ⚠️ Could not find {name} marker")
    
    # --- Fix fallback scanning to skip Oral TMT (OTRAILA/OTRAILB) ---
    old_fallback = '''        # Look for numeric columns with TMT-like value ranges
        for col in tmt_all_cols:
            vals = pd.to_numeric(nacc[col], errors="coerce").dropna()
            vals = vals[(vals > 0) & (vals < 900)]
            if len(vals) > 1000:
                median = vals.median()
                # TMT-A typical range: 20-120s (median ~35-50)
                # TMT-B typical range: 50-300s (median ~80-120)
                if not TMT_A_COL and 20 < median < 80:
                    if "B" not in col.upper()[-3:]:  # avoid Part B columns
                        TMT_A_COL = col
                        print(f"      → Detected TMT-A time: {col} (median={median:.0f}s)")
                elif not TMT_B_COL and 50 < median < 200:
                    if "A" not in col.upper()[-3:]:
                        TMT_B_COL = col
                        print(f"      → Detected TMT-B time: {col} (median={median:.0f}s)")'''
    
    new_fallback = '''        # Look for numeric columns with TMT-like value ranges
        # IMPORTANT: Skip "O" prefix columns (Oral TMT — different test!)
        #   OTRAILA/OTRAILB = Oral Trail Making Test (verbal, no pen)
        #   TRAILA/TRAILB   = Written Trail Making Test (what we need)
        written_cols = [c for c in tmt_all_cols if not c.upper().startswith("O")]
        # If no written cols found, use all (but prefer written)
        scan_cols = written_cols if written_cols else tmt_all_cols
        for col in scan_cols:
            vals = pd.to_numeric(nacc[col], errors="coerce").dropna()
            vals = vals[(vals > 0) & (vals < 900)]
            if len(vals) > 1000:
                median = vals.median()
                # TMT-A typical range: 20-120s (median ~35-50)
                # TMT-B typical range: 50-300s (median ~80-120)
                if not TMT_A_COL and 20 < median < 80:
                    if "B" not in col.upper()[-3:]:  # avoid Part B columns
                        TMT_A_COL = col
                        print(f"      → Detected TMT-A time: {col} (median={median:.0f}s)")
                elif not TMT_B_COL and 50 < median < 200:
                    if "A" not in col.upper()[-3:]:
                        TMT_B_COL = col
                        print(f"      → Detected TMT-B time: {col} (median={median:.0f}s)")'''
    
    if old_fallback in src:
        src = src.replace(old_fallback, new_fallback)
        changes.append("Fixed fallback TMT scanning to skip Oral TMT (OTRAILA/OTRAILB)")
    else:
        print("  ⚠️ Could not find fallback scanning block")
    
    # --- Remove duplicate APOE4 extraction in NACC cell ---
    apoe_extract_marker = "            # APOE4 (strongest genetic AD risk factor"
    first_pos = src.find(apoe_extract_marker)
    if first_pos >= 0:
        second_pos = src.find(apoe_extract_marker, first_pos + 1)
        if second_pos >= 0:
            # Find end of duplicate block (next line that doesn't start with space+code)
            end_search = src[second_pos:]
            lines = end_search.split('\n')
            # The block is: comment + apoe4=0 + if APOE_COL + try + val + apoe4=clip + except + pass
            # Find next line after the "pass" that belongs to the main flow
            remove_end = 0
            in_try = False
            for k, line in enumerate(lines):
                stripped = line.strip()
                if k == 0:
                    continue
                if 'apoe4 = 0' in line:
                    continue
                if 'if APOE_COL' in line:
                    continue
                if 'try:' in stripped:
                    in_try = True
                    continue
                if in_try and stripped in ('pass', ''):
                    if stripped == 'pass':
                        remove_end = k + 1
                        break
                    continue
                if in_try:
                    continue
                if stripped == '':
                    continue
                break
            
            if remove_end > 0:
                remove_text = '\n'.join(lines[:remove_end])
                src = src[:second_pos] + src[second_pos + len(remove_text):]
                changes.append("Removed duplicate APOE4 extraction from NACC cell")
            else:
                # Brute force: find exact duplicate text
                block_end = src.find('\n            b_over_a', second_pos)
                if block_end >= 0:
                    src = src[:second_pos] + src[block_end:]
                    changes.append("Removed duplicate APOE4 extraction from NACC cell (brute)")
    
    # --- Fix NACC shuffle alignment ---
    old_nacc_shuffle = '''        df = df.sample(frac=1, random_state=CFG.RANDOM_SEED).reset_index(drop=True)
        patient_rids = patient_rids.loc[df.index].reset_index(drop=True)'''
    new_nacc_shuffle = '''        shuffle_idx = df.sample(frac=1, random_state=CFG.RANDOM_SEED).index
        df = df.loc[shuffle_idx].reset_index(drop=True)
        patient_rids = patient_rids.loc[shuffle_idx].reset_index(drop=True)'''
    
    if old_nacc_shuffle in src:
        src = src.replace(old_nacc_shuffle, new_nacc_shuffle)
        changes.append("Fixed NACC shuffle alignment bug")
    
    set_source(nacc_idx, src)
    print(f"  ✅ NACC cell patched")
else:
    print("  ❌ NACC cell not found!")

# ═══════════════════════════════════════════════════════════════
# Save
# ═══════════════════════════════════════════════════════════════
with open(NB_PATH, 'w', encoding='utf-8') as f:
    json.dump(nb, f, indent=1, ensure_ascii=False)

print(f"\n{'='*60}")
print(f"✅ Notebook saved with {len(changes)} fixes:")
for i, c in enumerate(changes, 1):
    print(f"   {i}. {c}")
print(f"{'='*60}")
