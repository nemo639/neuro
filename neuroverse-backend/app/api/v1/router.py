"""
API v1 Router - Combines all endpoint routers
"""

from fastapi import APIRouter
from app.api.v1.endpoints import admin
from app.api.v1.endpoints import auth, users, tests, wellness, reports
from app.api.v1.endpoints import feedback, test, doctor_endpoints

api_router = APIRouter(prefix="/api/v1")

# Include all endpoint routers
api_router.include_router(auth.router, prefix="/auth", tags=["Authentication"])
api_router.include_router(users.router, prefix="/users", tags=["Users"])
api_router.include_router(tests.router, prefix="/tests", tags=["Tests"])
api_router.include_router(wellness.router, prefix="/wellness", tags=["Wellness"])
api_router.include_router(reports.router, prefix="/reports", tags=["Reports"])
api_router.include_router(feedback.router, prefix="/feedback", tags=["Feedback"])
# Additional routers can be added here as needed
api_router.include_router(test.router, prefix="/test", tags=["Email Testing"])
# Doctor endpoints - router already has /doctors prefix
api_router.include_router(doctor_endpoints.router)
api_router.include_router(admin.router)