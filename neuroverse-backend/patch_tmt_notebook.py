"""
Patch TMT notebook to:
1. Add APOE4 loading to ADNI cell
2. Add APOE4 features to NACC cell
3. Make N_FEATURES_SELECT adaptive
4. Fix inference demo scaling
5. Fix patient_rids alignment
"""
import json, sys, copy
sys.stdout.reconfigure(encoding='utf-8')

NB_PATH = r'd:\neuroverse\notebooks\cognitive_tmt_training.ipynb'

with open(NB_PATH, 'r', encoding='utf-8') as f:
    nb = json.load(f)

changes_made = []

# ═══════════════════════════════════════════════════════════════
# Helper: find cell by content substring
# ═══════════════════════════════════════════════════════════════
def find_cell(keyword, cell_type='code'):
    for i, cell in enumerate(nb['cells']):
        src = ''.join(cell.get('source', []))
        if keyword in src and cell['cell_type'] == cell_type:
            return i
    return None

def set_cell_source(idx, new_source):
    """Replace cell source with new multiline string."""
    lines = new_source.split('\n')
    # Convert to notebook line format (each line ends with \n except last)
    nb_lines = []
    for j, line in enumerate(lines):
        if j < len(lines) - 1:
            nb_lines.append(line + '\n')
        else:
            nb_lines.append(line)
    nb['cells'][idx]['source'] = nb_lines

