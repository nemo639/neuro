"""
NeuroVerse Security Utilities
JWT tokens, password hashing, OTP generation
"""

from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import secrets
import string
from app.models.doctor_model import Doctor  # Add this import
from app.db.database import get_db
from app.core.config import settings
from fastapi.security import OAuth2PasswordBearer
from app.models.admin import Admin
from app.models.user import User  # ← This was missing!

# Add this line (define oauth2_scheme)
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")
# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
# JWT Bearer
security = HTTPBearer()


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plain password against a hashed password."""
    return pwd_context.verify(plain_password, hashed_password)

async def get_current_doctor(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
) -> Doctor:
    """
    Get current authenticated doctor from JWT token.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id: str = payload.get("sub")
        user_type: str = payload.get("type")
        
        if user_id is None:
            raise credentials_exception
        
        # Verify this is a doctor token
        if user_type != "doctor":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not authorized. Doctor access required."
            )
            
    except JWTError:
        raise credentials_exception
    
    # Get doctor from database
    result = await db.execute(select(Doctor).where(Doctor.id == user_id))
    doctor = result.scalar_one_or_none()
    
    if doctor is None:
        raise credentials_exception
    
    return doctor
def verify_otp(stored_otp: str, provided_otp: str, expiry_time: datetime) -> bool:
    """
    Verify OTP code and check if it's expired.
    
    Args:
        stored_otp: The OTP stored in database
        provided_otp: The OTP provided by user
        expiry_time: The expiration datetime of the OTP
    
    Returns:
        True if OTP is valid and not expired, False otherwise
    """
    # Check if OTP matches
    if stored_otp != provided_otp:
        return False
    
    # Check if OTP is expired
    if datetime.utcnow() > expiry_time:
        return False
    
    return True

def get_password_hash(password: str) -> str:
    """Hash a password."""
    return pwd_context.hash(password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create a JWT access token."""
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire, "type": "access"})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def create_refresh_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    """Create a JWT refresh token."""
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS))
    to_encode.update({"exp": expire, "type": "refresh"})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def decode_token(token: str) -> Optional[dict]:
    """Decode and verify a JWT token."""
    try:
        return jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
    except JWTError:
        return None


def generate_otp(length: int = None) -> str:
    """Generate a numeric OTP code."""
    length = length or settings.OTP_LENGTH
    return ''.join(secrets.choice(string.digits) for _ in range(length))


def generate_reset_token() -> str:
    """Generate a secure random token for password reset."""
    return secrets.token_urlsafe(32)


async def get_current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> int:
    """Extract user ID from JWT token."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    token = credentials.credentials
    payload = decode_token(token)

    if payload is None or payload.get("type") != "access":
        raise credentials_exception

    user_id = payload.get("sub")
    if user_id is None:
        raise credentials_exception

    return int(user_id)


async def get_current_user_id_optional(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(HTTPBearer(auto_error=False))
) -> Optional[int]:
    """Extract user ID from JWT token (optional - returns None if no token)."""
    if credentials is None:
        return None

    payload = decode_token(credentials.credentials)
    if payload is None or payload.get("type") != "access":
        return None

    user_id = payload.get("sub")
    return int(user_id) if user_id else None

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# OAuth2 scheme
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def create_refresh_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)


def generate_otp() -> str:
    return ''.join(random.choices(string.digits, k=6))


def verify_otp(stored_otp: str, otp_expires_at: datetime, provided_otp: str) -> bool:
    if not stored_otp or not otp_expires_at:
        return False
    if datetime.utcnow() > otp_expires_at:
        return False
    return stored_otp == provided_otp


# ==================== GET CURRENT USER ====================
async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
) -> User:
    """Get current authenticated user from JWT token."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    
    if user is None:
        raise credentials_exception
    
    return user


# ==================== GET CURRENT DOCTOR ====================
async def get_current_doctor(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
) -> Doctor:
    """Get current authenticated doctor from JWT token."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id: str = payload.get("sub")
        user_type: str = payload.get("type")
        
        if user_id is None:
            raise credentials_exception
        
        if user_type != "doctor":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not authorized. Doctor access required."
            )
            
    except JWTError:
        raise credentials_exception
    
    result = await db.execute(select(Doctor).where(Doctor.id == user_id))
    doctor = result.scalar_one_or_none()
    
    if doctor is None:
        raise credentials_exception
    
    return doctor


# ==================== GET CURRENT ADMIN ====================
async def get_current_admin(
    token: str = Depends(oauth2_scheme),
    db: AsyncSession = Depends(get_db)
) -> Admin:
    """Get current authenticated admin from JWT token."""
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        user_id: str = payload.get("sub")
        user_type: str = payload.get("type")
        
        if user_id is None:
            raise credentials_exception
        
        if user_type != "admin":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not authorized. Admin access required."
            )
            
    except JWTError:
        raise credentials_exception
    
    result = await db.execute(select(Admin).where(Admin.id == user_id))
    admin = result.scalar_one_or_none()
    
    if admin is None:
        raise credentials_exception
    
    if not admin.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin account is deactivated."
        )
    
    return admin
