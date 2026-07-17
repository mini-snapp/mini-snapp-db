USE mini_snapp;
GO

INSERT INTO core.roles (role_name, role_description, hierarchy_level) VALUES
('customer',         'Standard platform user',                              1),
('driver',           'Registered fleet driver',                             2),
('restaurant_staff', 'Branch operational staff',                            2),
('branch_owner',     'Manager of a specific branch',                        3),
('brand_owner',      'Owner of the parent brand',                           3),
('admin',            'System administrator',                                5),
('super_admin',      'Top-level platform manager',                          10);
GO


INSERT INTO core.permissions (permission_name, permission_description) VALUES
('can_ban_user',          'Block or unblock user accounts'),
('can_create_coupon',     'Generate new discount codes'),
('can_resolve_complaint', 'Review and resolve submitted complaints'),
('can_manage_drivers',    'Approve or suspend driver accounts'),
('can_view_financials',   'Access to platform wallet and revenue');
GO


DECLARE @admin_id INT = (SELECT role_id FROM core.roles WHERE role_name = 'admin');
DECLARE @super_admin_id INT = (SELECT role_id FROM core.roles WHERE role_name = 'super_admin');

INSERT INTO core.role_permissions (role_id, permission_id)
SELECT @super_admin_id, permission_id FROM core.permissions;

INSERT INTO core.role_permissions (role_id, permission_id)
SELECT @admin_id, permission_id FROM core.permissions 
WHERE permission_name IN ('can_ban_user', 'can_resolve_complaint', 'can_manage_drivers');
GO


INSERT INTO core.app_wallets (total_balance) VALUES (0.00);
GO


INSERT INTO core.commission_rates (service_type, driver_share, restaurant_share, app_share, effective_from, effective_to) VALUES
('food', 15.00, 75.00, 10.00, DATEADD(MONTH, -6, GETDATE()), DATEADD(MONTH, -1, GETDATE())),
('food', 12.50, 77.50, 10.00, DATEADD(MONTH, -1, GETDATE()), NULL),                          
('taxi', 80.00, NULL,  20.00, DATEADD(MONTH, -2, GETDATE()), NULL);                            
GO


INSERT INTO core.coupons (code, [percentage], amount, min_requirement, max_cap, expiry_date, current_usage, max_usage, is_active) VALUES
('WELCOME10', 10.00, NULL,  15.00, 5.00, DATEADD(MONTH, 1, GETDATE()),  2, 100, 1),
('MINUS5',    NULL,  5.00,  20.00, NULL, DATEADD(MONTH, 2, GETDATE()),  0,  50, 1), 
('VIPNOEXP',  15.00, NULL,   0.00, 8.00, NULL,                          5, 999, 1), 
('EXPIRED20', 20.00, NULL,  10.00, 5.00, DATEADD(DAY, -5, GETDATE()),   3,  20, 1), 
('MAXEDOUT',  NULL,  2.50,   0.00, NULL, DATEADD(MONTH, 1, GETDATE()), 10,  10, 0); 
GO



DECLARE @r_cust INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @r_driv INT = (SELECT role_id FROM core.roles WHERE role_name = 'driver');
DECLARE @r_admn INT = (SELECT role_id FROM core.roles WHERE role_name = 'admin');


INSERT INTO core.users (username, password_hash, first_name, last_name, registration_phone, email, role_id, is_blocked, deleted_at) VALUES
('avesta',    '$2b$12$dummyhash1', 'Avesta',  NULL,      '5550100001', 'avesta@local.dev',  @r_cust, 0, NULL),
('arash',     '$2b$12$dummyhash2', 'Arash',   NULL,      '5550100002', 'arash@local.dev',   @r_driv, 0, NULL),
('kian_ce',   '$2b$12$dummyhash3', 'Kian',    'Rad',     '5550100003', 'kian.ce@edu.dev',   @r_cust, 0, NULL),
('sara_ta',   '$2b$12$dummyhash4', 'Sara',    'Ahmadi',  '5550100004', 'sara.ta@edu.dev',   @r_cust, 1, NULL),
('neda_db',   '$2b$12$dummyhash5', 'Neda',    'Karimi',  '5550100005', 'neda.db@local.dev', @r_admn, 0, NULL),
('deleted_u', '$2b$12$dummyhash6', 'John',    'Doe',     '5550100006', NULL,                @r_cust, 0, DATEADD(DAY, -10, GETDATE())); 
GO


