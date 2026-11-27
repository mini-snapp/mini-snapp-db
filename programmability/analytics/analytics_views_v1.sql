USE mini_snapp;
GO

-- =============================================
-- EXECUTIVE & MANAGERIAL BI ANALYTICAL VIEWS
-- Prerequisite: core, taxi, and food programmability objects
-- =============================================

-- 1. Daily Revenue & Running Cumulative GMV across Taxi and Food
CREATE OR ALTER VIEW core.vw_executive_daily_revenue AS
WITH daily_taxi AS (
    SELECT
        CAST(ISNULL(r.completed_at, r.requested_at) AS DATE) AS metric_date,
        'taxi' AS service_type,
        COUNT(*) AS completed_transactions,
        CAST(SUM(r.calculated_price) AS DECIMAL(18,2)) AS gross_merchandise_value,
        CAST(SUM(ISNULL(r.allocated_discount, 0)) AS DECIMAL(18,2)) AS total_discounts_allocated,
        CAST(SUM(r.calculated_price - ISNULL(r.allocated_discount, 0)) AS DECIMAL(18,2)) AS net_customer_revenue,
        CAST(
            ROUND(
                SUM((r.calculated_price - ISNULL(r.allocated_discount, 0)) * ISNULL(cr.app_share, 20.00) / 100.0),
                2
            ) AS DECIMAL(18,2)
        ) AS estimated_platform_revenue
    FROM taxi.rides r
    OUTER APPLY core.fn_get_active_commission_rate('taxi', ISNULL(r.completed_at, r.requested_at)) cr
    WHERE r.ride_status = 'completed'
    GROUP BY CAST(ISNULL(r.completed_at, r.requested_at) AS DATE)
),
daily_food AS (
    SELECT
        CAST(fo.created_at AS DATE) AS metric_date,
        'food' AS service_type,
        COUNT(*) AS completed_transactions,
        CAST(SUM(fo.final_price + ISNULL(fo.allocated_discount, 0)) AS DECIMAL(18,2)) AS gross_merchandise_value,
        CAST(SUM(ISNULL(fo.allocated_discount, 0)) AS DECIMAL(18,2)) AS total_discounts_allocated,
        CAST(SUM(fo.final_price) AS DECIMAL(18,2)) AS net_customer_revenue,
        CAST(
            ROUND(
                SUM(
                    CASE
                        WHEN (fo.final_price - fo.delivery_fee + ISNULL(fo.allocated_discount, 0)) > 0
                        THEN (fo.final_price - fo.delivery_fee + ISNULL(fo.allocated_discount, 0))
                             * ISNULL(br.commission_rate, ISNULL(cr.app_share, 10.00) / 100.0)
                        ELSE 0.00
                    END
                ),
                2
            ) AS DECIMAL(18,2)
        ) AS estimated_platform_revenue
    FROM food.food_orders fo
    JOIN food.branches b ON b.branch_id = fo.branch_id
    JOIN food.brands br ON br.brand_id = b.brand_id
    OUTER APPLY core.fn_get_active_commission_rate('food', CAST(fo.created_at AS DATETIME)) cr
    WHERE fo.status NOT IN ('cancelled')
      AND fo.final_price > 0
    GROUP BY CAST(fo.created_at AS DATE)
),
combined_daily AS (
    SELECT * FROM daily_taxi
    UNION ALL
    SELECT * FROM daily_food
)
SELECT
    metric_date,
    service_type,
    completed_transactions,
    gross_merchandise_value,
    total_discounts_allocated,
    net_customer_revenue,
    estimated_platform_revenue,
    CAST(
        SUM(net_customer_revenue) OVER (
            PARTITION BY service_type
            ORDER BY metric_date
            ROWS UNBOUNDED PRECEDING
        ) AS DECIMAL(18,2)
    ) AS cumulative_net_revenue,
    CAST(
        LAG(net_customer_revenue) OVER (
            PARTITION BY service_type
            ORDER BY metric_date
        ) AS DECIMAL(18,2)
    ) AS prev_day_net_revenue
