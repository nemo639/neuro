"""
Email Service - OTP, notifications, and transactional emails
"""

from typing import Optional
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import logging

from app.core.config import settings

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class EmailService:
    """Email service for sending OTP and notifications."""
    
    def __init__(self):
        self.smtp_server = settings.MAIL_SERVER
        self.smtp_port = settings.MAIL_PORT
        self.username = settings.MAIL_USERNAME
        self.password = settings.MAIL_PASSWORD
        self.from_email = settings.MAIL_FROM
        self.from_name = settings.MAIL_FROM_NAME
        
        # Log configuration (without password)
        logger.info(f"Email Service Initialized:")
        logger.info(f"  SMTP Server: {self.smtp_server}")
        logger.info(f"  SMTP Port: {self.smtp_port}")
        logger.info(f"  Username: {self.username}")
        logger.info(f"  From Email: {self.from_email}")
        logger.info(f"  STARTTLS: {settings.MAIL_STARTTLS}")
    
    async def send_otp_email(self, to_email: str, otp: str, name: str) -> bool:
        """Send OTP verification email."""
        subject = "NeuroVerse - Verify Your Email"
        
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
                .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
                .header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }}
                .content {{ background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }}
                .otp-box {{ background: #667eea; color: white; font-size: 32px; letter-spacing: 8px; padding: 20px; text-align: center; border-radius: 8px; margin: 20px 0; font-weight: bold; }}
                .footer {{ text-align: center; margin-top: 20px; color: #888; font-size: 12px; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>NeuroVerse</h1>
                    <p>AI-Powered Neurological Health Screening</p>
                </div>
                <div class="content">
                    <h2>Hello {name}!</h2>
                    <p>Welcome to NeuroVerse. Please use the following OTP to verify your email address:</p>
                    <div class="otp-box">{otp}</div>
                    <p><strong>This code will expire in {settings.OTP_EXPIRE_MINUTES} minutes.</strong></p>
                    <p>If you didn't request this verification, please ignore this email.</p>
                </div>
                <div class="footer">
                    <p>© 2024 NeuroVerse. All rights reserved.</p>
                    <p>This is an automated message, please do not reply.</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        return await self._send_email(to_email, subject, html_content)
    
    async def send_password_reset_email(self, to_email: str, otp: str, name: str) -> bool:
        """Send password reset OTP email."""
        subject = "NeuroVerse - Password Reset Code"
        
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
                .container {{ max-width: 600px; margin: 0 auto; padding: 20px; }}
                .header {{ background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }}
                .content {{ background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }}
                .otp-box {{ background: #f5576c; color: white; font-size: 32px; letter-spacing: 8px; padding: 20px; text-align: center; border-radius: 8px; margin: 20px 0; font-weight: bold; }}
                .warning {{ background: #fff3cd; border: 1px solid #ffc107; padding: 15px; border-radius: 8px; margin: 15px 0; }}
                .footer {{ text-align: center; margin-top: 20px; color: #888; font-size: 12px; }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>Password Reset</h1>
                    <p>NeuroVerse Account Recovery</p>
                </div>
                <div class="content">
                    <h2>Hello {name},</h2>
                    <p>We received a request to reset your password. Use this OTP to proceed:</p>
                    <div class="otp-box">{otp}</div>
                    <p><strong>This code will expire in {settings.OTP_EXPIRE_MINUTES} minutes.</strong></p>
                    <div class="warning">
                        ⚠️ If you didn't request a password reset, please ignore this email and your password will remain unchanged.
                    </div>
                </div>
                <div class="footer">
                    <p>© 2024 NeuroVerse. All rights reserved.</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        return await self._send_email(to_email, subject, html_content)
    
    async def _send_email(self, to_email: str, subject: str, html_content: str) -> bool:
        """Send email via SMTP."""
        if not self.username or not self.password:
            logger.error("❌ Email credentials not configured!")
            logger.error(f"Username: {self.username}")
            logger.error(f"Password: {'*' * len(self.password) if self.password else 'None'}")
            return False
        
        try:
            logger.info(f"📧 Preparing to send email to: {to_email}")
            logger.info(f"📧 Subject: {subject}")
            
            msg = MIMEMultipart('alternative')
            msg['Subject'] = subject
            msg['From'] = f"{self.from_name} <{self.from_email}>"
            msg['To'] = to_email
            
            # Attach HTML content
            html_part = MIMEText(html_content, 'html')
            msg.attach(html_part)
            
            # Send email
            logger.info(f"🔌 Connecting to {self.smtp_server}:{self.smtp_port}")
            
            if settings.MAIL_STARTTLS:
                # Use STARTTLS (port 587)
                logger.info("🔐 Using STARTTLS connection")
                server = smtplib.SMTP(self.smtp_server, self.smtp_port, timeout=30)
                server.set_debuglevel(1)  # Enable debug output
                server.ehlo()
                logger.info("⚡ Starting TLS...")
                server.starttls()
                server.ehlo()
            else:
                # Use SSL (port 465)
                logger.info("🔐 Using SSL connection")
                server = smtplib.SMTP_SSL(self.smtp_server, self.smtp_port, timeout=30)
            
            logger.info(f"🔑 Logging in as: {self.username}")
            server.login(self.username, self.password)
            
            logger.info(f"📤 Sending email to: {to_email}")
            server.sendmail(self.from_email, to_email, msg.as_string())
            server.quit()
            
            logger.info(f"✅ Email sent successfully to {to_email}")
            return True
            
        except smtplib.SMTPAuthenticationError as e:
            logger.error(f"❌ SMTP Authentication failed: {e}")
            logger.error("🔍 Check your email and app password")
            logger.error(f"   Username: {self.username}")
            logger.error(f"   Server: {self.smtp_server}:{self.smtp_port}")
            return False
        except smtplib.SMTPException as e:
            logger.error(f"❌ SMTP error: {e}")
            return False
        except Exception as e:
            logger.error(f"❌ Failed to send email: {type(e).__name__}: {e}")
            import traceback
            logger.error(traceback.format_exc())
            return False