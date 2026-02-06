"""
Seed initial doctors into the database
Run this script from project root: python seed_doctors.py
"""

import asyncio
import sys
import os

# Add the neuroverse-backend directory to the path
backend_path = os.path.join(os.path.dirname(__file__), 'neuroverse-backend')
sys.path.insert(0, backend_path)

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.db.database import async_session_maker
from app.models.doctor import Doctor
from app.core.security import get_password_hash


async def seed_doctors():
    """Create initial doctor accounts"""
    
    doctors_data = [
        {
            "email": "dr.smith@neuroverse.com",
            "password": "Doctor123",
            "first_name": "John",
            "last_name": "Smith",
            "phone": "+92-300-1234567",
            "specialization": "neurologist",
            "license_number": "MED-12345",
            "hospital_affiliation": "Lahore General Hospital",
            "department": "Neurology",
            "years_of_experience": 15,
            "bio": "Board-certified neurologist with 15 years of experience in cognitive disorders and dementia care.",
            "status": "active",
            "is_verified": True,
            "can_view_patients": True,
            "can_add_notes": True,
            "can_export_reports": True,
        },
        {
            "email": "dr.ahmed@neuroverse.com",
            "password": "Doctor123",
            "first_name": "Ahmed",
            "last_name": "Khan",
            "phone": "+92-321-9876543",
            "specialization": "psychiatrist",
            "license_number": "MED-67890",
            "hospital_affiliation": "Shaukat Khanum Memorial Hospital",
            "department": "Psychiatry",
            "years_of_experience": 10,
            "bio": "Psychiatrist specializing in neurodegenerative disorders and mental health assessment.",
            "status": "active",
            "is_verified": True,
            "can_view_patients": True,
            "can_add_notes": True,
            "can_export_reports": True,
        },
        {
            "email": "dr.fatima@neuroverse.com",
            "password": "Doctor123",
            "first_name": "Fatima",
            "last_name": "Ali",
            "phone": "+92-333-5555555",
            "specialization": "geriatrician",
            "license_number": "MED-11223",
            "hospital_affiliation": "Aga Khan University Hospital",
            "department": "Geriatrics",
            "years_of_experience": 8,
            "bio": "Geriatric medicine specialist focusing on elderly care and age-related cognitive decline.",
            "status": "active",
            "is_verified": True,
            "can_view_patients": True,
            "can_add_notes": True,
            "can_export_reports": True,
            "can_request_dataset": True,
        },
    ]
    
    async with async_session_maker() as session:
        try:
            print("=" * 60)
            print("Seeding Doctor Accounts")
            print("=" * 60)
            
            for doctor_data in doctors_data:
                # Check if doctor already exists
                result = await session.execute(
                    select(Doctor).where(Doctor.email == doctor_data["email"])
                )
                existing_doctor = result.scalar_one_or_none()
                
                if existing_doctor:
                    print(f"❌ Doctor {doctor_data['email']} already exists - skipping")
                    continue
                
                # Hash the password
                password = doctor_data.pop("password")
                doctor_data["password_hash"] = get_password_hash(password)
                
                # Create doctor
                doctor = Doctor(**doctor_data)
                session.add(doctor)
                
                print(f"✅ Created doctor: {doctor_data['email']}")
                print(f"   Name: Dr. {doctor_data['first_name']} {doctor_data['last_name']}")
                print(f"   Specialization: {doctor_data['specialization']}")
                print(f"   Password: Doctor123")
                print()
            
            await session.commit()
            
            print("=" * 60)
            print("✅ Doctor seeding completed!")
            print("=" * 60)
            print("\n🔐 Login Credentials:")
            print("-" * 60)
            print("Email: dr.smith@neuroverse.com")
            print("Password: Doctor123")
            print()
            print("Email: dr.ahmed@neuroverse.com")
            print("Password: Doctor123")
            print()
            print("Email: dr.fatima@neuroverse.com")
            print("Password: Doctor123")
            print("-" * 60)
            
        except Exception as e:
            print(f"❌ Error seeding doctors: {e}")
            import traceback
            traceback.print_exc()
            await session.rollback()
            raise


async def check_doctors():
    """Check existing doctors in database"""
    async with async_session_maker() as session:
        result = await session.execute(select(Doctor))
        doctors = result.scalars().all()
        
        print("\n" + "=" * 60)
        print(f"Total Doctors in Database: {len(doctors)}")
        print("=" * 60)
        
        if not doctors:
            print("\n⚠️  No doctors found in database!")
            print("Run option 1 to seed doctors first.")
        else:
            for doctor in doctors:
                print(f"\n✅ ID: {doctor.id}")
                print(f"   Name: Dr. {doctor.first_name} {doctor.last_name}")
                print(f"   Email: {doctor.email}")
                print(f"   Specialization: {doctor.specialization}")
                print(f"   Status: {doctor.status}")
                print(f"   Verified: {doctor.is_verified}")
                print("-" * 60)


if __name__ == "__main__":
    print("\n🧠 NeuroVerse - Doctor Seeding Script")
    print("=" * 60)
    
    choice = input("\n1. Seed doctors\n2. Check existing doctors\n3. Both\n\nChoice (1/2/3): ")
    
    try:
        if choice == "1":
            asyncio.run(seed_doctors())
        elif choice == "2":
            asyncio.run(check_doctors())
        elif choice == "3":
            asyncio.run(seed_doctors())
            asyncio.run(check_doctors())
        else:
            print("❌ Invalid choice")
    except KeyboardInterrupt:
        print("\n\n⚠️  Cancelled by user")
    except Exception as e:
        print(f"\n❌ Error: {e}")