FROM combined_daily;
GO

-- 2. Coupon Campaign Utilization & ROI Attribution
CREATE OR ALTER VIEW core.vw_coupon_campaign_roi AS
WITH usage_agg AS (
    SELECT
        cu.coupon_id,
        COUNT(DISTINCT cu.user_id) AS unique_users_redeemed,
        SUM(CASE WHEN cu.order_id IS NOT NULL THEN 1 ELSE 0 END) AS food_redemptions,
        SUM(CASE WHEN cu.ride_id IS NOT NULL THEN 1 ELSE 0 END) AS taxi_redemptions,
        CAST(
            SUM(
                CASE
                    WHEN cu.order_id IS NOT NULL THEN ISNULL(fo.allocated_discount, 0)
                    WHEN cu.ride_id IS NOT NULL THEN ISNULL(r.allocated_discount, 0)
                    ELSE 0
                END
            ) AS DECIMAL(18,2)
        ) AS total_discount_subsidy,
        CAST(
            SUM(
                CASE
                    WHEN cu.order_id IS NOT NULL AND fo.status <> 'cancelled' THEN ISNULL(fo.final_price, 0)
                    WHEN cu.ride_id IS NOT NULL AND r.ride_status <> 'cancelled'
                        THEN CASE
                                WHEN (r.calculated_price - ISNULL(r.allocated_discount, 0)) > 0
                                    THEN (r.calculated_price - ISNULL(r.allocated_discount, 0))
                                ELSE 0
                             END
                    ELSE 0
                END
            ) AS DECIMAL(18,2)
        ) AS attributed_net_revenue
    FROM core.coupon_usages cu
    LEFT JOIN food.food_orders fo ON fo.order_id = cu.order_id
    LEFT JOIN taxi.rides r ON r.ride_id = cu.ride_id
    GROUP BY cu.coupon_id
)
SELECT
    c.coupon_id,
    c.code,
    c.is_active,
    c.current_usage,
    c.max_usage,
    CAST(c.current_usage * 100.0 / NULLIF(c.max_usage, 0) AS DECIMAL(5,2)) AS utilization_pct,
    ISNULL(ua.unique_users_redeemed, 0) AS unique_users_redeemed,
    ISNULL(ua.food_redemptions, 0) AS food_redemptions,
    ISNULL(ua.taxi_redemptions, 0) AS taxi_redemptions,
    ISNULL(ua.total_discount_subsidy, 0.00) AS total_discount_subsidy,
    ISNULL(ua.attributed_net_revenue, 0.00) AS attributed_net_revenue,
    CAST(
        ISNULL(ua.attributed_net_revenue, 0.00) / NULLIF(ISNULL(ua.total_discount_subsidy, 0.00), 0.00)
        AS DECIMAL(10,2)
    ) AS revenue_to_subsidy_ratio
FROM core.coupons c
LEFT JOIN usage_agg ua ON ua.coupon_id = c.coupon_id;
GO

