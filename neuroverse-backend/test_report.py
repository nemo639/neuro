import urllib.request
import urllib.error
import json
import asyncio
from app.db.database import AsyncSessionLocal
from app.core.security import create_access_token
from sqlalchemy import text

BASE = "http://localhost:8000/api/v1"

async def get_doctor_id():
    async with AsyncSessionLocal() as db:
        r = await db.execute(text("SELECT id, first_name, last_name, email FROM doctors LIMIT 1"))
        row = r.fetchone()
        return row if row else None

doc = asyncio.run(get_doctor_id())
print(f"Doctor: id={doc[0]} {doc[1]} {doc[2]} ({doc[3]})")

# Create a valid token directly
token = create_access_token(data={"sub": str(doc[0]), "type": "doctor"})
print(f"Token created: {token[:30]}...")

# Test generate
try:
    data = json.dumps({"patient_id": 61, "report_type": "speech_cognitive"}).encode()
    req = urllib.request.Request(f"{BASE}/doctors/reports/generate", data=data, 
                                 headers={"Content-Type": "application/json", "Authorization": f"Bearer {token}"}, method="POST")
    resp = urllib.request.urlopen(req, timeout=30)
    result = resp.read().decode()
    print(f"Generate OK: {result[:500]}")
except urllib.error.HTTPError as e:
    body = e.read().decode()
    print(f"Generate FAILED: {e.code}")
    print(f"Error: {body[:1000]}")
except Exception as e:
    print(f"Generate error: {e}")
