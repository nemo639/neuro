"""
TalkBank Media Mirror — exact server folder structure with resume support.

Server:  https://media.talkbank.org/dementia/English/Pitt/
Local:   D:\\Desktop\\dementiabank_pitt\\Pitt\\Control\\cookie\\*.mp3  (exact mirror)

Folder structure on server:
  Pitt/
    Control/
      cookie/  fluency/  recall/  sentence/   ← MP3 files (+ nested subfolders)
    Dementia/
      cookie/  fluency/  recall/  sentence/   ← MP3 files (+ nested subfolders)

Features:
  - Mirrors exact server folder structure (including nested folders)
  - Skips already-downloaded files (resume-safe)
  - Retries failed downloads up to 3 times
  - Skips 0extra/0metadata/0wav processed folders
  - Handles TalkBank's Range-header requirement
  - Checks disk space before each download

Usage:
  1. Chrome → https://media.talkbank.org/dementia/English/Pitt/
  2. Log in / agree to terms
  3. F12 → Application → Cookies → media.talkbank.org → copy "talkbank" value
  4. Paste in COOKIE_VALUE below
  5. python download.py
"""

import requests, os, time, sys
from bs4 import BeautifulSoup
from urllib.parse import unquote
import shutil

# ── CONFIG ────────────────────────────────────────────────
COOKIE_VALUE = "s%3AuJskbTgY2t05K3qaC2Bybxpae4LTkP2Z.c0k5M0hIWv4ZycTSrymgkm9qTvLaIiG7CzbitY95Wms"
SAVE_BASE    = r"D:\Desktop\dementiabank_pitt"            # root save directory

# Corpora to download — (server_url, local_folder_name)
CORPORA = [
    ("https://media.talkbank.org/dementia/English/WLS/",       "WLS"),
    ("https://media.talkbank.org/dementia/English/Protocol/Baycrest/",  "Baycrest"),
    ("https://media.talkbank.org/dementia/English/Protocol/Delaware/",  "Delaware"),
]

# Folders to skip — match stripped/lowered name containing these
SKIP_NAMES   = {"0extra", "0metadata", "0wav"}
MEDIA_EXTS   = (".mp3", ".wav", ".mp4")
MAX_RETRIES  = 3
MIN_FREE_MB  = 500   # stop if disk free drops below this
# ──────────────────────────────────────────────────────────

session = requests.Session()
session.cookies.set("talkbank", COOKIE_VALUE, domain="media.talkbank.org")
session.headers.update({
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                  "AppleWebKit/537.36 (KHTML, like Gecko) "
                  "Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Referer": "https://media.talkbank.org/",
})

stats = {"downloaded": 0, "skipped": 0, "failed": 0, "bytes": 0, "retried": 0}


def should_skip_name(name):
    """Check if folder name matches any skip pattern (handles spaces/case)."""
    clean = name.strip().lower()
    for skip in SKIP_NAMES:
        if clean == skip or clean.startswith(skip):
            return True
    return False


SAVE_ROOT = None  # set per-corpus in main loop

def check_disk_space():
    """Return free MB on the target drive."""
    u = shutil.disk_usage(os.path.splitdrive(SAVE_BASE)[0] or SAVE_BASE)
    return u.free / (1024 * 1024)


def download_file(url, local_path):
    """Download one file with retry. Skip if already exists with valid size."""
    if os.path.exists(local_path) and os.path.getsize(local_path) > 100:
        stats["skipped"] += 1
        return True

    # Check disk space
    free_mb = check_disk_space()
    if free_mb < MIN_FREE_MB:
        print(f"\n  ⚠️  LOW DISK: {free_mb:.0f} MB free — stopping downloads")
        return False

    os.makedirs(os.path.dirname(local_path), exist_ok=True)
    fname = os.path.basename(local_path)

    for attempt in range(1, MAX_RETRIES + 1):
        try:
            r = session.get(url, stream=True, headers={"Range": "bytes=0-"}, timeout=120)
            if r.status_code not in (200, 206):
                print(f"  [FAIL] {r.status_code} — {fname}")
                stats["failed"] += 1
                return True  # skip this file, continue others

            with open(local_path, "wb") as f:
                for chunk in r.iter_content(chunk_size=32768):
                    f.write(chunk)

            size = os.path.getsize(local_path)
            if size < 100:
                os.remove(local_path)
                if attempt < MAX_RETRIES:
                    stats["retried"] += 1
                    time.sleep(2)
                    continue
                stats["failed"] += 1
                return True

            stats["downloaded"] += 1
            stats["bytes"] += size
            print(f"  [{stats['downloaded']:>4d}] {size/1024:>7.0f} KB  {fname}")
            return True

        except (requests.exceptions.ConnectionError,
                requests.exceptions.Timeout,
                requests.exceptions.ChunkedEncodingError) as e:
            if attempt < MAX_RETRIES:
                stats["retried"] += 1
                print(f"  [RETRY {attempt}/{MAX_RETRIES}] {fname} — {type(e).__name__}")
                time.sleep(3 * attempt)
                continue
            print(f"  [FAIL] {fname} — {e}")
            stats["failed"] += 1
            return True

        except OSError as e:
            # Disk full or permission error
            print(f"  [ERR] {fname} — {e}")
            if "No space" in str(e) or "Errno 28" in str(e):
                return False  # signal to stop
            stats["failed"] += 1
            return True

    return True


