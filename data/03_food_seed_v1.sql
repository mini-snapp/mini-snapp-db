USE mini_snapp;
GO

-- =============================================
-- SECTION 0: Clear existing data before re-seeding
-- Order matters: children before parents (reverse FK dependency)
-- =============================================

DELETE FROM food.food_logs;
DELETE FROM food.cart_items;
DELETE FROM food.menu_discounts;
DELETE FROM food.menu_items;
DELETE FROM food.food_ingredients;
DELETE FROM food.foods;
DELETE FROM food.work_schedules;
DELETE FROM food.business_phones;
DELETE FROM food.restaurant_staff;
DELETE FROM food.branch_owners;
DELETE FROM food.branch_wallets;
DELETE FROM food.branches;
DELETE FROM food.brand_owners;
DELETE FROM food.brands;
DELETE FROM food.customer_stats;
GO

DBCC CHECKIDENT ('food.food_logs', RESEED, 0);
DBCC CHECKIDENT ('food.cart_items', RESEED, 0);
DBCC CHECKIDENT ('food.menu_discounts', RESEED, 0);
DBCC CHECKIDENT ('food.menu_items', RESEED, 0);
DBCC CHECKIDENT ('food.food_ingredients', RESEED, 0);
DBCC CHECKIDENT ('food.foods', RESEED, 0);
DBCC CHECKIDENT ('food.work_schedules', RESEED, 0);
DBCC CHECKIDENT ('food.business_phones', RESEED, 0);
DBCC CHECKIDENT ('food.restaurant_staff', RESEED, 0);
DBCC CHECKIDENT ('food.branch_owners', RESEED, 0);
DBCC CHECKIDENT ('food.branch_wallets', RESEED, 0);
DBCC CHECKIDENT ('food.branches', RESEED, 0);
DBCC CHECKIDENT ('food.brand_owners', RESEED, 0);
DBCC CHECKIDENT ('food.brands', RESEED, 0);
DBCC CHECKIDENT ('food.customer_stats', RESEED, 0);
GO

-- =============================================
-- PART 1: Brands + brand_owners (M:N demonstrated:
-- brand_kianoosh co-owns Sib Sabz Vegan alongside its
-- primary owner, brandowner_rouzbeh)
-- =============================================

DECLARE @u_brand_kianoosh   INT = (SELECT user_id FROM core.users WHERE username = 'brand_kianoosh');
DECLARE @u_brandowner_ladan INT = (SELECT user_id FROM core.users WHERE username = 'brandowner_ladan');
DECLARE @u_brandowner_siavash INT = (SELECT user_id FROM core.users WHERE username = 'brandowner_siavash');
DECLARE @u_brandowner_elham INT = (SELECT user_id FROM core.users WHERE username = 'brandowner_elham');
DECLARE @u_brandowner_rouzbeh INT = (SELECT user_id FROM core.users WHERE username = 'brandowner_rouzbeh');

DECLARE @u_owner_leila   INT = (SELECT user_id FROM core.users WHERE username = 'owner_leila');
DECLARE @u_owner_shirin  INT = (SELECT user_id FROM core.users WHERE username = 'owner_shirin');
DECLARE @u_owner_babak   INT = (SELECT user_id FROM core.users WHERE username = 'owner_babak');
DECLARE @u_owner_nasrin  INT = (SELECT user_id FROM core.users WHERE username = 'owner_nasrin');
DECLARE @u_owner_farshid INT = (SELECT user_id FROM core.users WHERE username = 'owner_farshid');

DECLARE @u_staff_negar  INT = (SELECT user_id FROM core.users WHERE username = 'staff_negar');
DECLARE @u_staff_pouya  INT = (SELECT user_id FROM core.users WHERE username = 'staff_pouya');
DECLARE @u_staff_mahsa  INT = (SELECT user_id FROM core.users WHERE username = 'staff_mahsa');
DECLARE @u_staff_omid   INT = (SELECT user_id FROM core.users WHERE username = 'staff_omid');
DECLARE @u_staff_shadi  INT = (SELECT user_id FROM core.users WHERE username = 'staff_shadi');

DECLARE @u_sara    INT = (SELECT user_id FROM core.users WHERE username = 'sara_ahmadi');
DECLARE @u_reza    INT = (SELECT user_id FROM core.users WHERE username = 'reza_karimi');
DECLARE @u_mina    INT = (SELECT user_id FROM core.users WHERE username = 'mina_hosseini');
DECLARE @u_behnam  INT = (SELECT user_id FROM core.users WHERE username = 'behnam_moshiri');
DECLARE @u_taha    INT = (SELECT user_id FROM core.users WHERE username = 'newbie_taha');
DECLARE @u_parisa  INT = (SELECT user_id FROM core.users WHERE username = 'newbie_parisa');
DECLARE @u_admin   INT = (SELECT user_id FROM core.users WHERE username = 'admin_yasaman');

-- Added cart_items users:
DECLARE @u_avesta  INT = (SELECT user_id FROM core.users WHERE username = 'avesta');
DECLARE @u_arash   INT = (SELECT user_id FROM core.users WHERE username = 'arash');
DECLARE @u_neda_db INT = (SELECT user_id FROM core.users WHERE username = 'neda_db');

PRINT 'After Part 1: ' + ISNULL(CAST(@u_sara AS VARCHAR), 'NULL');
-- ... rest of Part 2, 3, 4 ...
PRINT 'Before Part 5: ' + ISNULL(CAST(@u_sara AS VARCHAR), 'NULL');
-- ── brands (5 rows) ──
INSERT INTO food.brands (name, central_support_phone, commission_rate, average_rating, rating_count, email)
VALUES ('Zeytoon Grill', '02188990011', 0.1500, 4.30, 210, 'support@zeytoongrill.com');
DECLARE @brand_zeytoon INT = SCOPE_IDENTITY();

