import asyncio
from sqlalchemy import text
from app.db.database import AsyncSessionLocal
from app.core.security import verify_password

async def check_password():
    async with AsyncSessionLocal() as session:
        result = await session.execute(
            text("SELECT email, password_hash FROM doctors WHERE email = 'dr.smith@neuroverse.com'")
        )
        row = result.fetchone()
        if row:
            email, password_hash = row
            print(f'Email: {email}')
            print(f'Password Hash (first 50 chars): {password_hash[:50]}...')
            is_valid = verify_password('Doctor123', password_hash)
            print(f'Password "Doctor123" valid: {is_valid}')
        else:
            print('Doctor not found')

asyncio.run(check_password())
