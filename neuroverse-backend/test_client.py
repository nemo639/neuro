"""Test using FastAPI TestClient to see the actual error."""
import sys
sys.path.insert(0, 'd:\\neuroverse\\neuroverse-backend')

from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

print("Testing with FastAPI TestClient...")
print("="*60)

# Test health endpoint
print("\n1. Health check:")
response = client.get("/health")
print(f"   Status: {response.status_code}")
print(f"   Response: {response.json()}")

# Test login
print("\n2. Doctor login:")
response = client.post(
    "/api/v1/doctors/login",
    json={"email": "dr.smith@neuroverse.com", "password": "Doctor123"}
)
print(f"   Status: {response.status_code}")
print(f"   Response: {response.text}")
