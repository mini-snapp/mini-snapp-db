USE mini_snapp;
GO

-- =============================================
-- SECTION 0: Clear existing data before re-seeding
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
-- PART 1: Roles & Permissions
-- =============================================
INSERT INTO core.roles (role_name, role_description, hierarchy_level) VALUES
('customer',         'Regular end-user ordering food or requesting rides', 1),
('driver',           'Delivers food or drives taxi rides',                  2),
('restaurant_staff', 'Works at a branch, manages incoming orders',          3),
('branch_owner',     'Owns/manages a specific restaurant branch',           3),
('brand_owner',      'Owns a restaurant brand across multiple branches',    3),
('admin',            'Platform administrator with elevated access',         5),
('super_admin',      'Full platform control, including admin management',   10);
GO

INSERT INTO core.permissions (permission_name, permission_description) VALUES
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

INSERT INTO core.role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM core.roles r
JOIN core.permissions p ON 1=1
WHERE r.role_name = 'super_admin';
GO

INSERT INTO core.role_permissions (role_id, permission_id)
SELECT r.role_id, p.permission_id
FROM core.roles r
JOIN core.permissions p ON p.permission_name IN
    ('can_ban_user','can_create_coupon','can_edit_coupon','can_resolve_complaint',
     'can_view_financials','can_manage_branches','can_manage_drivers','can_issue_refund','can_view_logs')
WHERE r.role_name = 'admin';
GO


-- PART 2: Business Logic Data (Coupons & Commissions)


INSERT INTO core.coupons (code, percentage, amount, min_requirement, max_cap, expiry_date, current_usage, max_usage, is_active) VALUES
('WELCOME20',   20.00, NULL, 15.00, 10.00, DATEADD(MONTH, 2, GETDATE()), 3,  100, 1), 
('FLAT5',       NULL,  5.00, 20.00, NULL,  DATEADD(MONTH, 1, GETDATE()), 0,  50,  1), 
('EXPIRED10',   10.00, NULL, 10.00, 5.00,  DATEADD(DAY, -5, GETDATE()),  2,  20,  1), 
('MAXEDOUT',    15.00, NULL, 0.00,  NULL,  DATEADD(MONTH, 3, GETDATE()), 10, 10,  1), 
('DISABLED5',   5.00,  NULL, 0.00,  NULL,  DATEADD(MONTH, 1, GETDATE()), 0,  100, 0), 
('SMALLCAP',    50.00, NULL, 12.00, 3.50,  DATEADD(MONTH, 1, GETDATE()), 4,  40,  1), 
('LASTUSE',     NULL,  8.00, 0.00,  NULL,  DATEADD(MONTH, 1, GETDATE()), 9,  10,  1); 
GO

INSERT INTO core.app_wallets (total_balance) VALUES (0);
GO

INSERT INTO core.commission_rates (service_type, driver_share, restaurant_share, app_share, effective_from, effective_to) VALUES
('food', 15.00, 75.00, 10.00, DATEADD(MONTH, -1, GETDATE()), NULL),                            
('taxi', 80.00, NULL,  20.00, DATEADD(MONTH, -1, GETDATE()), NULL),                            
('food', 16.00, 74.00, 10.00, DATEADD(MONTH, -3, GETDATE()), DATEADD(MONTH, -1, GETDATE())),  
('taxi', 82.00, NULL,  18.00, DATEADD(MONTH, -6, GETDATE()), DATEADD(MONTH, -1, GETDATE()));   
GO

-- =============================================
-- PART 3: Users, Wallets & Admins
-- =============================================
DECLARE @role_customer INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @role_driver INT = (SELECT role_id FROM core.roles WHERE role_name = 'driver');
DECLARE @role_staff INT = (SELECT role_id FROM core.roles WHERE role_name = 'restaurant_staff');
DECLARE @role_branch_owner INT = (SELECT role_id FROM core.roles WHERE role_name = 'branch_owner');
DECLARE @role_admin INT = (SELECT role_id FROM core.roles WHERE role_name = 'admin');
DECLARE @role_super_admin INT = (SELECT role_id FROM core.roles WHERE role_name = 'super_admin');

INSERT INTO core.users (username, password_hash, first_name, last_name, registration_phone, email, role_id, is_blocked, deleted_at) VALUES
('sara_ahmadi',    '$2b$12$hash...', 'Sara',     'Ahmadi',   '09121110001', 'sara@mini-snapp.ir',   @role_customer, 0, NULL),
('reza_karimi',    '$2b$12$hash...', 'Reza',     'Karimi',   '09121110002', 'reza@mini-snapp.ir',   @role_customer, 0, NULL),
('driver_neda',    '$2b$12$hash...', 'Neda',     'Rostami',  '09121110003', 'neda@mini-snapp.ir',   @role_driver,   0, NULL),
('staff_hamed',    '$2b$12$hash...', 'Hamed',    'Jafari',   '09121110004', 'hamed@mini-snapp.ir',  @role_staff,    0, NULL),
('behnam_moshiri', '$2b$12$hash...', 'Behnam',   'Moshiri',  '09121110005', 'behnam@mini-snapp.ir', @role_customer, 0, NULL),
('admin_yasaman',  '$2b$12$hash...', 'Yasaman',  'Bahrami',  '09121110006', 'yasaman@mini-snapp.ir',@role_admin,    0, NULL),
('avatar_aang',    '$2b$12$hash...', 'Aang',     'Airnomad', '09129990001', 'aang@mini-snapp.ir',   @role_customer, 0, NULL),
('driver_zuko',    '$2b$12$hash...', 'Zuko',     'Firelord', '09129990002', 'zuko@mini-snapp.ir',   @role_driver,   1, NULL),
('super_iroh',     '$2b$12$hash...', 'Iroh',     'Dragon',   '09129990003', 'iroh@mini-snapp.ir',   @role_super_admin, 0, NULL);
GO

