-- Final writer.
-- Uses product_id only.

\set ticket_id 'LAB04-FINAL-1'
\set ticket_code 'LAB04-CODE-FINAL-1'

select id as product_id
from products
where code = 'DAY'
\gset

insert into tickets
(
    id,
    user_id,
    trip_id,
    ticket_code,
    status,
    product_id,
    valid_from_utc,
    valid_to_utc,
    price,
    currency
)
values
(
    :'ticket_id',
    'USER-1',
    'TRIP-M2-20260429-1200',
    :'ticket_code',
    'Active',
    :'product_id'::uuid,
    '2026-04-29 00:00:00+00',
    '2026-04-30 00:00:00+00',
    80.00,
    'DKK'
);