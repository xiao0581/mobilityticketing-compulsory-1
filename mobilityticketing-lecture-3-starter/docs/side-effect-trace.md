# Lecture 3 Side-Effect Trace

## Selected operation

The selected write is a captured payment INSERT:

```sql
insert into payments (
    id,
    user_id,
    ticket_id,
    external_payment_reference,
    amount,
    currency,
    status,
    created_utc
) values (
    'PAY-CASE-CAPTURED',
    'USER-1',
    'TICKET-1',
    'gateway-case-captured',
    36,
    'DKK',
    'Captured',
    '2026-04-29 10:00:00+00'
);
```

## Side-effect trace

```text
Application
    |
    | INSERT payment
    v
payments
    |
    | AFTER INSERT trigger
    v
add_inserted_payment_to_daily_revenue()
    |
    | check NEW.status
    | status = Captured
    v
tickets
    |
    | find ticket trip
    v
trips
    |
    | find route
    v
routes
    |
    | obtain operator_id
    v
daily_revenue_by_operator
    |
    | INSERT or UPDATE aggregate row
    v
transaction completes
```

## 1. References and data read

The payment references:

```text
ticket_id = TICKET-1
```

The trigger then reads:

```text
tickets
-> trips
-> routes
```

to determine which operator owns the revenue.

## 2. Trigger execution

The trigger:

```text
payments_daily_revenue_after_insert
```

runs automatically after each payment INSERT.

The application does not explicitly request the reporting-table update.

This is therefore a hidden side effect of writing a payment.

## 3. Summary-table write

For a captured payment the trigger writes to:

```text
daily_revenue_by_operator
```

If the operator/date row does not exist, it inserts it.

If it already exists, it increases:

```text
captured_amount
captured_payments
```

## 4. Transaction scope

The trigger executes as part of the same payment transaction.

If the trigger raises an error, the payment INSERT can also fail.

This means reporting maintenance increases the responsibilities and possible failure points of the transactional write.

## 5. When reports become current

### Direct query

Current immediately after the payment transaction commits.

### SQL function

Current immediately after commit because it reads the base tables.

### Trigger summary

The handled captured INSERT is reflected as part of the same transaction.

However, historical rows and unsupported UPDATE/DELETE cases may still make the table incorrect.

### Materialized view

It remains stale after the payment commits.

It becomes current only after:

```sql
refresh materialized view daily_captured_revenue;
```

## 6. Application observation

The application explicitly observes only the payment operation.

Unless the application knows that the trigger exists, it may not know that the same INSERT also modifies reporting state.

This hidden coupling is one of the main disadvantages of trigger-maintained reporting.