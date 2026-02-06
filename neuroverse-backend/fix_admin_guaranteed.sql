
DELETE FROM admins WHERE email = 'test@admin.com';

INSERT INTO admins (
    id, email, password_hash, first_name, last_name, phone,
    role, can_manage_users, can_manage_doctors, can_manage_permissions,
    can_resolve_tickets, can_view_analytics, can_export_data, can_manage_admins,
    is_active, total_actions, tickets_resolved, users_managed, created_at
) VALUES (
    gen_random_uuid(),
    'test@admin.com',
    '$2b$12$bfT8ZWOKjOF8bCLwhDuQmufwRkeSEzLWGWin0FmtfMHIA1ndLq0dC',
    'Test', 'Admin', '+923001111111',
    'SUPER_ADMIN',
    true, true, true, true, true, true, true,
    true, 0, 0, 0, NOW()
);

SELECT 'Admin created successfully' as status;