INSERT INTO core.user_wallets (user_id, balance)
SELECT user_id, 
    CASE username
        WHEN 'avesta'  THEN 45.50
        WHEN 'arash'   THEN 120.00
        WHEN 'kian_ce' THEN 12.75
        WHEN 'sara_ta' THEN 0.00
        WHEN 'neda_db' THEN 500.00
        ELSE 0.00
    END
FROM core.users;
GO


INSERT INTO core.admins (user_id, admin_identifier, access_level)
SELECT user_id, 'ADM-001', 'full' FROM core.users WHERE username = 'neda_db';
GO


INSERT INTO core.saved_accounts (user_id, card_number, bank_name)
SELECT user_id, '4111111122223333', 'Tech Credit Union' FROM core.users WHERE username = 'avesta';
INSERT INTO core.saved_accounts (user_id, card_number, bank_name)
SELECT user_id, '5500000012345678', 'Global Bank' FROM core.users WHERE username = 'arash';
INSERT INTO core.saved_accounts (user_id, card_number, bank_name)
SELECT user_id, '4222222233334444', 'University Bank' FROM core.users WHERE username = 'sara_ta';
GO


INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'Campus Lab', 'State', 'City', 'University Blvd', 'Computer Engineering Department, Main Lab', 35.7001, 51.3890 FROM core.users WHERE username = 'avesta';
INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'Home', 'State', 'City', 'Oak Street 12', 'Ring the second bell', 35.7100, 51.4000 FROM core.users WHERE username = 'arash';
INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'TA Office', 'State', 'City', 'University Blvd', 'Room 404', 35.7005, 51.3895 FROM core.users WHERE username = 'sara_ta';
INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'Dormitory', 'State', 'City', 'Student Ave', 'Block B', 35.7050, 51.3950 FROM core.users WHERE username = 'kian_ce';
GO


DECLARE @c1 INT = (SELECT user_id FROM core.users WHERE username = 'avesta');
DECLARE @c2 INT = (SELECT user_id FROM core.users WHERE username = 'arash');
DECLARE @c3 INT = (SELECT user_id FROM core.users WHERE username = 'sara_ta');

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at) VALUES
(@c1, 'wallet_charge', 'completed', 50.00, 'card',   NULL, DATEADD(DAY, -2, GETDATE())),
(@c1, 'ride_payment',  'completed', 12.50, 'wallet', NULL, DATEADD(DAY, -1, GETDATE())),
(@c2, 'payout',        'pending',   85.00, 'card',   NULL, GETDATE()),                    
(@c3, 'wallet_charge', 'failed',    20.00, 'card',   NULL, DATEADD(HOUR, -5, GETDATE())),
(@c1, 'order_payment', 'completed', 24.00, 'wallet', (SELECT coupon_id FROM core.coupons WHERE code = 'WELCOME10'), GETDATE());
GO


INSERT INTO core.coupon_usages (coupon_id, user_id, used_at, order_id, ride_id)
SELECT c.coupon_id, u.user_id, GETDATE(), 1001, NULL
FROM core.coupons c, core.users u
WHERE c.code = 'WELCOME10' AND u.username = 'avesta';
GO

DECLARE @reporter INT = (SELECT user_id FROM core.users WHERE username = 'avesta');
DECLARE @target_driver INT = (SELECT user_id FROM core.users WHERE username = 'arash');
DECLARE @admin_assigned INT = (SELECT admin_id FROM core.admins JOIN core.users u ON core.admins.user_id = u.user_id WHERE u.username = 'neda_db');

INSERT INTO core.complaints (reporter_id, target_type, target_id, title, complaint_description, complaint_status, assigned_admin_id, created_at) VALUES
(@reporter, 'driver', @target_driver, 'Late arrival', 'The driver arrived 15 minutes late to the pickup point.', 'in_review', @admin_assigned, DATEADD(DAY, -1, GETDATE())),
(@reporter, 'branch', 105, 'Cold food', 'The delivery was quick but the meal was entirely cold.', 'open', NULL, GETDATE()),
((SELECT user_id FROM core.users WHERE username = 'kian_ce'), 'user', @reporter, 'Rude passenger', 'Passenger slammed the door.', 'resolved', @admin_assigned, DATEADD(DAY, -5, GETDATE()));
GO