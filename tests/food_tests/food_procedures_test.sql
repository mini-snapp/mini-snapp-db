USE mini_snapp;
GO

PRINT 'sp_write_log';
DECLARE @branch1_log INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'zeytoon Grill' AND b.city = 'tehran');
DECLARE @u_new_user_log INT = (SELECT user_id FROM core.users WHERE username = 'arash');
DECLARE @count_before_log INT = (SELECT COUNT(*) FROM food.food_logs);
PRINT 'scenario 1: full log entry';
EXEC food.sp_write_log
    @actor_id = @u_new_user_log, @operation_type = 'insert', @target_table = 'test_table',
    @target_id = '999', @old_value = NULL, @new_value = '{"test":true}',
    @description = 'manual test log entry', @branch_id = @branch1_log;
SELECT @count_before_log AS count_before, (SELECT COUNT(*) FROM food.food_logs) AS count_after;
SELECT TOP 1 * FROM food.food_logs ORDER BY food_log_id DESC;

GO

PRINT 'sp_add_to_cart';
DECLARE @branch1_cart INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'Zeytoon Grill' AND b.city = 'Tehran');
DECLARE @branch3_cart INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'Baradaran Pizza' AND b.city = 'Tehran');
DECLARE @mi_b1_kabab_cart INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id WHERE mi.branch_id = @branch1_cart AND f.name = 'Zeytoon Special Kabab');
DECLARE @mi_b3_pizza_cart INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id WHERE mi.branch_id = @branch3_cart AND f.name = 'Margherita Pizza');
DECLARE @u_new_user_cart INT = (SELECT user_id FROM core.users WHERE username = 'arash');
DECLARE @mi_b1_unavailable INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id JOIN food.branches b ON b.branch_id = mi.branch_id JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'Baradaran Pizza' AND b.city = 'Isfahan' AND f.name = 'Pepperoni Pizza');
DECLARE @unavailable_branch_id INT = (SELECT branch_id FROM food.menu_items WHERE menu_item_id = @mi_b1_unavailable);
EXEC food.sp_clear_cart @user_id = @u_new_user_cart;
PRINT 'scenario 1: quantity 0';
EXEC food.sp_add_to_cart @user_id = @u_new_user_cart, @branch_id = @branch1_cart, @menu_item_id = @mi_b1_kabab_cart, @quantity = 0;
SELECT COUNT(*) AS row_count_after_scenario1 FROM food.cart_items WHERE user_id = @u_new_user_cart;
PRINT 'scenario 2: valid new item, quantity 2';
EXEC food.sp_add_to_cart @user_id = @u_new_user_cart, @branch_id = @branch1_cart, @menu_item_id = @mi_b1_kabab_cart, @quantity = 2;
SELECT * FROM food.cart_items WHERE user_id = @u_new_user_cart;
PRINT 'scenario 3: same item added again with quantity 1';
EXEC food.sp_add_to_cart @user_id = @u_new_user_cart, @branch_id = @branch1_cart, @menu_item_id = @mi_b1_kabab_cart, @quantity = 1;
SELECT * FROM food.cart_items WHERE user_id = @u_new_user_cart;
PRINT 'scenario 4: unavailable menu item';
EXEC food.sp_add_to_cart @user_id = @u_new_user_cart, @branch_id = @unavailable_branch_id, @menu_item_id = @mi_b1_unavailable, @quantity = 1;
SELECT COUNT(*) AS row_count_after_scenario4 FROM food.cart_items WHERE user_id = @u_new_user_cart;
PRINT 'scenario 5: different branch while cart has branch1 items';
EXEC food.sp_add_to_cart @user_id = @u_new_user_cart, @branch_id = @branch3_cart, @menu_item_id = @mi_b3_pizza_cart, @quantity = 1;
SELECT branch_id, COUNT(*) AS item_count FROM food.cart_items WHERE user_id = @u_new_user_cart GROUP BY branch_id;

GO

