"""
Seed rich dashboard data using BATCH inserts for speed.
All IDs are auto-generated (SERIAL) — no manual ID assignment.
"""
import psycopg2
import psycopg2.extras
import random
from datetime import datetime, timedelta

DB_URL = "postgresql://postgres.juyfsdmahoaefowdtddm:0300mubeen$N@aws-1-ap-south-1.pooler.supabase.com:5432/postgres"

CATEGORIES = ["cognitive", "speech", "motor", "gait", "facial"]
TEST_ITEMS_MAP = {
    "cognitive": [("stroop", "cognitive"), ("nback", "cognitive"), ("trail_making", "cognitive"), ("digit_span", "cognitive")],
    "speech":    [("vowel_sustain", "audio"), ("word_repeat", "audio"), ("sentence_read", "audio"), ("spontaneous_speech", "audio")],
    "motor":     [("spiral_draw", "motor"), ("finger_tap", "motor"), ("hand_grip", "sensor"), ("line_trace", "motor")],
    "gait":      [("walk_straight", "sensor"), ("turn_walk", "sensor"), ("tandem_walk", "sensor"), ("stand_balance", "sensor")],
    "facial":    [("smile_detection", "video"), ("blink_rate", "video"), ("expression_mimic", "video"), ("face_symmetry", "video")],
}
NOTE_TYPES = ["general", "diagnosis", "treatment", "follow_up"]
MOODS = ["very_bad", "bad", "neutral", "good", "very_good"]
SLEEP_Q = ["poor", "fair", "good", "excellent"]


def rand_dt(start, end):
    return start + timedelta(seconds=random.randint(0, max(1, int((end - start).total_seconds()))))


def risk_ad_stage(s):
    if s < 20: return "CN"
    if s < 40: return "MCI"
    if s < 60: return "Mild AD"
    if s < 80: return "Moderate AD"
    return "Severe AD"


def risk_pd_stage(s):
    if s < 25: return "Normal"
    if s < 50: return "Early PD"
    if s < 75: return "Moderate PD"
    return "Advanced PD"


