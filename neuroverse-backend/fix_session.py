import asyncio
from app.db.database import AsyncSessionLocal
from sqlalchemy import text

async def fix():
    async with AsyncSessionLocal() as db:
        # Find incomplete sessions for user 6
        r = await db.execute(text(
            "SELECT id, category, status, created_at FROM test_sessions "
            "WHERE user_id = 6 AND status NOT IN ('completed', 'cancelled') "
            "ORDER BY created_at DESC"
        ))
        rows = r.fetchall()
        print(f"Found {len(rows)} incomplete sessions:")
        for row in rows:
            print(f"  id={row[0]}, category={row[1]}, status={row[2]}, created={row[3]}")
        
        if rows:
            # Cancel all incomplete sessions
            await db.execute(text(
                "UPDATE test_sessions SET status = 'cancelled' "
                "WHERE user_id = 6 AND status NOT IN ('completed', 'cancelled')"
            ))
            await db.commit()
            print("All incomplete sessions cancelled.")

asyncio.run(fix())
