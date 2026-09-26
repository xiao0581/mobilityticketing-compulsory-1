-- Old writer: represents the old application.
-- It knows only product_code and does not write product_id.

\set ticket_id 'LAB04-OLD-AFTER-NOTNULL'
\set ticket_code 'LAB04-CODE-AFTER-NOTNULL'

insert into tickets
    (
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
    )
select
    :'ticket_id',
    user_id,
    trip_id,
    :'ticket_code',
    status,
    product_code,
    valid_from_utc,
    valid_to_utc,
    price,
    currency
from tickets
where id = 'TICKET-1';