def main():
    conn = psycopg2.connect(DB_URL)
    conn.autocommit = False
    cur = conn.cursor()
    now = datetime.utcnow()

    print("=" * 60)
    print("  NeuroVerse Rich Dashboard Seeder (Batch Mode)")
    print("=" * 60)

    # ── 1. Clean old data ────────────────────────────────────────────────
    print("\n[1/6] Cleaning old test data...")
    for t in ["clinical_notes", "patient_accesses", "test_items",
              "test_results", "test_sessions", "wellness_entries",
              "reports", "feedbacks"]:
        try:
            cur.execute(f"DELETE FROM {t}")
            print(f"  Cleared {t}")
        except Exception as e:
            conn.rollback()
            print(f"  Skip {t}: {e}")
    conn.commit()

    # ── 2. Get existing user IDs & update their risk scores ──────────────
    print("\n[2/6] Updating existing users with risk data...")
    cur.execute("SELECT id FROM users ORDER BY id")
    all_user_ids = [r[0] for r in cur.fetchall()]
    print(f"  Found {len(all_user_ids)} existing users")

    for uid in all_user_ids:
        bucket = random.choices(["low", "mod", "high"], weights=[50, 30, 20])[0]
        if bucket == "low":
            ad, pd = random.uniform(5, 35), random.uniform(5, 30)
        elif bucket == "mod":
            ad, pd = random.uniform(40, 65), random.uniform(38, 60)
        else:
            ad, pd = random.uniform(70, 94), random.uniform(68, 92)

        cur.execute("""
            UPDATE users SET
                ad_risk_score=%s, pd_risk_score=%s,
                ad_stage=%s, pd_stage=%s,
                cognitive_score=%s, speech_score=%s,
                motor_score=%s, gait_score=%s, facial_score=%s
            WHERE id=%s
        """, (
            round(ad, 1), round(pd, 1),
            risk_ad_stage(ad), risk_pd_stage(pd),
            round(random.uniform(25, 92), 1), round(random.uniform(25, 90), 1),
            round(random.uniform(25, 88), 1), round(random.uniform(25, 90), 1),
            round(random.uniform(25, 88), 1), uid
        ))
    conn.commit()
    print(f"  Updated {len(all_user_ids)} users")

    if not all_user_ids:
        print("  ERROR: No users found! Run seed_data.py first.")
        return

    # ── 3. Batch-insert test sessions ────────────────────────────────────
    print("\n[3/6] Seeding test sessions (batch insert)...")

    # Build session rows: spread across 8 months + extra recent week
    session_meta = []  # store (uid, cat, status, started, completed) for later use

    # 8-month spread
    for month_offset in range(8):
        count = 20 + month_offset * 6 + random.randint(-3, 3)
        m_start = now - timedelta(days=30 * (7 - month_offset))
        m_end = now - timedelta(days=30 * (6 - month_offset)) if month_offset < 7 else now

        for _ in range(count):
            uid = random.choice(all_user_ids)
            cat = random.choice(CATEGORIES)
            status = random.choices(
                ["completed", "in_progress", "created", "cancelled"],
                weights=[85, 8, 5, 2]
            )[0]
            started = rand_dt(m_start, m_end)
            completed = (started + timedelta(minutes=random.randint(8, 45))) if status == "completed" else None
            session_meta.append((uid, cat, status, started, completed))

    # Extra sessions spread across last 7 days (for weekly chart)
    for days_ago in range(7):
        day = now - timedelta(days=days_ago)
        n = random.randint(8, 20) if days_ago < 5 else random.randint(4, 10)
        for _ in range(n):
            uid = random.choice(all_user_ids)
            cat = random.choice(CATEGORIES)
            started = day.replace(hour=random.randint(8, 18), minute=random.randint(0, 59))
            completed = started + timedelta(minutes=random.randint(10, 40))
            session_meta.append((uid, cat, "completed", started, completed))

    # Build value tuples for batch insert
    session_values = [(uid, cat, st, s, c, s) for uid, cat, st, s, c in session_meta]

    print(f"  Inserting {len(session_values)} sessions...")

    # Use execute_values for fast batch insert, then fetch all IDs
    psycopg2.extras.execute_values(
        cur,
        """INSERT INTO test_sessions (user_id, category, status, started_at, completed_at, created_at)
           VALUES %s""",
        session_values,
        template="(%s, %s, %s, %s, %s, %s)",
        page_size=500
    )
    conn.commit()

    # Get all session IDs in order
    cur.execute("SELECT id FROM test_sessions ORDER BY id")
    session_ids = [r[0] for r in cur.fetchall()]
    print(f"  Inserted {len(session_ids)} sessions")

    # ── 4. Batch-insert test_items + test_results ────────────────────────
    print("\n[4/6] Seeding test items & results (batch)...")

    item_rows = []
    result_rows = []

    for idx, (uid, cat, status, started, completed) in enumerate(session_meta):
        if idx >= len(session_ids):
            break
        sid = session_ids[idx]

        # Test items
        items = TEST_ITEMS_MAP.get(cat, [])
        for item_name, item_type in items:
            proc_val = round(random.uniform(30, 98), 2) if status == "completed" else None
            item_completed = completed if status == "completed" else None
            item_rows.append((sid, item_name, item_type, proc_val, started, item_completed, started))

        # Test result (only for completed)
        if status == "completed" and completed:
            ad_s = round(random.uniform(5, 95), 1)
            pd_s = round(random.uniform(5, 90), 1)
            cat_s = round(random.uniform(20, 95), 1)
            sev = "high" if max(ad_s, pd_s) >= 70 else ("medium" if max(ad_s, pd_s) >= 40 else "low")
            stg = "Severe" if max(ad_s, pd_s) >= 70 else ("Moderate" if max(ad_s, pd_s) >= 50 else ("Mild" if max(ad_s, pd_s) >= 30 else "Normal"))
            result_rows.append((sid, ad_s, pd_s, cat_s, stg, sev, completed))

    # Batch insert items
    print(f"  Inserting {len(item_rows)} test items...")
    psycopg2.extras.execute_values(
        cur,
        """INSERT INTO test_items (session_id, item_name, item_type, processed_value, started_at, completed_at, created_at)
           VALUES %s""",
        item_rows,
        template="(%s, %s, %s, %s, %s, %s, %s)",
        page_size=500
    )
    conn.commit()
    print(f"  Inserted {len(item_rows)} test items")

    # Batch insert results
    print(f"  Inserting {len(result_rows)} test results...")
    psycopg2.extras.execute_values(
        cur,
        """INSERT INTO test_results (session_id, ad_risk_score, pd_risk_score, category_score, stage, severity, created_at)
           VALUES %s""",
        result_rows,
        template="(%s, %s, %s, %s, %s, %s, %s)",
        page_size=500
    )
    conn.commit()
    print(f"  Inserted {len(result_rows)} test results")

    # ── 5. Clinical notes, reports, wellness, patient accesses ───────────
    print("\n[5/6] Seeding clinical notes, reports, wellness, accesses...")

    # Get doctor IDs
    cur.execute("SELECT id FROM doctors LIMIT 5")
    doctor_ids = [r[0] for r in cur.fetchall()]
    if not doctor_ids:
        doctor_ids = [1]
    print(f"  Using {len(doctor_ids)} doctors")

    note_titles = [
        "Initial Cognitive Assessment", "Follow-up: Memory Decline",
        "Gait Analysis Review", "Speech Therapy Progress",
        "Motor Function Evaluation", "Treatment Plan Update",
        "Quarterly Neurological Review", "Risk Score Discussion",
        "Family Consultation Notes", "Medication Adjustment",
    ]
    note_contents = [
        "Patient shows moderate improvement in cognitive function tests. Stroop test response time decreased by 15%.",
        "Noticeable decline in short-term memory recall. Trail-making B shows increased errors.",
        "Gait velocity has decreased 8% from baseline. Stride length asymmetry noted.",
        "Speech fluency improved over 6-week period. Word-finding difficulties persist but reduced.",
        "Finger tapping speed within normal range. Spiral drawing shows mild tremor.",
        "Updated treatment plan to include combination therapy. Patient and family informed.",
        "Comprehensive review completed. AD risk stable. PD markers showing slight elevation.",
        "Discussed elevated risk scores with patient. Emphasized lifestyle modifications.",
        "Met with patient family. Discussed care planning and early intervention strategies.",
        "Reduced donepezil dosage due to side effects. Switched to rivastigmine patch.",
    ]

    # Clinical notes (batch)
    note_rows = []
    for _ in range(80):
        note_rows.append((
            random.choice(doctor_ids), random.choice(all_user_ids),
            random.choice(note_titles), random.choice(note_contents),
            random.choice(NOTE_TYPES), random.random() < 0.15,
            rand_dt(now - timedelta(days=90), now)
        ))
    psycopg2.extras.execute_values(
        cur,
        """INSERT INTO clinical_notes (doctor_id, patient_id, title, content, note_type, is_flagged, created_at)
           VALUES %s""",
        note_rows, template="(%s, %s, %s, %s, %s, %s, %s)", page_size=100
    )
    conn.commit()
    print(f"  Inserted {len(note_rows)} clinical notes")

    # Reports (batch)
    report_rows = []
    for _ in range(60):
        uid = random.choice(all_user_ids)
        rtype = random.choice(["comprehensive", "speech_cognitive", "motor_gait"])
        report_rows.append((
            uid, f"{rtype.replace('_', ' ').title()} Report", rtype,
            random.randint(3, 12),
            round(random.uniform(5, 90), 1), round(random.uniform(5, 85), 1),
            round(random.uniform(25, 92), 1), round(random.uniform(25, 90), 1),
            round(random.uniform(25, 88), 1), round(random.uniform(25, 90), 1),
            round(random.uniform(25, 88), 1),
            random.choice(["CN", "MCI", "Mild AD", "Moderate AD"]),
            random.choice(["Normal", "Early PD", "Moderate PD"]),
            random.random() < 0.85,
            rand_dt(now - timedelta(days=120), now)
        ))
    psycopg2.extras.execute_values(
        cur,
        """INSERT INTO reports (user_id, title, report_type, tests_count,
               ad_risk_score, pd_risk_score, cognitive_score, speech_score,
               motor_score, gait_score, facial_score, ad_stage, pd_stage,
               is_ready, created_at)
           VALUES %s""",
        report_rows,
        template="(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
        page_size=100
    )
    conn.commit()
    print(f"  Inserted {len(report_rows)} reports")

    # Wellness entries (batch)
    wellness_rows = []
    for uid in random.sample(all_user_ids, min(35, len(all_user_ids))):
        for _ in range(random.randint(5, 18)):
            d = rand_dt(now - timedelta(days=60), now)
            wellness_rows.append((
                uid, round(random.uniform(4, 10), 1), random.choice(SLEEP_Q),
                round(random.uniform(1, 12), 1), round(random.uniform(0, 4), 1),
                random.randint(1, 10), random.choice(MOODS),
                random.randint(1, 10), random.randint(0, 120),
                random.randint(2, 12),
                random.choice([None, "Felt good", "Headache", "Tired", "Active day"]),
                d, d
            ))
    psycopg2.extras.execute_values(
        cur,
        """INSERT INTO wellness_entries (user_id, sleep_hours, sleep_quality,
               screen_time_hours, gaming_hours, stress_level, mood,
               anxiety_level, physical_activity_minutes, water_intake_glasses,
               notes, created_at, entry_date)
           VALUES %s""",
        wellness_rows,
        template="(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
        page_size=200
    )
    conn.commit()
    print(f"  Inserted {len(wellness_rows)} wellness entries")

    # Patient accesses (batch)
    access_rows = []
    for _ in range(100):
        access_rows.append((
            random.choice(doctor_ids), random.choice(all_user_ids),
            random.choice(["view", "view", "export", "note_added"]),
            rand_dt(now - timedelta(days=60), now)
        ))
    psycopg2.extras.execute_values(
        cur,
        """INSERT INTO patient_accesses (doctor_id, patient_id, access_type, accessed_at)
           VALUES %s""",
        access_rows, template="(%s, %s, %s, %s)", page_size=100
    )
    conn.commit()
    print(f"  Inserted {len(access_rows)} patient accesses")

    # ── 6. Summary ───────────────────────────────────────────────────────
    print("\n[6/6] Verification...")
    queries = [
        ("Users", "SELECT COUNT(*) FROM users"),
        ("Completed tests", "SELECT COUNT(*) FROM test_sessions WHERE status='completed'"),
        ("Test items", "SELECT COUNT(*) FROM test_items"),
        ("Test results", "SELECT COUNT(*) FROM test_results"),
        ("Clinical notes", "SELECT COUNT(*) FROM clinical_notes"),
        ("Reports", "SELECT COUNT(*) FROM reports"),
        ("Wellness entries", "SELECT COUNT(*) FROM wellness_entries"),
        ("High risk users", "SELECT COUNT(*) FROM users WHERE GREATEST(ad_risk_score, pd_risk_score) >= 70"),
    ]
    print("\n" + "=" * 50)
    print("  SEED SUMMARY")
    print("=" * 50)
    for label, q in queries:
        cur.execute(q)
        print(f"  {label:20s}: {cur.fetchone()[0]}")

    # Category breakdown
    cur.execute("SELECT category, COUNT(*) FROM test_sessions WHERE status='completed' GROUP BY category ORDER BY count DESC")
    print("\n  Tests by category:")
    for cat, cnt in cur.fetchall():
        print(f"    {cat:12s} -> {cnt}")

    # Weekly breakdown
    print("\n  Last 7 days:")
    for d in range(7):
        day = (now - timedelta(days=d)).strftime('%Y-%m-%d')
        cur.execute(f"SELECT COUNT(*) FROM test_sessions WHERE status='completed' AND completed_at::date = '{day}'")
        print(f"    {day}: {cur.fetchone()[0]} tests")

    print("\n" + "=" * 50)
    print("  DONE! Dashboard should now show rich data.")
    print("=" * 50)

    cur.close()
    conn.close()


if __name__ == "__main__":
    main()
