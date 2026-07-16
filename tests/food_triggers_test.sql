USE mini_snapp;
GO


DECLARE @u_sara INT = (SELECT user_id FROM core.users WHERE username = 'sara_ahmadi');
DECLARE @branch1 INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'zeytoon grill' AND b.city = 'tehran');
DECLARE @addr_sara INT = (SELECT address_id FROM core.addresses WHERE user_id = @u_sara AND address_name = 'Home');
DECLARE @mi_kabab INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id WHERE mi.branch_id = @branch1 AND f.name = 'zeytoon special kabab');
DECLARE @mi_chicken INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id WHERE mi.branch_id = @branch1 AND f.name = 'grilled chicken skewer');

GO

EXEC sp_set_session_context @key = N'current_user_id', @value = NULL;
PRINT 'trg_food_orders_status_validate'
DECLARE @branch1 INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'zeytoon grill' AND b.city = 'tehran');
DECLARE @u_sara INT = (SELECT user_id FROM core.users WHERE username = 'sara_ahmadi');
DECLARE @addr_sara INT = (SELECT address_id FROM core.addresses WHERE user_id = @u_sara AND address_name = 'home');
INSERT INTO food.food_orders (customer_id, branch_id, delivery_address_id, delivery_fee, final_price, allocated_discount, is_takeout, status)
VALUES (@u_sara, @branch1, @addr_sara, 20000.00, 0, 0, 0, 'pending');
DECLARE @test_order_1 INT = SCOPE_IDENTITY();
PRINT 'scenario 1: pending to confirmed';
UPDATE food.food_orders SET status = 'confirmed' WHERE order_id = @test_order_1;
SELECT status FROM food.food_orders WHERE order_id = @test_order_1;
PRINT 'scenario 2: confirmed to picked up';
UPDATE food.food_orders SET status = 'picked_up' WHERE order_id = @test_order_1;
SELECT status FROM food.food_orders WHERE order_id = @test_order_1;
PRINT 'scenario 3: advance through preparing to picked up to delivered';
UPDATE food.food_orders SET status = 'preparing' WHERE order_id = @test_order_1;
UPDATE food.food_orders SET status = 'picked_up' WHERE order_id = @test_order_1;
UPDATE food.food_orders SET status = 'delivered' WHERE order_id = @test_order_1;
UPDATE food.food_orders SET status = 'preparing' WHERE order_id = @test_order_1;
SELECT status FROM food.food_orders WHERE order_id = @test_order_1;
INSERT INTO food.food_orders (customer_id, branch_id, delivery_address_id, delivery_fee, final_price, allocated_discount, is_takeout, status)
VALUES (@u_sara, @branch1, @addr_sara, 20000.00, 0, 0, 0, 'pending');
DECLARE @test_order_2 INT = SCOPE_IDENTITY();
PRINT 'scenario 4: pending to cancelled directly';
UPDATE food.food_orders SET status = 'cancelled' WHERE order_id = @test_order_2;
SELECT status FROM food.food_orders WHERE order_id = @test_order_2;

GO

EXEC sp_set_session_context @key = N'current_user_id', @value = NULL;
PRINT 'trg_food_orders_timestamp_autofill';
DECLARE @u_sara INT = (SELECT user_id FROM core.users WHERE username = 'sara_ahmadi');
DECLARE @branch1 INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'zeytoon grill' AND b.city = 'tehran');
DECLARE @addr_sara INT = (SELECT address_id FROM core.addresses WHERE user_id = @u_sara AND address_name = 'home');
INSERT INTO food.food_orders (customer_id, branch_id, delivery_address_id, delivery_fee, final_price, allocated_discount, is_takeout, status)
VALUES (@u_sara, @branch1, @addr_sara, 20000.00, 0, 0, 0, 'pending');
DECLARE @test_order_3 INT = SCOPE_IDENTITY();
PRINT 'scenario 1: pending to confirmed';
UPDATE food.food_orders SET status = 'confirmed' WHERE order_id = @test_order_3;
SELECT confirmed_at, cooking_completed_at, handed_to_courier_at, delivered_at FROM food.food_orders WHERE order_id = @test_order_3;
UPDATE food.food_orders SET status = 'preparing' WHERE order_id = @test_order_3;
PRINT 'scenario 2: preparing to picked up';
UPDATE food.food_orders SET status = 'picked_up' WHERE order_id = @test_order_3;
SELECT confirmed_at, cooking_completed_at, handed_to_courier_at, delivered_at FROM food.food_orders WHERE order_id = @test_order_3;
PRINT 'scenario 3: picked up to delivered';
UPDATE food.food_orders SET status = 'delivered' WHERE order_id = @test_order_3;
SELECT confirmed_at, cooking_completed_at, handed_to_courier_at, delivered_at FROM food.food_orders WHERE order_id = @test_order_3;

