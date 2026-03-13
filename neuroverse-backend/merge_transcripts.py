"""
Merge transcript .cha files from zips into the MP3 audio folders.
Result: each folder has both .cha and .mp3 side-by-side.
"""
import os, zipfile, shutil, tempfile

AUDIO_ROOT = r"D:\Desktop\dementiabank_pitt"
ZIP_ROOT   = r"D:\Desktop\dementiabank_pitt - Copy"

def extract_and_merge(zip_name, corpus_name):
    """Extract a zip and copy .cha files into matching audio folder."""
    zip_path = os.path.join(ZIP_ROOT, zip_name)
    if not os.path.exists(zip_path):
        print(f"  [SKIP] {zip_name} not found")
        return

    print(f"\n{'='*50}")
    print(f"Processing: {zip_name} → {corpus_name}/")
    print(f"{'='*50}")

    # Extract to temp dir first to inspect structure
    with tempfile.TemporaryDirectory() as tmp:
        with zipfile.ZipFile(zip_path, 'r') as zf:
            zf.extractall(tmp)

        # Find all .cha files in the extracted zip
        cha_files = []
        for root, dirs, files in os.walk(tmp):
            for f in files:
                if f.lower().endswith('.cha'):
                    full = os.path.join(root, f)
                    # Get relative path from the first meaningful folder
                    rel = os.path.relpath(full, tmp)
                    cha_files.append((full, rel, f))

        print(f"  Found {len(cha_files)} .cha files in zip")

        # Show zip internal structure
        rel_dirs = set()
        for _, rel, _ in cha_files:
            rel_dirs.add(os.path.dirname(rel))
        print(f"  Zip folders: {sorted(rel_dirs)}")

        # Copy each .cha to the matching audio folder
        copied = 0
        created_dirs = set()
        for src_path, rel_path, filename in cha_files:
            # Figure out where this .cha belongs in the audio tree
            # The zip might have the corpus name as top folder or not
            parts = rel_path.replace('\\', '/').split('/')

            # Strip the corpus name prefix if present (e.g., "Pitt/Control/cookie/xxx.cha")
            if parts[0].lower() == corpus_name.lower():
                sub_path = os.path.join(*parts[1:]) if len(parts) > 1 else filename
            else:
                sub_path = rel_path

            dest = os.path.join(AUDIO_ROOT, corpus_name, sub_path)
            dest_dir = os.path.dirname(dest)

            if not os.path.exists(dest_dir):
                os.makedirs(dest_dir, exist_ok=True)
                if dest_dir not in created_dirs:
                    created_dirs.add(dest_dir)

            if not os.path.exists(dest):
                shutil.copy2(src_path, dest)
                copied += 1
            # else: already exists, skip

        print(f"  Copied {copied} .cha files into {AUDIO_ROOT}/{corpus_name}/")
        if created_dirs:
            print(f"  Created {len(created_dirs)} new directories")


# Process each corpus
extract_and_merge("Pitt.zip", "Pitt")
extract_and_merge("Baycrest.zip", "Baycrest")
extract_and_merge("Delaware.zip", "Delaware")
extract_and_merge("WLS.zip", "WLS")
extract_and_merge("Ye.zip", "Ye")

# Final summary
print(f"\n{'='*50}")
print("FINAL SUMMARY")
print(f"{'='*50}")
for corpus in ["Pitt", "Baycrest", "Delaware", "WLS", "Ye"]:
    corpus_dir = os.path.join(AUDIO_ROOT, corpus)
    if not os.path.isdir(corpus_dir):
        print(f"  {corpus}: NOT FOUND")
        continue
    mp3 = cha = 0
    for root, dirs, files in os.walk(corpus_dir):
        for f in files:
            if f.lower().endswith('.mp3'): mp3 += 1
            elif f.lower().endswith('.cha'): cha += 1
    print(f"  {corpus:12s}: {mp3:>5} MP3, {cha:>5} .cha")

# Check for matched pairs in Pitt
print(f"\n--- Pitt pair matching ---")
pitt = os.path.join(AUDIO_ROOT, "Pitt")
matched = unmatched_mp3 = unmatched_cha = 0
for root, dirs, files in os.walk(pitt):
    stems_mp3 = {os.path.splitext(f)[0] for f in files if f.lower().endswith('.mp3')}
    stems_cha = {os.path.splitext(f)[0] for f in files if f.lower().endswith('.cha')}
    matched += len(stems_mp3 & stems_cha)
    unmatched_mp3 += len(stems_mp3 - stems_cha)
    unmatched_cha += len(stems_cha - stems_mp3)
print(f"  Matched pairs: {matched}")
print(f"  MP3 without .cha: {unmatched_mp3}")
print(f"  .cha without MP3: {unmatched_cha}")