PRINT 'sp_clear_cart';
DECLARE @u_new_user_clear INT = (SELECT user_id FROM core.users WHERE username = 'arash');
DECLARE @branch1_clear INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'zeytoon grill' AND b.city = 'tehran');
DECLARE @avail_mi_b1 INT = (SELECT TOP 1 menu_item_id FROM food.menu_items WHERE branch_id = @branch1_clear AND availability_status = 1);
PRINT 'scenario 1: clear cart scoped to branch1';
EXEC food.sp_clear_cart @user_id = @u_new_user_clear, @branch_id = @branch1_clear;
SELECT COUNT(*) AS remaining_rows FROM food.cart_items WHERE user_id = @u_new_user_clear AND branch_id = @branch1_clear;
PRINT 'scenario 2: clear entire cart';
EXEC food.sp_add_to_cart @user_id = @u_new_user_clear, @branch_id = @branch1_clear, @menu_item_id = @avail_mi_b1, @quantity = 1;
EXEC food.sp_clear_cart @user_id = @u_new_user_clear;
SELECT COUNT(*) AS remaining_rows FROM food.cart_items WHERE user_id = @u_new_user_clear;
PRINT 'scenario 3: clear an already empty cart';
EXEC food.sp_clear_cart @user_id = @u_new_user_clear;

GO

PRINT 'sp_set_branch_schedule ';
DECLARE @branch1_sched INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'zeytoon grill' AND b.city = 'tehran');
PRINT 'scenario 1: day of week  9';
EXEC food.sp_set_branch_schedule @branch_id = @branch1_sched, @day_of_week = 9, @start_time = '09:00', @end_time = '20:00', @is_closed = 0;
PRINT 'scenario 2: update existing day of week 2';
EXEC food.sp_set_branch_schedule @branch_id = @branch1_sched, @day_of_week = 2, @start_time = '10:00', @end_time = '21:00', @is_closed = 0;
SELECT * FROM food.work_schedules WHERE branch_id = @branch1_sched AND day_of_week = 2;
PRINT 'scenario 3: insert path remove day 3 then readd it';
DELETE FROM food.work_schedules WHERE branch_id = @branch1_sched AND day_of_week = 3;
SELECT COUNT(*) AS row_exists_before_insert FROM food.work_schedules WHERE branch_id = @branch1_sched AND day_of_week = 3;
EXEC food.sp_set_branch_schedule @branch_id = @branch1_sched, @day_of_week = 3, @start_time = '09:00', @end_time = '23:00', @is_closed = 0;
SELECT * FROM food.work_schedules WHERE branch_id = @branch1_sched AND day_of_week = 3;

GO

PRINT 'sp_create_menu_discount';
DECLARE @mi_discount_test INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id JOIN food.branches b ON b.branch_id = mi.branch_id JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'Noon-o-Kabab' AND f.name = 'Koobideh Kabab');
PRINT 'scenario 1: valid discount with percentage only';
EXEC food.sp_create_menu_discount @menu_item_id = @mi_discount_test, @percentage = 10.00, @amount = NULL, @start_at = '2026-08-01', @end_at = '2026-08-10';
SELECT * FROM food.menu_discounts WHERE menu_item_id = @mi_discount_test ORDER BY menu_discount_id DESC;
PRINT 'scenario 2: both percentage and amount null';
EXEC food.sp_create_menu_discount @menu_item_id = @mi_discount_test, @percentage = NULL, @amount = NULL, @start_at = '2026-09-01', @end_at = '2026-09-10';
PRINT 'scenario 3: percentage 150';
EXEC food.sp_create_menu_discount @menu_item_id = @mi_discount_test, @percentage = 150.00, @amount = NULL, @start_at = '2026-09-01', @end_at = '2026-09-10';
PRINT 'scenario 4: overlapping active discount period';
EXEC food.sp_create_menu_discount @menu_item_id = @mi_discount_test, @percentage = 5.00, @amount = NULL, @start_at = '2026-08-05', @end_at = '2026-08-15';
SELECT * FROM food.menu_discounts WHERE menu_item_id = @mi_discount_test;