GO

EXEC sp_set_session_context @key = N'current_user_id', @value = NULL;
PRINT 'trg_food_orders_audit';
DECLARE @u_sara INT = (SELECT user_id FROM core.users WHERE username = 'sara_ahmadi');
DECLARE @branch1 INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'zeytoon grill' AND b.city = 'tehran');
DECLARE @addr_sara INT = (SELECT address_id FROM core.addresses WHERE user_id = @u_sara AND address_name = 'home');
INSERT INTO food.food_orders (customer_id, branch_id, delivery_address_id, delivery_fee, final_price, allocated_discount, is_takeout, status)
VALUES (@u_sara, @branch1, @addr_sara, 20000.00, 0, 0, 0, 'pending');
DECLARE @test_order_4 INT = SCOPE_IDENTITY();
PRINT 'scenario 1: status change with no session context set';
UPDATE food.food_orders SET status = 'confirmed' WHERE order_id = @test_order_4;
SELECT TOP 1 actor_id, old_value, new_value, description FROM food.food_logs
WHERE target_table = 'food_orders' AND target_id = CAST(@test_order_4 AS VARCHAR(50))
ORDER BY food_log_id DESC;
PRINT 'scenario 2: with session context set, expect actor_id';
EXEC sp_set_session_context @key = N'current_user_id', @value = @u_sara;
UPDATE food.food_orders SET status = 'preparing' WHERE order_id = @test_order_4;
SELECT TOP 1 actor_id, old_value, new_value FROM food.food_logs
WHERE target_table = 'food_orders' AND target_id = CAST(@test_order_4 AS VARCHAR(50))
ORDER BY food_log_id DESC;
PRINT 'scenario 3: a plain update that doesnt effect status';
DECLARE @count_before_scenario3 INT = (SELECT COUNT(*) FROM food.food_logs WHERE target_table = 'food_orders' AND operation_type = 'update');
UPDATE food.food_orders SET comment = 'test comment, status unchanged' WHERE order_id = @test_order_4;
SELECT @count_before_scenario3 AS count_before, (SELECT COUNT(*) FROM food.food_logs WHERE target_table = 'food_orders' AND operation_type = 'update') AS count_after;

GO

EXEC sp_set_session_context @key = N'current_user_id', @value = NULL;
PRINT 'trg_food_orders_after_insert';
DECLARE @u_reza INT = (SELECT user_id FROM core.users WHERE username = 'reza_karimi');
DECLARE @branch1 INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'zeytoon grill' AND b.city = 'tehran');
DECLARE @addr_reza INT = (SELECT address_id FROM core.addresses WHERE user_id = @u_reza AND address_name = 'home');
PRINT 'scenario 1: new order insert';
INSERT INTO food.food_orders (customer_id, branch_id, delivery_address_id, delivery_fee, final_price, allocated_discount, is_takeout, status)
VALUES (@u_reza, @branch1, @addr_reza, 20000.00, 0, 0, 0, 'pending');
DECLARE @test_order_5 INT = SCOPE_IDENTITY();
SELECT TOP 1 actor_id, operation_type, description FROM food.food_logs
WHERE target_table = 'food_orders' AND target_id = CAST(@test_order_5 AS VARCHAR(50)) AND operation_type = 'insert'
ORDER BY food_log_id DESC;
PRINT 'scenario 2: verify actor id fallback';
SELECT @u_reza AS expected_actor_id;
SELECT TOP 1 actor_id FROM food.food_logs
WHERE target_table = 'food_orders' AND target_id = CAST(@test_order_5 AS VARCHAR(50)) AND operation_type = 'insert'
ORDER BY food_log_id DESC;

GO

