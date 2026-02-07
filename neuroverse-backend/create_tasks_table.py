import asyncio
from app.db.database import engine
from sqlalchemy import text

async def create_table():
    async with engine.begin() as conn:
        await conn.execute(text("""
            CREATE TABLE IF NOT EXISTS admin_tasks (
                id VARCHAR(36) PRIMARY KEY,
                admin_id VARCHAR(36) NOT NULL,
                title VARCHAR(255) NOT NULL,
                description TEXT,
                category VARCHAR(50) DEFAULT 'general',
                due_date TIMESTAMPTZ,
                is_completed BOOLEAN DEFAULT FALSE,
                completed_at TIMESTAMPTZ,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                updated_at TIMESTAMPTZ
            )
        """))
        await conn.execute(text(
            "CREATE INDEX IF NOT EXISTS idx_admin_tasks_admin_id ON admin_tasks(admin_id)"
        ))
    print("admin_tasks table created successfully!")

asyncio.run(create_table())
