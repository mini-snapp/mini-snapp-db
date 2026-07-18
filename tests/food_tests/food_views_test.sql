USE mini_snapp;
GO

PRINT 'vw_branch_menu';
SELECT * FROM food.vw_branch_menu ORDER BY branch_id, menu_item_id;

GO

PRINT 'vw_open_branches_now';
SELECT * FROM food.vw_open_branches_now ORDER BY branch_id;

GO

PRINT 'vw_branch_access_roster';
SELECT * FROM food.vw_branch_access_roster ORDER BY branch_id, role_type;

GO

PRINT 'vw_cart_summary';
SELECT * FROM food.vw_cart_summary ORDER BY user_id, branch_id;

GO

PRINT 'vw_order_detail';
SELECT * FROM food.vw_order_detail ORDER BY order_id;

GO

PRINT 'vw_order_timing_analysis';
SELECT * FROM food.vw_order_timing_analysis ORDER BY order_id;

GO



PRINT 'vw_branches_by_brand';
SELECT * FROM food.vw_branches_by_brand ORDER BY brand_id, branch_id;

GO

PRINT 'vw_foods_by_brand';
SELECT * FROM food.vw_foods_by_brand ORDER BY brand_id, food_id, branch_id;

GO

PRINT '=== 11. food.vw_branch_staff_roster ===';
SELECT * FROM food.vw_branch_staff_roster ORDER BY branch_id, role_type;
GO

PRINT 'vw_customer_order_history';
SELECT * FROM food.vw_customer_order_history ORDER BY customer_id, created_at;

GO

PRINT 'vw_customer_stats_summary';
SELECT * FROM food.vw_customer_stats_summary ORDER BY user_id;

GO

PRINT 'vw_recent_food_logs';
SELECT * FROM food.vw_recent_food_logs ORDER BY log_timestamp DESC;
GO

PRINT 'vw_branches_in_range';
SELECT * FROM food.vw_branches_in_range ORDER BY branch_id;

GO