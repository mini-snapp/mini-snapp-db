USE mini_snapp;
GO

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- =============================================
-- PERFORMANCE & QUERY OPTIMIZATION INDEXES
-- Consolidates covering, composite, and filtered indexes
-- across core, taxi, and food schemas.
-- =============================================

-- Clean up legacy taxi index names if upgrading an existing database
DROP INDEX IF EXISTS IX_rides_passenger_id ON taxi.rides;
DROP INDEX IF EXISTS IX_rides_driver_id ON taxi.rides;
DROP INDEX IF EXISTS IX_ride_offers_passenger_id ON taxi.ride_offers;
DROP INDEX IF EXISTS IX_ride_offer_candidates_driver_id ON taxi.ride_offer_candidates;
GO

-- =============================================
-- 1. CORE SCHEMA INDEXES (8)
-- =============================================

-- User transaction ledger sorted newest-first for wallet history & analytics
DROP INDEX IF EXISTS ix_transactions_user_created ON core.transactions;
CREATE NONCLUSTERED INDEX ix_transactions_user_created
    ON core.transactions (user_id, created_at DESC)
    INCLUDE (transaction_type, transaction_status, amount, payment_method);
GO

-- Active promo coupon lookup by code (covers validation fields)
DROP INDEX IF EXISTS ix_coupons_active_lookup ON core.coupons;
CREATE NONCLUSTERED INDEX ix_coupons_active_lookup
    ON core.coupons (code)
    INCLUDE ([percentage], amount, min_requirement, max_cap, [expiry_date], current_usage, max_usage)
    WHERE is_active = 1;
GO

-- Fast per-user single-use validation in core.fn_validate_coupon
DROP INDEX IF EXISTS ix_coupon_usages_user_coupon ON core.coupon_usages;
CREATE NONCLUSTERED INDEX ix_coupon_usages_user_coupon
    ON core.coupon_usages (user_id, coupon_id);
GO

-- Filtered FK indexes on polymorphic coupon usage links
DROP INDEX IF EXISTS ix_coupon_usages_order_id ON core.coupon_usages;
CREATE NONCLUSTERED INDEX ix_coupon_usages_order_id
    ON core.coupon_usages (order_id)
    INCLUDE (coupon_id, user_id)
    WHERE order_id IS NOT NULL;
GO

DROP INDEX IF EXISTS ix_coupon_usages_ride_id ON core.coupon_usages;
CREATE NONCLUSTERED INDEX ix_coupon_usages_ride_id
    ON core.coupon_usages (ride_id)
    INCLUDE (coupon_id, user_id)
    WHERE ride_id IS NOT NULL;
GO

-- Filtered queue index for active moderation complaints
DROP INDEX IF EXISTS ix_complaints_open_queue ON core.complaints;
CREATE NONCLUSTERED INDEX ix_complaints_open_queue
    ON core.complaints (complaint_status, created_at DESC)
    INCLUDE (title, target_type, target_id, reporter_id, assigned_admin_id)
    WHERE complaint_status IN ('open', 'in_review');
GO

-- Point-in-time temporal lookup for commission rates
DROP INDEX IF EXISTS ix_commission_rates_lookup ON core.commission_rates;
CREATE NONCLUSTERED INDEX ix_commission_rates_lookup
    ON core.commission_rates (service_type, effective_from DESC)
    INCLUDE (driver_share, restaurant_share, app_share, effective_to);
GO

-- Audit trail inspection by entity
DROP INDEX IF EXISTS ix_core_logs_target ON core.core_logs;
CREATE NONCLUSTERED INDEX ix_core_logs_target
    ON core.core_logs (target_table, target_id, created_at DESC);
GO

-- =============================================
-- 2. TAXI SCHEMA INDEXES (8)
-- =============================================

-- Filtered dispatch index: only available drivers enter nearest-driver scans
DROP INDEX IF EXISTS ix_drivers_available ON taxi.drivers;
CREATE NONCLUSTERED INDEX ix_drivers_available
    ON taxi.drivers (driver_id)
    INCLUDE (user_id, average_rating, activity_points)
    WHERE driver_status = 'available';
GO

-- Filtered fleet index: only the driver's currently active vehicle
DROP INDEX IF EXISTS ix_vehicles_owner_active ON taxi.vehicles;
CREATE NONCLUSTERED INDEX ix_vehicles_owner_active
    ON taxi.vehicles (owner_id, vehicle_type)
    INCLUDE (vehicle_id, license_plate)
    WHERE is_active_now = 1;
GO

-- Point-in-time temporal lookup for taxi pricing parameters
DROP INDEX IF EXISTS ix_pricing_parameters_lookup ON taxi.pricing_parameters;
CREATE NONCLUSTERED INDEX ix_pricing_parameters_lookup
    ON taxi.pricing_parameters (vehicle_type, service_type, effective_from DESC)
    INCLUDE (base_fare, price_per_km, price_per_minute, effective_to);