-- 3. Customer 360 Lifetime Value (Cross-Domain Super-App Analytics)
CREATE OR ALTER VIEW core.vw_customer_360_ltv AS
WITH taxi_agg AS (
    SELECT
        r.passenger_id AS user_id,
        COUNT(*) AS completed_rides_count,
        CAST(SUM(r.calculated_price - ISNULL(r.allocated_discount, 0)) AS DECIMAL(18,2)) AS taxi_spend,
        MAX(ISNULL(r.completed_at, r.requested_at)) AS last_taxi_at
    FROM taxi.rides r
    WHERE r.ride_status = 'completed'
    GROUP BY r.passenger_id
),
food_agg AS (
    SELECT
        fo.customer_id AS user_id,
        COUNT(*) AS delivered_food_orders_count,
        CAST(SUM(fo.final_price) AS DECIMAL(18,2)) AS food_spend,
        MAX(CAST(ISNULL(fo.delivered_at, fo.created_at) AS DATETIME)) AS last_food_at
    FROM food.food_orders fo
    WHERE fo.status = 'delivered'
    GROUP BY fo.customer_id
)
SELECT
    u.user_id,
    u.username,
    u.created_at,
    ISNULL(uw.balance, 0.00) AS wallet_balance,
    ISNULL(ta.completed_rides_count, 0) AS completed_rides_count,
    ISNULL(ta.taxi_spend, 0.00) AS taxi_spend,
    ISNULL(fa.delivered_food_orders_count, 0) AS delivered_food_orders_count,
    ISNULL(fa.food_spend, 0.00) AS food_spend,
    ISNULL(ta.completed_rides_count, 0) + ISNULL(fa.delivered_food_orders_count, 0) AS lifetime_transactions_count,
    CAST(ISNULL(ta.taxi_spend, 0.00) + ISNULL(fa.food_spend, 0.00) AS DECIMAL(18,2)) AS lifetime_total_spend,
    CAST(
        CASE
            WHEN ISNULL(ta.completed_rides_count, 0) > 0 AND ISNULL(fa.delivered_food_orders_count, 0) > 0
                THEN 1
            ELSE 0
        END AS BIT
    ) AS is_super_app_user,
    CASE
        WHEN ta.last_taxi_at IS NULL THEN fa.last_food_at
        WHEN fa.last_food_at IS NULL THEN ta.last_taxi_at
        WHEN ta.last_taxi_at >= fa.last_food_at THEN ta.last_taxi_at
        ELSE fa.last_food_at
    END AS last_activity_at,
    DENSE_RANK() OVER (
        ORDER BY (ISNULL(ta.taxi_spend, 0.00) + ISNULL(fa.food_spend, 0.00)) DESC
    ) AS ltv_rank
FROM core.users u
JOIN core.roles rl ON rl.role_id = u.role_id
LEFT JOIN core.user_wallets uw ON uw.user_id = u.user_id
LEFT JOIN taxi_agg ta ON ta.user_id = u.user_id
LEFT JOIN food_agg fa ON fa.user_id = u.user_id
WHERE u.deleted_at IS NULL
  AND rl.role_name = 'customer';
GO

-- 4. Taxi Fleet Operational KPIs by Vehicle & Service Type
CREATE OR ALTER VIEW taxi.vw_fleet_operational_kpis AS
WITH supply_stats AS (
    SELECT
        v.vehicle_type,
        vts.service_type,
        COUNT(DISTINCT v.vehicle_id) AS active_registered_vehicles,
        COUNT(DISTINCT CASE WHEN d.driver_status = 'available' THEN d.driver_id END) AS available_drivers_now
    FROM taxi.vehicles v
    JOIN taxi.vehicle_type_services vts ON vts.vehicle_type = v.vehicle_type
    JOIN taxi.drivers d ON d.driver_id = v.owner_id
    WHERE v.is_active_now = 1
    GROUP BY v.vehicle_type, vts.service_type
),
offer_stats AS (
    SELECT
        ro.vehicle_type,
        ro.service_type,
        COUNT(*) AS total_offers_created
    FROM taxi.ride_offers ro
    GROUP BY ro.vehicle_type, ro.service_type
),
ride_stats AS (
    SELECT
        v.vehicle_type,
        r.service_type,
        COUNT(*) AS total_rides_accepted,
        SUM(CASE WHEN r.ride_status = 'completed' THEN 1 ELSE 0 END) AS completed_rides,
        SUM(CASE WHEN r.ride_status = 'cancelled' THEN 1 ELSE 0 END) AS cancelled_rides,
        CAST(AVG(CASE WHEN r.ride_status = 'completed' THEN r.estimated_distance END) AS DECIMAL(10,2)) AS avg_distance_km,
        CAST(
            SUM(CASE WHEN r.ride_status = 'completed' THEN (r.calculated_price - ISNULL(r.allocated_discount, 0)) ELSE 0 END)
            AS DECIMAL(18,2)
        ) AS total_completed_gmv
    FROM taxi.rides r
    JOIN taxi.vehicles v ON v.vehicle_id = r.vehicle_id
    GROUP BY v.vehicle_type, r.service_type
)
SELECT
    vts.vehicle_type,
    vts.service_type,
    ISNULL(ss.active_registered_vehicles, 0) AS active_registered_vehicles,
    ISNULL(ss.available_drivers_now, 0) AS available_drivers_now,
    ISNULL(os.total_offers_created, 0) AS total_offers_created,
    ISNULL(rs.total_rides_accepted, 0) AS total_rides_accepted,
    ISNULL(rs.completed_rides, 0) AS completed_rides,
    ISNULL(rs.cancelled_rides, 0) AS cancelled_rides,
    CAST(ISNULL(rs.cancelled_rides, 0) * 100.0 / NULLIF(ISNULL(rs.total_rides_accepted, 0), 0) AS DECIMAL(5,2)) AS cancellation_rate_pct,
    rs.avg_distance_km,
    ISNULL(rs.total_completed_gmv, 0.00) AS total_completed_gmv
