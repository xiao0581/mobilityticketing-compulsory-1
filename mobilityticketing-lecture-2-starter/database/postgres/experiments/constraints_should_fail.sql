-- Lecture 2 - negative constraint tests
-- Run after applying 011_ticketing_integrity.sql.
--
-- Every tested write below is expected to FAIL.
-- Each test is wrapped in its own transaction and rolled back,
-- so the file can be executed repeatedly.

\set ON_ERROR_STOP off
\set VERBOSITY verbose


-- =========================================================
-- TRIPS
-- =========================================================

-- 1. Capacity cannot be NULL.
-- Expected SQLSTATE: 23502 (NOT NULL violation)
begin;

update trips
set capacity = null
where id = 'TRIP-M2-20260429-0800';

rollback;


-- 2. Reserved seats cannot be NULL.
-- Expected SQLSTATE: 23502
begin;

update trips
set reserved_seats = null
where id = 'TRIP-M2-20260429-0800';

rollback;


-- 3. Capacity cannot be negative.
-- Expected SQLSTATE: 23514 (CHECK violation)
begin;

update trips
set capacity = -1
where id = 'TRIP-M2-20260429-0800';

rollback;


-- 4. Reserved seats cannot be negative.
-- Expected SQLSTATE: 23514
begin;

update trips
set reserved_seats = -1
where id = 'TRIP-M2-20260429-0800';

rollback;


-- 5. Reserved seats cannot exceed capacity.
-- Expected SQLSTATE: 23514
begin;

update trips
set reserved_seats = capacity + 1
where id = 'TRIP-M2-20260429-0800';

rollback;


-- =========================================================
-- TICKETS
-- =========================================================

-- 6. Ticket code cannot be NULL.
-- Expected SQLSTATE: 23502
begin;

insert into tickets (
    id, user_id, trip_id, ticket_code, status,
    product_code, valid_from_utc, valid_to_utc, price, currency
) values (
    'T-NULL-CODE',
    'USER-1',
    'TRIP-M2-20260429-0800',
    null,
    'Active',
    'SINGLE',
    '2026-04-29 08:00:00+00',
    '2026-04-29 09:00:00+00',
    36,
    'DKK'
);

rollback;


-- 7. Ticket status cannot be NULL.
-- Expected SQLSTATE: 23502
begin;

insert into tickets (
    id, user_id, trip_id, ticket_code, status,
    product_code, valid_from_utc, valid_to_utc, price, currency
) values (
    'T-NULL-STATUS',
    'USER-1',
    'TRIP-M2-20260429-0800',
    'CODE-NULL-STATUS',
    null,
    'SINGLE',
    '2026-04-29 08:00:00+00',
    '2026-04-29 09:00:00+00',
    36,
    'DKK'
);

rollback;


-- 8. Ticket currency cannot be NULL.
-- Expected SQLSTATE: 23502
begin;

insert into tickets (
    id, user_id, trip_id, ticket_code, status,
    product_code, valid_from_utc, valid_to_utc, price, currency
) values (
    'T-NULL-CURRENCY',
    'USER-1',
    'TRIP-M2-20260429-0800',
    'CODE-NULL-CURRENCY',
    'Active',
    'SINGLE',
    '2026-04-29 08:00:00+00',
    '2026-04-29 09:00:00+00',
    36,
    null
);

rollback;


-- 9. Ticket must reference an existing user.
-- Expected SQLSTATE: 23503 (FOREIGN KEY violation)
begin;

insert into tickets (
    id, user_id, trip_id, ticket_code, status,
    product_code, valid_from_utc, valid_to_utc, price, currency
) values (
    'T-UNKNOWN-USER',
    'USER-DOES-NOT-EXIST',
    'TRIP-M2-20260429-0800',
    'CODE-UNKNOWN-USER',
    'Active',
    'SINGLE',
    '2026-04-29 08:00:00+00',
    '2026-04-29 09:00:00+00',
    36,
    'DKK'
);

rollback;


-- 10. Ticket must reference an existing trip.
-- Expected SQLSTATE: 23503
begin;

insert into tickets (
    id, user_id, trip_id, ticket_code, status,
    product_code, valid_from_utc, valid_to_utc, price, currency
) values (
    'T-UNKNOWN-TRIP',
    'USER-1',
    'TRIP-DOES-NOT-EXIST',
    'CODE-UNKNOWN-TRIP',
    'Active',
    'SINGLE',
    '2026-04-29 08:00:00+00',
    '2026-04-29 09:00:00+00',
    36,
    'DKK'
);

rollback;


-- 11. Ticket must reference an existing product.
-- Expected SQLSTATE: 23503
begin;

