begin;

-- Trips
alter table trips
    alter column capacity set not null,
    alter column reserved_seats set not null,

    add constraint trips_capacity_non_negative
        check (capacity >= 0),

    add constraint trips_reserved_seats_valid
        check (
            reserved_seats >= 0
            and reserved_seats <= capacity
        );


-- Tickets
alter table tickets
    alter column ticket_code set not null,
    alter column status set not null,
    alter column currency set not null,

    add constraint tickets_user_fk
        foreign key (user_id)
        references users(id),

    add constraint tickets_trip_fk
        foreign key (trip_id)
        references trips(id),

    add constraint tickets_product_fk
        foreign key (product_code)
        references products(code),

    add constraint tickets_price_non_negative
        check (price >= 0),

    add constraint tickets_currency_consistent
        check (
            currency = upper(currency)
            and char_length(currency) = 3
        ),

    add constraint tickets_ticket_code_unique
        unique (ticket_code),

    add constraint tickets_status_valid
        check (
            status in (
                'Active',
                'Validated',
                'Cancelled',
                'Expired'
            )
        ),

    add constraint tickets_validity_window
        check (
            valid_to_utc >= valid_from_utc
        ),

    add constraint tickets_id_code_unique
        unique (id, ticket_code);


-- Payments
alter table payments
    alter column ticket_id set not null,
    alter column amount set not null,
    alter column currency set not null,
    alter column status set not null,

    add constraint payments_user_fk
        foreign key (user_id)
        references users(id),

    add constraint payments_ticket_fk
        foreign key (ticket_id)
        references tickets(id),

    add constraint payments_amount_non_negative
        check (amount >= 0),

    add constraint payments_currency_consistent
        check (
            currency = upper(currency)
            and char_length(currency) = 3
        ),

    add constraint payments_status_valid
        check (
            status in (
                'Pending',
                'Captured',
                'Failed',
                'Refunded'
            )
        ),

    add constraint payments_external_reference_unique
        unique (external_payment_reference);


-- Validations
alter table validations
    alter column ticket_id set not null,
    alter column ticket_code set not null,

    add constraint validations_ticket_identity_fk
        foreign key (ticket_id, ticket_code)
        references tickets(id, ticket_code);


-- Products
alter table products
    alter column currency set not null,

    add constraint products_price_non_negative
        check (price >= 0),

    add constraint products_currency_consistent
        check (
            currency = upper(currency)
            and char_length(currency) = 3
        );


commit;