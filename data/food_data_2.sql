USE mini_snapp;
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