FROM taxi.vehicle_type_services vts
LEFT JOIN supply_stats ss ON ss.vehicle_type = vts.vehicle_type AND ss.service_type = vts.service_type
LEFT JOIN offer_stats os ON os.vehicle_type = vts.vehicle_type AND os.service_type = vts.service_type
LEFT JOIN ride_stats rs ON rs.vehicle_type = vts.vehicle_type AND rs.service_type = vts.service_type;
GO

-- 5. Restaurant Branch Performance Leaderboard & Kitchen SLA Compliance
CREATE OR ALTER VIEW food.vw_branch_performance_leaderboard AS
WITH order_stats AS (
    SELECT
        fo.branch_id,
        COUNT(*) AS total_orders,
        SUM(CASE WHEN fo.status = 'delivered' THEN 1 ELSE 0 END) AS delivered_orders,
        SUM(CASE WHEN fo.status IN ('cancelled', 'disputed') THEN 1 ELSE 0 END) AS cancelled_or_disputed_orders,
        CAST(SUM(CASE WHEN fo.status = 'delivered' THEN fo.final_price ELSE 0 END) AS DECIMAL(18,2)) AS delivered_gmv,
        CAST(AVG(CASE WHEN fo.status = 'delivered' THEN fo.final_price END) AS DECIMAL(10,2)) AS avg_delivered_order_value,
        CAST(
            AVG(
                CASE
                    WHEN fo.status = 'delivered' AND fo.confirmed_at IS NOT NULL AND fo.cooking_completed_at IS NOT NULL
                        THEN CAST(DATEDIFF(MINUTE, fo.confirmed_at, fo.cooking_completed_at) AS DECIMAL(10,2))
                END
            ) AS DECIMAL(10,2)
        ) AS avg_cooking_minutes,
        SUM(
            CASE
                WHEN fo.status = 'delivered'
                 AND fo.confirmed_at IS NOT NULL
                 AND fo.cooking_completed_at IS NOT NULL
                 AND fo.estimated_cooking_time IS NOT NULL
                 AND DATEDIFF(MINUTE, fo.confirmed_at, fo.cooking_completed_at) <= fo.estimated_cooking_time
                    THEN 1
                ELSE 0
            END
        ) AS on_time_cooking_count,
        SUM(
            CASE
                WHEN fo.status = 'delivered'
                 AND fo.confirmed_at IS NOT NULL
                 AND fo.cooking_completed_at IS NOT NULL
                 AND fo.estimated_cooking_time IS NOT NULL
                    THEN 1
                ELSE 0
            END
        ) AS measured_cooking_count
    FROM food.food_orders fo
    GROUP BY fo.branch_id
)
SELECT
    b.branch_id,
    b.brand_id,
    br.name AS brand_name,
    b.city,
    b.food_type,
    b.is_active,
    b.rating,
    ISNULL(bw.balance, 0.00) AS wallet_balance,
    ISNULL(os.total_orders, 0) AS total_orders,
    ISNULL(os.delivered_orders, 0) AS delivered_orders,
    ISNULL(os.cancelled_or_disputed_orders, 0) AS cancelled_or_disputed_orders,
    CAST(ISNULL(os.delivered_orders, 0) * 100.0 / NULLIF(ISNULL(os.total_orders, 0), 0) AS DECIMAL(5,2)) AS fulfillment_rate_pct,
    ISNULL(os.delivered_gmv, 0.00) AS delivered_gmv,
    os.avg_delivered_order_value,
    os.avg_cooking_minutes,
    CAST(
        ISNULL(os.on_time_cooking_count, 0) * 100.0 / NULLIF(ISNULL(os.measured_cooking_count, 0), 0)
        AS DECIMAL(5,2)
    ) AS sla_on_time_cooking_pct,
    DENSE_RANK() OVER (
        PARTITION BY b.city
        ORDER BY ISNULL(os.delivered_gmv, 0.00) DESC
    ) AS city_gmv_rank,
    DENSE_RANK() OVER (
        PARTITION BY b.brand_id
        ORDER BY ISNULL(os.delivered_gmv, 0.00) DESC
    ) AS brand_branch_rank
