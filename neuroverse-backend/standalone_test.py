"""Standalone server test - run this in separate terminal."""
import subprocess
import time
import requests
import sys

def main():
    # Test if server is already running
    try:
        r = requests.get("http://localhost:8000/health", timeout=2)
        if r.status_code == 200:
            print("[OK] Server is running")
        else:
            print("[ERROR] Server responded but not healthy")
            return
    except:
        print("[ERROR] Server not running")
        print("Please start the server in a SEPARATE terminal with:")
        print("  cd d:\\neuroverse\\neuroverse-backend")
        print("  python -m uvicorn app.main:app --host 0.0.0.0 --port 8000")
        return
    
    print("\n" + "="*60)
    print("TESTING LOGIN ENDPOINT")
    print("="*60)
    
    url = "http://localhost:8000/api/v1/doctors/login"
    data = {"email": "dr.smith@neuroverse.com", "password": "Doctor123"}
    
    print(f"URL: {url}")
    print(f"Data: {data}")
    
    try:
        r = requests.post(url, json=data, timeout=30)
        print(f"\nStatus: {r.status_code}")
        print(f"Headers: {dict(r.headers)}")
        print(f"\nResponse Body:")
        print(r.text)
        
        if r.status_code == 200:
            print("\n✅ LOGIN SUCCESSFUL!")
        else:
            print(f"\n❌ LOGIN FAILED with status {r.status_code}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