GO

-- Covering index for passenger ride history API
DROP INDEX IF EXISTS ix_rides_passenger_history ON taxi.rides;
CREATE NONCLUSTERED INDEX ix_rides_passenger_history
    ON taxi.rides (passenger_id, requested_at DESC)
    INCLUDE (ride_status, ride_payment_status, service_type, calculated_price, allocated_discount, completed_at);
GO

-- Filtered index for active in-progress/scheduled rides
DROP INDEX IF EXISTS ix_rides_active ON taxi.rides;
CREATE NONCLUSTERED INDEX ix_rides_active
    ON taxi.rides (passenger_id, driver_id, ride_status)
    INCLUDE (vehicle_id, service_type, origin_latitude, origin_longitude, destination_latitude, destination_longitude, calculated_price, ride_payment_status, requested_at, started_at)
    WHERE ride_status IN ('scheduled', 'to_origin', 'to_destination');
GO

-- Filtered covering index for driver earnings & completed ride KPIs
DROP INDEX IF EXISTS ix_rides_driver_completed ON taxi.rides;
CREATE NONCLUSTERED INDEX ix_rides_driver_completed
    ON taxi.rides (driver_id)
    INCLUDE (calculated_price, allocated_discount, completed_at, passenger_rating_to_driver)
    WHERE ride_status = 'completed';
GO

-- Active/recent ride offers per passenger
DROP INDEX IF EXISTS ix_ride_offers_passenger_expires ON taxi.ride_offers;
CREATE NONCLUSTERED INDEX ix_ride_offers_passenger_expires
    ON taxi.ride_offers (passenger_id, expires_at DESC)
    INCLUDE (vehicle_type, service_type, calculated_price, is_prepaid);
GO

-- Filtered index for driver pending offer inbox
DROP INDEX IF EXISTS ix_ride_offer_candidates_driver_pending ON taxi.ride_offer_candidates;
CREATE NONCLUSTERED INDEX ix_ride_offer_candidates_driver_pending
    ON taxi.ride_offer_candidates (driver_id, offer_id)
    WHERE response_status = 'pending';
GO

-- =============================================
-- 3. FOOD SCHEMA INDEXES (7)
-- =============================================

-- Filtered geospatial branch discovery index
DROP INDEX IF EXISTS ix_branches_active_geo ON food.branches;
CREATE NONCLUSTERED INDEX ix_branches_active_geo
    ON food.branches (brand_id, city)
    INCLUDE (latitude, longitude, max_delivery_distance, food_type, rating, rating_count, province)
    WHERE is_active = 1;
GO

-- Covering index for branch menu rendering
DROP INDEX IF EXISTS ix_menu_items_branch_available ON food.menu_items;
CREATE NONCLUSTERED INDEX ix_menu_items_branch_available
    ON food.menu_items (branch_id, availability_status)
    INCLUDE (food_id, price, estimated_prep_time, available_from, available_to);
GO

-- Filtered index for active menu item discounts
DROP INDEX IF EXISTS ix_menu_discounts_active ON food.menu_discounts;
CREATE NONCLUSTERED INDEX ix_menu_discounts_active
    ON food.menu_discounts (menu_item_id, start_at, end_at)
    INCLUDE (percentage, amount)
    WHERE is_active = 1;
GO

-- Covering index for customer food order history
DROP INDEX IF EXISTS ix_food_orders_customer_created ON food.food_orders;
CREATE NONCLUSTERED INDEX ix_food_orders_customer_created
    ON food.food_orders (customer_id, created_at DESC)
    INCLUDE (branch_id, status, final_price, delivery_fee, allocated_discount, is_takeout, rating, delivered_at);
GO

-- Covering index for branch kitchen operations & SLA timing analytics
DROP INDEX IF EXISTS ix_food_orders_branch_status ON food.food_orders;
CREATE NONCLUSTERED INDEX ix_food_orders_branch_status
    ON food.food_orders (branch_id, status, created_at DESC)
    INCLUDE (customer_id, final_price, delivery_fee, allocated_discount, confirmed_at, cooking_completed_at, handed_to_courier_at, delivered_at, estimated_cooking_time);
GO

-- Covering index for order total calculation and line-item reporting
DROP INDEX IF EXISTS ix_order_items_order_id ON food.order_items;
CREATE NONCLUSTERED INDEX ix_order_items_order_id
    ON food.order_items (order_id)
    INCLUDE (menu_item_id, quantity, current_price);
GO

-- Branch audit trail inspection ordered by newest first
DROP INDEX IF EXISTS ix_food_logs_branch_timestamp ON food.food_logs;
CREATE NONCLUSTERED INDEX ix_food_logs_branch_timestamp
    ON food.food_logs (branch_id, log_timestamp DESC)
    INCLUDE (actor_id, operation_type, target_table, target_id);
GO