INSERT INTO food.brands (name, central_support_phone, commission_rate, average_rating, rating_count, email)
VALUES ('Baradaran Pizza', '02188990022', 0.1800, 4.10, 340, 'support@baradaranpizza.com');
DECLARE @brand_baradaran INT = SCOPE_IDENTITY();

INSERT INTO food.brands (name, central_support_phone, commission_rate, average_rating, rating_count, email)
VALUES ('Shab Cafe', '02188990033', NULL, 4.60, 95, 'hello@shabcafe.com');  -- edge: commission_rate not yet negotiated
DECLARE @brand_shabcafe INT = SCOPE_IDENTITY();

INSERT INTO food.brands (name, central_support_phone, commission_rate, average_rating, rating_count, email)
VALUES ('Noon-o-Kabab', '02188990044', 0.1600, 3.90, 480, 'info@noonokabab.com');
DECLARE @brand_noonokabab INT = SCOPE_IDENTITY();

INSERT INTO food.brands (name, central_support_phone, commission_rate, average_rating, rating_count, email)
VALUES ('Sib Sabz Vegan', '02188990055', 0.1200, 4.75, 60, 'contact@sibsabzvegan.com');
DECLARE @brand_sibsabz INT = SCOPE_IDENTITY();

-- ── brand_owners (6 rows: 5 primary + 1 co-owner, M:N) ──
INSERT INTO food.brand_owners (user_id, brand_id) VALUES
(@u_brand_kianoosh,     @brand_zeytoon),
(@u_brandowner_ladan,   @brand_baradaran),
(@u_brandowner_siavash, @brand_shabcafe),
(@u_brandowner_elham,   @brand_noonokabab),
(@u_brandowner_rouzbeh, @brand_sibsabz),
(@u_brand_kianoosh,     @brand_sibsabz);  -- edge: co-ownership, demonstrates M:N

-- =============================================
-- PART 2: Branches
-- branch_wallets rows are NOT inserted manually here —
-- trg_branches_after_insert_create_wallet creates them
-- automatically on each INSERT below.
-- =============================================

INSERT INTO food.branches (brand_id, rating, province, city, street, latitude, longitude, email, food_type, max_delivery_distance, is_active, rating_count)
VALUES (@brand_zeytoon, 4.40, 'Tehran', 'Tehran', 'Valiasr St, No. 130', 35.718500, 51.409500, 'valiasr@zeytoongrill.com', 'Kabab', 8.00, 1, 140);
DECLARE @branch1 INT = SCOPE_IDENTITY();  -- Zeytoon Grill, Valiasr, Tehran

INSERT INTO food.branches (brand_id, rating, province, city, street, latitude, longitude, email, food_type, max_delivery_distance, is_active, rating_count)
VALUES (@brand_zeytoon, 4.10, 'Alborz', 'Karaj', 'Azadi Blvd, No. 20', 35.833000, 50.992000, NULL, 'Kabab', 6.50, 1, 70);  -- edge: no branch email on file
DECLARE @branch2 INT = SCOPE_IDENTITY();  -- Zeytoon Grill, Karaj

INSERT INTO food.branches (brand_id, rating, province, city, street, latitude, longitude, email, food_type, max_delivery_distance, is_active, rating_count)
VALUES (@brand_baradaran, 4.00, 'Tehran', 'Tehran', 'Enghelab St, No. 90', 35.700500, 51.388000, 'enghelab@baradaranpizza.com', 'Pizza', 10.00, 1, 210);
DECLARE @branch3 INT = SCOPE_IDENTITY();  -- Baradaran Pizza, Enghelab, Tehran

INSERT INTO food.branches (brand_id, rating, province, city, street, latitude, longitude, email, food_type, max_delivery_distance, is_active, rating_count)
VALUES (@brand_baradaran, 3.95, 'Isfahan', 'Isfahan', 'Chahar Bagh St, No. 210', 32.655000, 51.668000, 'isfahan@baradaranpizza.com', 'Pizza', 9.00, 1, 130);
DECLARE @branch4 INT = SCOPE_IDENTITY();  -- Baradaran Pizza, Isfahan

INSERT INTO food.branches (brand_id, rating, province, city, street, latitude, longitude, email, food_type, max_delivery_distance, is_active, rating_count)
VALUES (@brand_shabcafe, 4.65, 'Tehran', 'Tehran', 'Niavaran St, No. 20', 35.809000, 51.483000, 'niavaran@shabcafe.com', 'Cafe', 5.00, 1, 55);
DECLARE @branch5 INT = SCOPE_IDENTITY();  -- Shab Cafe, Niavaran, Tehran

INSERT INTO food.branches (brand_id, rating, province, city, street, latitude, longitude, email, food_type, max_delivery_distance, is_active, rating_count)
VALUES (@brand_noonokabab, 3.85, 'Fars', 'Shiraz', 'Zand Blvd, No. 95', 29.610500, 52.531000, 'shiraz@noonokabab.com', 'Kabab', 12.00, 1, 260);
DECLARE @branch6 INT = SCOPE_IDENTITY();  -- Noon-o-Kabab, Shiraz

INSERT INTO food.branches (brand_id, rating, province, city, street, latitude, longitude, email, food_type, max_delivery_distance, is_active, rating_count)
VALUES (@brand_sibsabz, 4.80, 'Tehran', 'Tehran', 'Sohrevardi St, No. 50', 35.729000, 51.425000, 'tehran@sibsabzvegan.com', 'Vegan', 7.00, 1, 40);
DECLARE @branch7 INT = SCOPE_IDENTITY();  -- Sib Sabz Vegan, Tehran

