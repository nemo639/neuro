"""Fix the garbled Cell 3B in speech_model_training.ipynb.

The parse_cha_linguistic function and surrounding code got interleaved.
This script replaces the garbled lines with correct Python code,
AND updates Cell 2 to support both zip files and raw folders on Drive
(so Pitt's 10GB audio+transcripts can be uploaded as a folder).
"""
import json

NB_PATH = r'd:\neuroverse\notebooks\speech_model_training.ipynb'

with open(NB_PATH, 'r', encoding='utf-8') as f:
    nb = json.load(f)

# =====================================================
# FIX 1: Repair garbled Cell 3B (parse_cha_linguistic)
# =====================================================
target_cell_idx = None
for i, cell in enumerate(nb['cells']):
    src = ''.join(cell.get('source', []))
    if 'parse_cha_linguistic' in src:
        target_cell_idx = i
        break

assert target_cell_idx is not None, "Cell with parse_cha_linguistic not found!"

cell = nb['cells'][target_cell_idx]
old_lines = cell['source']
print(f"Cell 3B at index {target_cell_idx}, {len(old_lines)} lines")

# Keep lines 0-659 (before the garbled section)
keep_up_to = 660
good_lines = old_lines[:keep_up_to]

# Corrected code for linguistic features + status summary
new_code = '''    # as supplementary data for future multi-modal fusion.

    dementiabank_available = REAL_DATA_LOADED and (
        os.path.isdir(PITT_DIR) or os.path.isdir(DELAWARE_DIR))

    if dementiabank_available:
        print(f"\\n{'='*60}")
        print(f"\\U0001f4dd Parsing Pitt + Delaware .cha transcripts (linguistic features)...")
        print(f"{'='*60}")

        def parse_cha_linguistic(cha_path, source):
            """Parse a CHAT .cha transcript -> linguistic features dict."""
            with open(cha_path, 'r', encoding='utf-8', errors='replace') as f:
                text = f.read()

            path_lower = cha_path.lower().replace('\\\\', '/')
            if '/control/' in path_lower:
                group = 'HC'
            elif '/dementia/' in path_lower:
                group = 'AD'
            elif '/mci/' in path_lower:
                group = 'AD'
            else:
                group = 'UNKNOWN'

            par_lines = re.findall(r'\\*PAR:\\t(.+?)(?:\\n[%@]|\\Z)', text, re.DOTALL)
            speech_text = ' '.join(par_lines)
            words = speech_text.split()
            word_count = len(words)
            unique_words = len(set(w.lower().strip('.,!?') for w in words if w.strip('.,!?')))
            ttr = unique_words / max(word_count, 1)
            fillers = sum(1 for w in words if w.lower() in
                          ['um', 'uh', 'er', 'ah', 'hmm', 'well', '(.)', '(..)', '(...)'])
            pauses = text.count('(.)') + text.count('(..)') + text.count('(...)')
            utterances = len(par_lines)
            mlu = word_count / max(utterances, 1)

            return {
                'file': os.path.basename(cha_path), 'source': source,
                'group': group, 'word_count': word_count,
                'unique_words': unique_words, 'type_token_ratio': ttr,
                'filler_count': fillers, 'pause_markers': pauses,
                'utterance_count': utterances, 'mean_utterance_length': mlu,
            }

        all_ling = []
        for label, base in [("Pitt", PITT_DIR), ("Delaware", DELAWARE_DIR)]:
            if not os.path.isdir(base):
                continue
            cha_files = [os.path.join(r, f) for r, _, fs in os.walk(base) for f in fs if f.endswith('.cha')]
            for cha_path in tqdm(cha_files, desc=f"{label} .cha"):
                try:
                    all_ling.append(parse_cha_linguistic(cha_path, label.lower()))
                except Exception:
                    pass

        if all_ling:
            df_ling = pd.DataFrame(all_ling)
            df_ling = df_ling[df_ling['group'].isin(['HC', 'AD'])]
            ling_path = os.path.join(PROCESSED_DIR, 'dementiabank_linguistic_features.csv')
            df_ling.to_csv(ling_path, index=False)
            print(f"\\n   \\u2705 {len(df_ling)} transcripts parsed:")
            for src in df_ling['source'].unique():
                sub = df_ling[df_ling['source'] == src]
                print(f"      {src.capitalize():12s} -> HC: {len(sub[sub['group']=='HC'])}  "
                      f"AD: {len(sub[sub['group']=='AD'])}")
            print(f"   \\U0001f4be Saved to {ling_path}")
        else:
            print("   \\u26a0\\ufe0f  No .cha files parsed")
    elif os.path.isdir(PITT_DIR) or os.path.isdir(DELAWARE_DIR):
        print(f"\\n   \\u2139\\ufe0f  DementiaBank skipped (no audio features loaded)")

# ===================================================================
# Status summary
# ===================================================================
if not REAL_DATA_LOADED:
    print("\\u23ed\\ufe0f  Synthetic mode -- skipping real data processing")
else:
    print(f"\\n{'='*60}")
    print(f"\\u2705 DATASET READY FOR TRAINING")
    print(f"{'='*60}")
    print(f"   Groups:  {df['group'].value_counts().to_dict()}")
    print(f"   Sources: {df['source'].value_counts().to_dict()}")
    print(f"   {len(df)} samples | {df['group'].nunique()} classes | "
          f"{df['speaker_id'].nunique()} speakers")

if not REAL_DATA_LOADED:
    print("\\n\\u2139\\ufe0f  Real data not loaded -- Cell 4A will generate synthetic training data")
'''

