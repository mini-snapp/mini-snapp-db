USE mini_snapp;
GO

-- =============================================
-- SECTION 0: Clear existing data before re-seeding
-- =============================================
DELETE FROM taxi.taxi_logs;
DELETE FROM taxi.ride_payments;
DELETE FROM taxi.rides;
DELETE FROM taxi.ride_offer_candidates;
DELETE FROM taxi.ride_offers;
DELETE FROM taxi.passenger_stats;
DELETE FROM taxi.pricing_parameters;
DELETE FROM taxi.driver_locations;
DELETE FROM taxi.vehicles;
DELETE FROM taxi.driver_wallets;
DELETE FROM taxi.drivers;
DELETE FROM taxi.vehicle_type_services;
GO

DBCC CHECKIDENT ('taxi.taxi_logs', RESEED, 0);
DBCC CHECKIDENT ('taxi.rides', RESEED, 0);
DBCC CHECKIDENT ('taxi.ride_offer_candidates', RESEED, 0);
DBCC CHECKIDENT ('taxi.ride_offers', RESEED, 0);
DBCC CHECKIDENT ('taxi.pricing_parameters', RESEED, 0);
DBCC CHECKIDENT ('taxi.vehicles', RESEED, 0);
DBCC CHECKIDENT ('taxi.drivers', RESEED, 0);
GO

-- =============================================
-- PART 1: Direct inserts — base tables
-- =============================================

-- ── vehicle_type_services ──
INSERT INTO taxi.vehicle_type_services (vehicle_type, service_type) VALUES
('economy',    'passenger'),
('premium',    'passenger'),
('suv',        'passenger'),
('motorcycle', 'passenger'),
('motorcycle', 'cargo'),
('pickup',     'cargo'),
('truck',      'cargo');
GO

-- ── pricing_parameters ──
INSERT INTO taxi.pricing_parameters (vehicle_type, service_type, base_fare, price_per_km, price_per_minute, effective_from, effective_to) VALUES
('economy',    'passenger', 15000.00, 2000.00, 500.00, DATEADD(MONTH, -1, GETDATE()), NULL),
('premium',    'passenger', 30000.00, 4000.00, 1000.00, DATEADD(MONTH, -1, GETDATE()), NULL),
('motorcycle', 'passenger', 10000.00, 1500.00, 300.00, DATEADD(MONTH, -1, GETDATE()), NULL),
('motorcycle', 'cargo',     12000.00, 1800.00, 400.00, DATEADD(MONTH, -1, GETDATE()), NULL);
GO

-- ── drivers ──
DECLARE @amir_id INT = (SELECT user_id FROM core.users WHERE username = 'driver_amir');
DECLARE @neda_id INT = (SELECT user_id FROM core.users WHERE username = 'driver_neda');
DECLARE @kaveh_id INT = (SELECT user_id FROM core.users WHERE username = 'driver_kaveh');

INSERT INTO taxi.drivers (user_id, national_id, date_of_birth, gender, driver_status, average_rating, rating_count, activity_points) VALUES
(@amir_id,  '0011223344', '1990-05-14', 'male',   'available', 4.80, 150, 1200),
(@neda_id,  '0022334455', '1992-08-22', 'female', 'available', 4.95, 210, 1800),
(@kaveh_id, '0033445566', '1985-11-30', 'male',   'offline',   3.20, 45,  150);
GO

-- ── driver_wallets ──
INSERT INTO taxi.driver_wallets (driver_id, balance)
SELECT driver_id, 0.00 FROM taxi.drivers;
GO

-- ── vehicles ──
DECLARE @drv_amir INT = (SELECT driver_id FROM taxi.drivers WHERE national_id = '0011223344');
DECLARE @drv_neda INT = (SELECT driver_id FROM taxi.drivers WHERE national_id = '0022334455');
DECLARE @drv_kaveh INT = (SELECT driver_id FROM taxi.drivers WHERE national_id = '0033445566');

INSERT INTO taxi.vehicles (owner_id, vehicle_type, license_plate, color, model_name, is_active_now) VALUES
(@drv_amir, 'economy',    '11A11111', 'White', 'Peugeot 206', 1),
(@drv_neda, 'premium',    '22B22222', 'Black', 'Kia Optima',  1),
(@drv_neda, 'motorcycle', '33C33333', 'Red',   'Honda CG',    0), -- Neda has a second inactive vehicle
(@drv_kaveh,'economy',    '44D44444', 'Silver','Pride 131',   1);
GO
DECLARE @drv_amir INT = (SELECT driver_id FROM taxi.drivers WHERE national_id = '0011223344');
DECLARE @drv_neda INT = (SELECT driver_id FROM taxi.drivers WHERE national_id = '0022334455');
DECLARE @drv_kaveh INT = (SELECT driver_id FROM taxi.drivers WHERE national_id = '0033445566');

-- ── driver_locations ──
INSERT INTO taxi.driver_locations (driver_id, latitude, longitude, updated_at) VALUES
(@drv_amir,  35.71960000, 51.40880000, GETDATE()), -- Near Sara Ahmadi's Home
(@drv_neda,  35.73000000, 51.42550000, GETDATE()), -- Near Sara's Work
(@drv_kaveh, 35.70000000, 51.38700000, GETDATE());
GO