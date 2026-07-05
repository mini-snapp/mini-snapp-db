-- ai generated

USE mini_snapp;
GO

-- =============================================
-- SECTION 0: Clear existing data before re-seeding
-- Order matters: children before parents (reverse FK dependency)
-- =============================================

DELETE FROM core.core_logs;
DELETE FROM core.coupon_usages;
DELETE FROM core.complaints;
DELETE FROM core.transactions;
DELETE FROM core.saved_accounts;
DELETE FROM core.addresses;
DELETE FROM core.admins;
DELETE FROM core.user_wallets;
DELETE FROM core.role_permissions;
DELETE FROM core.users;
DELETE FROM core.roles;
DELETE FROM core.permissions;
DELETE FROM core.coupons;
DELETE FROM core.app_wallets;
DELETE FROM core.commission_rates;
GO

-- Reset IDENTITY counters back to 0 so IDs are clean and predictable
DBCC CHECKIDENT ('core.core_logs', RESEED, 0);
DBCC CHECKIDENT ('core.coupon_usages', RESEED, 0);
DBCC CHECKIDENT ('core.complaints', RESEED, 0);
DBCC CHECKIDENT ('core.transactions', RESEED, 0);
DBCC CHECKIDENT ('core.saved_accounts', RESEED, 0);
DBCC CHECKIDENT ('core.addresses', RESEED, 0);
DBCC CHECKIDENT ('core.admins', RESEED, 0);
DBCC CHECKIDENT ('core.user_wallets', RESEED, 0);
DBCC CHECKIDENT ('core.role_permissions', RESEED, 0);
DBCC CHECKIDENT ('core.users', RESEED, 0);
DBCC CHECKIDENT ('core.roles', RESEED, 0);
DBCC CHECKIDENT ('core.permissions', RESEED, 0);
DBCC CHECKIDENT ('core.coupons', RESEED, 0);
DBCC CHECKIDENT ('core.app_wallets', RESEED, 0);
DBCC CHECKIDENT ('core.commission_rates', RESEED, 0);
GO

-- =============================================
-- PART 1: Direct inserts — base tables
-- =============================================

-- ── roles (7 rows — small reference table, all values needed) ──
INSERT INTO core.roles (role_name, role_description, hierarchy_level) VALUES
('customer',         'Regular end-user ordering food or requesting rides', 1),
('driver',           'Delivers food or drives taxi rides',                  2),
('restaurant_staff', 'Works at a branch, manages incoming orders',          2),
('branch_owner',     'Owns/manages a specific restaurant branch',           3),
('brand_owner',      'Owns a restaurant brand across multiple branches',    3),
('admin',            'Platform administrator with elevated access',        5),
('super_admin',      'Full platform control, including admin management',  10);
GO

-- ── permissions (10 rows) ────────────────────
INSERT INTO core.permissions (permissions_name, permissions_description) VALUES
('can_ban_user',           'Block or unblock a user account'),
('can_create_coupon',      'Create new discount coupons'),
('can_edit_coupon',        'Edit or deactivate existing coupons'),
('can_resolve_complaint',  'Close or reject a complaint'),
('can_view_financials',    'View platform-wide financial reports'),
('can_manage_admins',      'Promote or demote other admins'),
('can_manage_branches',    'Approve or suspend restaurant branches'),
('can_manage_drivers',     'Approve, suspend, or ban drivers'),
('can_issue_refund',       'Manually issue a refund to a user wallet'),
('can_view_logs',          'View system audit logs across all schemas');
GO

-- ── role_permissions ─────────────────────────
-- super_admin: everything
INSERT INTO core.role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM core.roles r
JOIN core.permissions p ON 1=1
WHERE r.role_name = 'super_admin';
GO

-- admin: most, but not can_manage_admins (only super_admin can)
INSERT INTO core.role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM core.roles r
JOIN core.permissions p ON p.permissions_name IN
    ('can_ban_user','can_create_coupon','can_edit_coupon','can_resolve_complaint',
     'can_view_financials','can_manage_branches','can_manage_drivers','can_issue_refund','can_view_logs')
