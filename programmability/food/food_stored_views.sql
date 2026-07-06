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