EXEC sp_set_session_context @key = N'current_user_id', @value = NULL;
PRINT 'trg_food_orders_delivered_charge';
DECLARE @u_mina INT = (SELECT user_id FROM core.users WHERE username = 'mina_hosseini');
DECLARE @branch1 INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'zeytoon grill' AND b.city = 'tehran');
DECLARE @addr_mina INT = (SELECT address_id FROM core.addresses WHERE user_id = @u_mina AND address_name = 'home');
DECLARE @mi_kabab INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id WHERE mi.branch_id = @branch1 AND f.name = 'zeytoon special kabab');
INSERT INTO food.food_orders (customer_id, branch_id, delivery_address_id, delivery_fee, final_price, allocated_discount, is_takeout, status)
VALUES (@u_mina, @branch1, @addr_mina, 20000.00, 0, 0, 1, 'pending');
DECLARE @test_order_6 INT = SCOPE_IDENTITY();
INSERT INTO food.order_items (order_id, menu_item_id, quantity, current_price)
VALUES (@test_order_6, @mi_kabab, 1, food.fn_get_effective_menu_price(@mi_kabab));
PRINT 'payment rows created by order purchase at order creation time:';
SELECT COUNT(*) AS payment_row_count FROM food.order_payments WHERE order_id = @test_order_6
UPDATE food.food_orders SET status = 'confirmed' WHERE order_id = @test_order_6;
UPDATE food.food_orders SET status = 'preparing' WHERE order_id = @test_order_6;
UPDATE food.food_orders SET status = 'picked_up' WHERE order_id = @test_order_6;
UPDATE food.food_orders SET status = 'delivered' WHERE order_id = @test_order_6;
PRINT 'payment row count after reaching delivered status';
SELECT COUNT(*) AS payment_row_count_final FROM food.order_payments WHERE order_id = @test_order_6;

GO

EXEC sp_set_session_context @key = N'current_user_id', @value = NULL;
PRINT 'trg_branches_audit';
DECLARE @branch2 INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'zeytoon grill' AND b.city = 'karaj');
DECLARE @rating_before DECIMAL(3,2) = (SELECT rating FROM food.branches WHERE branch_id = @branch2);
PRINT 'scenario 1: rating change';
UPDATE food.branches SET rating = @rating_before + 0.05 WHERE branch_id = @branch2;
SELECT TOP 1 old_value, new_value FROM food.food_logs WHERE target_table = 'branches' AND target_id = CAST(@branch2 AS VARCHAR(50)) ORDER BY food_log_id DESC;
PRINT 'scenario 2: is active change';
UPDATE food.branches SET is_active = 0 WHERE branch_id = @branch2;
SELECT TOP 1 old_value, new_value FROM food.food_logs WHERE target_table = 'branches' AND target_id = CAST(@branch2 AS VARCHAR(50)) ORDER BY food_log_id DESC;
UPDATE food.branches SET is_active = 1 WHERE branch_id = @branch2;
PRINT 'scenario 3: update food type';
DECLARE @count_before_scenario3 INT = (SELECT COUNT(*) FROM food.food_logs WHERE target_table = 'branches' AND target_id = CAST(@branch2 AS VARCHAR(50)));
UPDATE food.branches SET food_type = 'Kabab' WHERE branch_id = @branch2;
SELECT @count_before_scenario3 AS count_before, (SELECT COUNT(*) FROM food.food_logs WHERE target_table = 'branches' AND target_id = CAST(@branch2 AS VARCHAR(50))) AS count_after;

GO

PRINT 'trg_menu_discounts_validate';
DECLARE @mi_test_discount INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id JOIN food.branches b ON b.branch_id = mi.branch_id JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'sib sabz vegan' AND b.city = 'tehran' AND f.name = 'lentil soup');
DELETE FROM food.menu_discounts WHERE menu_item_id = @mi_test_discount AND start_at IN ('2026-10-01', '2026-10-05', '2026-11-01');
PRINT 'scenario 1: valid discount';
INSERT INTO food.menu_discounts (menu_item_id, percentage, amount, start_at, end_at, is_active)
VALUES (@mi_test_discount, NULL, 8000.00, '2026-10-01', '2026-10-10', 1);
SELECT TOP 1 * FROM food.menu_discounts WHERE menu_item_id = @mi_test_discount ORDER BY menu_discount_id DESC;
PRINT 'scenario 2: neither percentage nor amount';
INSERT INTO food.menu_discounts (menu_item_id, percentage, amount, start_at, end_at, is_active)
VALUES (@mi_test_discount, NULL, NULL, '2026-11-01', '2026-11-10', 1);
PRINT 'scenario 3: negative percentage';
INSERT INTO food.menu_discounts (menu_item_id, percentage, amount, start_at, end_at, is_active)
VALUES (@mi_test_discount, -5.00, NULL, '2026-11-01', '2026-11-10', 1);
PRINT 'scenario 4: overlapping active discount period';
INSERT INTO food.menu_discounts (menu_item_id, percentage, amount, start_at, end_at, is_active)
VALUES (@mi_test_discount, 10.00, NULL, '2026-10-05', '2026-10-15', 1);
PRINT 'scenario 5: overlapping dates but is active 0';
INSERT INTO food.menu_discounts (menu_item_id, percentage, amount, start_at, end_at, is_active)
VALUES (@mi_test_discount, 10.00, NULL, '2026-10-05', '2026-10-15', 0);
SELECT * FROM food.menu_discounts WHERE menu_item_id = @mi_test_discount ORDER BY menu_discount_id;