WHERE r.role_name = 'admin';
GO

-- ── coupons (10 rows, wide variety of edge cases) ──
INSERT INTO core.coupons (code, percentage, amount, min_requirement, max_cap, expiry_date, current_usage, max_usage, is_active) VALUES
('WELCOME20',   20.00, NULL,      50000.00,  30000.00, DATEADD(MONTH, 2, GETDATE()), 3,   100, 1),  -- normal active, percentage
('FLAT50K',     NULL,  50000.00,  100000.00, NULL,     DATEADD(MONTH, 1, GETDATE()), 0,   50,  1),  -- normal active, flat amount
('EXPIRED10',   10.00, NULL,      20000.00,  10000.00, DATEADD(DAY, -5, GETDATE()),  2,   20,  1),  -- edge: expired
('MAXEDOUT',    15.00, NULL,      0.00,      NULL,     DATEADD(MONTH, 3, GETDATE()), 10,  10,  1),  -- edge: usage limit reached
('DISABLED5',   5.00,  NULL,      0.00,      NULL,     DATEADD(MONTH, 1, GETDATE()), 0,   100, 0),  -- edge: manually deactivated
('NOEXPIRY',    10.00, NULL,      0.00,      15000.00, NULL,                          1,   9999,1),  -- edge: no expiry date at all
('HIGHMIN',     30.00, NULL,      500000.00, 100000.00,DATEADD(MONTH, 1, GETDATE()), 0,   30,  1),  -- edge: very high min_requirement
('SMALLCAP',    50.00, NULL,      10000.00,  5000.00,  DATEADD(MONTH, 1, GETDATE()), 4,   40,  1),  -- normal, small max_cap
('LASTUSE',     NULL,  20000.00,  0.00,      NULL,     DATEADD(MONTH, 1, GETDATE()), 9,   10,  1),  -- edge: one use remaining
('BRANDNEW',    25.00, NULL,      0.00,      50000.00, DATEADD(DAY, 1, GETDATE()),   0,   200, 1);  -- edge: expires tomorrow
GO

-- ── app_wallets (singleton — only 1 row by design) ──
INSERT INTO core.app_wallets (total_balance) VALUES (0);
GO

-- ── commission_rates (11 rows: current + historical, to test effective_from/to logic) ──
INSERT INTO core.commission_rates (service_type, driver_share, restaurant_share, app_share, effective_from, effective_to) VALUES
('food', 15.00, 75.00, 10.00, DATEADD(MONTH, -6, GETDATE()), DATEADD(MONTH, -3, GETDATE())),  -- historical
('food', 16.00, 74.00, 10.00, DATEADD(MONTH, -3, GETDATE()), DATEADD(MONTH, -1, GETDATE())),  -- historical
('food', 15.00, 75.00, 10.00, DATEADD(MONTH, -1, GETDATE()), NULL),                            -- current active
('taxi', 82.00, NULL,  18.00, DATEADD(MONTH, -6, GETDATE()), DATEADD(MONTH, -1, GETDATE())),   -- historical
('taxi', 80.00, NULL,  20.00, DATEADD(MONTH, -1, GETDATE()), NULL),                            -- current active
('food', 14.00, 76.00, 10.00, DATEADD(MONTH, -12, GETDATE()), DATEADD(MONTH, -6, GETDATE())),  -- old historical
('taxi', 85.00, NULL,  15.00, DATEADD(MONTH, -12, GETDATE()), DATEADD(MONTH, -6, GETDATE())),  -- old historical
('food', 17.00, 73.00, 10.00, DATEADD(YEAR, -2, GETDATE()), DATEADD(MONTH, -12, GETDATE())),   -- very old
('taxi', 78.00, NULL,  22.00, DATEADD(YEAR, -2, GETDATE()), DATEADD(MONTH, -12, GETDATE())),   -- very old
('food', 15.50, 74.50, 10.00, DATEADD(MONTH, -9, GETDATE()), DATEADD(MONTH, -6, GETDATE())),   -- fills a gap
('taxi', 81.00, NULL,  19.00, DATEADD(MONTH, -9, GETDATE()), DATEADD(MONTH, -6, GETDATE()));   -- fills a gap
GO

