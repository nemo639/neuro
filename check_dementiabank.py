import zipfile, os, collections

zips = ['Pitt.zip', 'Baycrest.zip', 'Delaware.zip', 'WLS.zip']
base = r'D:\Desktop\dementiabank_pitt'

for zname in zips:
    zpath = os.path.join(base, zname)
    if not os.path.exists(zpath):
        print(f'\n  {zname} not found')
        continue
    with zipfile.ZipFile(zpath, 'r') as z:
        entries = z.namelist()
        exts = collections.Counter(os.path.splitext(e)[1].lower() for e in entries if os.path.splitext(e)[1])
        folders = set()
        for e in entries:
            parts = e.replace('\\','/').split('/')
            if len(parts) >= 2:
                folders.add('/'.join(parts[:2]))
            if len(parts) >= 3:
                folders.add('/'.join(parts[:3]))
        
        size_mb = os.path.getsize(zpath) / (1024*1024)
        print(f'\n{"="*60}')
        print(f'  {zname} ({size_mb:.1f} MB, {len(entries)} entries)')
        print(f'{"="*60}')
        print(f'  Extensions: {dict(exts.most_common(10))}')
        print(f'  Top folders:')
        for f in sorted(folders)[:20]:
            count = sum(1 for e in entries if e.startswith(f + '/') or e == f)
            print(f'    {f}/  ({count} items)')
        
        # Check for audio files
        audio_exts = ('.wav','.mp3','.mp4','.flac','.m4a','.ogg')
        audio_count = sum(1 for e in entries if e.lower().endswith(audio_exts))
        cha_count = sum(1 for e in entries if e.lower().endswith('.cha'))
        cdc_count = sum(1 for e in entries if e.lower().endswith('.cdc'))
        print(f'  Audio files: {audio_count}')
        print(f'  .cha transcripts: {cha_count}')
        print(f'  .cdc metadata: {cdc_count}')
        
        # Show sample of each file type
        for ext in ['.cha', '.mp3', '.wav', '.mp4']:
            samples = [e for e in entries if e.lower().endswith(ext)][:3]
            if samples:
                print(f'  Sample {ext}: {samples}')
