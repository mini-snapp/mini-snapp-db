USE mini_snapp;
GO

-- =============================================
-- Additional core.users needed for food schema seeding
-- Existing seed data only has 1 branch_owner, 1 brand_owner,
-- and 1 restaurant_staff (staff_hamed, later promoted to admin
-- via sp_assign_admin_role — excluded here to avoid role conflict).
-- This file adds the remaining users needed to reach 5 of each role.
-- =============================================

DECLARE @role_branch_owner INT = (SELECT role_id FROM core.roles WHERE role_name = 'branch_owner');
DECLARE @role_brand_owner  INT = (SELECT role_id FROM core.roles WHERE role_name = 'brand_owner');
DECLARE @role_staff        INT = (SELECT role_id FROM core.roles WHERE role_name = 'restaurant_staff');

-- ── 4 additional branch_owner users (owner_leila already covers #1) ──
INSERT INTO core.users (username, password_hash, first_name, last_name, registration_phone, email, role_id, is_blocked, deleted_at) VALUES
('owner_shirin',   '$2b$12$hashvalue0000000000000000000016', 'Shirin',   'Rahimi',   '09121234516', 'shirin.rahimi@example.com',   @role_branch_owner, 0, NULL),
('owner_babak',    '$2b$12$hashvalue0000000000000000000017', 'Babak',    'Farahani', '09121234517', 'babak.farahani@example.com',  @role_branch_owner, 0, NULL),
('owner_nasrin',   '$2b$12$hashvalue0000000000000000000018', 'Nasrin',   'Ghorbani', '09121234518', 'nasrin.ghorbani@example.com', @role_branch_owner, 0, NULL),
('owner_farshid',  '$2b$12$hashvalue0000000000000000000019', 'Farshid',  'Nikpour',  '09121234519', 'farshid.nikpour@example.com', @role_branch_owner, 0, NULL);
GO

-- ── 4 additional brand_owner users (brand_kianoosh already covers #1) ──
DECLARE @role_brand_owner INT = (SELECT role_id FROM core.roles WHERE role_name = 'brand_owner');

INSERT INTO core.users (username, password_hash, first_name, last_name, registration_phone, email, role_id, is_blocked, deleted_at) VALUES
('brandowner_ladan',    '$2b$12$hashvalue0000000000000000000020', 'Ladan',    'Soleimani', '09121234520', 'ladan.soleimani@example.com',  @role_brand_owner, 0, NULL),
('brandowner_siavash',  '$2b$12$hashvalue0000000000000000000021', 'Siavash',  'Kazemi',    '09121234521', 'siavash.kazemi@example.com',   @role_brand_owner, 0, NULL),
('brandowner_elham',    '$2b$12$hashvalue0000000000000000000022', 'Elham',    'Yousefi',   '09121234522', 'elham.yousefi@example.com',    @role_brand_owner, 0, NULL),
('brandowner_rouzbeh',  '$2b$12$hashvalue0000000000000000000023', 'Rouzbeh',  'Amini',     '09121234523', 'rouzbeh.amini@example.com',    @role_brand_owner, 0, NULL);
GO

-- ── 5 fresh restaurant_staff users ──
-- staff_hamed intentionally excluded: he is promoted to admin later
-- in the seed script via sp_assign_admin_role, which reassigns his
-- role_id. Reusing him here would create a user simultaneously
-- tagged as admin and referenced as food.restaurant_staff.
DECLARE @role_staff INT = (SELECT role_id FROM core.roles WHERE role_name = 'restaurant_staff');

INSERT INTO core.users (username, password_hash, first_name, last_name, registration_phone, email, role_id, is_blocked, deleted_at) VALUES
('staff_negar',  '$2b$12$hashvalue0000000000000000000024', 'Negar',  'Sharifi',  '09121234524', 'negar.sharifi@example.com',  @role_staff, 0, NULL),
('staff_pouya',  '$2b$12$hashvalue0000000000000000000025', 'Pouya',  'Kamangir', '09121234525', 'pouya.kamangir@example.com', @role_staff, 0, NULL),
('staff_mahsa',  '$2b$12$hashvalue0000000000000000000026', 'Mahsa',  'Zareii',   '09121234526', 'mahsa.zareii@example.com',   @role_staff, 0, NULL),
('staff_omid',   '$2b$12$hashvalue0000000000000000000027', 'Omid',   'Panahi',   '09121234527', 'omid.panahi@example.com',    @role_staff, 0, NULL),
('staff_shadi',  '$2b$12$hashvalue0000000000000000000028', 'Shadi',  'Ostovar',  '09121234528', 'shadi.ostovar@example.com',  @role_staff, 0, NULL);
GO