-- ── users (12 rows: multiple roles + blocked + soft-deleted edge cases) ──
DECLARE @role_customer INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @role_driver INT = (SELECT role_id FROM core.roles WHERE role_name = 'driver');
DECLARE @role_staff INT = (SELECT role_id FROM core.roles WHERE role_name = 'restaurant_staff');
DECLARE @role_branch_owner INT = (SELECT role_id FROM core.roles WHERE role_name = 'branch_owner');
DECLARE @role_brand_owner INT = (SELECT role_id FROM core.roles WHERE role_name = 'brand_owner');
DECLARE @role_admin INT = (SELECT role_id FROM core.roles WHERE role_name = 'admin');

INSERT INTO core.users (username, password_hash, first_name, last_name, registration_phone, email, role_id, is_blocked, deleted_at) VALUES
('sara_ahmadi',    '$2b$12$hashvalue0000000000000000000001', 'Sara',     'Ahmadi',   '09121234501', 'sara.ahmadi@example.com',   @role_customer, 0, NULL),
('reza_karimi',    '$2b$12$hashvalue0000000000000000000002', 'Reza',     'Karimi',   '09121234502', 'reza.karimi@example.com',   @role_customer, 0, NULL),
('mina_hosseini',  '$2b$12$hashvalue0000000000000000000003', 'Mina',     'Hosseini', '09121234503', 'mina.hosseini@example.com', @role_customer, 1, NULL),                          -- edge: blocked
('old_account99',  '$2b$12$hashvalue0000000000000000000004', 'Farhad',   'Ghasemi',  '09121234504', 'farhad.g@example.com',      @role_customer, 0, DATEADD(MONTH, -2, GETDATE())), -- edge: soft-deleted
('behnam_moshiri', '$2b$12$hashvalue0000000000000000000005', 'Behnam',   'Moshiri',  '09121234505', 'behnam.m@example.com',      @role_customer, 0, NULL),
('driver_amir',    '$2b$12$hashvalue0000000000000000000006', 'Amir',     'Sadeghi',  '09121234506', 'amir.sadeghi@example.com',  @role_driver,   0, NULL),
('driver_neda',    '$2b$12$hashvalue0000000000000000000007', 'Neda',     'Rostami',  '09121234507', 'neda.rostami@example.com',  @role_driver,   0, NULL),
('driver_kaveh',   '$2b$12$hashvalue0000000000000000000008', 'Kaveh',    'Tehrani',  '09121234508', 'kaveh.t@example.com',       @role_driver,   1, NULL),                          -- edge: blocked driver
('staff_hamed',    '$2b$12$hashvalue0000000000000000000009', 'Hamed',    'Jafari',   '09121234509', 'hamed.jafari@example.com',  @role_staff,    0, NULL),
('owner_leila',    '$2b$12$hashvalue0000000000000000000010', 'Leila',    'Moradi',   '09121234510', 'leila.moradi@example.com',  @role_branch_owner, 0, NULL),
('brand_kianoosh', '$2b$12$hashvalue0000000000000000000011', 'Kianoosh', 'Fallahi',  '09121234511', 'kianoosh.f@example.com',    @role_brand_owner,  0, NULL),
('admin_yasaman',  '$2b$12$hashvalue0000000000000000000012', 'Yasaman',  'Bahrami',  '09121234512', 'yasaman.b@example.com',     @role_admin,        0, NULL);
GO

