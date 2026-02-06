"""
GUARANTEED FIX - Generate Hash Using Your Backend's Function
Run this in your backend directory: python fix_admin_now.py
"""

# Import your own security function
from app.core.security import get_password_hash, verify_password

print("=" * 70)
print("GENERATING ADMIN PASSWORD HASH")
print("=" * 70)

# Generate hash using YOUR backend's function
password = "admin123"
hash_value = get_password_hash(password)

print(f"\nPassword: {password}")
print(f"Hash: {hash_value}")

# Test it immediately
test_result = verify_password(password, hash_value)
print(f"Test: {'✅ WORKS' if test_result else '❌ FAILED'}")

if test_result:
    print("\n" + "=" * 70)
    print("SQL TO RUN (This WILL work)")
    print("=" * 70)
    
    sql = f"""
DELETE FROM admins WHERE email = 'test@admin.com';

INSERT INTO admins (
    id, email, password_hash, first_name, last_name, phone,
    role, can_manage_users, can_manage_doctors, can_manage_permissions,
    can_resolve_tickets, can_view_analytics, can_export_data, can_manage_admins,
    is_active, total_actions, tickets_resolved, users_managed, created_at
) VALUES (
    gen_random_uuid(),
    'test@admin.com',
    '{hash_value}',
    'Test', 'Admin', '+923001111111',
    'SUPER_ADMIN',
    true, true, true, true, true, true, true,
    true, 0, 0, 0, NOW()
);

SELECT 'Admin created successfully' as status;
"""
    
    print(sql)
    
    # Save to file
    with open("fix_admin_guaranteed.sql", "w") as f:
        f.write(sql)
    f.write(f"\n-- Password: {password}\n")
    f.write(f"-- Email: test@admin.com\n")
    
    print("\n✅ SQL saved to: fix_admin_guaranteed.sql")
    print("\n🎯 Next steps:")
    print("   1. Copy the SQL above")
    print("   2. Run it in your PostgreSQL database")
    print("   3. Login with:")
    print("      Email: test@admin.com")
    print("      Password: admin123")

else:
    print("\n❌ ERROR: Hash generation failed!")
    print("Check your security.py file")