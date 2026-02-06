"""Test login API via HTTP."""
import requests

# Test login
url = "http://localhost:8000/api/v1/doctors/login"
data = {
    "email": "dr.smith@neuroverse.com",
    "password": "Doctor123"
}

print(f"Testing login API: {url}")
print(f"Request data: {data}")
print("-" * 50)

try:
    response = requests.post(url, json=data)
    print(f"Status Code: {response.status_code}")
    print(f"Response:")
    print(response.text)
except Exception as e:
    print(f"Error: {e}")
