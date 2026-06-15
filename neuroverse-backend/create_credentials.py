"""
Run this script to create admin and doctor credentials in the database.
Usage: python create_credentials.py
"""
import asyncio
import uuid
import bcrypt
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy import text

DATABASE_URL = "postgresql+asyncpg://postgres.juyfsdmahoaefowdtddm:0300mubeen%24N@aws-1-ap-south-1.pooler.supabase.com:5432/postgres"

def hash_password(password: str) -> str:
    pw = password.encode("utf-8")[:72]
    return bcrypt.hashpw(pw, bcrypt.gensalt()).decode("utf-8")

async def create_credentials():
    engine = create_async_engine(DATABASE_URL, echo=False)
    async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)

    async with async_session() as session:
        # --- ADMIN ---
        admin_id = str(uuid.uuid4())
        admin_email = "admin@neuroverse.com"
        admin_password = "Admin@1234"
        admin_hash = hash_password(admin_password)

        await session.execute(text("""
            INSERT INTO admins (id, email, password_hash, first_name, last_name, role, is_active,
                can_manage_users, can_manage_doctors, can_manage_permissions, can_resolve_tickets,
                can_view_analytics, can_export_data, can_manage_admins)
            VALUES (:id, :email, :password_hash, 'Super', 'Admin', 'super_admin', true,
                true, true, true, true, true, true, true)
            ON CONFLICT (email) DO UPDATE SET password_hash = :password_hash
        """), {
            "id": admin_id,
            "email": admin_email,
            "password_hash": admin_hash
        })

        # --- DOCTOR ---
        doctor_email = "doctor@neuroverse.com"
        doctor_password = "Doctor@1234"
        doctor_hash = hash_password(doctor_password)

        await session.execute(text("""
            INSERT INTO doctors (email, password_hash, first_name, last_name, specialization,
                is_verified, status)
            VALUES (:email, :password_hash, 'Sahar', 'Ajmal', 'neurologist', true, 'active')
            ON CONFLICT (email) DO UPDATE SET password_hash = :password_hash
        """), {
            "email": doctor_email,
            "password_hash": doctor_hash
        })

        await session.commit()
        print("Admin created:  admin@neuroverse.com  /  Admin@1234")
        print("Doctor created: doctor@neuroverse.com  /  Doctor@1234")

    await engine.dispose()

if __name__ == "__main__":
    asyncio.run(create_credentials())