new_lines = [line + '\n' for line in new_code.split('\n')]
cell['source'] = good_lines + new_lines
nb['cells'][target_cell_idx] = cell
print(f"  Fixed: {len(old_lines)} -> {len(cell['source'])} lines")

# =====================================================
# FIX 2: Update Cell 2 to support folders + zips on Drive
# =====================================================
# Find Cell 2 (Mount Drive & Configure Paths)
cell2_idx = None
for i, cell in enumerate(nb['cells']):
    src = ''.join(cell.get('source', []))
    if 'CELL 2: Mount Drive' in src and 'USE_REAL_DATA' in src:
        cell2_idx = i
        break

assert cell2_idx is not None, "Cell 2 not found!"
print(f"\nCell 2 at index {cell2_idx}")

# Replace Cell 2 entirely with updated version supporting folder uploads
cell2_new_source = r'''# ============================================================
# CELL 2: Mount Drive & Configure Paths
# ============================================================
# Supports BOTH zip archives AND raw folders on Drive.
# If Pitt is too large to zip (10+ GB), upload the folder directly.

import shutil

# ===========================================================
# CONFIGURE:
USE_REAL_DATA = True           # True -> load all datasets from Drive
# ===========================================================

# Google Drive paths
DRIVE_DATASETS = "/content/drive/MyDrive/Neuro_Datasets"

# -- Dataset names (zip OR folder on Drive) --
EWA_ZIP       = "EWA-DB-v1.0.zip"   # 13.5 GB -- streamed (NOT fully extracted)
PITT_NAME     = "Pitt"               # Can be Pitt.zip OR Pitt/ folder
DELAWARE_NAME = "Delaware"           # Can be Delaware.zip OR Delaware/ folder
WLS_NAME      = "WLS"                # Can be WLS.zip OR WLS/ folder
BAYCREST_NAME = "Baycrest"           # Can be Baycrest.zip OR Baycrest/ folder
YE_NAME       = "Ye"                 # Can be Ye.zip OR Ye/ folder

# Local paths (Colab local SSD -- fast I/O)
DATA_DIR = "/content/speech_data"
EWA_DIR = os.path.join(DATA_DIR, "ewa_db")
PITT_DIR = os.path.join(DATA_DIR, "pitt")
DELAWARE_DIR = os.path.join(DATA_DIR, "delaware")
WLS_DIR = os.path.join(DATA_DIR, "wls")
BAYCREST_DIR = os.path.join(DATA_DIR, "baycrest")
YE_DIR = os.path.join(DATA_DIR, "ye")
PROCESSED_DIR = os.path.join(DATA_DIR, "processed")
OUTPUT_DIR = "/content/speech_output"
MODEL_DIR = os.path.join(OUTPUT_DIR, "models")
PLOT_DIR = os.path.join(OUTPUT_DIR, "plots")

for d in [DATA_DIR, EWA_DIR, PITT_DIR, DELAWARE_DIR, WLS_DIR, BAYCREST_DIR,
          YE_DIR, PROCESSED_DIR, MODEL_DIR, PLOT_DIR]:
    os.makedirs(d, exist_ok=True)

# ===========================================================
# Mount Google Drive
# ===========================================================
if USE_REAL_DATA:
    try:
        from google.colab import drive
        if not os.path.exists('/content/drive/MyDrive'):
            drive.mount('/content/drive')
        IS_COLAB = True
    except ImportError:
        IS_COLAB = False
        print("Warning: Not running on Colab -- set local paths accordingly")

    import zipfile

    # -- Helper: load dataset from zip OR folder on Drive --
    def load_dataset(name, dest_dir, label):
        """
        Load a DementiaBank dataset from Drive. Supports:
        1. name.zip  -> extract to dest_dir
        2. name/     -> symlink or copy to dest_dir
        Returns True if data was loaded.
        """
        zip_path = os.path.join(DRIVE_DATASETS, f"{name}.zip")
        folder_path = os.path.join(DRIVE_DATASETS, name)

        # Priority 1: Folder on Drive (avoids re-zipping large datasets)
        if os.path.isdir(folder_path):
            # Count contents
            cha_count = sum(1 for _, _, fs in os.walk(folder_path)
                            for f in fs if f.endswith('.cha'))
            audio_count = sum(1 for _, _, fs in os.walk(folder_path)
                              for f in fs if f.lower().endswith(('.wav', '.mp3')))
            size_gb = sum(os.path.getsize(os.path.join(r, f))
                          for r, _, fs in os.walk(folder_path)
                          for f in fs) / 1e9

            print(f"\n   FOLDER {label}: {name}/ ({size_gb:.1f} GB)")
            print(f"   {cha_count} .cha transcripts, {audio_count} audio files")

            # Symlink folder to local path (no copy needed -- Drive is fast enough)
            if not os.path.exists(dest_dir) or not os.listdir(dest_dir):
                if os.path.islink(dest_dir) or os.path.exists(dest_dir):
                    if os.path.islink(dest_dir):
                        os.unlink(dest_dir)
                    elif os.path.isdir(dest_dir) and not os.listdir(dest_dir):
                        os.rmdir(dest_dir)
                try:
                    os.symlink(folder_path, dest_dir)
                    print(f"   Symlinked -> {dest_dir}")
                except OSError:
                    # Symlink failed (Windows?) -- copy instead
                    shutil.copytree(folder_path, dest_dir, dirs_exist_ok=True)
                    print(f"   Copied -> {dest_dir}")
            return True

        # Priority 2: Zip file on Drive
        elif os.path.exists(zip_path):
            size_mb = os.path.getsize(zip_path) / (1024**2)
            print(f"\n   ZIP {label}: {name}.zip ({size_mb:.1f} MB)")

            with zipfile.ZipFile(zip_path, 'r') as z:
                z.extractall(dest_dir)

            cha_count = sum(1 for _, _, fs in os.walk(dest_dir)
                            for f in fs if f.endswith('.cha'))
            audio_count = sum(1 for _, _, fs in os.walk(dest_dir)
                              for f in fs if f.lower().endswith(('.wav', '.mp3')))
            print(f"   {cha_count} .cha transcripts, {audio_count} audio files")
            return True

        else:
            print(f"\n   {label}: NOT FOUND (no {name}.zip or {name}/ folder)")
            return False

    print("=" * 60)
    print("Loading datasets from Drive:")
    print("=" * 60)

    # -- EWA-DB: special (streamed, never fully extracted) --
    ewa_path = os.path.join(DRIVE_DATASETS, EWA_ZIP)
    if os.path.exists(ewa_path):
        print(f"\n   EWA-DB: {EWA_ZIP} ({os.path.getsize(ewa_path)/1e9:.1f} GB) -- will stream")
    else:
        print(f"\n   EWA-DB: NOT FOUND")

    # -- Load each corpus (zip or folder) --
    pitt_available = load_dataset(PITT_NAME, PITT_DIR, "Pitt")
    delaware_available = load_dataset(DELAWARE_NAME, DELAWARE_DIR, "Delaware")
    wls_available = load_dataset(WLS_NAME, WLS_DIR, "WLS")
    baycrest_available = load_dataset(BAYCREST_NAME, BAYCREST_DIR, "Baycrest")
    ye_available = load_dataset(YE_NAME, YE_DIR, "Ye")

    # -- Scan for audio files --
    for label, base_dir, avail in [("Pitt", PITT_DIR, pitt_available),
                                    ("WLS", WLS_DIR, wls_available),
                                    ("Baycrest", BAYCREST_DIR, baycrest_available),
                                    ("Ye", YE_DIR, ye_available)]:
        if not avail:
            continue
        audio_count = sum(1 for _, _, fs in os.walk(base_dir)
                          for f in fs if f.lower().endswith(('.wav', '.mp3')))
        if audio_count > 0:
            print(f"   {label}: {audio_count} audio files found")
        else:
            print(f"   {label}: transcripts only (no audio)")

    # -- EWA-DB metadata --
    if os.path.exists(ewa_path):
        print(f"\nReading EWA-DB metadata...")

        with zipfile.ZipFile(ewa_path, 'r') as z:
            speakers_raw = z.read('EWA-DB/SPEAKERS.TSV').decode('utf-8', errors='replace')
            speakers_lines = speakers_raw.strip().split('\n')
            speakers_header = speakers_lines[0].split('\t')

            speakers_data = []
            for line in speakers_lines[1:]:
                cols = line.split('\t')
                if len(cols) >= len(speakers_header):
                    row = dict(zip(speakers_header, cols))
                    speakers_data.append(row)

            speakers_df = pd.DataFrame(speakers_data)
            speakers_df['AGE'] = pd.to_numeric(speakers_df['AGE'], errors='coerce')
            speakers_df['MOCA'] = pd.to_numeric(speakers_df['MOCA'], errors='coerce')
            speakers_df['DIAGNOSIS'] = speakers_df['DIAGNOSIS'].str.strip()

            print(f"\n   EWA-DB Speaker Demographics:")
            print(f"   Total speakers: {len(speakers_df)}")
            for dx, grp in speakers_df.groupby('DIAGNOSIS'):
                print(f"   {dx:25s} {len(grp):4d} speakers  "
                      f"age: {grp['AGE'].mean():.0f}+/-{grp['AGE'].std():.0f}  "
                      f"MOCA: {grp['MOCA'].mean():.1f}")

            audio_by_dx = {}
            for entry in z.namelist():
                if entry.lower().endswith('.wav'):
                    parts = entry.split('/')
                    if len(parts) >= 2:
                        dx_folder = parts[1]
                        audio_by_dx[dx_folder] = audio_by_dx.get(dx_folder, 0) + 1

            print(f"\n   Audio files by diagnosis:")
            for dx, count in sorted(audio_by_dx.items(), key=lambda x: -x[1]):
                print(f"   {dx:25s} {count:6,} .wav files")
            total_wav = sum(audio_by_dx.values())
            print(f"   {'TOTAL':25s} {total_wav:6,} .wav files")

    # -- Pitt/Delaware transcript summaries --
    if pitt_available and os.path.exists(PITT_DIR):
        control_dir = dementia_dir = None
        for root, dirs, files in os.walk(PITT_DIR):
            if 'Control' in dirs:
                control_dir = os.path.join(root, 'Control')
            if 'Dementia' in dirs:
                dementia_dir = os.path.join(root, 'Dementia')
        ctrl_count = sum(1 for _, _, fs in os.walk(control_dir) for f in fs if f.endswith('.cha')) if control_dir else 0
        dem_count = sum(1 for _, _, fs in os.walk(dementia_dir) for f in fs if f.endswith('.cha')) if dementia_dir else 0
        print(f"\n   DementiaBank Pitt:")
        print(f"   Control:  {ctrl_count} transcripts")
        print(f"   Dementia: {dem_count} transcripts")

    if delaware_available and os.path.exists(DELAWARE_DIR):
        del_ctrl = del_mci = 0
        for root, dirs, files in os.walk(DELAWARE_DIR):
            for f in files:
                if f.endswith('.cha'):
                    path_lower = os.path.join(root, f).lower().replace('\\', '/')
                    if '/control/' in path_lower:
                        del_ctrl += 1
                    elif '/mci/' in path_lower:
                        del_mci += 1
        print(f"\n   DementiaBank Delaware:")
        print(f"   Control: {del_ctrl} transcripts")
        print(f"   MCI:     {del_mci} transcripts")

    print(f"\n{'='*60}")
    print(f"Setup complete -- all datasets loaded")
    print(f"{'='*60}")
else:
    print("Using SYNTHETIC dataset (USE_REAL_DATA = False)")
    print("   Set USE_REAL_DATA = True after uploading data to Drive")
'''

# Convert to list of lines
cell2_lines = [line + '\n' for line in cell2_new_source.split('\n')]
nb['cells'][cell2_idx]['source'] = cell2_lines
print(f"  Cell 2 updated: {len(cell2_lines)} lines")

# Save
with open(NB_PATH, 'w', encoding='utf-8') as f:
    json.dump(nb, f, ensure_ascii=False, indent=1)

print("\nNotebook saved successfully!")
