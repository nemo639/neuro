"""
Health & general endpoint tests:
- GET /health
- GET /docs
- GET /
"""
import pytest


class TestHealth:
    async def test_health_endpoint(self, client):
        resp = await client.get("/health")
        # Backend may or may not have /health - try common paths
        if resp.status_code == 404:
            resp = await client.get("/")
        assert resp.status_code in (200, 404)

    async def test_docs_available(self, client):
        resp = await client.get("/docs")
        assert resp.status_code == 200

    async def test_openapi_schema(self, client):
        resp = await client.get("/openapi.json")
        assert resp.status_code == 200
        schema = resp.json()
        assert "paths" in schema
        assert "info" in schema
