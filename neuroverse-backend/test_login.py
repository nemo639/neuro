import asyncio
from sqlalchemy import select
from app.db.database import AsyncSessionLocal
from app.models.doctor_model import Doctor, DoctorStatus
from app.core.security import verify_password, create_access_token

async def test_login():
    email = 'dr.smith@neuroverse.com'
    password = 'Doctor123'
    
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(Doctor).where(Doctor.email == email.lower()))
        doctor = result.scalar_one_or_none()
        
        if not doctor:
            print('Doctor not found')
            return
            
        print(f'Doctor found: {doctor.email}')
        print(f'Status: {doctor.status}')
        
        if not verify_password(password, doctor.password_hash):
            print('Invalid password')
            return
            
        print('Password valid!')
        
        # Check status
        print(f'Doctor status type: {type(doctor.status)}')
        print(f'DoctorStatus.ACTIVE: {DoctorStatus.ACTIVE}')
        
        # Try creating token
        try:
            token = create_access_token(data={'sub': str(doctor.id), 'type': 'doctor'})
            print(f'Token created successfully: {token[:50]}...')
        except Exception as e:
            print(f'Token error: {e}')
            import traceback
            traceback.print_exc()

asyncio.run(test_login())
