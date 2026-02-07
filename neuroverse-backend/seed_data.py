"""
Seed script: Populates NeuroVerse database with realistic demo data.
Run: python seed_data.py
"""

import psycopg2
import uuid
import random
from datetime import datetime, timedelta, timezone
from passlib.context import CryptContext

# ── Connection (convert asyncpg URL → psycopg2 format) ──────────────────────
DB_URL = "postgresql://postgres.juyfsdmahoaefowdtddm:0300mubeen$N@aws-1-ap-south-1.pooler.supabase.com:5432/postgres"

pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")
now = datetime.now(timezone.utc)

# ── Helper data ──────────────────────────────────────────────────────────────
FIRST_NAMES = [
    "Ahmed", "Fatima", "Sara", "Omar", "Maryam", "Hassan", "Ayesha", "Bilal",
    "Zainab", "Usman", "Anum", "Tariq", "Hira", "Ali", "Rabia", "Imran",
    "Nadia", "Kamran", "Sana", "Faisal", "Amina", "Waseem", "Mehak", "Junaid",
    "Saima", "Irfan", "Nimra", "Shahid", "Kiran", "Naveed",
]

LAST_NAMES = [
    "Malik", "Khan", "Siddiqui", "Noor", "Raza", "Tariq", "Ahmed", "Ali",
    "Khalid", "Shah", "Iqbal", "Butt", "Chaudhry", "Qureshi", "Hashmi",
    "Rizvi", "Mirza", "Baig", "Ansari", "Hussain",
]

SPECIALIZATIONS = ["neurologist", "psychiatrist", "geriatrician", "general_physician", "psychologist", "researcher"]
HOSPITALS = [
    "Agha Khan University Hospital", "Shaukat Khanum Cancer Hospital",
    "Shifa International Hospital", "Combined Military Hospital",
    "Pakistan Institute of Medical Sciences", "Jinnah Hospital",
    "Lady Reading Hospital", "Mayo Hospital Lahore",
    "Liaquat National Hospital", "Ziauddin Hospital",
]

AD_STAGES = ["CN", "MCI", "Mild AD", "Moderate AD", "Severe AD"]
PD_STAGES = ["Normal", "Early PD", "Moderate PD", "Advanced PD"]

TICKET_SUBJECTS = [
    "Cannot login to my account",
    "Test results not showing correctly",
    "App crashes during cognitive test",
    "How to share report with my doctor?",
    "Password reset not working",
    "Request data export for research",
    "Audio recording failed during speech test",
    "Score seems incorrect after gait test",
    "Profile picture upload fails",
    "Need help interpreting risk scores",
    "Billing inquiry for premium plan",
    "Feature request: dark mode",
    "Motor test calibration issue",
    "Cannot access historical reports",
    "Push notifications not working",
]

ACTIVITY_ACTIONS = [
    ("user_verified", "update", "user"),
    ("doctor_approved", "update", "doctor"),
    ("ticket_resolved", "update", "ticket"),
    ("user_suspended", "update", "user"),
    ("report_exported", "create", "report"),
    ("permission_granted", "create", "permission"),
    ("doctor_rejected", "update", "doctor"),
    ("ticket_assigned", "update", "ticket"),
    ("settings_updated", "update", "settings"),
    ("data_exported", "create", "export"),
]