def crawl(url, local_dir):
    """Recursively mirror a TalkBank directory to local_dir."""
    rel = os.path.relpath(local_dir, SAVE_ROOT) if local_dir != SAVE_ROOT else "/"
    print(f"\n📁  {rel}")

    try:
        r = session.get(url, timeout=30)
    except Exception as e:
        print(f"  [ERR] Cannot list {rel} — {e}")
        # Retry directory listing once
        try:
            time.sleep(3)
            r = session.get(url, timeout=30)
        except Exception:
            return True

    if r.status_code != 200:
        print(f"  [FAIL] Status {r.status_code} for {rel}")
        return True

    soup = BeautifulSoup(r.text, "html.parser")

    for link in soup.find_all("a"):
        href = link.get("href", "")
        text = link.get_text().strip()
        if not href or "Parent" in text or href in ("../", "#"):
            continue

        # Build absolute URL
        full_url = href if href.startswith("http") else url.rstrip("/") + "/" + href.lstrip("/")
        name = unquote(full_url.rstrip("/").split("/")[-1])

        # Folder detection: TalkBank link text ends with "/" for directories
        is_folder = text.endswith("/") or href.endswith("/")

        if is_folder:
            if should_skip_name(name):
                print(f"  [SKIP] {name}/")
                continue
            ok = crawl(full_url.rstrip("/") + "/", os.path.join(local_dir, name))
            if not ok:
                return False  # propagate disk-full stop

        elif name.lower().endswith(MEDIA_EXTS):
            ok = download_file(full_url, os.path.join(local_dir, name))
            if not ok:
                return False  # propagate disk-full stop

    return True


def download_corpus(base_url, name):
    """Download one full corpus."""
    global SAVE_ROOT
    SAVE_ROOT = os.path.join(SAVE_BASE, name)

    print("\n" + "=" * 55)
    print(f"  📦 Corpus: {name}")
    print(f"  Server : {base_url}")
    print(f"  Local  : {SAVE_ROOT}")
    print(f"  Disk   : {check_disk_space():.0f} MB free")
    print("=" * 55)

    # Verify cookie on this URL
    print("\n🔑 Verifying cookie...")
    try:
        r = session.get(base_url, timeout=30)
    except Exception as e:
        print(f"❌ Cannot reach {base_url} — {e}")
        return
    if r.status_code != 200 or ("initAuthModals" in r.text and "<table>" not in r.text):
        print(f"❌ Cookie expired or URL invalid (status {r.status_code})")
        return
    soup = BeautifulSoup(r.text, "html.parser")
    folders = [l.get_text().strip() for l in soup.find_all("a")
               if l.get_text().strip().endswith("/") and "Parent" not in l.get_text()]
    print(f"✅ Cookie valid — contents: {folders}")

    os.makedirs(SAVE_ROOT, exist_ok=True)

    # Reset stats per-corpus
    for k in stats:
        stats[k] = 0
    t0 = time.time()

    ok = crawl(base_url, SAVE_ROOT)

    elapsed = time.time() - t0
    mb = stats["bytes"] / 1024 / 1024
    print("\n" + "-" * 55)
    print(f"  {name} DONE in {elapsed/60:.1f} min")
    print(f"  Downloaded : {stats['downloaded']} files ({mb:.1f} MB)")
    print(f"  Skipped    : {stats['skipped']} (already had)")
    print(f"  Retried    : {stats['retried']}")
    print(f"  Failed     : {stats['failed']}")
    print(f"  Disk free  : {check_disk_space():.0f} MB")
    if not ok:
        print("  ⚠️  STOPPED EARLY — disk space low!")
    print("-" * 55)

    # Show final tree
    print(f"\n📂 {name} structure:")
    for root, dirs, files in os.walk(SAVE_ROOT):
        media = [f for f in files if f.lower().endswith(MEDIA_EXTS)]
        if media:
            rel = os.path.relpath(root, SAVE_ROOT)
            total_mb = sum(os.path.getsize(os.path.join(root, f)) for f in media) / 1024 / 1024
            print(f"  {rel}: {len(media)} files ({total_mb:.0f} MB)")


if __name__ == "__main__":
    print("=" * 55)
    print("  TalkBank Media Mirror — Multi-Corpus Downloader")
    print(f"  Corpora: {', '.join(name for _, name in CORPORA)}")
    print(f"  Save to: {SAVE_BASE}")
    print(f"  Disk   : {check_disk_space():.0f} MB free")
    print("=" * 55)

    for base_url, name in CORPORA:
        download_corpus(base_url, name)
        print()

    print("\n" + "=" * 55)
    print("  ALL CORPORA COMPLETE")
    print("=" * 55)