-- ── user_wallets (12 rows — one per user, varied balances incl. zero) ──
INSERT INTO core.user_wallets (user_id, balance)
SELECT user_id,
    CASE username
        WHEN 'sara_ahmadi'    THEN 250000.00
        WHEN 'reza_karimi'    THEN 0.00              -- edge: zero balance
        WHEN 'mina_hosseini'  THEN 75000.50
        WHEN 'old_account99'  THEN 12000.00
        WHEN 'behnam_moshiri' THEN 4500000.00        -- edge: unusually high balance
        WHEN 'driver_amir'    THEN 1850000.00
        WHEN 'driver_neda'    THEN 940000.00
        WHEN 'driver_kaveh'   THEN 0.00              -- edge: zero balance, also blocked
        WHEN 'staff_hamed'    THEN 300000.00
        WHEN 'owner_leila'    THEN 5200000.00
        WHEN 'brand_kianoosh' THEN 9800000.00
        WHEN 'admin_yasaman'  THEN 0.00
    END
FROM core.users;
GO

-- ── admins (1 row for now — more can be added later via sp_assign_admin_role) ──
INSERT INTO core.admins (user_id, admin_identifier, access_level)
SELECT user_id, 'ADM-1001', 'full'
FROM core.users WHERE username = 'admin_yasaman';
GO

-- ── addresses (10 rows across several users, varied cities) ──
INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'Home', 'Tehran', 'Tehran', 'Valiasr St, No. 124', 'Blue door, 3rd floor', 35.71956200, 51.40871900
FROM core.users WHERE username = 'sara_ahmadi';

INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'Work', 'Tehran', 'Tehran', 'Sohrevardi St, No. 45', 'Office building, unit 8', 35.72981100, 51.42501300
FROM core.users WHERE username = 'sara_ahmadi';

INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'Home', 'Alborz', 'Karaj', 'Azadi Blvd, No. 12', NULL, 35.83273400, 50.99163800
FROM core.users WHERE username = 'reza_karimi';

INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'Home', 'Tehran', 'Tehran', 'Enghelab St, No. 78', 'Ring the bell twice', 35.70019800, 51.38712400
FROM core.users WHERE username = 'mina_hosseini';

INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'Home', 'Isfahan', 'Isfahan', 'Chahar Bagh St, No. 200', NULL, 32.65464600, 51.66795500
FROM core.users WHERE username = 'owner_leila';

INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'Home', 'Tehran', 'Tehran', 'Shariati St, No. 310', 'Near the pharmacy', 35.75842100, 51.44562300
FROM core.users WHERE username = 'behnam_moshiri';

INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'Parents House', 'Tehran', 'Tehran', 'Pasdaran St, No. 55', NULL, 35.78432900, 51.46893100
FROM core.users WHERE username = 'behnam_moshiri';

INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'Branch Office', 'Fars', 'Shiraz', 'Zand Blvd, No. 88', NULL, 29.61032500, 52.53114700
FROM core.users WHERE username = 'brand_kianoosh';

INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'Home', 'Tehran', 'Tehran', 'Niavaran St, No. 15', 'Gated community', 35.80963200, 51.48291500
FROM core.users WHERE username = 'admin_yasaman';

INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'Home', 'Qazvin', 'Qazvin', 'Imam Khomeini Blvd, No. 60', 'Next to the bakery', 36.28974700, 50.00415300
FROM core.users WHERE username = 'old_account99';
GO

-- ── saved_accounts (6 rows) ──
INSERT INTO core.saved_accounts (user_id, card_number, bank_name)
SELECT user_id, '6037991234567890', 'Melli Bank' FROM core.users WHERE username = 'sara_ahmadi';
INSERT INTO core.saved_accounts (user_id, card_number, bank_name)
SELECT user_id, '6104337654321098', 'Mellat Bank' FROM core.users WHERE username = 'owner_leila';
INSERT INTO core.saved_accounts (user_id, card_number, bank_name)
SELECT user_id, '5892101122334455', 'Saman Bank' FROM core.users WHERE username = 'brand_kianoosh';
INSERT INTO core.saved_accounts (user_id, card_number, bank_name)
SELECT user_id, '6219861112223334', 'Sepah Bank' FROM core.users WHERE username = 'behnam_moshiri';
INSERT INTO core.saved_accounts (user_id, card_number, bank_name)
SELECT user_id, '6393461234509876', 'Tejarat Bank' FROM core.users WHERE username = 'driver_amir';
INSERT INTO core.saved_accounts (user_id, card_number, bank_name)
SELECT user_id, '6280231239874561', 'Parsian Bank' FROM core.users WHERE username = 'admin_yasaman';
GO

