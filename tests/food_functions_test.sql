USE mini_snapp;
GO

PRINT 'fn_haversine_km';
PRINT 'scenario 1: same point';
SELECT food.fn_haversine_km(35.719562, 51.408719, 35.719562, 51.408719) AS distance_km;
PRINT 'scenario 2: difftent point with less distance';
SELECT food.fn_haversine_km(35.718500, 51.409500, 35.833000, 50.992000) AS distance_km;
PRINT 'scenario 3: diffrent point with large distance';
SELECT food.fn_haversine_km(35.718500, 51.409500, 29.610500, 52.531000) AS distance_km;

GO

PRINT 'fn_branches_within_distance';
PRINT 'scenario 1: tehran area branches';
SELECT * FROM food.fn_branches_within_distance(35.700000, 51.400000, 50.00)
ORDER BY distance_km;
PRINT 'scenario 2: very small radius shoudl return zero to smal rows';
SELECT * FROM food.fn_branches_within_distance(35.700000, 51.400000, 0.001);
PRINT 'scenario 3: max_delivery distance';
SELECT * FROM food.fn_branches_within_distance(35.718500, 51.409500, 800.00)
ORDER BY distance_km;
PRINT 'scenario 4: inactive branch excluded';
SELECT * FROM food.fn_branches_within_distance(36.289500, 50.004000, 5.00);

GO

PRINT 'fn_is_branch_open';
DECLARE @branch1 INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'zeytoon grill' AND b.city = 'tehran');
PRINT 'scenario 1: wednesday at 12';
SELECT food.fn_is_branch_open(@branch1, '2026-07-08 12:00:00') AS is_open; 
PRINT 'scenario 2: friday at 12';
SELECT food.fn_is_branch_open(@branch1, '2026-07-10 12:00:00') AS is_open; 
PRINT 'scenario 3: wednesday at 03';
SELECT food.fn_is_branch_open(@branch1, '2026-07-08 03:00:00') AS is_open;
PRINT 'scenario 4: nonexistent branch';
SELECT food.fn_is_branch_open(-1, SYSDATETIME()) AS is_open;

GO

PRINT 'fn_get_effective_menu_price';
DECLARE @mi_discounted INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id JOIN food.branches b ON b.branch_id = mi.branch_id JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'Zeytoon Grill' AND b.city = 'Tehran' AND f.name = 'Zeytoon Special Kabab');
DECLARE @mi_expired_discount INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id JOIN food.branches b ON b.branch_id = mi.branch_id JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'Zeytoon Grill' AND b.city = 'Tehran' AND f.name = 'Grilled Chicken Skewer');
DECLARE @mi_no_discount INT = (SELECT mi.menu_item_id FROM food.menu_items mi JOIN food.foods f ON f.food_id = mi.food_id JOIN food.branches b ON b.branch_id = mi.branch_id JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'Baradaran Pizza' AND b.city = 'Isfahan' AND f.name = 'Margherita Pizza');
PRINT 'scenario 1: menu item with active discount';
SELECT mi.price AS original_price, food.fn_get_effective_menu_price(@mi_discounted) AS effective_price
FROM food.menu_items mi WHERE mi.menu_item_id = @mi_discounted;
PRINT 'scenario 2: menu item with expired discount';
SELECT mi.price AS original_price, food.fn_get_effective_menu_price(@mi_expired_discount) AS effective_price
FROM food.menu_items mi WHERE mi.menu_item_id = @mi_expired_discount;
PRINT 'scenario 3: menu item with no discount';
SELECT mi.price AS original_price, food.fn_get_effective_menu_price(@mi_no_discount) AS effective_price
FROM food.menu_items mi WHERE mi.menu_item_id = @mi_no_discount;
PRINT 'scenario 4: nonexistent menu_item_id';
SELECT food.fn_get_effective_menu_price(-1) AS effective_price;

GO

PRINT 'fn_calculate_cart_total';
DECLARE @u_sara INT = (SELECT user_id FROM core.users WHERE username = 'sara_ahmadi');
DECLARE @u_reza INT = (SELECT user_id FROM core.users WHERE username = 'reza_karimi');
DECLARE @branch1 INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'zeytoon Grill' AND b.city = 'tehran');
DECLARE @branch7 INT = (SELECT b.branch_id FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id WHERE br.name = 'sib sabz vegan' AND b.city = 'tehran');
PRINT 'scenario 1: sara_ahmadi cart at branch1';
SELECT food.fn_calculate_cart_total(@u_sara, @branch1) AS cart_total;
PRINT 'scenario 2: sara_ahmadi cart at branch7 where she has no items in session';
SELECT food.fn_calculate_cart_total(@u_sara, @branch7) AS cart_total;
PRINT 'scenario 3: reza_karimi cart at branch1';
SELECT food.fn_calculate_cart_total(@u_reza, @branch1) AS cart_total;
PRINT 'scenario 4: nonexistent user_id and branch_id';
SELECT food.fn_calculate_cart_total(-1, -1) AS cart_total;

GO

PRINT 'fn_calculate_order_total';
DECLARE @order1 INT = (SELECT MIN(order_id) FROM food.food_orders WHERE customer_id = (SELECT user_id FROM core.users WHERE username = 'sara_ahmadi'));
PRINT 'scenario 1: sara_ahmadi first orders';
SELECT food.fn_calculate_order_total(@order1) AS order_total;
SELECT SUM(quantity * current_price) AS manual_check_total FROM food.order_items WHERE order_id = @order1;
PRINT 'scenario 2: order_id with no items at all';
SELECT food.fn_calculate_order_total(-1) AS order_total;

GO

PRINT ' fn_can_cancel_order';
DECLARE @order_pending INT = (SELECT order_id FROM food.food_orders WHERE status = 'pending');
DECLARE @order_preparing INT = (SELECT order_id FROM food.food_orders WHERE status = 'preparing');
DECLARE @order_delivered INT = (SELECT TOP 1 order_id FROM food.food_orders WHERE status = 'delivered');
DECLARE @order_cancelled INT = (SELECT order_id FROM food.food_orders WHERE status = 'cancelled');
DECLARE @order_picked_up INT = (SELECT order_id FROM food.food_orders WHERE status = 'picked_up');
PRINT 'scenario 1: user cancels pending order';
SELECT food.fn_can_cancel_order(@order_pending, 'user') AS can_cancel;
PRINT 'scenario 2: user cancels preparing order';
SELECT food.fn_can_cancel_order(@order_preparing, 'user') AS can_cancel;
PRINT 'scenario 3: restaurant cancels preparing order';
SELECT food.fn_can_cancel_order(@order_preparing, 'restaurant') AS can_cancel;
PRINT 'scenario 4: user cancels already delivered order';
SELECT food.fn_can_cancel_order(@order_delivered, 'user') AS can_cancel;
PRINT 'scenario 5: restaurant cancels already cancelled order';
SELECT food.fn_can_cancel_order(@order_cancelled, 'restaurant') AS can_cancel;
PRINT 'scenario 6: user cancels picked up order';
SELECT food.fn_can_cancel_order(@order_picked_up, 'user') AS can_cancel;

GO