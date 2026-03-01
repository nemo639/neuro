import asyncio
from app.db.database import AsyncSessionLocal
from sqlalchemy import text
from app.core.security import get_password_hash

async def reset():
    async with AsyncSessionLocal() as db:
        r = await db.execute(text("SELECT id, email, first_name, last_name FROM users WHERE email = 'naeemubeen639@gmail.com'"))
        user = r.fetchone()
        if not user:
            print("User not found")
            return
        print(f"Found: id={user[0]}, {user[2]} {user[3]}, {user[1]}")
        new_hash = get_password_hash("Naeem@123")
        await db.execute(text("UPDATE users SET password_hash = :h WHERE email = 'naeemubeen639@gmail.com'"), {"h": new_hash})
        await db.commit()
        print("Password reset to: Naeem@123")

asyncio.run(reset())
