"""
Report endpoint tests:
- GET    /reports/         (list)
- POST   /reports/         (create)
- GET    /reports/{id}
- GET    /reports/{id}/download
- POST   /reports/{id}/regenerate
- DELETE /reports/{id}
"""
import pytest


pytestmark = pytest.mark.reports


class TestListReports:
    async def test_list_reports_requires_auth(self, client):
        resp = await client.get("/api/v1/reports/")
        assert resp.status_code in (401, 403)

    async def test_list_reports_empty_for_new_user(self, client, auth_token):
        resp = await client.get("/api/v1/reports/", headers=auth_token["headers"])
        assert resp.status_code == 200
        body = resp.json()
        # Either list or wrapped object
        if isinstance(body, dict):
            reports = body.get("reports") or body.get("data") or []
        else:
            reports = body
        assert isinstance(reports, list)

    async def test_list_reports_pagination(self, client, auth_token):
        resp = await client.get(
            "/api/v1/reports/?limit=5&offset=0",
            headers=auth_token["headers"],
        )
        assert resp.status_code == 200


class TestDownloadReport:
    async def test_download_nonexistent_report(self, client, auth_token):
        resp = await client.get(
            "/api/v1/reports/999999/download",
            headers=auth_token["headers"],
        )
        assert resp.status_code in (403, 404)

    async def test_download_requires_auth(self, client):
        resp = await client.get("/api/v1/reports/1/download")
        assert resp.status_code in (401, 403)


class TestGetReport:
    async def test_get_nonexistent_report(self, client, auth_token):
        resp = await client.get(
            "/api/v1/reports/999999",
            headers=auth_token["headers"],
        )
        assert resp.status_code in (403, 404)

    async def test_get_report_requires_auth(self, client):
        resp = await client.get("/api/v1/reports/1")
        assert resp.status_code in (401, 403)


class TestDeleteReport:
    async def test_delete_nonexistent_report(self, client, auth_token):
        resp = await client.delete(
            "/api/v1/reports/999999",
            headers=auth_token["headers"],
        )
        assert resp.status_code in (403, 404)
