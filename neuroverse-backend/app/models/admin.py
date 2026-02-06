# app/models/admin.py
# ============================================================
# ADMIN MODEL - System Administrator Account
# ============================================================

from sqlalchemy import Column, String, Integer, Boolean, DateTime, Text, Enum as SQLEnum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.db.database import Base
import enum
import uuid


class AdminRole(str, enum.Enum):
    SUPER_ADMIN = "super_admin"
    ADMIN = "admin"
    MODERATOR = "moderator"
    SUPPORT = "support"


class Admin(Base):
    __tablename__ = "admins"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # Basic Info
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    phone = Column(String(20), nullable=True)
    
    # Role & Permissions
    role = Column(SQLEnum(AdminRole), default=AdminRole.ADMIN)
    
    # Permissions
    can_manage_users = Column(Boolean, default=True)
    can_manage_doctors = Column(Boolean, default=True)
    can_manage_permissions = Column(Boolean, default=True)
    can_resolve_tickets = Column(Boolean, default=True)
    can_view_analytics = Column(Boolean, default=True)
    can_export_data = Column(Boolean, default=False)
    can_manage_admins = Column(Boolean, default=False)  # Only super_admin
    
    # Profile
    profile_image_path = Column(String(500), nullable=True)
    
    # Status
    is_active = Column(Boolean, default=True)
    
    # Activity Stats
    total_actions = Column(Integer, default=0)
    tickets_resolved = Column(Integer, default=0)
    users_managed = Column(Integer, default=0)
    
    # Timestamps
    last_login_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    def __repr__(self):
        return f"<Admin {self.email} - {self.role.value}>"


class SupportTicket(Base):
    """User support tickets"""
    __tablename__ = "support_tickets"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    ticket_number = Column(String(20), unique=True, nullable=False)  # TKT-001
    
    # Requester
    user_id = Column(String(36), nullable=True, index=True)  # Can be null for guests
    user_email = Column(String(255), nullable=False)
    user_name = Column(String(200), nullable=True)
    
    # Ticket Details
    subject = Column(String(255), nullable=False)
    description = Column(Text, nullable=False)
    category = Column(String(50), default="general")  # general, technical, billing, feedback
    priority = Column(String(20), default="medium")  # low, medium, high, urgent
    
    # Status
    status = Column(String(20), default="open")  # open, in_progress, resolved, closed
    
    # Assignment
    assigned_to = Column(String(36), nullable=True)  # Admin ID
    assigned_at = Column(DateTime(timezone=True), nullable=True)
    
    # Resolution
    resolution_notes = Column(Text, nullable=True)
    resolved_by = Column(String(36), nullable=True)
    resolved_at = Column(DateTime(timezone=True), nullable=True)
    
    # Timestamps
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    def __repr__(self):
        return f"<SupportTicket {self.ticket_number} - {self.status}>"


class TicketMessage(Base):
    """Messages in support ticket thread"""
    __tablename__ = "ticket_messages"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    ticket_id = Column(String(36), nullable=False, index=True)
    
    # Sender
    sender_type = Column(String(20), nullable=False)  # user, admin
    sender_id = Column(String(36), nullable=False)
    sender_name = Column(String(200), nullable=True)
    
    # Message
    message = Column(Text, nullable=False)
    
    # Timestamp
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    def __repr__(self):
        return f"<TicketMessage {self.id} in {self.ticket_id}>"


class AdminActivityLog(Base):
    """Audit log for admin actions"""
    __tablename__ = "admin_activity_logs"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    admin_id = Column(String(36), nullable=False, index=True)
    
    # Action Details
    action = Column(String(100), nullable=False)  # user_verified, ticket_resolved, etc.
    action_type = Column(String(50), nullable=False)  # create, update, delete, view
    target_type = Column(String(50), nullable=True)  # user, doctor, ticket, etc.
    target_id = Column(String(36), nullable=True)
    
    # Details
    details = Column(Text, nullable=True)  # JSON string with additional info
    ip_address = Column(String(50), nullable=True)
    user_agent = Column(String(500), nullable=True)
    
    # Timestamp
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    def __repr__(self):
        return f"<AdminActivityLog {self.action} by {self.admin_id}>"


class DataPermission(Base):
    """Data access permissions for doctors/researchers"""
    __tablename__ = "data_permissions"

    id = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    
    # Who
    grantee_type = Column(String(20), nullable=False)  # doctor, researcher
    grantee_id = Column(String(36), nullable=False, index=True)
    
    # What
    permission_type = Column(String(50), nullable=False)  # view_patients, export_data, request_dataset
    resource_type = Column(String(50), nullable=True)  # all, cognitive, motor, etc.
    
    # Granted by
    granted_by = Column(String(36), nullable=False)  # Admin ID
    granted_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Expiry
    expires_at = Column(DateTime(timezone=True), nullable=True)
    
    # Status
    is_active = Column(Boolean, default=True)
    revoked_by = Column(String(36), nullable=True)
    revoked_at = Column(DateTime(timezone=True), nullable=True)
    revoke_reason = Column(Text, nullable=True)

    def __repr__(self):
        return f"<DataPermission {self.permission_type} for {self.grantee_type}:{self.grantee_id}>"