FROM food.branches b
JOIN food.brands br ON br.brand_id = b.brand_id
LEFT JOIN food.branch_wallets bw ON bw.branch_id = b.branch_id
LEFT JOIN order_stats os ON os.branch_id = b.branch_id;
GO

-- 6. Top-Selling Menu Items Ranked by Category Revenue
CREATE OR ALTER VIEW food.vw_top_selling_menu_items AS
WITH item_sales AS (
    SELECT
        oi.menu_item_id,
        COUNT(DISTINCT oi.order_id) AS orders_count,
        SUM(oi.quantity) AS total_units_sold,
        CAST(SUM(oi.quantity * oi.current_price) AS DECIMAL(18,2)) AS total_item_revenue
    FROM food.order_items oi
    JOIN food.food_orders fo ON fo.order_id = oi.order_id
    WHERE fo.status <> 'cancelled'
    GROUP BY oi.menu_item_id
)
SELECT
    mi.menu_item_id,
    f.food_id,
    f.name AS food_name,
    f.category,
    br.name AS brand_name,
    b.branch_id,
    b.city,
    mi.price AS listed_price,
    mi.availability_status,
    ISNULL(isa.orders_count, 0) AS orders_count,
    ISNULL(isa.total_units_sold, 0) AS total_units_sold,
    ISNULL(isa.total_item_revenue, 0.00) AS total_item_revenue,
    DENSE_RANK() OVER (
        PARTITION BY f.category
        ORDER BY ISNULL(isa.total_item_revenue, 0.00) DESC
    ) AS category_revenue_rank
FROM food.menu_items mi
JOIN food.foods f ON f.food_id = mi.food_id
JOIN food.branches b ON b.branch_id = mi.branch_id
JOIN food.brands br ON br.brand_id = b.brand_id
LEFT JOIN item_sales isa ON isa.menu_item_id = mi.menu_item_id;
GO

-- Grant BI Read Access to readonly_analyst
GRANT SELECT ON core.vw_executive_daily_revenue TO readonly_analyst;
GRANT SELECT ON core.vw_coupon_campaign_roi TO readonly_analyst;
GRANT SELECT ON core.vw_customer_360_ltv TO readonly_analyst;
GRANT SELECT ON taxi.vw_fleet_operational_kpis TO readonly_analyst;
GRANT SELECT ON food.vw_branch_performance_leaderboard TO readonly_analyst;
GRANT SELECT ON food.vw_top_selling_menu_items TO readonly_analyst;
GO
