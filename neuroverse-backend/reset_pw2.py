import asyncio
from app.db.database import AsyncSessionLocal
from sqlalchemy import text
from app.core.security import get_password_hash

async def reset():
    async with AsyncSessionLocal() as db:
        # First find the column names
        r = await db.execute(text("SELECT column_name FROM information_schema.columns WHERE table_name = 'users' AND column_name LIKE '%pass%'"))
        cols = r.fetchall()
        print("Password columns:", [c[0] for c in cols])
        
        # Get all columns
        r2 = await db.execute(text("SELECT column_name FROM information_schema.columns WHERE table_name = 'users'"))
        all_cols = r2.fetchall()
        print("All columns:", [c[0] for c in all_cols])

asyncio.run(reset())
