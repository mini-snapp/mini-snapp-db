USE mini_snapp;
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
