"""
Doctor endpoint tests:
- POST /doctors/login
- POST /doctors/forgot-password
- POST /doctors/reset-password
- GET  /doctors/me
- PATCH /doctors/me
- GET  /doctors/dashboard
- GET  /doctors/patients
- GET  /doctors/patients/{id}
- POST /doctors/notes
- GET  /doctors/notes
- PATCH /doctors/notes/{id}
- DELETE /doctors/notes/{id}
- GET  /doctors/alerts
"""
import pytest


pytestmark = pytest.mark.doctor


class TestDoctorAuth:
    async def test_doctor_login_wrong_password(self, client):
        resp = await client.post("/api/v1/doctors/login", json={
            "email": "doctor@neuroverse.com",
            "password": "WrongPassword",
        })
        assert resp.status_code in (400, 401, 403)

    async def test_doctor_login_nonexistent(self, client):
        resp = await client.post("/api/v1/doctors/login", json={
            "email": "nobody@nowhere.com",
            "password": "Test@1234",
        })
        assert resp.status_code in (400, 401, 404)

    async def test_doctor_login_success(self, client, doctor_token):
        # If fixture loaded, login worked
        assert doctor_token["token"]


class TestDoctorMe:
    async def test_doctor_me_requires_auth(self, client):
        resp = await client.get("/api/v1/doctors/me")
        assert resp.status_code in (401, 403)

    async def test_doctor_me_returns_profile(self, client, doctor_token):
        resp = await client.get("/api/v1/doctors/me", headers=doctor_token["headers"])
        assert resp.status_code == 200
        body = resp.json()
        assert "email" in body or "data" in body


class TestDoctorDashboard:
    async def test_dashboard_requires_auth(self, client):
        resp = await client.get("/api/v1/doctors/dashboard")
        assert resp.status_code in (401, 403)

    async def test_dashboard_returns_data(self, client, doctor_token):
        resp = await client.get("/api/v1/doctors/dashboard", headers=doctor_token["headers"])
        assert resp.status_code == 200


class TestDoctorPatients:
    async def test_list_patients(self, client, doctor_token):
        resp = await client.get("/api/v1/doctors/patients", headers=doctor_token["headers"])
        assert resp.status_code == 200

    async def test_list_patients_requires_auth(self, client):
        resp = await client.get("/api/v1/doctors/patients")
        assert resp.status_code in (401, 403)

    async def test_get_nonexistent_patient(self, client, doctor_token):
        resp = await client.get(
            "/api/v1/doctors/patients/999999",
            headers=doctor_token["headers"],
        )
        assert resp.status_code in (403, 404)


class TestDoctorNotes:
    async def test_list_notes(self, client, doctor_token):
        resp = await client.get("/api/v1/doctors/notes", headers=doctor_token["headers"])
        assert resp.status_code == 200

    async def test_create_note_invalid_patient(self, client, doctor_token):
        resp = await client.post(
            "/api/v1/doctors/notes",
            json={
                "patient_id": 999999,
                "note_type": "general",
                "content": "Test note",
            },
            headers=doctor_token["headers"],
        )
        assert resp.status_code in (400, 403, 404, 422)


class TestDoctorAlerts:
    async def test_list_alerts(self, client, doctor_token):
        resp = await client.get("/api/v1/doctors/alerts", headers=doctor_token["headers"])
        assert resp.status_code == 200