INSERT INTO food.branches (brand_id, rating, province, city, street, latitude, longitude, email, food_type, max_delivery_distance, is_active, rating_count)
VALUES (@brand_sibsabz, 4.70, 'Qazvin', 'Qazvin', 'Imam Khomeini Blvd, No. 65', 36.289500, 50.004000, 'qazvin@sibsabzvegan.com', 'Vegan', 6.00, 0, 15);  -- edge: temporarily inactive branch
DECLARE @branch8 INT = SCOPE_IDENTITY();  -- Sib Sabz Vegan, Qazvin

-- ── branch_owners (8 rows: some owners hold branches
-- across different brands, demonstrating M:N) ──
INSERT INTO food.branch_owners (user_id, branch_id) VALUES
(@u_owner_leila,   @branch1),
(@u_owner_shirin,  @branch2),
(@u_owner_babak,   @branch3),
(@u_owner_nasrin,  @branch4),
(@u_owner_farshid, @branch5),
(@u_owner_leila,   @branch6),  -- edge: same owner across two different brands
(@u_owner_shirin,  @branch7),
(@u_owner_babak,   @branch8);

-- ── restaurant_staff (5 rows) ──
INSERT INTO food.restaurant_staff (user_id, branch_id) VALUES
(@u_staff_negar, @branch1),
(@u_staff_pouya, @branch3),
(@u_staff_mahsa, @branch5),
(@u_staff_omid,  @branch6),
(@u_staff_shadi, @branch7);

-- ── business_phones (10 rows, branch1 has two — support + delivery) ──
INSERT INTO food.business_phones (branch_id, phone_number, phone_type) VALUES
(@branch1, '02177001001', 'support'),
(@branch1, '02177001002', 'delivery'),   -- edge: multivalued attribute, second phone for same branch
(@branch2, '02677002001', 'support'),
(@branch3, '02177003001', 'support'),
(@branch4, '03177004001', 'support'),
(@branch5, '02177005001', 'support'),
(@branch6, '07177006001', 'support'),
(@branch6, '07177006002', 'delivery'),
(@branch7, '02177007001', 'support'),
(@branch8, '02877008001', 'support');

-- ── work_schedules (56 rows: full week per branch,
-- Friday closed for all — Iran weekend convention) ──
INSERT INTO food.work_schedules (branch_id, day_of_week, start_time, end_time, is_closed)
SELECT b.branch_id, d.day_of_week, '09:00', '23:00',
       CASE WHEN d.day_of_week = 5 THEN 1 ELSE 0 END
FROM food.branches b
CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6)) AS d(day_of_week)
WHERE b.branch_id IN (@branch1,@branch2,@branch3,@branch4,@branch5,@branch6,@branch7,@branch8);

-- =============================================
-- PART 3: Foods + food_ingredients
-- =============================================

INSERT INTO food.foods (brand_id, name, category, average_rating, rating_count) VALUES (@brand_zeytoon, 'Zeytoon Special Kabab', 'Kabab', 4.50, 180);
DECLARE @food_kabab1 INT = SCOPE_IDENTITY();
INSERT INTO food.foods (brand_id, name, category, average_rating, rating_count) VALUES (@brand_zeytoon, 'Grilled Chicken Skewer', 'Kabab', 4.20, 150);
DECLARE @food_kabab2 INT = SCOPE_IDENTITY();
INSERT INTO food.foods (brand_id, name, category, average_rating, rating_count) VALUES (@brand_baradaran, 'Margherita Pizza', 'Pizza', 4.30, 300);
DECLARE @food_pizza1 INT = SCOPE_IDENTITY();
INSERT INTO food.foods (brand_id, name, category, average_rating, rating_count) VALUES (@brand_baradaran, 'Pepperoni Pizza', 'Pizza', 4.00, 260);
DECLARE @food_pizza2 INT = SCOPE_IDENTITY();
INSERT INTO food.foods (brand_id, name, category, average_rating, rating_count) VALUES (@brand_shabcafe, 'Iced Latte', 'Beverage', 4.60, 90);
DECLARE @food_bev1 INT = SCOPE_IDENTITY();
INSERT INTO food.foods (brand_id, name, category, average_rating, rating_count) VALUES (@brand_shabcafe, 'Cheesecake', 'Dessert', 4.70, 75);
DECLARE @food_dessert1 INT = SCOPE_IDENTITY();
INSERT INTO food.foods (brand_id, name, category, average_rating, rating_count) VALUES (@brand_noonokabab, 'Koobideh Kabab', 'Kabab', 3.90, 400);
DECLARE @food_kabab3 INT = SCOPE_IDENTITY();
INSERT INTO food.foods (brand_id, name, category, average_rating, rating_count) VALUES (@brand_noonokabab, 'Joojeh Kabab', 'Kabab', 4.10, 350);
DECLARE @food_kabab4 INT = SCOPE_IDENTITY();
INSERT INTO food.foods (brand_id, name, category, average_rating, rating_count) VALUES (@brand_sibsabz, 'Vegan Burger', 'Vegan', 4.80, 50);
DECLARE @food_vegan1 INT = SCOPE_IDENTITY();
INSERT INTO food.foods (brand_id, name, category, average_rating, rating_count) VALUES (@brand_sibsabz, 'Lentil Soup', 'Vegan', 4.65, 45);
DECLARE @food_vegan2 INT = SCOPE_IDENTITY();