GO

PRINT 'trg_branches_after_insert_create_wallet';
DELETE FROM food.branch_wallets WHERE branch_id IN (SELECT branch_id FROM food.branches WHERE brand_id IN (SELECT brand_id FROM food.brands WHERE name = 'test brand for trigger'));
DELETE FROM food.branches WHERE brand_id IN (SELECT brand_id FROM food.brands WHERE name = 'test brand for trigger');
DELETE FROM food.brands WHERE name = 'test brand for trigger';
DECLARE @new_brand_id INT;
INSERT INTO food.brands (name, central_support_phone, commission_rate, average_rating, rating_count, email)
VALUES ('test brand for trigger', '02100000000', 0.15, 0, 0, 'test@example.com');
SET @new_brand_id = SCOPE_IDENTITY();
PRINT 'scenario 1: new branch insert';
INSERT INTO food.branches (brand_id, rating, province, city, street, latitude, longitude, email, food_type, max_delivery_distance, is_active, rating_count)
VALUES (@new_brand_id, 0, 'tehran', 'tehran', 'test street 1', 35.700000, 51.400000, 'branch@example.com', 'test', 5.00, 1, 0);
DECLARE @new_branch_id INT = SCOPE_IDENTITY();
SELECT branch_id, balance FROM food.branch_wallets WHERE branch_id = @new_branch_id;
PRINT 'scenario 2: attempt manual duplicate branch wallets insert';
INSERT INTO food.branch_wallets (branch_id, balance) VALUES (@new_branch_id, 500.00);

GO

PRINT 'trg_cart_items_validate';
DECLARE @u_reza INT = (SELECT user_id FROM core.users WHERE username = 'reza_karimi');
DECLARE @branch1 INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'zeytoon grill' AND b.city = 'tehran');
DECLARE @branch2 INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'zeytoon grill' AND b.city = 'karaj');
DECLARE @mi_b1_kabab INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id WHERE mi.branch_id = @branch1 AND f.name = 'zeytoon special kabab');
DECLARE @mi_b4_pizza2_unavailable INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id JOIN food.branches b ON b.branch_id = mi.branch_id JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'baradaran pizza' AND b.city = 'isfahan' AND f.name = 'pepperoni pizza');
EXEC food.sp_clear_cart @user_id = @u_reza;
PRINT 'scenario 1: branch id and menu item id mismatch';
INSERT INTO food.cart_items (user_id, branch_id, menu_item_id, quantity) VALUES (@u_reza, @branch2, @mi_b1_kabab, 1);
SELECT COUNT(*) AS row_count FROM food.cart_items WHERE user_id = @u_reza;
PRINT 'scenario 2: correct branch and menu item';
INSERT INTO food.cart_items (user_id, branch_id, menu_item_id, quantity) VALUES (@u_reza, @branch1, @mi_b1_kabab, 1);
SELECT * FROM food.cart_items WHERE user_id = @u_reza;
PRINT 'scenario 3: unavailable menu';
DECLARE @unavailable_item_branch INT = (SELECT branch_id FROM food.menu_items WHERE menu_item_id = @mi_b4_pizza2_unavailable);
INSERT INTO food.cart_items (user_id, branch_id, menu_item_id, quantity) VALUES (@u_reza, @unavailable_item_branch, @mi_b4_pizza2_unavailable, 1);
SELECT COUNT(*) AS row_count FROM food.cart_items WHERE user_id = @u_reza AND menu_item_id = @mi_b4_pizza2_unavailable;
EXEC food.sp_clear_cart @user_id = @u_reza;

GO

