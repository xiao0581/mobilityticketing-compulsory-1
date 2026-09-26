-- Lecture 4 - Step 1 baseline
-- Record the existing state before changing product identity.

-- 1. Show the available products
select
    code,
    price,
    currency
from products
order by code;


-- 2. Verify that every existing ticket points to a valid product.
-- Expected result: 0 rows.

select t.id, t.product_code
from tickets t
left join products p on p.code = t.product_code
where t.product_code is null
   or p.code is null;


-- 3. Record existing tickets before the migration.
-- These values will be compared again later.

select
    id,
    product_code,
    price,
    currency
from tickets
order by id;