-- Lecture 2 - successful constraint tests
-- Run after applying 011_ticketing_integrity.sql.
--
-- All statements in this file should succeed.
-- The transaction is rolled back at the end so the test can be run repeatedly.

\set ON_ERROR_STOP on

begin;

-- =========================================================
-- 1. TRIP
-- Valid capacity and reserved seats.
-- Proves:
--   capacity >= 0
--   reserved_seats >= 0
--   reserved_seats <= capacity
--   both values are NOT NULL
-- =========================================================

update trips
set capacity = 120,
    reserved_seats = 3
where id = 'TRIP-M2-20260429-1200';


-- =========================================================
-- 2. PRODUCT
-- Valid positive price and uppercase three-letter currency.
-- Proves:
--   price >= 0
--   currency is NOT NULL
--   currency format is valid
-- =========================================================

update products
set price = 36.00,
    currency = 'DKK'
where code = 'SINGLE';


-- =========================================================
-- 3. TICKET
-- Valid ticket referencing existing user, trip and product.
-- Proves:
--   user FK
--   trip FK
--   product FK
--   ticket_code NOT NULL + UNIQUE
--   valid status
--   positive price
--   valid currency
--   valid validity window
-- =========================================================

insert into tickets (
    id,
    user_id,
    trip_id,
    ticket_code,
    status,
    product_code,
    valid_from_utc,
    valid_to_utc,
    price,
    currency
) values (
    'TICKET-SUCCESS-1',
    'USER-1',
    'TRIP-M2-20260429-1200',
    'CODE-SUCCESS-0001',
    'Active',
    'SINGLE',
    '2026-04-29 11:45:00+00',
    '2026-04-29 14:00:00+00',
    36.00,
    'DKK'
);


-- =========================================================
-- 4. PAYMENT
-- Valid payment referencing existing user and ticket.
-- Proves:
--   user FK
--   ticket FK
--   amount >= 0
--   valid currency
--   valid status
--   unique external payment reference
-- =========================================================

insert into payments (
    id,
    user_id,
    ticket_id,
    external_payment_reference,
    amount,
    currency,
    status
) values (
    'PAYMENT-SUCCESS-1',
    'USER-1',
    'TICKET-SUCCESS-1',
    'gateway-capture-success-0001',
    36.00,
    'DKK',
    'Captured'
);


-- =========================================================
-- 5. VALIDATION
-- Valid ticket ID and ticket code combination.
-- Proves the composite foreign key.
-- =========================================================

insert into validations (
    id,
    ticket_id,
    ticket_code,
    vehicle_id,
    stop_id,
    device_id,
    result
) values (
    'VALIDATION-SUCCESS-1',
    'TICKET-SUCCESS-1',
    'CODE-SUCCESS-0001',
    'METRO-M2-01',
    'STOP-CENTRAL',
    'DEVICE-02',
    'Accepted'
);


-- =========================================================
-- Evidence
-- =========================================================

select
    id,
    capacity,
    reserved_seats
from trips
where id = 'TRIP-M2-20260429-1200';


select
    code,
    price,
    currency
from products
where code = 'SINGLE';


select
    id,
    user_id,
    trip_id,
    ticket_code,
    status,
    product_code,
    price,
    currency
from tickets
where id = 'TICKET-SUCCESS-1';


select
    id,
    user_id,
    ticket_id,
    external_payment_reference,
    amount,
    currency,
    status
from payments
where id = 'PAYMENT-SUCCESS-1';


select
    id,
    ticket_id,
    ticket_code,
    result
from validations
where id = 'VALIDATION-SUCCESS-1';


-- Remove test data so this file can be run again.
rollback;