# ═══════════════════════════════════════════════════════════════
# PATCH 1: ADNI Cell — Add APOE4 loading + features
# ═══════════════════════════════════════════════════════════════
adni_idx = find_cell('Cell 4 · Load ADNI Data')
if adni_idx is not None:
    print(f"[PATCH 1] Found ADNI cell at index {adni_idx}")
    src = ''.join(nb['cells'][adni_idx].get('source', []))
    
    # 1a) Add APOE loading section after PTDEMOG loading
    apoe_loading_code = '''
# ── Step 1c': Load APOE genotype (strongest AD genetic risk factor) ──
# APOE ε4 allele count (0/1/2) increases AD risk 3-15×
# Check multiple potential sources in ADNIMERGE2 package
apoe_dict = {}  # RID → APOE4 allele count (0, 1, or 2)
apoe_rda_candidates = [
    dxsum_extract_dir / "ADNIMERGE2" / "data" / "APOERES.rda",
    dxsum_extract_dir / "ADNIMERGE2" / "data" / "APOEGEN.rda",
    dxsum_extract_dir / "ADNIMERGE2" / "data" / "APOE.rda",
]
APOE_LOADED = False

for apoe_path in apoe_rda_candidates:
    if apoe_path.exists():
        try:
            print(f"\\n🧬 Loading APOE from: {apoe_path.name}")
            result = pyreadr.read_r(str(apoe_path))
            apoe_df = result[list(result.keys())[0]]
            print(f"   Columns: {list(apoe_df.columns[:15])}")

            # Detect APOE4 allele count column
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
                            apoe_dict[int(rid)] = n_e4

            if apoe_dict:
                APOE_LOADED = True
                print(f"   ✅ APOE4 loaded for {len(apoe_dict):,} patients")
                e4_counts = list(apoe_dict.values())
                print(f"      ε4=0: {e4_counts.count(0):,} | ε4=1: {e4_counts.count(1):,} | ε4=2: {e4_counts.count(2):,}")
                break
        except Exception as e:
            print(f"   ⚠️  Error reading {apoe_path.name}: {e}")

# Also check if APOE info is embedded in PTDEMOG
if not APOE_LOADED and ptdemog_rda_path.exists():
    try:
        result = pyreadr.read_r(str(ptdemog_rda_path))
        ptd = result[list(result.keys())[0]]
        apoe_col_ptd = next((c for c in ["APOE4", "NACCNE4S", "APGEN1"]
                             if c in ptd.columns), None)
        if apoe_col_ptd:
            print(f"\\n🧬 Found APOE in PTDEMOG: {apoe_col_ptd}")
            for _, row in ptd.iterrows():
                rid = row.get("RID")
                val = pd.to_numeric(row.get(apoe_col_ptd), errors="coerce")
                if pd.notna(rid) and pd.notna(val):
                    apoe_dict[int(rid)] = int(np.clip(val, 0, 2))
            if apoe_dict:
                APOE_LOADED = True
                print(f"   ✅ APOE4 loaded for {len(apoe_dict):,} patients from PTDEMOG")
    except Exception:
        pass

if not APOE_LOADED:
    print(f"\\n⚠️  APOE genotype not found — will use default (0) for ADNI")
    print(f"   (NACC dataset provides APOE via NACCNE4S column)")
'''
    
    # Insert APOE loading before "# ── Step 1d: Load NEUROBAT CSV ──"
    marker = '# ── Step 1d: Load NEUROBAT CSV ──'
    if marker in src:
        src = src.replace(marker, apoe_loading_code + '\n' + marker)
        changes_made.append("Added APOE4 loading section to ADNI cell")
    else:
        print("  ⚠️ Could not find NEUROBAT marker in ADNI cell")
    
    # 1b) Add APOE4 to row building loop — after education_years line
    edu_marker = '        row["education_years"] = (float(r[edu_col]) if edu_col and edu_col in r.index\n                                   and pd.notna(r[edu_col]) else 14.0)'
    apoe_row_code = '''        row["education_years"] = (float(r[edu_col]) if edu_col and edu_col in r.index
                                   and pd.notna(r[edu_col]) else 14.0)

        # ── APOE4 genotype (0/1/2 ε4 alleles) ──
        rid_int = int(r["RID"])
        row["apoe4"] = float(apoe_dict.get(rid_int, np.nan))'''
    
    if edu_marker in src:
        src = src.replace(edu_marker, apoe_row_code)
        changes_made.append("Added APOE4 to ADNI row building")
    else:
        # Try without exact whitespace
        print("  ⚠️ Could not find education_years marker exactly — trying alternate")
        alt_marker = 'row["education_years"] = (float(r[edu_col])'
        if alt_marker in src:
            # Find the full line and replace
            lines = src.split('\n')
            new_lines = []
            for line in lines:
                new_lines.append(line)
                if 'row["education_years"]' in line and 'edu_col' in line:
                    # Check if it's a multi-line statement
                    if line.strip().endswith('else 14.0)'):
                        new_lines.append('')
                        new_lines.append('        # ── APOE4 genotype (0/1/2 ε4 alleles) ──')
                        new_lines.append('        rid_int = int(r["RID"])')
                        new_lines.append('        row["apoe4"] = float(apoe_dict.get(rid_int, np.nan))')
            src = '\n'.join(new_lines)
            changes_made.append("Added APOE4 to ADNI row building (alt)")
    
    # 1c) Add apoe4 to synthetic fallback
    synth_marker = '"age": age, "education_years": edu,'
    synth_replace = '"age": age, "education_years": edu,\n                "apoe4": float(np.nan),'
    if synth_marker in src:
        src = src.replace(synth_marker, synth_replace)
        changes_made.append("Added APOE4 NaN to synthetic fallback")
    
    # 1d) Add APOE4 diagnostics after age diagnostics
    age_diag_marker = '    if age_unique > 1:\n        print(f"      Range: {df[\'age\'].min():.0f}'
    if age_diag_marker in src:
        # Find the age diagnostics block end and insert after
        insert_pos = src.find(age_diag_marker)
        # Find the end of this if block
        next_else = src.find('\nelse:', insert_pos)
        next_blank = src.find('\n\n', insert_pos + len(age_diag_marker))
        
        # Insert APOE diagnostics
        apoe_diag = '''

    # APOE4 diagnostics
    apoe_valid = df["apoe4"].notna().sum() if "apoe4" in df.columns else 0
    apoe_pct = 100.0 * apoe_valid / len(df) if len(df) > 0 else 0
    print(f"   🧬 APOE4: {apoe_valid:,}/{len(df):,} patients ({apoe_pct:.1f}%) have genotype data")
    if apoe_valid > 0:
        print(f"      ε4=0: {(df[\\'apoe4\\']==0).sum():,} | ε4=1: {(df[\\'apoe4\\']==1).sum():,} | ε4=2: {(df[\\'apoe4\\']==2).sum():,}")
'''
        # Actually this is getting too complex with string escaping. Let me use a different approach.
    
    # 1e) Add APOE4 feature engineering after log_errors_b
    log_errors_marker = 'df["log_errors_b"]     = np.log1p(df["errors_b"])'
    apoe_feat_code = '''df["log_errors_b"]     = np.log1p(df["errors_b"])

# ── APOE4 genetic risk features ─────────────────────────────────────
# APOE ε4 is the strongest genetic risk factor for late-onset AD.
# Impute missing with median (typically 0 — most people have 0 ε4 alleles).
if "apoe4" in df.columns:
    apoe_missing = df["apoe4"].isna().sum()
    if apoe_missing > 0:
        apoe_median = df["apoe4"].median()
        if pd.isna(apoe_median):
            apoe_median = 0.0  # if ALL are NaN, default to 0
        df["apoe4"] = df["apoe4"].fillna(apoe_median)
        print(f"   🧬 APOE4: imputed {apoe_missing:,} missing values with median={apoe_median:.0f}")
    df["apoe4_positive"]   = (df["apoe4"] > 0).astype(float)
    df["apoe4_x_age"]      = df["apoe4"] * df["age"] / 100.0
    df["apoe4_x_tmt_b"]    = df["apoe4"] * df["tmt_b_time"] / 100.0
    print(f"   ✅ APOE4 features: apoe4, apoe4_positive, apoe4_x_age, apoe4_x_tmt_b")'''
    
    if log_errors_marker in src:
        src = src.replace(log_errors_marker, apoe_feat_code)
        changes_made.append("Added APOE4 feature engineering")
    
    # 1f) Fix patient_rids alignment bug
    old_shuffle = '''df = df.sample(frac=1, random_state=CFG.RANDOM_SEED).reset_index(drop=True)
patient_rids = patient_rids.loc[df.index].reset_index(drop=True)'''
    new_shuffle = '''shuffle_order = df.sample(frac=1, random_state=CFG.RANDOM_SEED).index
df = df.loc[shuffle_order].reset_index(drop=True)
patient_rids = patient_rids.loc[shuffle_order].reset_index(drop=True)'''
    
    if old_shuffle in src:
        src = src.replace(old_shuffle, new_shuffle)
        changes_made.append("Fixed patient_rids alignment in ADNI cell")
    
    # Write back
    set_cell_source(adni_idx, src)
    print(f"  ✅ ADNI cell patched ({len(changes_made)} changes)")
