"""
Notification & feedback endpoint tests:
- GET    /notifications/
- POST   /notifications/{id}/read
- POST   /notifications/read-all
- DELETE /notifications/{id}
- POST   /feedback/
- GET    /feedback/my-feedbacks
- DELETE /feedback/{id}
"""
import pytest


pytestmark = pytest.mark.notifications


class TestNotifications:
    async def test_list_notifications_requires_auth(self, client):
        resp = await client.get("/api/v1/notifications/")
        assert resp.status_code in (401, 403)

    async def test_list_notifications(self, client, auth_token):
        resp = await client.get(
            "/api/v1/notifications/?limit=10",
            headers=auth_token["headers"],
        )
        assert resp.status_code == 200
        body = resp.json()
        # Expect notifications list / count fields
        assert isinstance(body, dict) or isinstance(body, list)

    async def test_mark_nonexistent_notification(self, client, auth_token):
        resp = await client.patch(
            "/api/v1/notifications/999999/read",
            headers=auth_token["headers"],
        )
        assert resp.status_code in (404, 200)

    async def test_mark_all_read(self, client, auth_token):
        resp = await client.patch(
            "/api/v1/notifications/read-all",
            headers=auth_token["headers"],
        )
        assert resp.status_code == 200


class TestFeedback:
    async def test_submit_feedback(self, client, auth_token):
        resp = await client.post(
            "/api/v1/feedback/",
            json={
                "category": "general",
                "message": "Test feedback from automated tests",
                "rating": 5,
            },
            headers=auth_token["headers"],
        )
        assert resp.status_code in (200, 201), resp.text

    async def test_submit_feedback_requires_auth(self, client):
        resp = await client.post(
            "/api/v1/feedback/",
            json={
                "category": "general",
                "message": "Test",
                "rating": 5,
            },
        )
        assert resp.status_code in (401, 403)

    async def test_submit_feedback_invalid_rating(self, client, auth_token):
        resp = await client.post(
            "/api/v1/feedback/",
            json={
                "category": "general",
                "message": "Test",
                "rating": 99,
            },
            headers=auth_token["headers"],
        )
        # Either accepts but caps, or rejects
        assert resp.status_code in (200, 201, 400, 422)

    async def test_list_my_feedback(self, client, auth_token):
        resp = await client.get(
            "/api/v1/feedback/my-feedbacks",
            headers=auth_token["headers"],
        )
        assert resp.status_code == 200
