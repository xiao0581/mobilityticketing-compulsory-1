-- Step 4: test mismatched product identity.
-- product_code points to SINGLE,
-- while product_id points to DAY.

insert into tickets
(
    id,
    user_id,
    trip_id,
    ticket_code,
    status,
    product_code,
    product_id,
    valid_from_utc,
    valid_to_utc,
    price,
    currency
)
select
    'LAB04-MISMATCH-1',
    t.user_id,
    t.trip_id,
    'LAB04-CODE-MISMATCH-1',
    t.status,
    'SINGLE',
    p.id,
    t.valid_from_utc,
    t.valid_to_utc,
    t.price,
    t.currency
from tickets t
cross join products p
where t.id = 'TICKET-1'
  and p.code = 'DAY';

select
    t.id,
    t.product_code,
    t.product_id,
    p.code as product_id_code
from tickets t
left join products p on p.id = t.product_id
where t.id = 'LAB04-MISMATCH-1';