else:
    print("  ❌ ADNI cell not found!")

# ═══════════════════════════════════════════════════════════════
# PATCH 2: NACC Cell — Add APOE4 to feature building
# ═══════════════════════════════════════════════════════════════
nacc_idx = find_cell('NACC Data Integration')
if nacc_idx is not None:
    print(f"\n[PATCH 2] Found NACC cell at index {nacc_idx}")
    src = ''.join(nb['cells'][nacc_idx].get('source', []))
    
    # 2a) Add APOE4 computation before the row dict
    # Find the "# Log transforms" section in the NACC row building
    log_transform_marker = '                "log_tmt_a": float(np.log1p(ta)),'
    apoe_before_row = '''                "log_tmt_a": float(np.log1p(ta)),'''
    
    # Actually, let's find the last lines of the row dict and add APOE4 before the closing brace
    # The row dict ends with:
    #     "log_errors_b": float(np.log1p(eb)),
    # }
    
    row_end_marker = '                "log_errors_b": float(np.log1p(eb)),\n            }'
    
    apoe_in_nacc_row = '''                "log_errors_b": float(np.log1p(eb)),
                # ── APOE4 genetic risk ──
                "apoe4": int(apoe4),
                "apoe4_positive": 1.0 if apoe4 > 0 else 0.0,
                "apoe4_x_age": apoe4 * float(age) / 100.0,
                "apoe4_x_tmt_b": apoe4 * tb / 100.0,
            }'''
    
    if row_end_marker in src:
        src = src.replace(row_end_marker, apoe_in_nacc_row)
        changes_made.append("Added APOE4 to NACC row dict")
    else:
        print("  ⚠️ Could not find row dict end marker in NACC cell")
        # Try alternate
        alt_end = '"log_errors_b": float(np.log1p(eb)),'
        if alt_end in src:
            # Find position and look for closing brace
            pos = src.find(alt_end)
            remaining = src[pos + len(alt_end):]
            brace_pos = remaining.find('}')
            if brace_pos >= 0:
                old_section = alt_end + remaining[:brace_pos + 1]
                new_section = '''                "log_errors_b": float(np.log1p(eb)),
                # ── APOE4 genetic risk ──
                "apoe4": int(apoe4),
                "apoe4_positive": 1.0 if apoe4 > 0 else 0.0,
                "apoe4_x_age": apoe4 * float(age) / 100.0,
                "apoe4_x_tmt_b": apoe4 * tb / 100.0,
            }'''
                # This is getting complicated. Let me try a simpler approach.
                pass
    
    # 2b) Add APOE4 value extraction before the row dict building
    # After errors extraction, before the row dict
    total_err_marker = '            total_err = ea + eb'
    apoe_extract = '''            total_err = ea + eb

            # APOE4 (strongest genetic AD risk factor — 0/1/2 ε4 alleles)
            apoe4 = 0
            if APOE_COL and pd.notna(r.get(APOE_COL)):
                try:
                    val = int(float(r[APOE_COL]))
                    apoe4 = np.clip(val, 0, 2)
                except (ValueError, TypeError):
                    pass'''
    
    if total_err_marker in src:
        src = src.replace(total_err_marker, apoe_extract, 1)  # replace first occurrence only
        changes_made.append("Added APOE4 extraction to NACC cell")
    
    # 2c) Fix patient_rids alignment in NACC cell too
    if old_shuffle in src:
        src = src.replace(old_shuffle, new_shuffle)
        changes_made.append("Fixed patient_rids alignment in NACC cell")
    
    # Write back
    set_cell_source(nacc_idx, src)
    print(f"  ✅ NACC cell patched")
