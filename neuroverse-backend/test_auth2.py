import urllib.request, urllib.error, json, base64

req = urllib.request.Request(
    'http://localhost:8000/api/v1/auth/login',
    data=json.dumps({'email': 'naeemubeen639@gmail.com', 'password': 'Naeem@123'}).encode(),
    headers={'Content-Type': 'application/json'}
)

try:
    resp = urllib.request.urlopen(req, timeout=10)
    data = json.loads(resp.read())
    token = data['access_token']
    
    # Decode JWT payload (without verification)
    payload_b64 = token.split('.')[1]
    payload_b64 += '=' * (4 - len(payload_b64) % 4)  # pad
    payload = json.loads(base64.b64decode(payload_b64))
    print("Token payload:", json.dumps(payload, indent=2))
    
    # Test /tests/
    req2 = urllib.request.Request(
        'http://localhost:8000/api/v1/tests/',
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
    )
    resp2 = urllib.request.urlopen(req2, timeout=10)
    print("Tests OK:", resp2.read().decode()[:200])
except urllib.error.HTTPError as e:
    body = e.read().decode()
    print(f"HTTP {e.code}: {body[:500]}")
except Exception as e:
    print(f"Error: {e}")