insert into tickets (
    id, user_id, trip_id, ticket_code, status,
    product_code, valid_from_utc, valid_to_utc, price, currency
) values (
    'T-UNKNOWN-PRODUCT',
    'USER-1',
    'TRIP-M2-20260429-0800',
    'CODE-UNKNOWN-PRODUCT',
    'Active',
    'PRODUCT-DOES-NOT-EXIST',
    '2026-04-29 08:00:00+00',
    '2026-04-29 09:00:00+00',
    36,
    'DKK'
);

rollback;


-- 12. Ticket price cannot be negative.
-- Expected SQLSTATE: 23514
begin;

insert into tickets (
    id, user_id, trip_id, ticket_code, status,
    product_code, valid_from_utc, valid_to_utc, price, currency
) values (
    'T-NEGATIVE-PRICE',
    'USER-1',
    'TRIP-M2-20260429-0800',
    'CODE-NEGATIVE-PRICE',
    'Active',
    'SINGLE',
    '2026-04-29 08:00:00+00',
    '2026-04-29 09:00:00+00',
    -1,
    'DKK'
);

rollback;


-- 13. Ticket currency must use uppercase three-letter representation.
-- Expected SQLSTATE: 23514
begin;

insert into tickets (
    id, user_id, trip_id, ticket_code, status,
    product_code, valid_from_utc, valid_to_utc, price, currency
) values (
    'T-BAD-CURRENCY',
    'USER-1',
    'TRIP-M2-20260429-0800',
    'CODE-BAD-CURRENCY',
    'Active',
    'SINGLE',
    '2026-04-29 08:00:00+00',
    '2026-04-29 09:00:00+00',
    36,
    'dkk'
);

rollback;


-- 14. Ticket code must be unique.
-- CODE-M2-0001 already belongs to TICKET-1.
-- Expected SQLSTATE: 23505 (UNIQUE violation)
begin;

insert into tickets (
    id, user_id, trip_id, ticket_code, status,
    product_code, valid_from_utc, valid_to_utc, price, currency
) values (
    'T-DUPLICATE-CODE',
    'USER-1',
    'TRIP-M2-20260429-0800',
    'CODE-M2-0001',
    'Active',
    'SINGLE',
    '2026-04-29 08:00:00+00',
    '2026-04-29 09:00:00+00',
    36,
    'DKK'
);

rollback;


-- 15. Ticket status must come from the allowed set.
-- Expected SQLSTATE: 23514
begin;

update tickets
set status = 'Unknown'
where id = 'TICKET-1';

rollback;


-- 16. Ticket validity end cannot be earlier than its start.
-- Expected SQLSTATE: 23514
begin;

insert into tickets (
    id, user_id, trip_id, ticket_code, status,
    product_code, valid_from_utc, valid_to_utc, price, currency
) values (
    'T-REVERSED',
    'USER-1',
    'TRIP-M2-20260429-0800',
    'CODE-REVERSED',
    'Active',
    'SINGLE',
    '2026-04-29 09:00:00+00',
    '2026-04-29 08:00:00+00',
    36,
    'DKK'
);

rollback;


-- =========================================================
-- PAYMENTS
-- =========================================================

-- 17. Payment ticket ID cannot be NULL.
-- Expected SQLSTATE: 23502
begin;

insert into payments (
    id, user_id, ticket_id, external_payment_reference,
    amount, currency, status
) values (
    'P-NULL-TICKET',
    'USER-1',
    null,
    'gateway-null-ticket',
    36,
    'DKK',
    'Captured'
);

rollback;


-- 18. Payment amount cannot be NULL.
-- Expected SQLSTATE: 23502
begin;

insert into payments (
    id, user_id, ticket_id, external_payment_reference,
    amount, currency, status
) values (
    'P-NULL-AMOUNT',
    'USER-1',
    'TICKET-1',
    'gateway-null-amount',
    null,
    'DKK',
    'Captured'
);

rollback;


-- 19. Payment currency cannot be NULL.
-- Expected SQLSTATE: 23502
begin;

insert into payments (
    id, user_id, ticket_id, external_payment_reference,
    amount, currency, status
) values (
    'P-NULL-CURRENCY',
    'USER-1',
    'TICKET-1',
    'gateway-null-currency',
    36,
    null,
    'Captured'
);

rollback;


-- 20. Payment status cannot be NULL.
-- Expected SQLSTATE: 23502
begin;

insert into payments (
    id, user_id, ticket_id, external_payment_reference,
    amount, currency, status
) values (
    'P-NULL-STATUS',
    'USER-1',
    'TICKET-1',
    'gateway-null-status',
    36,
    'DKK',
    null
);

