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

DECLARE @r_cust  INT = (SELECT role_id FROM core.roles WHERE role_name = 'customer');
DECLARE @r_driv  INT = (SELECT role_id FROM core.roles WHERE role_name = 'driver');
DECLARE @r_staff INT = (SELECT role_id FROM core.roles WHERE role_name = 'restaurant_staff');
DECLARE @r_bown  INT = (SELECT role_id FROM core.roles WHERE role_name = 'branch_owner');
DECLARE @r_brown INT = (SELECT role_id FROM core.roles WHERE role_name = 'brand_owner');
DECLARE @r_admn  INT = (SELECT role_id FROM core.roles WHERE role_name = 'admin');

INSERT INTO core.users (username, password_hash, first_name, last_name, registration_phone, email, role_id, is_blocked, deleted_at) VALUES
-- Core & Taxi primary users
('avesta',             '$2b$12$dummyhash01', 'Avesta',   NULL,       '09120100001', 'avesta@local.dev',            @r_cust,  0, NULL),
('arash',              '$2b$12$dummyhash02', 'Arash',    'Rostami',  '09120100002', 'arash@local.dev',             @r_driv,  0, NULL),
('kian_rad',           '$2b$12$dummyhash03', 'Kian',     'Rad',      '09120100003', 'kian.rad@local.dev',          @r_cust,  0, NULL),
('sara_moradi',        '$2b$12$dummyhash04', 'Sara',     'Moradi',   '09120100004', 'sara.moradi@local.dev',       @r_cust,  1, NULL),
('neda_db',            '$2b$12$dummyhash05', 'Neda',     'Karimi',   '09120100005', 'neda.db@local.dev',           @r_admn,  0, NULL),
('deleted_u',          '$2b$12$dummyhash06', 'Farhad',   'Ghasemi',  '09120100006', NULL,                          @r_cust,  0, DATEADD(DAY, -10, GETDATE())),
-- Food brand owners
('brand_kianoosh',     '$2b$12$dummyhash07', 'Kianoosh', 'Irani',    '09120100007', 'kianoosh@brands.local',       @r_brown, 0, NULL),
('brandowner_ladan',   '$2b$12$dummyhash08', 'Ladan',    'Shams',    '09120100008', 'ladan@brands.local',          @r_brown, 0, NULL),
('brandowner_siavash', '$2b$12$dummyhash09', 'Siavash',  'Tehrani',  '09120100009', 'siavash@brands.local',        @r_brown, 0, NULL),
('brandowner_elham',   '$2b$12$dummyhash10', 'Elham',    'Pouri',    '09120100010', 'elham@brands.local',          @r_brown, 0, NULL),
('brandowner_rouzbeh', '$2b$12$dummyhash11', 'Rouzbeh',  'Parsa',    '09120100011', 'rouzbeh@brands.local',        @r_brown, 0, NULL),
-- Food branch owners
('owner_leila',        '$2b$12$dummyhash12', 'Leila',    'Afshar',   '09120100012', 'leila@branches.local',        @r_bown,  0, NULL),
('owner_shirin',       '$2b$12$dummyhash13', 'Shirin',   'Kamali',   '09120100013', 'shirin@branches.local',       @r_bown,  0, NULL),
('owner_babak',        '$2b$12$dummyhash14', 'Babak',    'Nouri',    '09120100014', 'babak@branches.local',        @r_bown,  0, NULL),
('owner_nasrin',       '$2b$12$dummyhash15', 'Nasrin',   'Zand',     '09120100015', 'nasrin@branches.local',       @r_bown,  0, NULL),
('owner_farshid',      '$2b$12$dummyhash16', 'Farshid',  'Nik',      '09120100016', 'farshid@branches.local',      @r_bown,  0, NULL),
-- Restaurant staff
('staff_negar',        '$2b$12$dummyhash17', 'Negar',    'Sadeghi',  '09120100017', 'negar@staff.local',           @r_staff, 0, NULL),
('staff_pouya',        '$2b$12$dummyhash18', 'Pouya',    'Azimi',    '09120100018', 'pouya@staff.local',           @r_staff, 0, NULL),
('staff_mahsa',        '$2b$12$dummyhash19', 'Mahsa',    'Alavi',    '09120100019', 'mahsa@staff.local',           @r_staff, 0, NULL),
('staff_omid',         '$2b$12$dummyhash20', 'Omid',     'Fallah',   '09120100020', 'omid@staff.local',            @r_staff, 0, NULL),
('staff_shadi',        '$2b$12$dummyhash21', 'Shadi',    'Riahi',    '09120100021', 'shadi@staff.local',           @r_staff, 0, NULL),
-- Food customers & secondary admin
('sara_ahmadi',        '$2b$12$dummyhash22', 'Sara',     'Ahmadi',   '09120100022', 'sara.ahmadi@local.dev',       @r_cust,  0, NULL),
('reza_karimi',        '$2b$12$dummyhash23', 'Reza',     'Karimi',   '09120100023', 'reza.karimi@local.dev',       @r_cust,  0, NULL),
('mina_hosseini',      '$2b$12$dummyhash24', 'Mina',     'Hosseini', '09120100024', 'mina.hosseini@local.dev',     @r_cust,  1, NULL),
('behnam_moshiri',     '$2b$12$dummyhash25', 'Behnam',   'Moshiri',  '09120100025', 'behnam.moshiri@local.dev',    @r_cust,  0, NULL),
('newbie_taha',        '$2b$12$dummyhash26', 'Taha',     'Ebrahimi', '09120100026', 'taha@local.dev',              @r_cust,  0, NULL),
('newbie_parisa',      '$2b$12$dummyhash27', 'Parisa',   'Kiani',    '09120100027', 'parisa@local.dev',            @r_cust,  0, NULL),
('admin_yasaman',      '$2b$12$dummyhash28', 'Yasaman',  'Bahrami',  '09120100028', 'yasaman.admin@local.dev',     @r_admn,  0, NULL);
GO

