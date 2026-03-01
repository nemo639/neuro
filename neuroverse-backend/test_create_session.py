import urllib.request, urllib.error, json

# Login first
login_req = urllib.request.Request(
    'http://localhost:8000/api/v1/auth/login',
    data=json.dumps({'email': 'naeemubeen639@gmail.com', 'password': 'Naeem@123'}).encode(),
    headers={'Content-Type': 'application/json'}
)
login_resp = urllib.request.urlopen(login_req, timeout=10)
token = json.loads(login_resp.read())['access_token']
print(f"Logged in, token: {token[:30]}...")

# Try to create a test session
for cat in ['cognitive', 'speech', 'motor', 'gait', 'facial']:
    try:
        req = urllib.request.Request(
            'http://localhost:8000/api/v1/tests/',
            data=json.dumps({'category': cat}).encode(),
            headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
            method='POST'
        )
        resp = urllib.request.urlopen(req, timeout=10)
        data = json.loads(resp.read())
        print(f"Created {cat} session: id={data.get('id')}, status={data.get('status')}")
        
        # Cancel it right away so we can test the next one
        cancel_req = urllib.request.Request(
            f"http://localhost:8000/api/v1/tests/{data['id']}/cancel",
            headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
            method='POST'
        )
        cancel_resp = urllib.request.urlopen(cancel_req, timeout=10)
        print(f"  Cancelled {cat} session")
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"FAILED {cat}: {e.code} - {body[:300]}")
