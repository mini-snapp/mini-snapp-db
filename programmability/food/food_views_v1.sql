USE mini_snapp;
GO

CREATE VIEW food.vw_branch_menu AS
SELECT
    mi.menu_item_id,
    mi.branch_id,
    f.food_id,
    f.name AS food_name,
    f.category,
    mi.price,
    mi.availability_status,
    mi.estimated_prep_time,
    mi.available_from,
    mi.available_to,
    md.percentage AS discount_pct,
    md.amount AS discount_amount,
    CASE
        WHEN md.menu_discount_id IS NOT NULL THEN
            mi.price - ISNULL(md.amount, 0) - (mi.price * ISNULL(md.percentage, 0) / 100)
        ELSE mi.price
    END AS effective_price
FROM food.menu_items mi
JOIN food.foods f ON mi.food_id = f.food_id
LEFT JOIN food.menu_discounts md
    ON md.menu_item_id = mi.menu_item_id
    AND md.is_active = 1
    AND SYSDATETIME() BETWEEN md.start_at AND md.end_at

GO

CREATE VIEW food.vw_open_branches_now AS
SELECT
    b.branch_id,
    b.brand_id,
    br.name AS brand_name,
    b.city,
    b.food_type,
    b.rating,
    b.rating_count
FROM food.branches b
JOIN food.brands br ON b.brand_id = br.brand_id
WHERE b.is_active = 1
  AND EXISTS (
      SELECT 1 FROM food.work_schedules ws
      WHERE ws.branch_id = b.branch_id
        AND ws.day_of_week = DATEPART(WEEKDAY, GETDATE()) - 1
        AND ws.is_closed = 0
        AND CAST(GETDATE() AS TIME) BETWEEN ws.start_time AND ws.end_time
  )

GO

CREATE VIEW food.vw_branch_access_roster AS
SELECT 
    bo.user_id,
    br.branch_id,
    'brand_owner' AS role_type
FROM food.brand_owners bo
JOIN food.branches br ON br.brand_id = bo.brand_id
UNION ALL
SELECT 
    bwo.user_id,
    bwo.branch_id, 
    'branch_owner' AS role_type
FROM food.branch_owners bwo
UNION ALL
SELECT 
    rs.user_id,
    rs.branch_id,
    'staff' AS role_type
FROM food.restaurant_staff rs

GO

CREATE VIEW food.vw_cart_summary AS
SELECT
    ci.cart_item_id,
    ci.user_id,
    ci.branch_id,
    ci.menu_item_id,
    bm.food_name,
    ci.quantity,
    bm.effective_price AS unit_price,
    ci.quantity * bm.effective_price AS line_total,
    bm.availability_status
FROM food.cart_items ci
JOIN food.vw_branch_menu bm ON ci.menu_item_id = bm.menu_item_id

GO

CREATE VIEW food.vw_order_detail AS
SELECT
    fo.order_id, fo.customer_id, fo.status, fo.delivery_fee, fo.final_price,
    fo.allocated_discount, fo.is_takeout, fo.rating, fo.comment,
    b.branch_id, b.city, br.name AS brand_name,
    oi.order_item_id, oi.menu_item_id, f.name AS food_name,
    oi.quantity, oi.current_price, oi.quantity * oi.current_price AS line_total
FROM food.food_orders fo JOIN food.branches b ON fo.branch_id = b.branch_id
JOIN food.brands br ON b.brand_id = br.brand_id JOIN food.order_items oi ON oi.order_id = fo.order_id
JOIN food.menu_items mi ON oi.menu_item_id = mi.menu_item_id JOIN food.foods f ON mi.food_id = f.food_id;

GO 

CREATE VIEW food.vw_order_timing_analysis AS
SELECT
    fo.order_id, fo.branch_id,
    DATEDIFF(MINUTE, fo.created_at, fo.confirmed_at) AS branch_response_min,
    DATEDIFF(MINUTE, fo.confirmed_at, fo.cooking_completed_at) AS cooking_time_min,
    DATEDIFF(MINUTE, fo.cooking_completed_at, fo.handed_to_courier_at) AS courier_wait_min,
    DATEDIFF(MINUTE, fo.handed_to_courier_at, fo.delivered_at) AS delivery_time_min,
    DATEDIFF(MINUTE, fo.created_at, fo.delivered_at) AS total_time_min,
    fo.estimated_cooking_time
FROM food.food_orders fo
WHERE fo.status = 'delivered';

GO


CREATE VIEW food.vw_branches_by_brand AS
SELECT
    br.brand_id,
    br.name AS brand_name,
    b.branch_id,
    b.city,
    b.food_type,
    b.rating,
    b.is_active
FROM food.brands br JOIN food.branches b ON b.brand_id = br.brand_id;

GO

CREATE VIEW food.vw_foods_by_brand AS
SELECT
    br.brand_id,
    br.name AS brand_name,
    f.food_id,
    f.name AS food_name,
    f.category,
    mi.branch_id,
    mi.price,
    mi.availability_status
FROM food.brands br JOIN food.foods f ON f.brand_id = br.brand_id
JOIN food.menu_items mi ON mi.food_id = f.food_id;

GO

CREATE VIEW food.vw_branch_staff_roster AS
SELECT branch_id, user_id, 'owner' AS role_type FROM food.branch_owners
UNION ALL
SELECT branch_id, user_id, 'staff' AS role_type FROM food.restaurant_staff;

GO

CREATE VIEW food.vw_customer_order_history AS
SELECT
    fo.order_id,
    fo.customer_id,
    br.name AS brand_name,
    b.city,
    fo.status,
    fo.final_price,
    fo.rating,
    fo.created_at,
    fo.delivered_at
FROM food.food_orders fo JOIN food.branches b ON fo.branch_id = b.branch_id
JOIN food.brands br ON b.brand_id = br.brand_id;

GO

CREATE VIEW food.vw_customer_stats_summary AS
SELECT
    cs.user_id,
    cs.score,
    cs.rank,
    COUNT(fo.order_id) AS total_orders,
    SUM(CASE WHEN fo.status = 'delivered' THEN fo.final_price ELSE 0 END) AS total_spent
FROM food.customer_stats cs LEFT JOIN food.food_orders fo ON fo.customer_id = cs.user_id
GROUP BY cs.user_id, cs.score, cs.rank;

GO

CREATE VIEW food.vw_recent_food_logs AS
SELECT
    fl.food_log_id,
    fl.actor_id,
    u.username AS actor_username,
    fl.operation_type,
    fl.target_table,
    fl.target_id,
    fl.old_value,
    fl.new_value,
    fl.description,
    fl.log_timestamp,
    fl.branch_id
FROM food.food_logs fl LEFT JOIN core.users u ON u.user_id = fl.actor_id;

GO

CREATE VIEW food.vw_branches_in_range AS
SELECT
    b.branch_id,
    b.brand_id,
    br.name AS brand_name,
    b.city,
    b.province,
    b.food_type,
    b.rating,
    b.latitude,
    b.longitude,
    b.max_delivery_distance
FROM food.branches b JOIN food.brands br ON br.brand_id = b.brand_id
WHERE b.is_active = 1;

GO