-- ── food_ingredients (multivalued composite attribute, 2-3 per food) ──
INSERT INTO food.food_ingredients (food_id, ingredient_name, amount, unit) VALUES
(@food_kabab1, 'Lamb meat', 200.00, 'g'),
(@food_kabab1, 'Grilled tomato', 1.00, 'unit'),
(@food_kabab2, 'Chicken breast', 220.00, 'g'),
(@food_kabab2, 'Saffron', 0.50, 'g'),
(@food_pizza1, 'Mozzarella cheese', 150.00, 'g'),
(@food_pizza1, 'Tomato sauce', 100.00, 'ml'),
(@food_pizza1, 'Basil', 5.00, 'g'),
(@food_pizza2, 'Pepperoni', 120.00, 'g'),
(@food_pizza2, 'Mozzarella cheese', 150.00, 'g'),
(@food_bev1, 'Espresso shot', 30.00, 'ml'),
(@food_bev1, 'Milk', 200.00, 'ml'),
(@food_dessert1, 'Cream cheese', 180.00, 'g'),
(@food_dessert1, 'Biscuit base', 100.00, 'g'),
(@food_kabab3, 'Ground beef', 250.00, 'g'),
(@food_kabab3, 'Grilled tomato', 1.00, 'unit'),
(@food_kabab4, 'Chicken thigh', 230.00, 'g'),
(@food_kabab4, 'Saffron', 0.50, 'g'),
(@food_vegan1, 'Chickpea patty', 180.00, 'g'),
(@food_vegan1, 'Vegan bun', 1.00, 'unit'),
(@food_vegan2, 'Red lentils', 150.00, 'g'),
(@food_vegan2, 'Vegetable broth', 300.00, 'ml');

-- =============================================
-- PART 4: Menu items (foods only placed onto branches
-- of their own matching brand) + menu_discounts
-- =============================================

INSERT INTO food.menu_items (branch_id, food_id, price, availability_status, average_rating, rating_count, estimated_prep_time, available_from, available_to)
VALUES (@branch1, @food_kabab1, 320000.00, 1, 4.50, 90, 25, '11:00', '22:30');
DECLARE @mi_b1_kabab1 INT = SCOPE_IDENTITY();

INSERT INTO food.menu_items (branch_id, food_id, price, availability_status, average_rating, rating_count, estimated_prep_time, available_from, available_to)
VALUES (@branch1, @food_kabab2, 280000.00, 1, 4.20, 60, 20, '11:00', '22:30');
DECLARE @mi_b1_kabab2 INT = SCOPE_IDENTITY();

INSERT INTO food.menu_items (branch_id, food_id, price, availability_status, average_rating, rating_count, estimated_prep_time, available_from, available_to)
VALUES (@branch2, @food_kabab1, 300000.00, 1, 4.30, 40, 25, '11:00', '22:00');
DECLARE @mi_b2_kabab1 INT = SCOPE_IDENTITY();

INSERT INTO food.menu_items (branch_id, food_id, price, availability_status, average_rating, rating_count, estimated_prep_time, available_from, available_to)
VALUES (@branch2, @food_kabab2, 265000.00, 1, 4.00, 30, 20, '11:00', '22:00');

INSERT INTO food.menu_items (branch_id, food_id, price, availability_status, average_rating, rating_count, estimated_prep_time, available_from, available_to)
VALUES (@branch3, @food_pizza1, 210000.00, 1, 4.40, 120, 18, '12:00', '23:30');
DECLARE @mi_b3_pizza1 INT = SCOPE_IDENTITY();

INSERT INTO food.menu_items (branch_id, food_id, price, availability_status, average_rating, rating_count, estimated_prep_time, available_from, available_to)
VALUES (@branch3, @food_pizza2, 230000.00, 1, 4.10, 100, 18, '12:00', '23:30');
DECLARE @mi_b3_pizza2 INT = SCOPE_IDENTITY();

INSERT INTO food.menu_items (branch_id, food_id, price, availability_status, average_rating, rating_count, estimated_prep_time, available_from, available_to)
VALUES (@branch4, @food_pizza1, 205000.00, 1, 4.05, 70, 18, '12:00', '23:00');

INSERT INTO food.menu_items (branch_id, food_id, price, availability_status, average_rating, rating_count, estimated_prep_time, available_from, available_to)
VALUES (@branch4, @food_pizza2, 225000.00, 0, 3.80, 55, 18, '12:00', '23:00');  -- edge: currently unavailable
DECLARE @mi_b4_pizza2 INT = SCOPE_IDENTITY();

INSERT INTO food.menu_items (branch_id, food_id, price, availability_status, average_rating, rating_count, estimated_prep_time, available_from, available_to)
VALUES (@branch5, @food_bev1, 95000.00, 1, 4.60, 85, 8, '08:00', '22:00');
DECLARE @mi_b5_bev1 INT = SCOPE_IDENTITY();

INSERT INTO food.menu_items (branch_id, food_id, price, availability_status, average_rating, rating_count, estimated_prep_time, available_from, available_to)
VALUES (@branch5, @food_dessert1, 130000.00, 1, 4.70, 70, 10, '08:00', '22:00');
DECLARE @mi_b5_dessert1 INT = SCOPE_IDENTITY();

INSERT INTO food.menu_items (branch_id, food_id, price, availability_status, average_rating, rating_count, estimated_prep_time, available_from, available_to)
VALUES (@branch6, @food_kabab3, 250000.00, 1, 3.90, 210, 22, '11:30', '23:00');

INSERT INTO food.menu_items (branch_id, food_id, price, availability_status, average_rating, rating_count, estimated_prep_time, available_from, available_to)
VALUES (@branch6, @food_kabab4, 260000.00, 1, 4.10, 190, 22, '11:30', '23:00');

