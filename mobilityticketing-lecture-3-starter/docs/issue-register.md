# Lecture 3 Issue Register

## Issue 1 - Trigger-maintained reporting becomes incorrect after corrections

### Evidence

The supplied trigger is:

```text
AFTER INSERT ON payments
```

and only adds revenue when the inserted payment already has:

```text
status = Captured
```

### Problem

Real payment data can change after insertion.

Examples include:

```text
Failed -> Captured
Captured -> Refunded
DELETE
```

The supplied trigger does not react to these operations.

### Consequence

`daily_revenue_by_operator` can disagree with the authoritative `payments` data.

The reporting table may therefore look current while actually containing stale or incorrect information.

### Additional problem

The summary table is created after the starter payments already exist.

No initial backfill is performed.

This means the summary is incomplete from the moment it is created.

### Possible solutions

Possible approaches include:

1. Add INSERT, UPDATE, DELETE and backfill logic to the trigger design.
2. Provide a deterministic rebuild process for the summary table.
3. Avoid the trigger summary and calculate from the base tables.
4. Use a materialized view with an explicit refresh policy.

### Open question

How fresh does the revenue report actually need to be?

The answer determines whether synchronous trigger maintenance is worth its additional coupling and complexity.