USE mini_snapp;
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

CREATE VIEW taxi.vw_active_rides AS
SELECT
    r.ride_id, r.passenger_id, r.driver_id, r.ride_status,
    r.origin_city, r.destination_city, r.calculated_price, r.requested_at,
    d.average_rating AS driver_rating, v.vehicle_type, v.license_plate
FROM taxi.rides r
JOIN taxi.drivers d ON r.driver_id = d.driver_id JOIN taxi.vehicles v ON r.vehicle_id = v.vehicle_id
WHERE r.ride_status NOT IN ('completed','cancelled');

GO

CREATE VIEW taxi.vw_driver_current_status AS
SELECT
    d.driver_id, d.driver_status, d.average_rating, d.activity_points,
    dl.latitude, dl.longitude, dl.updated_at AS location_updated_at,
    v.vehicle_type, v.license_plate,
    r.ride_id AS active_ride_id
FROM taxi.drivers d
JOIN taxi.driver_locations dl ON dl.driver_id = d.driver_id LEFT JOIN taxi.vehicles v ON v.owner_id = d.driver_id AND v.is_active_now = 1
LEFT JOIN taxi.rides r ON r.driver_id = d.driver_id AND r.ride_status NOT IN ('completed','cancelled');

GO