INSERT INTO food.menu_items (branch_id, food_id, price, availability_status, average_rating, rating_count, estimated_prep_time, available_from, available_to)
VALUES (@branch7, @food_vegan1, 175000.00, 1, 4.80, 35, 15, '11:00', '22:00');
DECLARE @mi_b7_vegan1 INT = SCOPE_IDENTITY();

INSERT INTO food.menu_items (branch_id, food_id, price, availability_status, average_rating, rating_count, estimated_prep_time, available_from, available_to)
VALUES (@branch7, @food_vegan2, 110000.00, 1, 4.60, 25, 12, '11:00', '22:00');

INSERT INTO food.menu_items (branch_id, food_id, price, availability_status, average_rating, rating_count, estimated_prep_time, available_from, available_to)
VALUES (@branch8, @food_vegan1, 170000.00, 1, 4.75, 10, 15, '11:00', '21:00');

INSERT INTO food.menu_items (branch_id, food_id, price, availability_status, average_rating, rating_count, estimated_prep_time, available_from, available_to)
VALUES (@branch8, @food_vegan2, 108000.00, 1, 4.55, 8, 12, '11:00', '21:00');

-- ── menu_discounts (4 rows, one per item — avoids any
-- overlap conflict with trg_menu_discounts_validate) ──
INSERT INTO food.menu_discounts (menu_item_id, percentage, amount, start_at, end_at, is_active)
VALUES (@mi_b1_kabab1, 15.00, NULL, DATEADD(DAY, -2, GETDATE()), DATEADD(DAY, 5, GETDATE()), 1);  -- currently active

INSERT INTO food.menu_discounts (menu_item_id, percentage, amount, start_at, end_at, is_active)
VALUES (@mi_b3_pizza1, NULL, 30000.00, DATEADD(DAY, -1, GETDATE()), DATEADD(DAY, 3, GETDATE()), 1);  -- currently active, flat amount

INSERT INTO food.menu_discounts (menu_item_id, percentage, amount, start_at, end_at, is_active)
VALUES (@mi_b1_kabab2, 20.00, NULL, DATEADD(DAY, -30, GETDATE()), DATEADD(DAY, -10, GETDATE()), 1);  -- edge: stale, dates already passed but never deactivated

INSERT INTO food.menu_discounts (menu_item_id, percentage, amount, start_at, end_at, is_active)
VALUES (@mi_b4_pizza2, 10.00, NULL, DATEADD(DAY, -5, GETDATE()), DATEADD(DAY, 10, GETDATE()), 0);  -- edge: manually deactivated

-- =============================================
-- PART 5: cart_items (each user's cart limited to a
-- single branch, matching the sp_add_to_cart business rule,
-- and only referencing available menu_items per
-- trg_cart_items_validate)
-- =============================================

INSERT INTO food.cart_items (user_id, branch_id, menu_item_id, quantity) VALUES
(@u_avesta,   @branch1, @mi_b1_kabab1,  2),
(@u_avesta,   @branch1, @mi_b1_kabab2,  1),
(@u_arash,   @branch2, @mi_b2_kabab1,  1),
(@u_neda_db, @branch5, @mi_b5_bev1,    3),
(@u_neda_db, @branch5, @mi_b5_dessert1,1),
(@u_arash,   @branch7, @mi_b7_vegan1,  1),
(@u_arash, @branch3, @mi_b3_pizza1,  1),
(@u_avesta, @branch3, @mi_b3_pizza2,  1);

-- =============================================
-- PART 6: customer_stats (1:1 with users; old_account99
-- intentionally excluded — soft-deleted, no active stats)
-- =============================================

INSERT INTO food.customer_stats (user_id, score, rank) VALUES
(@u_sara,   860, 'gold'),
(@u_reza,   120, 'bronze'),
(@u_mina,   40,  'bronze'),   -- edge: blocked user, low activity
(@u_behnam, 1450,'platinum')

-- =============================================
-- PART 7: branch_wallets — balances updated after
-- trigger-created rows (NOT manually inserted)
-- =============================================

UPDATE food.branch_wallets SET balance = 4200000.00 WHERE branch_id = @branch1;
UPDATE food.branch_wallets SET balance = 1850000.00 WHERE branch_id = @branch2;
UPDATE food.branch_wallets SET balance = 6100000.00 WHERE branch_id = @branch3;
UPDATE food.branch_wallets SET balance = 2300000.00 WHERE branch_id = @branch4;
UPDATE food.branch_wallets SET balance = 950000.00  WHERE branch_id = @branch5;
UPDATE food.branch_wallets SET balance = 7400000.00 WHERE branch_id = @branch6;
UPDATE food.branch_wallets SET balance = 610000.00  WHERE branch_id = @branch7;
-- branch8 wallet left at trigger default (0.00) — matches its inactive status

-- =============================================
-- PART 8: food_logs — populated only by exercising
-- trg_branches_audit, never inserted directly.
-- Session context must be set first or the trigger's
-- own INSERT fails on food_logs.actor_id NOT NULL.
-- =============================================

EXEC sp_set_session_context @key = N'current_user_id', @value = @u_admin;

UPDATE food.branches SET rating = 4.55 WHERE branch_id = @branch1;      -- rating correction, logged
UPDATE food.branches SET is_active = 0 WHERE branch_id = @branch8;      -- edge: already inactive, but re-confirms audit fires on rating too if changed alongside
UPDATE food.branches SET rating = 3.75 WHERE branch_id = @branch4;      -- rating adjustment, logged
GO

-- =============================================
-- SECTION 0: Clear existing data before re-seeding
-- =============================================

DELETE FROM food.order_payments;
DELETE FROM food.order_items;
DELETE FROM food.food_orders;
GO

