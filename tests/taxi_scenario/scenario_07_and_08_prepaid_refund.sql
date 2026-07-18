USE mini_snapp;
GO


PRINT '--- TAXI SCENARIO 7 | STEP 1: Create Scheduled Prepaid Ride ---';
DECLARE @p_id INT = (SELECT TOP 1 user_id FROM core.users WHERE username = 'demo_pass1');
DECLARE @sched_offer INT, @sched_ride INT;
DECLARE @tomorrow DATETIME = DATEADD(DAY, 1, GETDATE());


EXEC taxi.sp_create_ride_offer @p_id, 35.0, 51.0, 35.5, 51.5, 'economy', 'passenger', 5, 5, 1, @tomorrow, @sched_offer OUTPUT;


DECLARE @actual_candidate INT = (SELECT TOP 1 driver_id FROM taxi.ride_offer_candidates WHERE offer_id = @sched_offer);


EXEC taxi.sp_respond_to_ride_offer @sched_offer, @actual_candidate, 'accepted', @sched_ride OUTPUT;

SELECT 
    ride_id, ride_status, ride_payment_status, scheduled_start_time 
FROM taxi.rides WHERE ride_id = @sched_ride;

PRINT '--- TAXI SCENARIO 8 | STEP 1: Check Passenger Wallet Before Cancel ---';
DECLARE @wallet_before DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @p_id);

PRINT '--- TAXI SCENARIO 8 | STEP 2: Driver Cancels the Ride ---';

EXEC taxi.sp_cancel_ride @ride_id = @sched_ride, @cancel_reason = 'Car broke down';


SELECT 
    ride_status, ride_payment_status, cancel_reason 
FROM taxi.rides WHERE ride_id = @sched_ride;

PRINT '--- TAXI SCENARIO 8 | STEP 3: Check Core Audit and Refund ---';

SELECT TOP 1 transaction_type, transaction_status, amount 
FROM core.transactions WHERE user_id = @p_id ORDER BY transaction_id DESC;

DECLARE @wallet_after DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @p_id);
SELECT 
    @wallet_before AS Wallet_Before_Cancel, 
    @wallet_after AS Wallet_After_Refund;
GO