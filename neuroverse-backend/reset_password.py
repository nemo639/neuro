import asyncio
from sqlalchemy import text
from app.db.database import AsyncSessionLocal
from app.core.security import get_password_hash, verify_password

async def reset_doctor_password():
    """Reset doctor password to Doctor123"""
    new_password = "Doctor123"
    new_hash = get_password_hash(new_password)
    
    async with AsyncSessionLocal() as session:
        # Update all doctors' passwords
        await session.execute(
            text(f"UPDATE doctors SET password_hash = '{new_hash}' WHERE email IN ('dr.smith@neuroverse.com', 'dr.ahmed@neuroverse.com', 'dr.fatima@neuroverse.com', 'doctor@neuroverse.com')")
        )
        await session.commit()
        
        print("✅ Passwords reset successfully!")
        print()
        print("🔐 Login Credentials:")
        print("-" * 50)
        print("Email: dr.smith@neuroverse.com")
        print("Password: Doctor123")
        print()
        print("Email: dr.ahmed@neuroverse.com")
        print("Password: Doctor123")
        print()
        print("Email: dr.fatima@neuroverse.com")
        print("Password: Doctor123")
        print()
        print("Email: doctor@neuroverse.com")
        print("Password: Doctor123")
        print("-" * 50)
        
        # Verify the password works
        result = await session.execute(
            text("SELECT password_hash FROM doctors WHERE email = 'dr.smith@neuroverse.com'")
        )
        row = result.fetchone()
        if row:
            is_valid = verify_password("Doctor123", row[0])
            print(f"\n✓ Verification test passed: {is_valid}")

asyncio.run(reset_doctor_password())
