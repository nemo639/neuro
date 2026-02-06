import asyncio
from sqlalchemy import select
from datetime import datetime
from app.db.database import AsyncSessionLocal
from app.models.doctor_model import Doctor, DoctorStatus
from app.core.security import verify_password, create_access_token, create_refresh_token
from app.schemas.doctor_schemas import DoctorProfile, DoctorLoginResponse

async def test_full_login():
    email = 'dr.smith@neuroverse.com'
    password = 'Doctor123'
    
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(Doctor).where(Doctor.email == email.lower()))
        doctor = result.scalar_one_or_none()
        
        if not doctor:
            print('Doctor not found')
            return
            
        print(f'Doctor found: {doctor.email}')
        
        # Verify password
        if not verify_password(password, doctor.password_hash):
            print('Invalid password')
            return
            
        print('Password valid!')
        
        # Check status comparisons
        print(f'doctor.status: {doctor.status} (type: {type(doctor.status)})')
        print(f'DoctorStatus.SUSPENDED: {DoctorStatus.SUSPENDED} (type: {type(DoctorStatus.SUSPENDED)})')
        print(f'Comparison (==): {doctor.status == DoctorStatus.SUSPENDED}')
        print(f'String comparison: {doctor.status == "suspended"}')
        
        # Try creating profile
        try:
            profile = DoctorProfile.model_validate(doctor)
            print(f'Profile created: {profile.email}')
        except Exception as e:
            print(f'Profile error: {e}')
            import traceback
            traceback.print_exc()
            return
        
        # Try creating tokens
        try:
            access_token = create_access_token(
                data={"sub": doctor.id, "type": "doctor", "email": doctor.email}
            )
            refresh_token = create_refresh_token(
                data={"sub": doctor.id, "type": "doctor"}
            )
            print(f'Access token: {access_token[:50]}...')
            print(f'Refresh token: {refresh_token[:50]}...')
        except Exception as e:
            print(f'Token error: {e}')
            import traceback
            traceback.print_exc()
            return
        
        # Try creating response
        try:
            response = DoctorLoginResponse(
                access_token=access_token,
                refresh_token=refresh_token,
                doctor=profile
            )
            print(f'Login response created successfully!')
            print(f'Response: {response.model_dump_json()[:200]}...')
        except Exception as e:
            print(f'Response error: {e}')
            import traceback
            traceback.print_exc()

asyncio.run(test_full_login())
