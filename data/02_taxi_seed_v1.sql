USE mini_snapp;
GO

INSERT INTO taxi.vehicle_type_services (vehicle_type, service_type) VALUES 
('economy', 'passenger'), ('premium', 'passenger'), ('motorcycle', 'cargo'), ('pickup', 'cargo');
GO


INSERT INTO taxi.pricing_parameters (vehicle_type, service_type, base_fare, price_per_km, price_per_minute, effective_from) VALUES 
('economy', 'passenger', 10.00, 2.00, 0.50, DATEADD(MONTH, -1, GETDATE())),
('premium', 'passenger', 25.00, 4.00, 1.00, DATEADD(MONTH, -1, GETDATE())),
('motorcycle', 'cargo', 5.00, 1.50, 0.20, DATEADD(MONTH, -1, GETDATE()));
GO

DECLARE @arash_uid INT = (SELECT user_id FROM core.users WHERE username = 'arash');
INSERT INTO taxi.drivers (user_id, national_id, date_of_birth, driver_status, gender) 
VALUES (@arash_uid, '0012345678', '1995-05-15', 'available', 'male');

DECLARE @arash_d_id INT = SCOPE_IDENTITY();
INSERT INTO taxi.driver_wallets (driver_id, balance) VALUES (@arash_d_id, 150.00);
INSERT INTO taxi.vehicles (owner_id, vehicle_type, license_plate, color, model_name, is_active_now) 
VALUES (@arash_d_id, 'economy', '11-A-123', 'White', 'Pride', 1);
INSERT INTO taxi.driver_locations (driver_id, latitude, longitude, updated_at) 
VALUES (@arash_d_id, 35.7010, 51.4010, GETDATE());


DECLARE @d2_uid INT;
DECLARE @rl_id INT =  (SELECT role_id FROM core.roles WHERE role_name = 'driver');
EXEC core.sp_register_user @username = 'driver_reza', @password_hash = 'hash', @registration_phone = '09201112233', @role_id =@rl_id, @new_user_id = @d2_uid OUTPUT;

INSERT INTO taxi.drivers (user_id, national_id, date_of_birth, driver_status, gender) 
VALUES (@d2_uid, '0087654321', '1992-08-20', 'available', 'male');

DECLARE @reza_d_id INT = SCOPE_IDENTITY();
INSERT INTO taxi.driver_wallets (driver_id, balance) VALUES (@reza_d_id, 200.00);
INSERT INTO taxi.vehicles (owner_id, vehicle_type, license_plate, color, model_name, is_active_now) 
VALUES (@reza_d_id, 'economy', '22-B-456', 'Silver', 'Tiba', 1);
INSERT INTO taxi.driver_locations (driver_id, latitude, longitude, updated_at) 
VALUES (@reza_d_id, 35.7020, 51.4020, GETDATE());
GO


DECLARE @avesta_uid INT = (SELECT user_id FROM core.users WHERE username = 'avesta');
DECLARE @kian_uid INT = (SELECT user_id FROM core.users WHERE username = 'kian_ce');

INSERT INTO taxi.passenger_stats (user_id, average_score, score_count, activity_score) VALUES
(@avesta_uid, 4.8, 12, 120),
(@kian_uid, 4.5, 8, 80);
GO