-- ── transactions (12 rows, all types/statuses/payment methods represented) ──
INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT user_id, 'wallet_charge', 'completed', 300000.00, 'card', NULL, DATEADD(DAY, -10, GETDATE())
FROM core.users WHERE username = 'sara_ahmadi';

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT u.user_id, 'order_payment', 'completed', 145000.00, 'wallet', c.coupon_id, DATEADD(DAY, -8, GETDATE())
FROM core.users u JOIN core.coupons c ON c.code = 'WELCOME20'
WHERE u.username = 'sara_ahmadi';

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT user_id, 'wallet_charge', 'failed', 100000.00, 'card', NULL, DATEADD(DAY, -6, GETDATE())
FROM core.users WHERE username = 'reza_karimi';                                       -- edge: failed charge

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT user_id, 'ride_payment', 'completed', 68000.00, 'wallet', NULL, DATEADD(DAY, -3, GETDATE())
FROM core.users WHERE username = 'mina_hosseini';

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT user_id, 'refund', 'reversed', 68000.00, 'wallet', NULL, DATEADD(DAY, -2, GETDATE())
FROM core.users WHERE username = 'mina_hosseini';                                     -- edge: reversed refund

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT user_id, 'payout', 'completed', 620000.00, 'wallet', NULL, DATEADD(DAY, -1, GETDATE())
FROM core.users WHERE username = 'driver_amir';

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT user_id, 'withdrawal', 'pending', 500000.00, 'card', NULL, GETDATE()
FROM core.users WHERE username = 'owner_leila';                                       -- edge: pending withdrawal

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT user_id, 'wallet_charge', 'completed', 1000000.00, 'card', NULL, DATEADD(DAY, -15, GETDATE())
FROM core.users WHERE username = 'behnam_moshiri';                                    -- edge: large amount

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT user_id, 'wallet_charge', 'completed', 50000.00, 'cash', NULL, DATEADD(DAY, -4, GETDATE())
FROM core.users WHERE username = 'driver_neda';                                       -- cash payment method

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT user_id, 'order_payment', 'completed', 89000.00, 'wallet', NULL, DATEADD(DAY, -7, GETDATE())
FROM core.users WHERE username = 'staff_hamed';

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT user_id, 'payout', 'completed', 2400000.00, 'wallet', NULL, DATEADD(DAY, -1, GETDATE())
FROM core.users WHERE username = 'brand_kianoosh';

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT user_id, 'ride_payment', 'failed', 42000.00, 'card', NULL, DATEADD(HOUR, -5, GETDATE())
FROM core.users WHERE username = 'driver_kaveh';                                      -- edge: failed ride payment
GO

-- ── complaints (10 rows, all target_types and statuses represented) ──
INSERT INTO core.complaints (reporter_id, target_type, target_id, title, complaint_description, complaint_status, assigned_admin_id, created_at, resolved_at)
SELECT u.user_id, 'driver', (SELECT user_id FROM core.users WHERE username = 'driver_amir'),
       'Driver was rude', 'The driver was very impolite during the ride and took a longer route than necessary.',
       'resolved', a.admin_id, DATEADD(DAY, -7, GETDATE()), DATEADD(DAY, -5, GETDATE())
FROM core.users u
JOIN core.admins a ON a.user_id = (SELECT user_id FROM core.users WHERE username = 'admin_yasaman')
WHERE u.username = 'mina_hosseini';

INSERT INTO core.complaints (reporter_id, target_type, target_id, title, complaint_description, complaint_status, assigned_admin_id, created_at, resolved_at)
SELECT user_id, 'branch', 1, 'Wrong order delivered', 'I ordered a pizza but received a completely different dish.',
       'open', NULL, DATEADD(DAY, -1, GETDATE()), NULL
FROM core.users WHERE username = 'sara_ahmadi';                                       -- edge: open, unassigned

