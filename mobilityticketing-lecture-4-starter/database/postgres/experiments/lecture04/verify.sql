-- Lecture 4 - Step 5 verification

-- 1. Verify that every ticket has a valid and matching product_id.
-- Expected result: 0 rows.

select
    t.id,
    t.product_code,
    t.product_id
from tickets t
left join products p on p.id = t.product_id
where t.product_id is null
   or p.id is null
   or t.product_code is distinct from p.code;


-- 2. Compare the original tickets with the baseline values.

select
    id,
    product_code,
    product_id,
    price,
    currency
from tickets
where id in ('TICKET-1', 'TICKET-2', 'TICKET-3')
order by id;