DBCC CHECKIDENT ('food.order_payments', RESEED, 0);
DBCC CHECKIDENT ('food.order_items', RESEED, 0);
DBCC CHECKIDENT ('food.food_orders', RESEED, 0);
GO

-- =============================================
-- PART 1: Look up prerequisites via natural keys.
-- Restricted to the 3 users that actually exist in
-- core.users: sara_ahmadi, reza_karimi, mina_hosseini.
-- =============================================

DECLARE @u_sara INT = (SELECT user_id FROM core.users WHERE username = 'sara_ahmadi');
DECLARE @u_reza INT = (SELECT user_id FROM core.users WHERE username = 'reza_karimi');
DECLARE @u_mina INT = (SELECT user_id FROM core.users WHERE username = 'mina_hosseini');

DECLARE @branch1 INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'Zeytoon Grill' AND b.city = 'Tehran');
DECLARE @branch2 INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'Zeytoon Grill' AND b.city = 'Karaj');
DECLARE @branch3 INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'Baradaran Pizza' AND b.city = 'Tehran');
DECLARE @branch5 INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'Shab Cafe' AND b.city = 'Tehran');
DECLARE @branch6 INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'Noon-o-Kabab' AND b.city = 'Shiraz');
DECLARE @branch7 INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'Sib Sabz Vegan' AND b.city = 'Tehran');

DECLARE @mi_b1_kabab1  INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id WHERE mi.branch_id = @branch1 AND f.name = 'Zeytoon Special Kabab');
DECLARE @mi_b1_chicken INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id WHERE mi.branch_id = @branch1 AND f.name = 'Grilled Chicken Skewer');
DECLARE @mi_b2_kabab1  INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id WHERE mi.branch_id = @branch2 AND f.name = 'Zeytoon Special Kabab');
DECLARE @mi_b3_pizza1  INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id WHERE mi.branch_id = @branch3 AND f.name = 'Margherita Pizza');
DECLARE @mi_b3_pizza2  INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id WHERE mi.branch_id = @branch3 AND f.name = 'Pepperoni Pizza');
DECLARE @mi_b5_latte   INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id WHERE mi.branch_id = @branch5 AND f.name = 'Iced Latte');
DECLARE @mi_b5_cake    INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id WHERE mi.branch_id = @branch5 AND f.name = 'Cheesecake');
DECLARE @mi_b6_koobideh INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id WHERE mi.branch_id = @branch6 AND f.name = 'Koobideh Kabab');
DECLARE @mi_b7_burger  INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id WHERE mi.branch_id = @branch7 AND f.name = 'Vegan Burger');
DECLARE @mi_b7_soup    INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id WHERE mi.branch_id = @branch7 AND f.name = 'Lentil Soup');

DECLARE @addr_sara_home INT = (SELECT address_id FROM core.addresses WHERE user_id = @u_sara AND address_name = 'Home');
DECLARE @addr_reza_home INT = (SELECT address_id FROM core.addresses WHERE user_id = @u_reza AND address_name = 'Home');
DECLARE @addr_mina_home INT = (SELECT address_id FROM core.addresses WHERE user_id = @u_mina AND address_name = 'Home');

IF @u_sara IS NULL OR @u_reza IS NULL OR @u_mina IS NULL
   OR @branch1 IS NULL OR @branch2 IS NULL OR @branch3 IS NULL OR @branch5 IS NULL OR @branch6 IS NULL OR @branch7 IS NULL
   OR @mi_b1_kabab1 IS NULL OR @mi_b1_chicken IS NULL OR @mi_b2_kabab1 IS NULL OR @mi_b3_pizza1 IS NULL OR @mi_b3_pizza2 IS NULL
   OR @mi_b5_latte IS NULL OR @mi_b5_cake IS NULL OR @mi_b6_koobideh IS NULL OR @mi_b7_burger IS NULL OR @mi_b7_soup IS NULL
   OR @addr_sara_home IS NULL OR @addr_reza_home IS NULL OR @addr_mina_home IS NULL
BEGIN
    RAISERROR('One or more required prerequisite rows were not found. Run the core and food seed scripts first.', 16, 1);
    RETURN;
END

-- =============================================
-- PART 2: Orders — 8 rows across the 3 real users,
-- covering pending/preparing/picked_up/delivered/
-- cancelled/disputed, plus delivery/takeout/discount variety.
-- =============================================

-- Order 1: sara_ahmadi, delivered, delivery, no discount
INSERT INTO food.food_orders (customer_id, branch_id, delivery_address_id, delivery_fee, final_price, allocated_discount, is_takeout, ride_id, rating, comment, created_at, confirmed_at, cooking_completed_at, estimated_cooking_time, handed_to_courier_at, delivered_at, status, rejection_reason)
VALUES (@u_sara, @branch1, @addr_sara_home, 25000.00, 0, 0, 0, NULL, 5, 'Great food, arrived hot.',
        DATEADD(DAY,-3,SYSDATETIME()), DATEADD(MINUTE,5,DATEADD(DAY,-3,SYSDATETIME())), DATEADD(MINUTE,30,DATEADD(DAY,-3,SYSDATETIME())),
        25, DATEADD(MINUTE,35,DATEADD(DAY,-3,SYSDATETIME())), DATEADD(MINUTE,55,DATEADD(DAY,-3,SYSDATETIME())), 'delivered', NULL);
DECLARE @order1 INT = SCOPE_IDENTITY();

