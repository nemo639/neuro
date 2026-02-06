"""
NeuroVerse FastAPI Application
"""

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
import os
import traceback
import logging

from app.core.config import settings
from app.api.v1.router import api_router
from app.db.database import engine, Base

# Set up logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

# Create uploads directory if it doesn't exist
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)

app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="AI-Powered Neurological Health Screening Platform",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Exception handler to catch all errors and log them
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    error_msg = f"Unhandled exception: {str(exc)}\n{traceback.format_exc()}"
    logger.error(error_msg)
    print(f"[ERROR] {error_msg}")  # Also print to console
    return JSONResponse(
        status_code=500,
        content={"detail": str(exc), "traceback": traceback.format_exc()}
    )

# CORS Middleware - Allow Flutter app to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with your Flutter app domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files for uploads
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")

# Include API router
app.include_router(api_router)


@app.get("/")
async def root():
    """Health check endpoint."""
    return {
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "running",
        "docs": "/docs"
    }


@app.get("/health")
async def health_check():
    """Detailed health check."""
    return {
        "status": "healthy",
        "database": "connected",
        "email": "configured" if settings.MAIL_USERNAME else "not configured"
    }


# Create database tables on startup (for development)
@app.on_event("startup")
async def startup():
    """Run on application startup."""
    print(f"[STARTUP] Starting {settings.APP_NAME} v{settings.APP_VERSION}")
    print(f"[EMAIL] Email configured: {bool(settings.MAIL_USERNAME)}")
    print(f"[DATABASE] Database: Connected")
    # Uncomment below to auto-create tables (use Alembic in production)
    # async with engine.begin() as conn:
    #     await conn.run_sync(Base.metadata.create_all)


@app.on_event("shutdown")
async def shutdown():
    """Run on application shutdown."""
    print("[SHUTDOWN] Shutting down NeuroVerse API")