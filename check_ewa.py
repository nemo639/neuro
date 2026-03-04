import zipfile, collections

zpath = r'G:\My Drive\Neuro_Datasets\EWA-DB-v1.0.zip'

with zipfile.ZipFile(zpath, 'r') as z:
    content = z.read('EWA-DB/SPEAKERS.TSV').decode('utf-8', errors='replace')
    lines = content.strip().split('\n')
    header = lines[0].split('\t')
    
    diag_idx = header.index('DIAGNOSIS')
    age_idx = header.index('AGE')
    
    diagnoses = collections.Counter()
    ages = {}
    
    for line in lines[1:]:
        cols = line.split('\t')
        if len(cols) > diag_idx:
            dx = cols[diag_idx].strip()
            diagnoses[dx] += 1
            try:
                ages.setdefault(dx, []).append(int(cols[age_idx]))
            except (ValueError, IndexError):
                pass
    
    print('SPEAKERS by DIAGNOSIS:')
    for dx, count in diagnoses.most_common():
        age_list = ages.get(dx, [])
        avg_age = sum(age_list)/len(age_list) if age_list else 0
        print(f'  {dx:25s} {count:5d} speakers  avg age: {avg_age:.0f}')
    
    print(f'\nTotal speakers: {sum(diagnoses.values())}')
    
    print('\nAUDIO FILES per folder:')
    folder_audio = collections.Counter()
    for e in z.namelist():
        if e.lower().endswith('.wav'):
            parts = e.split('/')
            if len(parts) >= 2:
                folder_audio[parts[1]] += 1
    for folder, count in folder_audio.most_common():
        print(f'  {folder:25s} {count:6d} .wav files')
    
    print('\nTASK TYPES:')
    tasks = set()
    for e in z.namelist():
        parts = e.split('/')
        if len(parts) >= 4:
            tasks.add(parts[3])
    for t in sorted(tasks):
        print(f'  {t}')