INSERT INTO food.order_items (order_id, menu_item_id, quantity, current_price) VALUES
(@order1, @mi_b1_kabab1,  2, food.fn_get_effective_menu_price(@mi_b1_kabab1)),
(@order1, @mi_b1_chicken, 1, food.fn_get_effective_menu_price(@mi_b1_chicken));

UPDATE food.food_orders SET final_price = food.fn_calculate_order_total(@order1) + 25000.00 WHERE order_id = @order1;

-- Order 2: mina_hosseini, delivered, takeout
INSERT INTO food.food_orders (customer_id, branch_id, delivery_address_id, delivery_fee, final_price, allocated_discount, is_takeout, ride_id, rating, comment, created_at, confirmed_at, cooking_completed_at, estimated_cooking_time, handed_to_courier_at, delivered_at, status, rejection_reason)
VALUES (@u_mina, @branch5, NULL, 0, 0, 0, 1, NULL, 4, 'Nice coffee, quick pickup.',
        DATEADD(DAY,-1,SYSDATETIME()), DATEADD(MINUTE,3,DATEADD(DAY,-1,SYSDATETIME())), DATEADD(MINUTE,13,DATEADD(DAY,-1,SYSDATETIME())),
        10, NULL, DATEADD(MINUTE,18,DATEADD(DAY,-1,SYSDATETIME())), 'delivered', NULL);
DECLARE @order2 INT = SCOPE_IDENTITY();

INSERT INTO food.order_items (order_id, menu_item_id, quantity, current_price) VALUES
(@order2, @mi_b5_latte, 2, food.fn_get_effective_menu_price(@mi_b5_latte)),
(@order2, @mi_b5_cake,  1, food.fn_get_effective_menu_price(@mi_b5_cake));

UPDATE food.food_orders SET final_price = food.fn_calculate_order_total(@order2) WHERE order_id = @order2;

-- Order 3: reza_karimi, pending, takeout
INSERT INTO food.food_orders (customer_id, branch_id, delivery_address_id, delivery_fee, final_price, allocated_discount, is_takeout, ride_id, rating, comment, created_at, confirmed_at, cooking_completed_at, estimated_cooking_time, handed_to_courier_at, delivered_at, status, rejection_reason)
VALUES (@u_reza, @branch7, NULL, 0, 0, 0, 1, NULL, NULL, NULL,
        DATEADD(MINUTE,-2,SYSDATETIME()), NULL, NULL, 15, NULL, NULL, 'pending', NULL);
DECLARE @order3 INT = SCOPE_IDENTITY();

INSERT INTO food.order_items (order_id, menu_item_id, quantity, current_price) VALUES
(@order3, @mi_b7_burger, 1, food.fn_get_effective_menu_price(@mi_b7_burger));

UPDATE food.food_orders SET final_price = food.fn_calculate_order_total(@order3) WHERE order_id = @order3;

-- Order 4: sara_ahmadi second order, preparing, takeout
INSERT INTO food.food_orders (customer_id, branch_id, delivery_address_id, delivery_fee, final_price, allocated_discount, is_takeout, ride_id, rating, comment, created_at, confirmed_at, cooking_completed_at, estimated_cooking_time, handed_to_courier_at, delivered_at, status, rejection_reason)
VALUES (@u_sara, @branch3, NULL, 0, 0, 0, 1, NULL, NULL, NULL,
        DATEADD(MINUTE,-15,SYSDATETIME()), DATEADD(MINUTE,-12,SYSDATETIME()), NULL, 18, NULL, NULL, 'preparing', NULL);
DECLARE @order4 INT = SCOPE_IDENTITY();

INSERT INTO food.order_items (order_id, menu_item_id, quantity, current_price) VALUES
(@order4, @mi_b3_pizza1, 1, food.fn_get_effective_menu_price(@mi_b3_pizza1)),
(@order4, @mi_b3_pizza2, 1, food.fn_get_effective_menu_price(@mi_b3_pizza2));

UPDATE food.food_orders SET final_price = food.fn_calculate_order_total(@order4) WHERE order_id = @order4;

-- Order 5: reza_karimi second order, cancelled while pending, never charged
INSERT INTO food.food_orders (customer_id, branch_id, delivery_address_id, delivery_fee, final_price, allocated_discount, is_takeout, ride_id, rating, comment, created_at, confirmed_at, cooking_completed_at, estimated_cooking_time, handed_to_courier_at, delivered_at, status, rejection_reason)
VALUES (@u_reza, @branch2, @addr_reza_home, 20000.00, 0, 0, 0, NULL, NULL, NULL,
        DATEADD(MINUTE,-40,SYSDATETIME()), NULL, NULL, 20, NULL, NULL, 'cancelled', 'Customer requested cancellation before confirmation.');
DECLARE @order5 INT = SCOPE_IDENTITY();

INSERT INTO food.order_items (order_id, menu_item_id, quantity, current_price) VALUES
(@order5, @mi_b2_kabab1, 1, food.fn_get_effective_menu_price(@mi_b2_kabab1));

UPDATE food.food_orders SET final_price = 0 WHERE order_id = @order5;

-- Order 6: mina_hosseini second order, disputed after delivery
INSERT INTO food.food_orders (customer_id, branch_id, delivery_address_id, delivery_fee, final_price, allocated_discount, is_takeout, ride_id, rating, comment, created_at, confirmed_at, cooking_completed_at, estimated_cooking_time, handed_to_courier_at, delivered_at, status, rejection_reason)
VALUES (@u_mina, @branch1, @addr_mina_home, 22000.00, 0, 0, 0, NULL, 2, 'Order arrived cold and 30 minutes late.',
        DATEADD(DAY,-6,SYSDATETIME()), DATEADD(MINUTE,4,DATEADD(DAY,-6,SYSDATETIME())), DATEADD(MINUTE,26,DATEADD(DAY,-6,SYSDATETIME())),
        22, DATEADD(MINUTE,30,DATEADD(DAY,-6,SYSDATETIME())), DATEADD(MINUTE,55,DATEADD(DAY,-6,SYSDATETIME())), 'disputed', NULL);
