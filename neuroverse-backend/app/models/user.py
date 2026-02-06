"""
User Model - Stores user profile, authentication, and risk scores
"""

from sqlalchemy import Column, Integer, String, Float, DateTime, Boolean, Date
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.db.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)

    # Authentication
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)

    # Profile
    first_name = Column(String, nullable=False)
    last_name = Column(String, nullable=False)
    phone = Column(String, nullable=True)
    date_of_birth = Column(Date, nullable=True)
    gender = Column(String, nullable=True)  # "male", "female", "other"
    profile_image_path = Column(String, nullable=True)

    # OTP & Verification
    otp_code = Column(String, nullable=True)
    otp_expires_at = Column(DateTime, nullable=True)
    is_verified = Column(Boolean, default=False)

    # Risk Scores (0-100, calculated by ML fusion)
    ad_risk_score = Column(Float, default=0.0)  # Alzheimer's Disease risk
    pd_risk_score = Column(Float, default=0.0)  # Parkinson's Disease risk

    # Category-specific scores (0-100)
    cognitive_score = Column(Float, default=0.0)
    speech_score = Column(Float, default=0.0)
    motor_score = Column(Float, default=0.0)
    gait_score = Column(Float, default=0.0)
    facial_score = Column(Float, default=0.0)

    # Stage Classification
    ad_stage = Column(String, nullable=True)  # "CN", "MCI", "Mild AD", "Moderate AD", "Severe AD"
    pd_stage = Column(String, nullable=True)  # "Normal", "Early PD", "Moderate PD", "Advanced PD"

    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relationships
    test_sessions = relationship("TestSession", back_populates="user", cascade="all, delete-orphan")
    wellness_entries = relationship("WellnessEntry", back_populates="user", cascade="all, delete-orphan")
    reports = relationship("Report", back_populates="user", cascade="all, delete-orphan")

    feedbacks = relationship("Feedback", back_populates="user", cascade="all, delete-orphan")
    clinical_notes = relationship("ClinicalNote", back_populates="patient", cascade="all, delete-orphan")
    @property
    def full_name(self) -> str:
        return f"{self.first_name} {self.last_name}"

    @property
    def age(self) -> int | None:
        if self.date_of_birth:
            from datetime import date
            today = date.today()
            return today.year - self.date_of_birth.year - (
                (today.month, today.day) < (self.date_of_birth.month, self.date_of_birth.day)
            )
        return None