rollback;


-- 21. Payment must reference an existing user.
-- Expected SQLSTATE: 23503
begin;

insert into payments (
    id, user_id, ticket_id, external_payment_reference,
    amount, currency, status
) values (
    'P-UNKNOWN-USER',
    'USER-DOES-NOT-EXIST',
    'TICKET-1',
    'gateway-unknown-user',
    36,
    'DKK',
    'Captured'
);

rollback;


-- 22. Payment must reference an existing ticket.
-- Expected SQLSTATE: 23503
begin;

insert into payments (
    id, user_id, ticket_id, external_payment_reference,
    amount, currency, status
) values (
    'P-UNKNOWN-TICKET',
    'USER-1',
    'NO-SUCH-TICKET',
    'gateway-unknown-ticket',
    36,
    'DKK',
    'Captured'
);

rollback;


-- 23. Payment amount cannot be negative.
-- Expected SQLSTATE: 23514
begin;

insert into payments (
    id, user_id, ticket_id, external_payment_reference,
    amount, currency, status
) values (
    'P-NEGATIVE-AMOUNT',
    'USER-1',
    'TICKET-1',
    'gateway-negative-amount',
    -1,
    'DKK',
    'Captured'
);

rollback;


-- 24. Payment currency must use uppercase three-letter representation.
-- Expected SQLSTATE: 23514
begin;

insert into payments (
    id, user_id, ticket_id, external_payment_reference,
    amount, currency, status
) values (
    'P-BAD-CURRENCY',
    'USER-1',
    'TICKET-1',
    'gateway-bad-currency',
    36,
    'dkk',
    'Captured'
);

rollback;


-- 25. Payment status must come from the allowed set.
-- Expected SQLSTATE: 23514
begin;

insert into payments (
    id, user_id, ticket_id, external_payment_reference,
    amount, currency, status
) values (
    'P-BAD-STATUS',
    'USER-1',
    'TICKET-1',
    'gateway-bad-status',
    36,
    'DKK',
    'Unknown'
);

rollback;


-- 26. External payment reference must be unique.
-- gateway-capture-0001 already exists.
-- Expected SQLSTATE: 23505
begin;

insert into payments (
    id, user_id, ticket_id, external_payment_reference,
    amount, currency, status
) values (
    'P-DUPLICATE-REFERENCE',
    'USER-1',
    'TICKET-1',
    'gateway-capture-0001',
    36,
    'DKK',
    'Captured'
);

rollback;


-- =========================================================
-- VALIDATIONS
-- =========================================================

-- 27. Validation ticket ID cannot be NULL.
-- Expected SQLSTATE: 23502
begin;

insert into validations (
    id, ticket_id, ticket_code,
    vehicle_id, stop_id, device_id, result
) values (
    'V-NULL-TICKET-ID',
    null,
    'CODE-M2-0001',
    'METRO-M2-01',
    'STOP-CENTRAL',
    'DEVICE-01',
    'Accepted'
);

rollback;


-- 28. Validation ticket code cannot be NULL.
-- Expected SQLSTATE: 23502
begin;

insert into validations (
    id, ticket_id, ticket_code,
    vehicle_id, stop_id, device_id, result
) values (
    'V-NULL-TICKET-CODE',
    'TICKET-1',
    null,
    'METRO-M2-01',
    'STOP-CENTRAL',
    'DEVICE-01',
    'Accepted'
);

rollback;


-- 29. Ticket ID and ticket code must belong to the same ticket.
-- TICKET-1 belongs to CODE-M2-0001,
-- while CODE-5C-0001 belongs to TICKET-2.
-- Expected SQLSTATE: 23503
begin;

insert into validations (
    id, ticket_id, ticket_code,
    vehicle_id, stop_id, device_id, result
) values (
    'V-MISMATCH',
    'TICKET-1',
    'CODE-5C-0001',
    'BUS-5C-01',
    'STOP-CENTRAL',
    'DEVICE-01',
    'Accepted'
);

rollback;


-- =========================================================
-- PRODUCTS
-- =========================================================

-- 30. Product currency cannot be NULL.
-- Expected SQLSTATE: 23502
begin;

update products
set currency = null
where code = 'SINGLE';

rollback;


-- 31. Product price cannot be negative.
-- Expected SQLSTATE: 23514
begin;

update products
set price = -1
where code = 'SINGLE';

rollback;


-- 32. Product currency must use uppercase three-letter representation.
-- Expected SQLSTATE: 23514
begin;

update products
set currency = 'dkk'
where code = 'SINGLE';

rollback;