DECLARE @order6 INT = SCOPE_IDENTITY();

INSERT INTO food.order_items (order_id, menu_item_id, quantity, current_price) VALUES
(@order6, @mi_b1_chicken, 1, food.fn_get_effective_menu_price(@mi_b1_chicken));

UPDATE food.food_orders SET final_price = food.fn_calculate_order_total(@order6) + 22000.00 WHERE order_id = @order6;

-- Order 7: sara_ahmadi third order, delivered, takeout, with allocated discount
INSERT INTO food.food_orders (customer_id, branch_id, delivery_address_id, delivery_fee, final_price, allocated_discount, is_takeout, ride_id, rating, comment, created_at, confirmed_at, cooking_completed_at, estimated_cooking_time, handed_to_courier_at, delivered_at, status, rejection_reason)
VALUES (@u_sara, @branch7, NULL, 0, 0, 15000.00, 1, NULL, 3, 'Good, but portion was a bit small.',
        DATEADD(DAY,-10,SYSDATETIME()), DATEADD(MINUTE,2,DATEADD(DAY,-10,SYSDATETIME())), DATEADD(MINUTE,14,DATEADD(DAY,-10,SYSDATETIME())),
        15, NULL, DATEADD(MINUTE,17,DATEADD(DAY,-10,SYSDATETIME())), 'delivered', NULL);
DECLARE @order7 INT = SCOPE_IDENTITY();

INSERT INTO food.order_items (order_id, menu_item_id, quantity, current_price) VALUES
(@order7, @mi_b7_burger, 1, food.fn_get_effective_menu_price(@mi_b7_burger)),
(@order7, @mi_b7_soup,   1, food.fn_get_effective_menu_price(@mi_b7_soup));

UPDATE food.food_orders SET final_price = food.fn_calculate_order_total(@order7) - 15000.00 WHERE order_id = @order7;

-- Order 8: mina_hosseini third order, picked_up, in transit, not yet delivered
INSERT INTO food.food_orders (customer_id, branch_id, delivery_address_id, delivery_fee, final_price, allocated_discount, is_takeout, ride_id, rating, comment, created_at, confirmed_at, cooking_completed_at, estimated_cooking_time, handed_to_courier_at, delivered_at, status, rejection_reason)
VALUES (@u_mina, @branch6, @addr_mina_home, 28000.00, 0, 0, 0, NULL, NULL, NULL,
        DATEADD(MINUTE,-25,SYSDATETIME()), DATEADD(MINUTE,-22,SYSDATETIME()), DATEADD(MINUTE,-10,SYSDATETIME()),
        22, DATEADD(MINUTE,-8,SYSDATETIME()), NULL, 'picked_up', NULL);
DECLARE @order8 INT = SCOPE_IDENTITY();

INSERT INTO food.order_items (order_id, menu_item_id, quantity, current_price) VALUES
(@order8, @mi_b6_koobideh, 2, food.fn_get_effective_menu_price(@mi_b6_koobideh));

UPDATE food.food_orders SET final_price = food.fn_calculate_order_total(@order8) + 28000.00 WHERE order_id = @order8;

-- =============================================
-- PART 3: Transactions + order_payments for charged orders.
-- Orders 3 (pending) and 5 (cancelled pre-confirmation) are
-- intentionally excluded — never charged.
-- =============================================

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT @u_sara, 'order_payment', 'completed', final_price, 'wallet', NULL, confirmed_at FROM food.food_orders WHERE order_id = @order1;
DECLARE @txn1 INT = SCOPE_IDENTITY();
INSERT INTO food.order_payments (order_id, transaction_id) VALUES (@order1, @txn1);

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT @u_mina, 'order_payment', 'completed', final_price, 'wallet', NULL, confirmed_at FROM food.food_orders WHERE order_id = @order2;
DECLARE @txn2 INT = SCOPE_IDENTITY();
INSERT INTO food.order_payments (order_id, transaction_id) VALUES (@order2, @txn2);

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT @u_sara, 'order_payment', 'completed', final_price, 'wallet', NULL, confirmed_at FROM food.food_orders WHERE order_id = @order4;
DECLARE @txn4 INT = SCOPE_IDENTITY();
INSERT INTO food.order_payments (order_id, transaction_id) VALUES (@order4, @txn4);

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT @u_mina, 'order_payment', 'completed', final_price, 'wallet', NULL, confirmed_at FROM food.food_orders WHERE order_id = @order6;
DECLARE @txn6 INT = SCOPE_IDENTITY();
INSERT INTO food.order_payments (order_id, transaction_id) VALUES (@order6, @txn6);

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT @u_sara, 'order_payment', 'completed', final_price, 'wallet', NULL, confirmed_at FROM food.food_orders WHERE order_id = @order7;
DECLARE @txn7 INT = SCOPE_IDENTITY();
INSERT INTO food.order_payments (order_id, transaction_id) VALUES (@order7, @txn7);

INSERT INTO core.transactions (user_id, transaction_type, transaction_status, amount, payment_method, coupon_id, created_at)
SELECT @u_mina, 'order_payment', 'completed', final_price, 'wallet', NULL, confirmed_at FROM food.food_orders WHERE order_id = @order8;
DECLARE @txn8 INT = SCOPE_IDENTITY();
INSERT INTO food.order_payments (order_id, transaction_id) VALUES (@order8, @txn8);
GO