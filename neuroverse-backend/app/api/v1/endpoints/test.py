"""
Email Testing Endpoints - For development/testing purposes only
"""

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel, EmailStr
from typing import Optional, Literal
from app.services.email_service import EmailService
from app.core.config import settings
from app.core.security import generate_otp  # Import the OTP generator

router = APIRouter()


class EmailTestRequest(BaseModel):
    """Request model for testing emails"""
    email: EmailStr
    email_type: Literal["otp", "password_reset", "report_ready", "risk_alert"] = "otp"
    recipient_name: Optional[str] = "Test User"
    report_title: Optional[str] = "Monthly Health Assessment"
    risk_type: Optional[str] = "Alzheimer's Disease"
    risk_score: Optional[float] = 75.5


@router.post("/test-email", tags=["Testing"])
async def test_email(request: EmailTestRequest):
    """
    Test email sending with different templates.
    
    **Email Types:**
    - `otp`: OTP verification email
    - `password_reset`: Password reset OTP
    - `report_ready`: Report ready notification
    - `risk_alert`: High risk alert notification
    
    **Example:**
    ```json
    {
      "email": "test@example.com",
      "email_type": "otp",
      "recipient_name": "John Doe",
      "otp": "123456"
    }
    ```
    """
    if not settings.MAIL_USERNAME or not settings.MAIL_PASSWORD:
        raise HTTPException(
            status_code=503,
            detail="Email service not configured. Please set MAIL_USERNAME and MAIL_PASSWORD in .env"
        )
    
    try:
        email_service = EmailService()
        success = False
        otp_code = None  # Store generated OTP to return in response
        
        if request.email_type == "otp":
            otp_code = generate_otp()  # Generate random OTP
            success = await email_service.send_otp_email(
                to_email=request.email,
                otp=otp_code,
                name=request.recipient_name
            )
            
        elif request.email_type == "password_reset":
            otp_code = generate_otp()  # Generate random OTP
            success = await email_service.send_password_reset_email(
                to_email=request.email,
                otp=otp_code,
                name=request.recipient_name
            )
            
        elif request.email_type == "report_ready":
            success = await email_service.send_report_ready_email(
                to_email=request.email,
                name=request.recipient_name,
                report_title=request.report_title or "Monthly Health Assessment"
            )
            
        elif request.email_type == "risk_alert":
            success = await email_service.send_risk_alert_email(
                to_email=request.email,
                name=request.recipient_name,
                risk_type=request.risk_type or "Alzheimer's Disease",
                risk_score=request.risk_score or 75.5
            )
        
        if success:
            response_data = {
                "success": True,
                "message": f"{request.email_type.upper()} email sent successfully to {request.email}",
                "details": {
                    "email_type": request.email_type,
                    "recipient": request.email,
                    "smtp_server": settings.MAIL_SERVER,
                    "from_address": settings.MAIL_FROM
                }
            }
            
            # Include OTP in response for testing purposes
            if otp_code:
                response_data["otp"] = otp_code
                response_data["note"] = "OTP shown for testing purposes only. In production, this would not be returned."
            
            return response_data
        else:
            raise HTTPException(
                status_code=500,
                detail="Failed to send email. Check server logs for details."
            )
            
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error sending email: {str(e)}"
        )


@router.get("/test-email/config", tags=["Testing"])
async def get_email_config():
    """
    Get current email configuration status (for debugging).
    """
    return {
        "configured": bool(settings.MAIL_USERNAME and settings.MAIL_PASSWORD),
        "smtp_server": settings.MAIL_SERVER,
        "smtp_port": settings.MAIL_PORT,
        "from_address": settings.MAIL_FROM,
        "from_name": settings.MAIL_FROM_NAME,
        "starttls": settings.MAIL_STARTTLS,
        "username": settings.MAIL_USERNAME if settings.MAIL_USERNAME else "Not configured",
        "password_set": bool(settings.MAIL_PASSWORD),
    }


@router.post("/test-email/quick/{email_type}", tags=["Testing"])
async def quick_test_email(
    email_type: Literal["otp", "password_reset", "report_ready", "risk_alert"],
    to_email: EmailStr
):
    """
    Quick test email with default values.
    
    **Usage:**
    - `POST /test-email/quick/otp?to_email=user@example.com`
    - `POST /test-email/quick/password_reset?to_email=user@example.com`
    """
    if not settings.MAIL_USERNAME or not settings.MAIL_PASSWORD:
        raise HTTPException(
            status_code=503,
            detail="Email service not configured"
        )
    
    try:
        email_service = EmailService()
        success = False
        otp_code = generate_otp()  # Generate random OTP
        
        if email_type == "otp":
            success = await email_service.send_otp_email(
                to_email=to_email,
                otp=otp_code,
                name="Test User"
            )
        elif email_type == "password_reset":
            success = await email_service.send_password_reset_email(
                to_email=to_email,
                otp=otp_code,
                name="Test User"
            )
        elif email_type == "report_ready":
            success = await email_service.send_report_ready_email(
                to_email=to_email,
                name="Test User",
                report_title="Test Health Report"
            )
        elif email_type == "risk_alert":
            success = await email_service.send_risk_alert_email(
                to_email=to_email,
                name="Test User",
                risk_type="Test Risk Assessment",
                risk_score=75.0
            )
        
        if success:
            response = {
                "success": True,
                "message": f"{email_type} email sent to {to_email}"
            }
            # Include OTP for testing
            if email_type in ["otp", "password_reset"]:
                response["otp"] = otp_code
            return response
        else:
            raise HTTPException(500, "Failed to send email")
            
    except Exception as e:
        raise HTTPException(500, f"Error: {str(e)}")


@router.post("/test-email/batch", tags=["Testing"])
async def test_batch_emails(emails: list[EmailStr]):
    """
    Send test OTP emails to multiple recipients.
    
    **Example:**
    ```json
    ["user1@example.com", "user2@example.com", "user3@example.com"]
    ```
    """
    if not settings.MAIL_USERNAME or not settings.MAIL_PASSWORD:
        raise HTTPException(503, "Email service not configured")
    
    if len(emails) > 10:
        raise HTTPException(400, "Maximum 10 emails allowed per batch")
    
    email_service = EmailService()
    results = []
    
    for email in emails:
        try:
            otp_code = generate_otp()  # Generate unique OTP for each email
            success = await email_service.send_otp_email(
                to_email=email,
                otp=otp_code,
                name="Test User"
            )
            results.append({
                "email": email,
                "success": success,
                "otp": otp_code if success else None,
                "error": None if success else "Failed to send"
            })
        except Exception as e:
            results.append({
                "email": email,
                "success": False,
                "error": str(e)
            })
    
    successful = sum(1 for r in results if r["success"])
    
    return {
        "total": len(emails),
        "successful": successful,
        "failed": len(emails) - successful,
        "results": results
    }