GO

PRINT 'sp_get_available_branches_for_customer';
PRINT 'scenario 1: 50km radius';
EXEC food.sp_get_available_branches_for_customer @user_lat = 35.700000, @user_lng = 51.400000, @radius_km = 50.00;
PRINT 'scenario 2: same radius  explicit wednesday 14';
EXEC food.sp_get_available_branches_for_customer @user_lat = 35.700000, @user_lng = 51.400000, @radius_km = 50.00, @check_datetime = '2026-07-08 14:00:00';
PRINT 'scenario 3: same radius explicit Friday 14';
EXEC food.sp_get_available_branches_for_customer @user_lat = 35.700000, @user_lng = 51.400000, @radius_km = 50.00, @check_datetime = '2026-07-10 14:00:00';
PRINT 'scenario 4: 0.001km radius';
EXEC food.sp_get_available_branches_for_customer @user_lat = 35.700000, @user_lng = 51.400000, @radius_km = 0.001, @check_datetime = '2026-07-08 14:00:00';

GO

PRINT 'food.sp_assign_restaurant_staff';
DECLARE @u_new_staff_test INT = (SELECT user_id FROM core.users WHERE username = 'arash');
DECLARE @branch5_staff INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'shab cafe' AND b.city = 'tehran');
DECLARE @u_existing_owner INT = (SELECT TOP 1 user_id FROM food.branch_owners WHERE branch_id = @branch5_staff);
DELETE FROM food.restaurant_staff WHERE user_id = @u_new_staff_test AND branch_id = @branch5_staff;
PRINT 'scenario 1: valid new assignment';
EXEC food.sp_assign_restaurant_staff @user_id = @u_new_staff_test, @branch_id = @branch5_staff;
SELECT * FROM food.restaurant_staff WHERE user_id = @u_new_staff_test AND branch_id = @branch5_staff;
PRINT 'scenario 2: duplicate assignment';
EXEC food.sp_assign_restaurant_staff @user_id = @u_new_staff_test, @branch_id = @branch5_staff;
PRINT 'scenario 3: assigning existing branch owner as staff';
EXEC food.sp_assign_restaurant_staff @user_id = @u_existing_owner, @branch_id = @branch5_staff;
DELETE FROM food.restaurant_staff WHERE user_id = @u_new_staff_test AND branch_id = @branch5_staff;

GO

PRINT 'sp_cancel_order';
DECLARE @order_pending_cancel INT = (SELECT TOP 1 order_id FROM food.food_orders WHERE status = 'pending');
DECLARE @order_delivered_cancel INT = (SELECT TOP 1 order_id FROM food.food_orders WHERE status = 'delivered');
DECLARE @cust_pending INT = (SELECT customer_id FROM food.food_orders WHERE order_id = @order_pending_cancel);
DECLARE @wallet_before DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @cust_pending);
PRINT 'was there a payment row before cancelling?';
SELECT COUNT(*) AS payment_row_count FROM food.order_payments WHERE order_id = @order_pending_cancel;
EXEC sp_set_session_context @key = N'current_user_id', @value = @cust_pending;
PRINT 'scenario 1: cancel pending order as user';
EXEC food.sp_cancel_order @order_id = @order_pending_cancel, @actor_type = 'user', @reason = 'test cancellation';
SELECT status, rejection_reason FROM food.food_orders WHERE order_id = @order_pending_cancel;
SELECT @wallet_before AS wallet_before, (SELECT balance FROM core.user_wallets WHERE user_id = @cust_pending) AS wallet_after;
PRINT 'scenario 2: cancel an already cancelled order';
EXEC food.sp_cancel_order @order_id = @order_pending_cancel, @actor_type = 'user', @reason = 'second attempt';
PRINT 'scenario 3: cancel an already delivered order';
EXEC food.sp_cancel_order @order_id = @order_delivered_cancel, @actor_type = 'restaurant', @reason = 'should not be allowed';
SELECT status FROM food.food_orders WHERE order_id = @order_delivered_cancel;

GO