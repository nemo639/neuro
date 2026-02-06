"""Test to find the actual error."""
import asyncio
import sys
import traceback

# Add path
sys.path.insert(0, 'd:\\neuroverse\\neuroverse-backend')

from sqlalchemy import select
from app.db.database import AsyncSessionLocal
from app.models.doctor_model import Doctor, DoctorStatus
from app.core.security import verify_password, create_access_token, create_refresh_token
from app.schemas.doctor_schemas import DoctorLoginResponse, DoctorProfile

async def test_full_flow():
    print("=" * 60)
    print("FULL HTTP-LIKE LOGIN FLOW TEST")
    print("=" * 60)
    
    email = "dr.smith@neuroverse.com"
    password = "Doctor123"
    
    try:
        async with AsyncSessionLocal() as db:
            print(f"\n1. Finding doctor with email: {email}")
            result = await db.execute(
                select(Doctor).where(Doctor.email == email.lower())
            )
            doctor = result.scalar_one_or_none()
            
            if not doctor:
                print("   ERROR: Doctor not found!")
                return
            print(f"   Found doctor: {doctor.email}")
            
            print(f"\n2. Verifying password...")
            if not verify_password(password, doctor.password_hash):
                print("   ERROR: Password invalid!")
                return
            print("   Password verified!")
            
            print(f"\n3. Checking status: {doctor.status}")
            
            print(f"\n4. Generating tokens...")
            access_token = create_access_token(
                data={"sub": doctor.id, "type": "doctor", "email": doctor.email}
            )
            refresh_token = create_refresh_token(
                data={"sub": doctor.id, "type": "doctor"}
            )
            print(f"   Access token: {access_token[:50]}...")
            
            print(f"\n5. Creating DoctorProfile from ORM model...")
            try:
                # This is where the error might be - the model_validate call
                profile = DoctorProfile.model_validate(doctor)
                print(f"   Profile created successfully!")
                print(f"   Profile dict: {profile.model_dump()}")
            except Exception as e:
                print(f"   ERROR creating profile: {e}")
                traceback.print_exc()
                return
            
            print(f"\n6. Creating DoctorLoginResponse...")
            try:
                response = DoctorLoginResponse(
                    access_token=access_token,
                    refresh_token=refresh_token,
                    doctor=profile
                )
                print(f"   Response created!")
                print(f"   Response dict keys: {list(response.model_dump().keys())}")
            except Exception as e:
                print(f"   ERROR creating response: {e}")
                traceback.print_exc()
                return
            
            print("\n" + "=" * 60)
            print("ALL STEPS PASSED SUCCESSFULLY!")
            print("=" * 60)
            
    except Exception as e:
        print(f"\nUNEXPECTED ERROR: {e}")
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test_full_flow())
