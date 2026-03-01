import urllib.request, urllib.error, json

req = urllib.request.Request(
    'http://localhost:8000/api/v1/auth/login',
    data=json.dumps({'email': 'naeemubeen639@gmail.com', 'password': 'Naeem@123'}).encode(),
    headers={'Content-Type': 'application/json'}
)

try:
    resp = urllib.request.urlopen(req, timeout=10)
    data = json.loads(resp.read())
    print("Login OK")
    print("Keys:", list(data.keys()))
    print("Has access_token:", 'access_token' in data)
    token = data.get('access_token', '')
    print("Token prefix:", token[:50])
    
    # Now test /tests/ with the token
    req2 = urllib.request.Request(
        'http://localhost:8000/api/v1/tests/',
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}
    )
    resp2 = urllib.request.urlopen(req2, timeout=10)
    data2 = json.loads(resp2.read())
    print("Tests endpoint OK:", str(data2)[:200])
except urllib.error.HTTPError as e:
    body = e.read().decode()
    print(f"HTTP {e.code}: {body[:500]}")
except Exception as e:
    print(f"Error: {e}")
