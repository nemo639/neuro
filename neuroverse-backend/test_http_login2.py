"""Test login with more detailed error handling."""
import requests
import traceback

# Test login with detailed error capture
url = "http://localhost:8000/api/v1/doctors/login"
data = {
    "email": "dr.smith@neuroverse.com",
    "password": "Doctor123"
}

print(f"Testing login API: {url}")
print(f"Request data: {data}")
print("-" * 50)

try:
    response = requests.post(url, json=data, timeout=30)
    print(f"Status Code: {response.status_code}")
    print(f"Headers: {dict(response.headers)}")
    print(f"Response Body:")
    print(response.text)
    
    if response.status_code == 200:
        print("\n✅ LOGIN SUCCESSFUL!")
        import json
        data = response.json()
        print(f"Access Token: {data.get('access_token', 'N/A')[:50]}...")
        print(f"Doctor Email: {data.get('doctor', {}).get('email', 'N/A')}")
except requests.exceptions.ConnectionError as e:
    print(f"Connection Error: Server not running? {e}")
except Exception as e:
    print(f"Error: {e}")
    traceback.print_exc()