-- Realistic wallet balances
INSERT INTO core.user_wallets (user_id, balance)
SELECT user_id,
    CASE username
        WHEN 'sara_ahmadi'    THEN 45.50
        WHEN 'reza_karimi'    THEN 0.00              
        WHEN 'driver_neda'    THEN 120.00
        WHEN 'staff_hamed'    THEN 85.25
        WHEN 'behnam_moshiri' THEN 350.00        
        WHEN 'admin_yasaman'  THEN 0.00
        WHEN 'avatar_aang'    THEN 25.00
        WHEN 'driver_zuko'    THEN 0.00
        WHEN 'super_iroh'     THEN 999.00
        ELSE 0.00
    END
FROM core.users;
GO

INSERT INTO core.admins (user_id, admin_identifier, access_level)
SELECT user_id, 'ADM-1001', 'full' FROM core.users WHERE username = 'admin_yasaman';

INSERT INTO core.admins (user_id, admin_identifier, access_level)
SELECT user_id, 'ADM-9999', 'super' FROM core.users WHERE username = 'super_iroh';
GO

-- =============================================
-- PART 4: Transactions & Complaints
-- =============================================
-- Realistic transaction amounts
INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT user_id, 'wallet_charge', 'completed', 50.00, 'card', NULL, DATEADD(DAY, -10, GETDATE()) FROM core.users WHERE username = 'sara_ahmadi';

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT u.user_id, 'order_payment', 'completed', 24.50, 'wallet', c.coupon_id, DATEADD(DAY, -8, GETDATE()) FROM core.users u JOIN core.coupons c ON c.code = 'WELCOME20' WHERE u.username = 'sara_ahmadi';

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT user_id, 'ride_payment', 'completed', 12.50, 'wallet', NULL, DATEADD(DAY, -3, GETDATE()) FROM core.users WHERE username = 'avatar_aang';

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT user_id, 'ride_payment', 'failed', 8.50, 'card', NULL, DATEADD(HOUR, -5, GETDATE()) FROM core.users WHERE username = 'driver_zuko';
GO

DECLARE @aang_id INT = (SELECT user_id FROM core.users WHERE username = 'avatar_aang');
DECLARE @zuko_id INT = (SELECT user_id FROM core.users WHERE username = 'driver_zuko');
DECLARE @iroh_admin_id INT = (SELECT admin_id FROM core.admins a JOIN core.users u ON a.user_id = u.user_id WHERE u.username = 'super_iroh');

INSERT INTO core.complaints (reporter_id, target_type, target_id, title, complaint_description, complaint_status, assigned_admin_id, created_at, resolved_at)
VALUES (@aang_id, 'driver', @zuko_id, 'Aggressive and unsafe driving!', 'The driver kept talking about his honor and was speeding aggressively.', 'resolved', @iroh_admin_id, DATEADD(DAY, -7, GETDATE()), DATEADD(DAY, -5, GETDATE()));

DECLARE @sara_id INT = (SELECT user_id FROM core.users WHERE username = 'sara_ahmadi');
INSERT INTO core.complaints (reporter_id, target_type, target_id, title, complaint_description, complaint_status, assigned_admin_id, created_at, resolved_at)
VALUES (@sara_id, 'branch', 1, 'Wrong order delivered', 'I ordered a pizza but received a completely different dish.', 'open', NULL, DATEADD(DAY, -1, GETDATE()), NULL);
GO

-- =============================================
-- PART 5: Procedure Calls (Triggers Validation)
-- =============================================
DECLARE @role_customer_id INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @role_driver_id   INT = (SELECT role_id FROM core.roles WHERE role_name = 'driver');

DECLARE @new_user_1 INT, @new_user_2 INT;

EXEC core.sp_register_user
    @username = 'newbie_taha', @password_hash = '$2b$12$hash...',
    @first_name = 'Taha', @last_name = 'Nazari', @registration_phone = '09121234513',
    @email = 'taha.nazari@example.com', @role_id = @role_customer_id, @new_user_id = @new_user_1 OUTPUT;

EXEC core.sp_register_user
    @username = 'newbie_arash', @password_hash = '$2b$12$hash...',
    @first_name = 'Arash', @last_name = 'Kamali', @registration_phone = '09121234515',
    @email = 'arash.kamali@example.com', @role_id = @role_driver_id, @new_user_id = @new_user_2 OUTPUT;
GO

DECLARE @hamed_id INT = (SELECT user_id FROM core.users WHERE username = 'staff_hamed');
EXEC core.sp_assign_admin_role @user_id = @hamed_id, @admin_identifier = 'ADM-1002', @access_level = 'limited';
GO