else:
    print("  ❌ NACC cell not found!")

# ═══════════════════════════════════════════════════════════════
# PATCH 3: Cell 8 — Adaptive N_FEATURES_SELECT
# ═══════════════════════════════════════════════════════════════
feat_sel_idx = find_cell('Feature Selection + SMOTE')
if feat_sel_idx is not None:
    print(f"\n[PATCH 3] Found Feature Selection cell at index {feat_sel_idx}")
    src = ''.join(nb['cells'][feat_sel_idx].get('source', []))
    
    old_n_feat = 'N_FEATURES_SELECT = 12  # sweet spot for ~3k samples'
    new_n_feat = '''# Adaptive feature selection based on dataset size
# More data → can use more features without overfitting
n_samples = len(df)
if n_samples > 15000:
    N_FEATURES_SELECT = min(20, len(feature_cols))
elif n_samples > 8000:
    N_FEATURES_SELECT = min(18, len(feature_cols))
elif n_samples > 4000:
    N_FEATURES_SELECT = min(15, len(feature_cols))
else:
    N_FEATURES_SELECT = min(12, len(feature_cols))  # sweet spot for ~3k samples

print(f"📊 Dataset: {n_samples:,} samples → selecting top {N_FEATURES_SELECT} features")'''
    
    if old_n_feat in src:
        src = src.replace(old_n_feat, new_n_feat)
        set_cell_source(feat_sel_idx, src)
        changes_made.append("Made N_FEATURES_SELECT adaptive")
        print(f"  ✅ Feature selection made adaptive")
    else:
        print("  ⚠️ Could not find N_FEATURES_SELECT marker")
