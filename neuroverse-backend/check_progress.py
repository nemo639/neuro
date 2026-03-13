import os
base = "D:/Desktop/dementiabank_pitt/Pitt"
good = 0
total_size = 0
by_dir = {}
for root, dirs, files in os.walk(base):
    for f in files:
        if f.lower().endswith((".mp3", ".wav")):
            p = os.path.join(root, f)
            s = os.path.getsize(p)
            if s > 1024:
                good += 1
                total_size += s
                rel = os.path.relpath(root, base)
                by_dir[rel] = by_dir.get(rel, 0) + 1
print(f"Good files: {good}, Total: {total_size/1024/1024:.1f} MB")
for d in sorted(by_dir):
    print(f"  {d}: {by_dir[d]}")
