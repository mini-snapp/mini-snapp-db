USE mini_snapp;
GO

PRINT '--- TAXI SCENARIO 7 | STEP 1: Create Scheduled Prepaid Ride ---';
DECLARE @p_id INT = ISNULL(
    (SELECT TOP 1 user_id FROM core.users WHERE username = 'demo_pass1'),
    (SELECT TOP 1 user_id FROM core.users WHERE username = 'avesta')
);
EXEC core.sp_charge_wallet @p_id, 50.00, 'card';

DECLARE @wallet_before_offer DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @p_id);
DECLARE @sched_offer INT, @sched_ride INT;
DECLARE @tomorrow DATETIME = DATEADD(DAY, 1, GETDATE());

EXEC taxi.sp_create_ride_offer
    @passenger_id = @p_id,
    @origin_latitude = 35.70100000, @origin_longitude = 51.40100000,
    @destination_latitude = 35.72500000, @destination_longitude = 51.42500000,
    @vehicle_type = 'economy', @service_type = 'passenger',
    @candidate_count = 5, @offer_ttl_minutes = 5, @is_prepaid = 1, @scheduled_start_time = @tomorrow,
    @new_offer_id = @sched_offer OUTPUT;

DECLARE @actual_candidate INT = (SELECT TOP 1 driver_id FROM taxi.ride_offer_candidates WHERE offer_id = @sched_offer);

EXEC taxi.sp_respond_to_ride_offer @sched_offer, @actual_candidate, 'accepted', @sched_ride OUTPUT;

SELECT ride_id, ride_status, ride_payment_status, calculated_price, scheduled_start_time
FROM taxi.rides WHERE ride_id = @sched_ride;

PRINT '--- TAXI SCENARIO 8 | STEP 1: Check Passenger Wallet After Upfront Prepaid Deduction ---';
DECLARE @wallet_after_accept DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @p_id);

PRINT '--- TAXI SCENARIO 8 | STEP 2: Driver Cancels the Ride ---';
EXEC taxi.sp_cancel_ride @ride_id = @sched_ride, @cancel_reason = 'Vehicle mechanical issue';

SELECT ride_status, ride_payment_status, cancel_reason
FROM taxi.rides WHERE ride_id = @sched_ride;

PRINT '--- TAXI SCENARIO 8 | STEP 3: Verify Full Escrow Refund ---';
SELECT TOP 1 transaction_type, transaction_status, amount
FROM core.transactions WHERE user_id = @p_id ORDER BY transaction_id DESC;

DECLARE @wallet_after_refund DECIMAL(10,2) = (SELECT balance FROM core.user_wallets WHERE user_id = @p_id);
SELECT
    @wallet_before_offer AS Wallet_Before_Prepaid_Offer,
    @wallet_after_accept AS Wallet_After_Upfront_Accept,
    @wallet_after_refund AS Wallet_After_Cancel_Refund;
GO
