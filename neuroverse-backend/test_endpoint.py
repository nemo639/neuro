import requests

BASE = 'http://localhost:8000/api/v1'

# Login
r = requests.post(f'{BASE}/doctors/login', json={'email':'dr.smith@neuroverse.com','password':'Doctor123'}, timeout=10)
print(f"Login: {r.status_code}")
if r.status_code != 200:
    print(r.text[:500])
    exit()

token = r.json().get('access_token')
print(f"Token: {token[:30]}...")

# Dashboard
headers = {'Authorization': f'Bearer {token}'}
try:
    r2 = requests.get(f'{BASE}/doctors/dashboard', headers=headers, timeout=30)
    print(f"\nDashboard: {r2.status_code}")
    if r2.status_code == 200:
        import json
        d = r2.json()
        print(json.dumps({k: v for k, v in d.items() if k not in ('recent_patients','pending_diagnostics')}, indent=2, default=str))
        print(f"recent_patients: {len(d.get('recent_patients',[]))} items")
        print(f"pending_diagnostics: {len(d.get('pending_diagnostics',[]))} items")
    else:
        print(r2.text[:1000])
except requests.exceptions.Timeout:
    print("\nDashboard: TIMEOUT after 30s")
except Exception as e:
    print(f"\nDashboard error: {e}")