INSERT INTO core.user_wallets (user_id, balance)
SELECT user_id, 
    CASE username
        WHEN 'avesta'         THEN 150.00
        WHEN 'arash'          THEN 120.00
        WHEN 'kian_rad'       THEN 45.00
        WHEN 'sara_moradi'    THEN 0.00
        WHEN 'neda_db'        THEN 500.00
        WHEN 'admin_yasaman'  THEN 500.00
        WHEN 'sara_ahmadi'    THEN 250.00
        WHEN 'reza_karimi'    THEN 150.00
        WHEN 'mina_hosseini'  THEN 200.00
        WHEN 'behnam_moshiri' THEN 300.00
        WHEN 'deleted_u'      THEN 0.00
        ELSE 50.00
    END
FROM core.users;
GO

INSERT INTO core.admins (user_id, admin_identifier, access_level)
SELECT user_id, 'ADM-001', 'full' FROM core.users WHERE username = 'neda_db';

INSERT INTO core.admins (user_id, admin_identifier, access_level)
SELECT user_id, 'ADM-002', 'full' FROM core.users WHERE username = 'admin_yasaman';
GO

INSERT INTO core.saved_accounts (user_id, card_number, bank_name)
SELECT user_id, '4111111122223333', 'Tech Credit Union' FROM core.users WHERE username = 'avesta';
INSERT INTO core.saved_accounts (user_id, card_number, bank_name)
SELECT user_id, '5500000012345678', 'Global Bank' FROM core.users WHERE username = 'arash';
INSERT INTO core.saved_accounts (user_id, card_number, bank_name)
SELECT user_id, '4222222233334444', 'City Bank' FROM core.users WHERE username = 'sara_ahmadi';
GO

INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'Office', 'Tehran', 'Tehran', 'Valiasr Ave', 'Main Engineering Office, Floor 3', 35.70010000, 51.38900000 FROM core.users WHERE username = 'avesta';
INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'Home', 'Tehran', 'Tehran', 'Jordan Blvd, No. 18', 'Unit 4', 35.71200000, 51.40200000 FROM core.users WHERE username = 'avesta';
INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'Home', 'Tehran', 'Tehran', 'Karimkhan St, No. 12', 'Ring the second bell', 35.71000000, 51.40000000 FROM core.users WHERE username = 'arash';
INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'Work', 'Tehran', 'Tehran', 'Enghelab Ave', 'Suite 404', 35.70050000, 51.38950000 FROM core.users WHERE username = 'sara_moradi';
INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'Home', 'Tehran', 'Tehran', 'Keshavarz Blvd', 'Block B', 35.70500000, 51.39500000 FROM core.users WHERE username = 'kian_rad';
INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'Home', 'Tehran', 'Tehran', 'Yousefabad St, No. 42', 'Floor 2', 35.72200000, 51.40800000 FROM core.users WHERE username = 'sara_ahmadi';
INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'Home', 'Alborz', 'Karaj', 'Gohar Dasht, 5th St', 'Building 10', 35.83800000, 50.99400000 FROM core.users WHERE username = 'reza_karimi';
INSERT INTO core.addresses (user_id, address_name, province, city, street, description_text, latitude, longitude)
SELECT user_id, 'Home', 'Tehran', 'Tehran', 'Fatemi Sq, No. 9', 'Unit 1', 35.71600000, 51.40400000 FROM core.users WHERE username = 'mina_hosseini';
GO

DECLARE @c1 INT = (SELECT user_id FROM core.users WHERE username = 'avesta');
DECLARE @c2 INT = (SELECT user_id FROM core.users WHERE username = 'arash');
DECLARE @c3 INT = (SELECT user_id FROM core.users WHERE username = 'sara_moradi');

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at) VALUES
(@c1, 'wallet_charge', 'completed', 50.00, 'card',   NULL, DATEADD(DAY, -2, GETDATE())),
(@c1, 'ride_payment',  'completed', 12.50, 'wallet', NULL, DATEADD(DAY, -1, GETDATE())),
(@c2, 'payout',        'pending',   85.00, 'card',   NULL, GETDATE()),                    
(@c3, 'wallet_charge', 'failed',    20.00, 'card',   NULL, DATEADD(HOUR, -5, GETDATE()));
GO

DECLARE @reporter INT = (SELECT user_id FROM core.users WHERE username = 'avesta');
DECLARE @target_driver INT = (SELECT user_id FROM core.users WHERE username = 'arash');
DECLARE @admin_assigned INT = (SELECT admin_id FROM core.admins JOIN core.users u ON core.admins.user_id = u.user_id WHERE u.username = 'neda_db');

INSERT INTO core.complaints (reporter_id, target_type, target_id, title, complaint_description, complaint_status, assigned_admin_id, created_at) VALUES
(@reporter, 'driver', @target_driver, 'Late arrival', 'The driver arrived 15 minutes late to the pickup point.', 'in_review', @admin_assigned, DATEADD(DAY, -1, GETDATE())),
((SELECT user_id FROM core.users WHERE username = 'kian_rad'), 'user', @reporter, 'Rude passenger', 'Passenger slammed the door.', 'resolved', @admin_assigned, DATEADD(DAY, -5, GETDATE()));
GO