else:
    print("  ❌ Feature selection cell not found!")

# ═══════════════════════════════════════════════════════════════
# PATCH 4: Inference Demo — Fix scaling inconsistency 
# ═══════════════════════════════════════════════════════════════
demo_idx = find_cell('Inference Demo')
if demo_idx is not None:
    print(f"\n[PATCH 4] Found Inference Demo cell at index {demo_idx}")
    src = ''.join(nb['cells'][demo_idx].get('source', []))
    
    # Fix unscaled interaction terms in _build_patient
    old_interactions = '''        # ── NEW: Interaction terms ──
        "age_x_tmt_b": age * tb,
        "errors_x_time_b": total_err * tb,
        "edu_x_ratio": edu * b_over_a,'''
    
    new_interactions = '''        # ── Interaction terms (SAME scaling as training Cell 4!) ──
        "age_x_tmt_b": age * tb / 1000.0,
        "errors_x_time_b": total_err * tb / 100.0,
        "edu_x_ratio": edu * b_over_a / 10.0,
        # ── APOE4 (default 0 for demo — real values come from genotyping) ──
        "apoe4": 0,
        "apoe4_positive": 0.0,
        "apoe4_x_age": 0.0,
        "apoe4_x_tmt_b": 0.0,'''
    
    if old_interactions in src:
        src = src.replace(old_interactions, new_interactions)
        set_cell_source(demo_idx, src)
        changes_made.append("Fixed inference demo scaling + added APOE4 defaults")
        print(f"  ✅ Inference demo patched")
    else:
        print("  ⚠️ Could not find interaction terms marker in demo cell")
        # Try the other inference demo cell
        for i, cell in enumerate(nb['cells']):
            s = ''.join(cell.get('source', []))
            if 'age_x_tmt_b": age * tb,' in s:
                print(f"  Found interaction terms in cell {i}")
                s = s.replace(
                    '"age_x_tmt_b": age * tb,',
                    '"age_x_tmt_b": age * tb / 1000.0,'
                )
                s = s.replace(
                    '"errors_x_time_b": total_err * tb,',
                    '"errors_x_time_b": total_err * tb / 100.0,'
                )
                s = s.replace(
                    '"edu_x_ratio": edu * b_over_a,',
                    '"edu_x_ratio": edu * b_over_a / 10.0,'
                )
                set_cell_source(i, s)
                changes_made.append(f"Fixed scaling in cell {i}")
                print(f"  ✅ Fixed scaling in cell {i}")
else:
    print("  ❌ Inference demo cell not found!")

# ═══════════════════════════════════════════════════════════════
# PATCH 5: Update summary markdown
# ═══════════════════════════════════════════════════════════════
summary_idx = find_cell('Training Complete', cell_type='markdown')
if summary_idx is not None:
    print(f"\n[PATCH 5] Found summary markdown at index {summary_idx}")
    src = ''.join(nb['cells'][summary_idx].get('source', []))
    
    # Update feature count references
    old_feat_ref = '4 timing features (TMT-A/B times, per-circle times)'
    # This is in a different cell, skip
    
    # Update expected accuracy
    if 'ADNI-only | ~2,965' in src:
        src = src.replace('ADNI-only | ~2,965', 'ADNI-only | ~2,965 (+APOE4)')
        set_cell_source(summary_idx, src)
        changes_made.append("Updated summary markdown")

# ═══════════════════════════════════════════════════════════════
# Save notebook
# ═══════════════════════════════════════════════════════════════
with open(NB_PATH, 'w', encoding='utf-8') as f:
    json.dump(nb, f, indent=1, ensure_ascii=False)

print(f"\n{'='*60}")
print(f"✅ Notebook saved with {len(changes_made)} changes:")
for i, c in enumerate(changes_made, 1):
    print(f"   {i}. {c}")
print(f"{'='*60}")
