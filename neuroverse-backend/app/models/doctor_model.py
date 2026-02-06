# app/models/doctor.py
# ============================================================
# DOCTOR MODEL - Healthcare Professional Account
# ============================================================

from sqlalchemy import Column, String, Integer, Boolean, DateTime, Text, Enum as SQLEnum, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.db.database import Base
import enum


class DoctorSpecialization(str, enum.Enum):
    NEUROLOGIST = "neurologist"
    PSYCHIATRIST = "psychiatrist"
    GERIATRICIAN = "geriatrician"
    GENERAL_PHYSICIAN = "general_physician"
    PSYCHOLOGIST = "psychologist"
    RESEARCHER = "researcher"
    OTHER = "other"


class DoctorStatus(str, enum.Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    SUSPENDED = "suspended"
    PENDING_VERIFICATION = "pending_verification"


class Doctor(Base):
    __tablename__ = "doctors"

    id = Column(Integer, primary_key=True, index=True)
    
    # Basic Info
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    phone = Column(String(20), nullable=True)
    
    # Professional Info
    specialization = Column(String(50), default="neurologist")
    license_number = Column(String(100), nullable=True)
    hospital_affiliation = Column(String(255), nullable=True)
    department = Column(String(100), nullable=True)
    years_of_experience = Column(Integer, default=0)
    
    # Profile
    profile_image_path = Column(String(500), nullable=True)
    bio = Column(Text, nullable=True)
    
    # Status & Verification
    status = Column(String(50), default="active")
    is_verified = Column(Boolean, default=False)
    verified_at = Column(DateTime(timezone=True), nullable=True)
    verified_by = Column(Integer, nullable=True)  # Admin ID who verified
    
    # Access Control
    can_view_patients = Column(Boolean, default=True)
    can_add_notes = Column(Boolean, default=True)
    can_export_reports = Column(Boolean, default=True)
    can_request_dataset = Column(Boolean, default=False)  # Research access
    
    # Statistics
    total_patients_viewed = Column(Integer, default=0)
    total_notes_created = Column(Integer, default=0)
    total_reports_exported = Column(Integer, default=0)
    
    # Timestamps
    last_login_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    clinical_notes = relationship("ClinicalNote", back_populates="doctor", cascade="all, delete-orphan")
    patient_accesses = relationship("PatientAccess", back_populates="doctor", cascade="all, delete-orphan")

    @property
    def full_name(self) -> str:
        return f"{self.first_name} {self.last_name}"

    def __repr__(self):
        return f"<Doctor {self.email} - {self.specialization}>"


class ClinicalNote(Base):
    """Clinical notes added by doctors for patients"""
    __tablename__ = "clinical_notes"

    id = Column(Integer, primary_key=True, index=True)
    doctor_id = Column(Integer, ForeignKey("doctors.id", ondelete="CASCADE"), nullable=False, index=True)
    patient_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Note Content
    title = Column(String(255), nullable=False)
    content = Column(Text, nullable=False)
    note_type = Column(String(50), default="general")  # general, diagnosis, treatment, follow_up
    
    # Related Data
    related_session_id = Column(Integer, nullable=True)  # Test session if applicable
    related_report_id = Column(Integer, nullable=True)   # Report if applicable
    
    # Status
    is_private = Column(Boolean, default=False)  # Only visible to this doctor
    is_flagged = Column(Boolean, default=False)  # Important/urgent
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    doctor = relationship("Doctor", back_populates="clinical_notes")
    patient = relationship("User", back_populates="clinical_notes")

    def __repr__(self):
        return f"<ClinicalNote {self.id} by Doctor {self.doctor_id}>"


class PatientAccess(Base):
    """Track which doctors have accessed which patients"""
    __tablename__ = "patient_accesses"

    id = Column(Integer, primary_key=True, index=True)
    doctor_id = Column(Integer, ForeignKey("doctors.id", ondelete="CASCADE"), nullable=False, index=True)
    patient_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Access Info
    access_type = Column(String(50), default="view")  # view, export, note_added
    accessed_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    doctor = relationship("Doctor", back_populates="patient_accesses")

    def __repr__(self):
        return f"<PatientAccess Doctor:{self.doctor_id} Patient:{self.patient_id}>"


class DatasetRequest(Base):
    """Requests for anonymized research datasets"""
    __tablename__ = "dataset_requests"

    id = Column(Integer, primary_key=True, index=True)
    doctor_id = Column(Integer, ForeignKey("doctors.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # Request Details
    purpose = Column(Text, nullable=False)
    research_title = Column(String(255), nullable=True)
    institution = Column(String(255), nullable=True)
    
    # Data Specifications
    data_types = Column(Text, nullable=True)  # JSON: ["cognitive", "motor", etc.]
    date_range_start = Column(DateTime(timezone=True), nullable=True)
    date_range_end = Column(DateTime(timezone=True), nullable=True)
    min_samples = Column(Integer, default=100)
    
    # Status
    status = Column(String(50), default="pending")  # pending, approved, rejected, completed
    reviewed_by = Column(Integer, nullable=True)  # Admin ID
    reviewed_at = Column(DateTime(timezone=True), nullable=True)
    rejection_reason = Column(Text, nullable=True)
    
    # Generated Dataset
    dataset_path = Column(String(500), nullable=True)
    samples_included = Column(Integer, nullable=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    def __repr__(self):
        return f"<DatasetRequest {self.id} by Doctor {self.doctor_id} - {self.status}>"