import asyncio
from app.db.database import AsyncSessionLocal
from sqlalchemy import text

async def verify():
    async with AsyncSessionLocal() as db:
        await db.execute(text("UPDATE users SET is_verified = true WHERE email = 'naeemubeen639@gmail.com'"))
        await db.commit()
        print("Email verified for naeemubeen639@gmail.com")

asyncio.run(verify())