def run():
    conn = psycopg2.connect(DB_URL)
    conn.autocommit = False
    cur = conn.cursor()

    try:
        # ── 0. Create missing tables ────────────────────────────────────
        cur.execute("""
            CREATE TABLE IF NOT EXISTS ticket_messages (
                id VARCHAR(36) PRIMARY KEY,
                ticket_id VARCHAR(36) NOT NULL,
                sender_type VARCHAR(20) NOT NULL,
                sender_id VARCHAR(36) NOT NULL,
                sender_name VARCHAR(200),
                message TEXT NOT NULL,
                created_at TIMESTAMPTZ DEFAULT now()
            );
            CREATE INDEX IF NOT EXISTS ix_ticket_messages_ticket_id ON ticket_messages(ticket_id);

            CREATE TABLE IF NOT EXISTS admin_activity_logs (
                id VARCHAR(36) PRIMARY KEY,
                admin_id VARCHAR(36) NOT NULL,
                action VARCHAR(100) NOT NULL,
                action_type VARCHAR(50) NOT NULL,
                target_type VARCHAR(50),
                target_id VARCHAR(36),
                details TEXT,
                ip_address VARCHAR(50),
                user_agent VARCHAR(500),
                created_at TIMESTAMPTZ DEFAULT now()
            );
            CREATE INDEX IF NOT EXISTS ix_admin_activity_logs_admin_id ON admin_activity_logs(admin_id);

            CREATE TABLE IF NOT EXISTS admin_tasks (
                id VARCHAR(36) PRIMARY KEY,
                admin_id VARCHAR(36) NOT NULL,
                title VARCHAR(255) NOT NULL,
                description TEXT,
                category VARCHAR(50) DEFAULT 'general',
                due_date TIMESTAMPTZ,
                is_completed BOOLEAN DEFAULT false,
                completed_at TIMESTAMPTZ,
                created_at TIMESTAMPTZ DEFAULT now(),
                updated_at TIMESTAMPTZ
            );
            CREATE INDEX IF NOT EXISTS ix_admin_tasks_admin_id ON admin_tasks(admin_id);

            CREATE TABLE IF NOT EXISTS data_permissions (
                id VARCHAR(36) PRIMARY KEY,
                grantee_type VARCHAR(20) NOT NULL,
                grantee_id VARCHAR(36) NOT NULL,
                permission_type VARCHAR(50) NOT NULL,
                resource_type VARCHAR(50),
                granted_by VARCHAR(36) NOT NULL,
                granted_at TIMESTAMPTZ DEFAULT now(),
                expires_at TIMESTAMPTZ,
                is_active BOOLEAN DEFAULT true,
                revoked_by VARCHAR(36),
                revoked_at TIMESTAMPTZ,
                revoke_reason TEXT
            );
            CREATE INDEX IF NOT EXISTS ix_data_permissions_grantee_id ON data_permissions(grantee_id);
        """)
        conn.commit()
        print("✓ Ensured all tables exist")

        # ── 1. Check / get admin ─────────────────────────────────────────
        cur.execute("SELECT id FROM admins WHERE email = 'test@admin.com' LIMIT 1")
        row = cur.fetchone()
        if not row:
            cur.execute("SELECT id FROM admins LIMIT 1")
            row = cur.fetchone()
        if row:
            admin_id = row[0]
            print(f"✓ Existing admin found: {admin_id}")
        else:
            admin_id = str(uuid.uuid4())
            cur.execute("""
                INSERT INTO admins (id, email, password_hash, first_name, last_name, role, is_active, created_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
            """, (admin_id, "test@admin.com", pwd_ctx.hash("admin123"), "Admin", "User", "super_admin", True, now))
            print(f"✓ Admin created: {admin_id}")

        # ── 2. Seed Users (30 patients) ──────────────────────────────────
        cur.execute("SELECT COUNT(*) FROM users")
        user_count = cur.fetchone()[0]

        user_ids = []
        if user_count < 25:
            print("  Seeding 30 users...")
            for i in range(30):
                fn = random.choice(FIRST_NAMES)
                ln = random.choice(LAST_NAMES)
                email = f"{fn.lower()}.{ln.lower()}{random.randint(1,99)}@email.com"
                created = now - timedelta(days=random.randint(1, 180))
                last_active = created + timedelta(days=random.randint(0, 60), hours=random.randint(0, 23))
                if last_active > now:
                    last_active = now - timedelta(minutes=random.randint(5, 120))
                is_verified = random.random() < 0.75
                ad_risk = round(random.uniform(0, 95), 1) if random.random() < 0.6 else 0.0
                pd_risk = round(random.uniform(0, 85), 1) if random.random() < 0.5 else 0.0
                cog = round(random.uniform(30, 100), 1)
                speech = round(random.uniform(30, 100), 1)
                motor = round(random.uniform(30, 100), 1)
                gait = round(random.uniform(40, 100), 1)
                facial = round(random.uniform(40, 100), 1)
                ad_stage = random.choice(AD_STAGES) if ad_risk > 20 else "CN"
                pd_stage = random.choice(PD_STAGES) if pd_risk > 15 else "Normal"
                gender = random.choice(["male", "female"])
                dob_year = random.randint(1945, 1990)
                dob = f"{dob_year}-{random.randint(1,12):02d}-{random.randint(1,28):02d}"
                total_tests = random.randint(0, 25)

                cur.execute("""
                    INSERT INTO users (email, password_hash, first_name, last_name, phone, date_of_birth,
                        gender, is_verified, ad_risk_score, pd_risk_score, cognitive_score, speech_score,
                        motor_score, gait_score, facial_score, ad_stage, pd_stage, created_at, updated_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING id
                """, (email, pwd_ctx.hash("user123"), fn, ln,
                      f"+92-3{random.randint(10,99)}-{random.randint(1000000,9999999)}", dob,
                      gender, is_verified, ad_risk, pd_risk, cog, speech, motor, gait, facial,
                      ad_stage, pd_stage, created, last_active))
                uid = cur.fetchone()[0]
                user_ids.append(uid)
            print(f"  ✓ {len(user_ids)} users seeded")
        else:
            cur.execute("SELECT id FROM users ORDER BY created_at DESC LIMIT 30")
            user_ids = [r[0] for r in cur.fetchall()]
            print(f"  ✓ {user_count} users already exist, using existing IDs")

        # ── 3. Seed Doctors (12 doctors) ─────────────────────────────────
        cur.execute("SELECT COUNT(*) FROM doctors")
        doc_count = cur.fetchone()[0]

        doctor_ids = []
        if doc_count < 10:
            print("  Seeding 12 doctors...")
            doc_names = [
                ("Dr. Fatima", "Zahra"), ("Dr. Omar", "Siddiqui"), ("Dr. Ayesha", "Tariq"),
                ("Dr. Zainab", "Ali"), ("Dr. Ahmad", "Khan"), ("Dr. Nadia", "Qureshi"),
                ("Dr. Kamran", "Mirza"), ("Dr. Hira", "Hashmi"), ("Dr. Faisal", "Butt"),
                ("Dr. Rabia", "Shah"), ("Dr. Imran", "Rizvi"), ("Dr. Sana", "Iqbal"),
            ]
            statuses = ["active", "active", "active", "pending_verification", "active",
                        "active", "active", "inactive", "active", "pending_verification", "active", "active"]
            for i, (fn, ln) in enumerate(doc_names):
                fn_clean = fn.replace("Dr. ", "")
                email = f"{fn_clean.lower()}.{ln.lower()}@hospital.com"
                spec = random.choice(SPECIALIZATIONS)
                hosp = random.choice(HOSPITALS)
                created = now - timedelta(days=random.randint(10, 200))
                is_verified = statuses[i] == "active"
                yoe = random.randint(2, 25)
                patients_viewed = random.randint(5, 150)

                cur.execute("""
                    INSERT INTO doctors (email, password_hash, first_name, last_name, phone,
                        specialization, license_number, hospital_affiliation, department,
                        years_of_experience, status, is_verified, total_patients_viewed, created_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                    RETURNING id
                """, (email, pwd_ctx.hash("doctor123"), fn_clean, ln,
                      f"+92-3{random.randint(10,99)}-{random.randint(1000000,9999999)}",
                      spec, f"PMC-{random.randint(10000,99999)}", hosp, spec.replace("_", " ").title(),
                      yoe, statuses[i], is_verified, patients_viewed, created))
                did = cur.fetchone()[0]
                doctor_ids.append(did)
            print(f"  ✓ {len(doctor_ids)} doctors seeded")
        else:
            cur.execute("SELECT id FROM doctors ORDER BY created_at DESC LIMIT 12")
            doctor_ids = [r[0] for r in cur.fetchall()]
            print(f"  ✓ {doc_count} doctors already exist")

        # ── 4. Seed Support Tickets (15 tickets) ────────────────────────
        cur.execute("SELECT COUNT(*) FROM support_tickets")
        tkt_count = cur.fetchone()[0]

        if tkt_count < 10:
            print("  Seeding 15 support tickets...")
            priorities = ["low", "medium", "medium", "high", "urgent"]
            statuses_t = ["open", "open", "in_progress", "resolved", "closed"]
            tkt_offset = tkt_count + 100  # avoid collisions
            for i in range(15):
                tid = str(uuid.uuid4())
                uid = random.choice(user_ids) if user_ids else None
                fn = random.choice(FIRST_NAMES)
                ln = random.choice(LAST_NAMES)
                email = f"{fn.lower()}.{ln.lower()}{random.randint(1,99)}@email.com"
                subject = TICKET_SUBJECTS[i % len(TICKET_SUBJECTS)]
                priority = random.choice(priorities)
                status = random.choice(statuses_t)
                created = now - timedelta(days=random.randint(0, 30), hours=random.randint(0, 23))
                created_by = f"{fn} {ln}"

                cur.execute("""
                    INSERT INTO support_tickets (id, ticket_number, user_id, user_email, user_name,
                        subject, description, category, priority, status, assigned_to, created_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """, (tid, f"TKT-{tkt_offset + i + 1:03d}", str(uid) if uid else None, email, created_by,
                      subject, f"Detailed description for: {subject}",
                      random.choice(["general", "technical", "billing", "feedback"]),
                      priority, status,
                      admin_id if status in ("in_progress", "resolved") else None,
                      created))

                # Add a message for each ticket
                cur.execute("""
                    INSERT INTO ticket_messages (id, ticket_id, sender_type, sender_id, sender_name, message, created_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s)
                """, (str(uuid.uuid4()), tid, "user", str(uid) if uid else "guest", created_by,
                      f"Hi, I need help with: {subject}", created))

                # Admin reply for some
                if status in ("in_progress", "resolved", "closed"):
                    cur.execute("""
                        INSERT INTO ticket_messages (id, ticket_id, sender_type, sender_id, sender_name, message, created_at)
                        VALUES (%s, %s, %s, %s, %s, %s, %s)
                    """, (str(uuid.uuid4()), tid, "admin", admin_id, "Admin Support",
                          f"Thank you for reaching out. We're looking into this issue.", created + timedelta(hours=random.randint(1, 12))))

            print("  ✓ 15 tickets seeded")
        else:
            print(f"  ✓ {tkt_count} tickets already exist")

        # ── 5. Seed Admin Activity Logs (25 entries) ─────────────────────
        cur.execute("SELECT COUNT(*) FROM admin_activity_logs")
        log_count = cur.fetchone()[0]

        if log_count < 15:
            print("  Seeding 25 activity logs...")
            for i in range(25):
                action, atype, target = random.choice(ACTIVITY_ACTIONS)
                target_id = str(random.choice(user_ids)) if user_ids and target == "user" else str(uuid.uuid4())
                created = now - timedelta(hours=random.randint(0, 168))  # past week
                details_map = {
                    "user_verified": "Verified user account after email confirmation",
                    "doctor_approved": "Approved doctor verification request",
                    "ticket_resolved": "Resolved support ticket after investigation",
                    "user_suspended": "Suspended user account due to policy violation",
                    "report_exported": "Exported monthly analytics report",
                    "permission_granted": "Granted data access permission to researcher",
                    "doctor_rejected": "Rejected doctor verification - incomplete documents",
                    "ticket_assigned": "Assigned ticket to support team",
                    "settings_updated": "Updated platform security settings",
                    "data_exported": "Exported anonymized dataset for research",
                }

                cur.execute("""
                    INSERT INTO admin_activity_logs (id, admin_id, action, action_type, target_type, target_id, details, created_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """, (str(uuid.uuid4()), admin_id, action, atype, target, target_id,
                      details_map.get(action, "Admin action performed"), created))
            print("  ✓ 25 activity logs seeded")
        else:
            print(f"  ✓ {log_count} activity logs already exist")

        # ── 6. Seed Admin Tasks (8 tasks) ────────────────────────────────
        cur.execute("SELECT COUNT(*) FROM admin_tasks")
        task_count = cur.fetchone()[0]

        if task_count < 5:
            print("  Seeding 8 tasks...")
            tasks = [
                ("Review pending doctor verifications", "Check documents and approve/reject pending doctors", "evaluation", 1),
                ("Resolve critical support tickets", "Address all high/urgent priority tickets", "engagement", 0),
                ("Monthly platform security audit", "Review access logs and security compliance", "general", 3),
                ("Generate analytics report", "Compile monthly user growth and test data", "selection", 5),
                ("Update patient consent forms", "Review and update data consent templates", "relationship", 7),
                ("Doctor onboarding follow-up", "Check in with newly verified doctors", "engagement", 2),
                ("Review data export requests", "Process pending dataset export requests", "evaluation", 4),
                ("Plan user feedback survey", "Design and schedule quarterly user survey", "relationship", 14),
            ]
            for title, desc, cat, due_days in tasks:
                cur.execute("""
                    INSERT INTO admin_tasks (id, admin_id, title, description, category, due_date, is_completed, created_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                """, (str(uuid.uuid4()), admin_id, title, desc, cat,
                      now + timedelta(days=due_days), False,
                      now - timedelta(days=random.randint(0, 5))))
            print("  ✓ 8 tasks seeded")
        else:
            print(f"  ✓ {task_count} tasks already exist")

        conn.commit()
        print("\n🎉 Database seeded successfully!")

    except Exception as e:
        conn.rollback()
        print(f"\n❌ Error: {e}")
        raise
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    run()