EXEC sp_set_session_context @key = N'current_user_id', @value = NULL;
PRINT 'trg_order_purchase';
DECLARE @u_sara INT = (SELECT user_id FROM core.users WHERE username = 'sara_ahmadi');
DECLARE @branch1 INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'zeytoon grill' AND b.city = 'tehran');
DECLARE @addr_sara INT = (SELECT address_id FROM core.addresses WHERE user_id = @u_sara AND address_name = 'home');
DECLARE @mi_kabab INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id WHERE mi.branch_id = @branch1 AND f.name = 'zeytoon special kabab');
DECLARE @mi_chicken INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id WHERE mi.branch_id = @branch1 AND f.name = 'grilled chicken skewer');
DECLARE @wallet_before DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @u_sara);
DECLARE @branch_wallet_before DECIMAL(10,2) = (SELECT balance FROM food.branch_wallets WHERE branch_id = @branch1);
PRINT 'scenario 1: delivery order';
EXEC food.sp_add_to_cart @user_id = @u_sara, @branch_id = @branch1, @menu_item_id = @mi_kabab, @quantity = 1;
INSERT INTO food.food_orders (customer_id, branch_id, delivery_address_id, delivery_fee, final_price, allocated_discount, is_takeout, status)
VALUES (@u_sara, @branch1, @addr_sara, 25000.00, 0, 0, 0, 'pending');
DECLARE @order_scenario1 INT = SCOPE_IDENTITY();
DECLARE @offer_count_before INT = (SELECT COUNT(*) FROM taxi.ride_offers);
INSERT INTO food.order_items (order_id, menu_item_id, quantity, current_price)
VALUES (@order_scenario1, @mi_kabab, 1, food.fn_get_effective_menu_price(@mi_kabab));
DECLARE @new_offer_id_check INT = (SELECT TOP 1 ride_offer_id FROM taxi.ride_offers ORDER BY ride_offer_id DESC);
SELECT
    @wallet_before AS wallet_before,
    (SELECT balance FROM core.user_wallets WHERE user_id = @u_sara) AS wallet_after,
    @branch_wallet_before AS branch_wallet_before,
    (SELECT balance FROM food.branch_wallets WHERE branch_id = @branch1) AS branch_wallet_after,
    (SELECT COUNT(*) FROM food.cart_items WHERE user_id = @u_sara AND branch_id = @branch1) AS remaining_cart_items,
    @offer_count_before AS ride_offer_count_before,
    (SELECT COUNT(*) FROM taxi.ride_offers) AS ride_offer_count_after,
    (SELECT final_price FROM food.food_orders WHERE order_id = @order_scenario1) AS final_price_computed,
    (SELECT COUNT(*) FROM taxi.ride_offer_candidates WHERE offer_id = @new_offer_id_check) AS candidate_count_expect_0;
PRINT 'scenario 2: takeout order';
DECLARE @u_reza INT = (SELECT user_id FROM core.users WHERE username = 'reza_karimi');
INSERT INTO food.food_orders (customer_id, branch_id, delivery_address_id, delivery_fee, final_price, allocated_discount, is_takeout, status)
VALUES (@u_reza, @branch1, NULL, 0, 0, 0, 1, 'pending');
DECLARE @order_scenario2 INT = SCOPE_IDENTITY();
DECLARE @offer_count_before_s2 INT = (SELECT COUNT(*) FROM taxi.ride_offers);
INSERT INTO food.order_items (order_id, menu_item_id, quantity, current_price)
VALUES (@order_scenario2, @mi_chicken, 1, food.fn_get_effective_menu_price(@mi_chicken));
SELECT
    @offer_count_before_s2 AS ride_offer_count_before,
    (SELECT COUNT(*) FROM taxi.ride_offers) AS ride_offer_count_after_expect_same,
    (SELECT COUNT(*) FROM food.order_payments WHERE order_id = @order_scenario2) AS payment_row_count_expect_1;
PRINT 'scenario 3: top up an already charged order with more items';
INSERT INTO food.order_items (order_id, menu_item_id, quantity, current_price)
VALUES (@order_scenario2, @mi_kabab, 5, food.fn_get_effective_menu_price(@mi_kabab));
SELECT
    (SELECT COUNT(*) FROM food.order_payments WHERE order_id = @order_scenario2) AS payment_row_count_expect_2,
    (SELECT SUM(quantity * current_price) FROM food.order_items WHERE order_id = @order_scenario2) AS true_total_including_all_items,
    (SELECT SUM(t.amount) FROM core.transactions t JOIN food.order_payments op ON op.transaction_id = t.transaction_id WHERE op.order_id = @order_scenario2) AS total_amount_actually_charged;

GO