"""
Test session endpoint tests:
- GET  /tests/dashboard
- POST /tests/  (create session)
- GET  /tests/  (list sessions)
- POST /tests/{id}/start
- POST /tests/{id}/items
- POST /tests/{id}/items/batch
- POST /tests/{id}/complete
- GET  /tests/{id}
- GET  /tests/latest-results
"""
import pytest


pytestmark = pytest.mark.tests


class TestDashboard:
    async def test_dashboard_requires_auth(self, client):
        resp = await client.get("/api/v1/tests/dashboard")
        assert resp.status_code in (401, 403)

    async def test_dashboard_returns_data(self, client, auth_token):
        resp = await client.get("/api/v1/tests/dashboard", headers=auth_token["headers"])
        assert resp.status_code == 200, resp.text
        body = resp.json()
        # Expect categories, risk scores, etc.
        assert isinstance(body, dict)


class TestCreateSession:
    async def test_create_cognitive_session(self, client, auth_token):
        resp = await client.post(
            "/api/v1/tests/",
            json={"category": "cognitive"},
            headers=auth_token["headers"],
        )
        assert resp.status_code in (200, 201), resp.text
        body = resp.json()
        assert "id" in body or "data" in body

    async def test_create_motor_session(self, client, auth_token):
        resp = await client.post(
            "/api/v1/tests/",
            json={"category": "motor"},
            headers=auth_token["headers"],
        )
        assert resp.status_code in (200, 201)

    async def test_create_speech_session(self, client, auth_token):
        resp = await client.post(
            "/api/v1/tests/",
            json={"category": "speech"},
            headers=auth_token["headers"],
        )
        assert resp.status_code in (200, 201)

    async def test_create_facial_session(self, client, auth_token):
        resp = await client.post(
            "/api/v1/tests/",
            json={"category": "facial"},
            headers=auth_token["headers"],
        )
        assert resp.status_code in (200, 201)

    async def test_create_invalid_category_rejected(self, client, auth_token):
        resp = await client.post(
            "/api/v1/tests/",
            json={"category": "gait"},  # gait was removed
            headers=auth_token["headers"],
        )
        assert resp.status_code in (400, 422)

    async def test_create_requires_auth(self, client):
        resp = await client.post("/api/v1/tests/", json={"category": "cognitive"})
        assert resp.status_code in (401, 403)


class TestSessionLifecycle:
    async def test_full_session_flow(self, client, auth_token):
        # Create
        create_resp = await client.post(
            "/api/v1/tests/",
            json={"category": "cognitive"},
            headers=auth_token["headers"],
        )
        assert create_resp.status_code in (200, 201)
        session_data = create_resp.json()
        session_id = session_data.get("id") or session_data.get("data", {}).get("id")
        assert session_id

        # Start
        start_resp = await client.post(
            f"/api/v1/tests/{session_id}/start",
            headers=auth_token["headers"],
        )
        assert start_resp.status_code == 200, start_resp.text

        # Get session
        get_resp = await client.get(
            f"/api/v1/tests/{session_id}",
            headers=auth_token["headers"],
        )
        assert get_resp.status_code == 200


class TestListSessions:
    async def test_list_sessions(self, client, auth_token):
        resp = await client.get("/api/v1/tests/", headers=auth_token["headers"])
        assert resp.status_code == 200
        body = resp.json()
        assert isinstance(body, (list, dict))

    async def test_list_sessions_with_filter(self, client, auth_token):
        resp = await client.get(
            "/api/v1/tests/?category=cognitive",
            headers=auth_token["headers"],
        )
        assert resp.status_code == 200


class TestLatestResults:
    async def test_latest_results(self, client, auth_token):
        resp = await client.get("/api/v1/tests/latest-results", headers=auth_token["headers"])
        assert resp.status_code == 200
