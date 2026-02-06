"""Debug login endpoint to find the exact error."""
import asyncio
from datetime import datetime
from app.db.database import AsyncSessionLocal
from app.models.doctor_model import Doctor
from sqlalchemy import select
from app.core.security import verify_password, create_access_token, create_refresh_token
from app.schemas.doctor_schemas import DoctorLoginResponse, DoctorProfile

async def debug_login():
    email = "dr.smith@neuroverse.com"
    password = "Doctor123"
    
    async with AsyncSessionLocal() as db:
        try:
            # Find doctor
            print("1. Finding doctor...")
            result = await db.execute(
                select(Doctor).where(Doctor.email == email.lower())
            )
            doctor = result.scalar_one_or_none()
            
            if not doctor:
                print("ERROR: Doctor not found!")
                return
                
            print(f"   Found: {doctor.email}")
            
            # Verify password
            print("2. Verifying password...")
            if not verify_password(password, doctor.password_hash):
                print("ERROR: Password mismatch!")
                return
            print("   Password OK!")
            
            # Update last login
            print("3. Updating last login...")
            doctor.last_login_at = datetime.utcnow()
            await db.commit()
            print("   Updated!")
            
            # Generate tokens
            print("4. Generating tokens...")
            access_token = create_access_token(
                data={"sub": doctor.id, "type": "doctor", "email": doctor.email}
            )
            refresh_token = create_refresh_token(
                data={"sub": doctor.id, "type": "doctor"}
            )
            print(f"   Access token: {access_token[:50]}...")
            print(f"   Refresh token: {refresh_token[:50]}...")
            
            # Try to create DoctorProfile
            print("5. Creating DoctorProfile from doctor...")
            try:
                profile = DoctorProfile.model_validate(doctor)
                print(f"   Profile created: {profile.email}")
            except Exception as e:
                print(f"   ERROR creating profile: {e}")
                # Try to debug which field is failing
                print("\n   Debugging fields:")
                print(f"   - id: {doctor.id} (type: {type(doctor.id)})")
                print(f"   - email: {doctor.email}")
                print(f"   - first_name: {doctor.first_name}")
                print(f"   - last_name: {doctor.last_name}")
                print(f"   - specialization: {doctor.specialization} (type: {type(doctor.specialization)})")
                print(f"   - status: {doctor.status} (type: {type(doctor.status)})")
                print(f"   - is_verified: {doctor.is_verified}")
                print(f"   - can_view_patients: {doctor.can_view_patients}")
                print(f"   - can_add_notes: {doctor.can_add_notes}")
                print(f"   - can_export_reports: {doctor.can_export_reports}")
                print(f"   - can_request_dataset: {doctor.can_request_dataset}")
                print(f"   - total_patients_viewed: {doctor.total_patients_viewed}")
                print(f"   - total_notes_created: {doctor.total_notes_created}")
                print(f"   - total_reports_exported: {doctor.total_reports_exported}")
                print(f"   - last_login_at: {doctor.last_login_at}")
                print(f"   - created_at: {doctor.created_at}")
                return
            
            # Try to create response
            print("6. Creating DoctorLoginResponse...")
            try:
                response = DoctorLoginResponse(
                    access_token=access_token,
                    refresh_token=refresh_token,
                    doctor=profile
                )
                print("   SUCCESS! Response created!")
            except Exception as e:
                print(f"   ERROR: {e}")
                return
            
            print("\n✅ ALL STEPS PASSED!")
            
        except Exception as e:
            print(f"\n❌ UNEXPECTED ERROR: {e}")
            import traceback
            traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(debug_login())