INSERT INTO core.complaints (reporter_id, target_type, target_id, title, complaint_description, complaint_status, assigned_admin_id, created_at, resolved_at)
SELECT u.user_id, 'user', (SELECT user_id FROM core.users WHERE username = 'reza_karimi'),
       'Passenger did not show up', 'Waited 15 minutes and the passenger never came, then cancelled.',
       'in_review', a.admin_id, DATEADD(HOUR, -6, GETDATE()), NULL
FROM core.users u
JOIN core.admins a ON a.user_id = (SELECT user_id FROM core.users WHERE username = 'admin_yasaman')
WHERE u.username = 'driver_neda';

INSERT INTO core.complaints (reporter_id, target_type, target_id, title, complaint_description, complaint_status, assigned_admin_id, created_at, resolved_at)
SELECT user_id, 'brand', 1, 'Poor food quality', 'The food was cold and clearly not freshly prepared.',
       'rejected', NULL, DATEADD(DAY, -12, GETDATE()), DATEADD(DAY, -10, GETDATE())
FROM core.users WHERE username = 'behnam_moshiri';                                    -- edge: rejected complaint

INSERT INTO core.complaints (reporter_id, target_type, target_id, title, complaint_description, complaint_status, assigned_admin_id, created_at, resolved_at)
SELECT user_id, 'driver', (SELECT user_id FROM core.users WHERE username = 'driver_kaveh'),
       'Unsafe driving', 'The driver was speeding and ran a red light during the trip.',
       'open', NULL, DATEADD(HOUR, -2, GETDATE()), NULL
FROM core.users WHERE username = 'old_account99';                                     -- edge: reporter is soft-deleted user

INSERT INTO core.complaints (reporter_id, target_type, target_id, title, complaint_description, complaint_status, assigned_admin_id, created_at, resolved_at)
SELECT u.user_id, 'branch', 2, 'Missing item in order', 'One of the side dishes was missing from my order.',
       'resolved', a.admin_id, DATEADD(DAY, -20, GETDATE()), DATEADD(DAY, -18, GETDATE())
FROM core.users u
JOIN core.admins a ON a.user_id = (SELECT user_id FROM core.users WHERE username = 'admin_yasaman')
WHERE u.username = 'sara_ahmadi';

INSERT INTO core.complaints (reporter_id, target_type, target_id, title, complaint_description, complaint_status, assigned_admin_id, created_at, resolved_at)
SELECT user_id, 'user', (SELECT user_id FROM core.users WHERE username = 'behnam_moshiri'),
       'Customer was verbally abusive', 'The customer shouted at me over a small delay.',
       'in_review', NULL, DATEADD(HOUR, -20, GETDATE()), NULL
FROM core.users WHERE username = 'driver_amir';

INSERT INTO core.complaints (reporter_id, target_type, target_id, title, complaint_description, complaint_status, assigned_admin_id, created_at, resolved_at)
SELECT user_id, 'branch', 1, 'Overcharged for delivery', 'The delivery fee charged was higher than what was shown in the app.',
       'open', NULL, DATEADD(MINUTE, -45, GETDATE()), NULL
FROM core.users WHERE username = 'mina_hosseini';

INSERT INTO core.complaints (reporter_id, target_type, target_id, title, complaint_description, complaint_status, assigned_admin_id, created_at, resolved_at)
SELECT u.user_id, 'brand', 2, 'Allergy information incorrect', 'The menu did not disclose a nut allergen that caused a reaction.',
       'resolved', a.admin_id, DATEADD(DAY, -30, GETDATE()), DATEADD(DAY, -28, GETDATE())
FROM core.users u
JOIN core.admins a ON a.user_id = (SELECT user_id FROM core.users WHERE username = 'admin_yasaman')
WHERE u.username = 'reza_karimi';                                                     -- edge: sensitive/serious complaint

