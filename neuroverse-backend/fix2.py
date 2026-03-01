import asyncio
from app.db.database import AsyncSessionLocal
from sqlalchemy import text

async def fix():
    async with AsyncSessionLocal() as db:
        # Find ALL sessions for user 6 - check their status
        r = await db.execute(text(
            "SELECT id, category, status, created_at FROM test_sessions "
            "WHERE user_id = 6 ORDER BY created_at DESC LIMIT 10"
        ))
        rows = r.fetchall()
        print(f"All sessions for user 6 ({len(rows)}):")
        for row in rows:
            print(f"  id={row[0]}, category={row[1]}, status='{row[2]}', created={row[3]}")
        
        # Also check created/in_progress specifically
        r2 = await db.execute(text(
            "SELECT id, category, status FROM test_sessions "
            "WHERE user_id = 6 AND status IN ('created', 'in_progress')"
        ))
        blocking = r2.fetchall()
        print(f"\nBlocking sessions (created/in_progress): {len(blocking)}")
        for row in blocking:
            print(f"  id={row[0]}, category={row[1]}, status='{row[2]}'")
        
        if blocking:
            await db.execute(text(
                "UPDATE test_sessions SET status = 'cancelled' "
                "WHERE user_id = 6 AND status IN ('created', 'in_progress')"
            ))
            await db.commit()
            print("Cancelled all blocking sessions.")

asyncio.run(fix())
