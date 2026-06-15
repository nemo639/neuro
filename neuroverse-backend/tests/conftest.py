"""
Pytest fixtures for NeuroVerse backend tests.
Uses httpx.AsyncClient against the FastAPI app.
Test users are inserted directly into DB to bypass OTP email flow.
"""
import os
import sys
import asyncio
import uuid
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from app.main import app  # noqa: E402
from app.db.database import AsyncSessionLocal  # noqa: E402
from app.core.security import get_password_hash, create_access_token  # noqa: E402
from app.models.user import User  # noqa: E402


@pytest.fixture(scope="session")
def event_loop():
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


async def _create_test_user(email: str, password: str) -> int:
    """Insert a verified user directly into DB, return user_id."""
    async with AsyncSessionLocal() as session:
        user = User(
            email=email,
            password_hash=get_password_hash(password),
            first_name="Test",
            last_name="User",
            is_verified=True,
        )
        session.add(user)
        await session.commit()
        await session.refresh(user)
        return user.id


@pytest_asyncio.fixture
async def auth_token():
    """Direct-DB test user + JWT token, no OTP email triggered."""
    email = f"pytest_{uuid.uuid4().hex[:8]}@example.com"
    password = "Test@1234"
    try:
        user_id = await _create_test_user(email, password)
    except Exception as e:
        pytest.skip(f"DB unavailable: {e}")

    token = create_access_token(data={"sub": str(user_id)})
    return {
        "token": token,
        "email": email,
        "user_id": user_id,
        "headers": {"Authorization": f"Bearer {token}"},
    }


@pytest_asyncio.fixture
async def doctor_token(client):
    resp = await client.post("/api/v1/doctors/login", json={
        "email": "doctor@neuroverse.com",
        "password": "Doctor@1234",
    })
    if resp.status_code != 200:
        pytest.skip(f"Doctor login unavailable: {resp.status_code}")
    token = resp.json().get("access_token")
    if not token:
        pytest.skip("No doctor token")
    return {"token": token, "headers": {"Authorization": f"Bearer {token}"}}


@pytest_asyncio.fixture
async def admin_token(client):
    resp = await client.post("/api/v1/admin/login", json={
        "email": "admin@neuroverse.com",
        "password": "Admin@1234",
    })
    if resp.status_code != 200:
        pytest.skip(f"Admin login unavailable: {resp.status_code}")
    token = resp.json().get("access_token")
    if not token:
        pytest.skip("No admin token")
    return {"token": token, "headers": {"Authorization": f"Bearer {token}"}}