INSERT INTO core.complaints (reporter_id, target_type, target_id, title, complaint_description, complaint_status, assigned_admin_id, created_at, resolved_at)
SELECT user_id, 'driver', (SELECT user_id FROM core.users WHERE username = 'driver_neda'),
       'Vehicle was not clean', 'The car had a strong smell and visible trash on the floor.',
       'open', NULL, DATEADD(HOUR, -1, GETDATE()), NULL
FROM core.users WHERE username = 'owner_leila';
GO


-- =============================================
-- PART 2: Procedure calls — exercise triggers.
-- These populate core_logs and coupon_usages automatically.
-- Do NOT INSERT into core_logs or coupon_usages directly.
-- =============================================

-- Register new users (tests sp_register_user + trg_users_after_insert,
-- and auto-creates their wallets)
--
-- NOTE: SQL Server does not allow a subquery like (SELECT ...) to be passed
-- directly as an EXEC parameter value. It must first be stored in a variable.
DECLARE @role_customer_id INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @role_driver_id   INT = (SELECT role_id FROM core.roles WHERE role_name = 'driver');

DECLARE @new_user_1 INT, @new_user_2 INT, @new_user_3 INT;

EXEC core.sp_register_user
    @username = 'newbie_taha', @password_hash = '$2b$12$hashvalue0000000000000000000013',
    @first_name = 'Taha', @last_name = 'Nazari', @registration_phone = '09121234513',
    @email = 'taha.nazari@example.com',
    @role_id = @role_customer_id,
    @new_user_id = @new_user_1 OUTPUT;

EXEC core.sp_register_user
    @username = 'newbie_parisa', @password_hash = '$2b$12$hashvalue0000000000000000000014',
    @first_name = 'Parisa', @last_name = 'Ebrahimi', @registration_phone = '09121234514',
    @email = 'parisa.ebrahimi@example.com',
    @role_id = @role_customer_id,
    @new_user_id = @new_user_2 OUTPUT;

EXEC core.sp_register_user
    @username = 'newbie_arash', @password_hash = '$2b$12$hashvalue0000000000000000000015',
    @first_name = 'Arash', @last_name = 'Kamali', @registration_phone = '09121234515',
    @email = 'arash.kamali@example.com',
    @role_id = @role_driver_id,
    @new_user_id = @new_user_3 OUTPUT;
GO

-- Charge wallets (tests sp_charge_wallet + trg_transactions_after_insert)
DECLARE @taha_id INT = (SELECT user_id FROM core.users WHERE username = 'newbie_taha');
DECLARE @parisa_id INT = (SELECT user_id FROM core.users WHERE username = 'newbie_parisa');

EXEC core.sp_charge_wallet
    @user_id = @taha_id,
    @amount = 150000.00, @payment_method = 'card';

EXEC core.sp_charge_wallet
    @user_id = @parisa_id,
    @amount = 80000.00, @payment_method = 'wallet';
GO

-- Promote a user to admin (tests sp_assign_admin_role + trg_admins_after_insert,
-- which should sync role_id automatically)
DECLARE @hamed_id INT = (SELECT user_id FROM core.users WHERE username = 'staff_hamed');

EXEC core.sp_assign_admin_role
    @user_id = @hamed_id,
    @admin_identifier = 'ADM-1002', @access_level = 'limited';
GO

-- Apply coupons (tests sp_apply_coupon + fn_validate_coupon,
-- populates coupon_usages correctly instead of a direct insert)
DECLARE @taha_id2 INT = (SELECT user_id FROM core.users WHERE username = 'newbie_taha');
DECLARE @parisa_id2 INT = (SELECT user_id FROM core.users WHERE username = 'newbie_parisa');

EXEC core.sp_apply_coupon
    @coupon_code = 'FLAT50K',
    @user_id = @taha_id2,
    @order_amount = 120000.00, @order_id = NULL, @ride_id = 9001;  -- placeholder ride_id, taxi.rides not built yet

EXEC core.sp_apply_coupon
    @coupon_code = 'WELCOME20',
    @user_id = @parisa_id2,
    @order_amount = 60000.00, @order_id = 9002, @ride_id = NULL;   -- placeholder order_id, food.food_orders not built yet
GO