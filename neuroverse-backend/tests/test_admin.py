"""
Admin endpoint tests:
- POST /admin/login
- GET  /admin/dashboard
- GET  /admin/users
- GET  /admin/doctors
- POST /admin/doctors/verify
- GET  /admin/tickets
- GET  /admin/tickets/{id}
- POST /admin/tickets/assign
- POST /admin/tickets/resolve
- POST /admin/tickets/reply
- GET  /admin/permissions
- POST /admin/permissions/grant
- POST /admin/permissions/revoke
"""
import pytest


pytestmark = pytest.mark.admin


class TestAdminAuth:
    async def test_admin_login_wrong_password(self, client):
        resp = await client.post("/api/v1/admin/login", json={
            "email": "admin@neuroverse.com",
            "password": "WrongPassword",
        })
        assert resp.status_code in (400, 401, 403)

    async def test_admin_login_nonexistent(self, client):
        resp = await client.post("/api/v1/admin/login", json={
            "email": "nobody@nowhere.com",
            "password": "Test@1234",
        })
        assert resp.status_code in (400, 401, 404)

    async def test_admin_login_success(self, client, admin_token):
        assert admin_token["token"]


class TestAdminDashboard:
    async def test_dashboard_requires_auth(self, client):
        resp = await client.get("/api/v1/admin/dashboard")
        assert resp.status_code in (401, 403)

    async def test_dashboard_returns_data(self, client, admin_token):
        resp = await client.get("/api/v1/admin/dashboard", headers=admin_token["headers"])
        assert resp.status_code == 200


class TestAdminUsers:
    async def test_list_users(self, client, admin_token):
        resp = await client.get("/api/v1/admin/users", headers=admin_token["headers"])
        assert resp.status_code == 200

    async def test_list_users_requires_auth(self, client):
        resp = await client.get("/api/v1/admin/users")
        assert resp.status_code in (401, 403)

    async def test_list_users_pagination(self, client, admin_token):
        resp = await client.get(
            "/api/v1/admin/users?limit=10&offset=0",
            headers=admin_token["headers"],
        )
        assert resp.status_code == 200


class TestAdminDoctors:
    async def test_list_doctors(self, client, admin_token):
        resp = await client.get("/api/v1/admin/doctors", headers=admin_token["headers"])
        assert resp.status_code == 200

    async def test_list_doctors_requires_auth(self, client):
        resp = await client.get("/api/v1/admin/doctors")
        assert resp.status_code in (401, 403)


class TestAdminTickets:
    async def test_list_tickets(self, client, admin_token):
        resp = await client.get("/api/v1/admin/tickets", headers=admin_token["headers"])
        assert resp.status_code == 200

    async def test_get_nonexistent_ticket(self, client, admin_token):
        resp = await client.get(
            "/api/v1/admin/tickets/999999",
            headers=admin_token["headers"],
        )
        assert resp.status_code in (403, 404)


class TestAdminPermissions:
    async def test_list_permissions(self, client, admin_token):
        resp = await client.get("/api/v1/admin/permissions", headers=admin_token["headers"])
        assert resp.status_code == 200


class TestAdminAccessControl:
    async def test_admin_endpoint_rejects_user_token(self, client, auth_token):
        """A regular user token must NOT access admin endpoints."""
        resp = await client.get("/api/v1/admin/dashboard", headers=auth_token["headers"])
        assert resp.status_code in (401, 403)
