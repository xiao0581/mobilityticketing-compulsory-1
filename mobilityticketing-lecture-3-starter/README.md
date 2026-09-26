# Lecture 3 implementation lab: Where should reporting logic execute?

## Purpose

Implement and compare four approaches for producing daily captured revenue:

1. direct SQL query;
2. SQL function;
3. materialized view;
4. trigger-maintained summary table.

The goal is to compare correctness, freshness, dependencies, write cost, read cost, hidden side effects, recovery, and operational complexity.

The `payments` table is treated as the authority. Stored reporting results are derived data.


# Implemented approaches

## 1. Direct query

The reference query is located in:

`database/postgres/queries/base_revenue.sql`

It calculates captured revenue directly from:

```text
payments
    ↓
tickets
    ↓
trips
    ↓
routes
```

Because the query reads the authoritative base tables each time, corrections to payment data are visible immediately on the next execution.


## 2. SQL function

The SQL function is defined in:

`database/postgres/migrations/020_reporting_function.sql`

It wraps the reporting query in:

```text
captured_revenue_for_day(...)
```

The function does not store reporting results.

It recalculates from the base tables whenever it is executed.


## 3. Trigger-maintained summary

The trigger implementation is located in:

`database/postgres/migrations/021_daily_revenue_trigger.sql`

It maintains:

`daily_revenue_by_operator`

for newly inserted payments whose status is:

`Captured`

The supplied trigger intentionally handles only part of the payment lifecycle.

The experiments demonstrate limitations involving:

- initial historical backfill;
- `Failed -> Captured`;
- `Captured -> Refunded`;
- DELETE;
- corrections;
- duplicate payment delivery.


## 4. Materialized view

The materialized view is defined in:

`database/postgres/migrations/022_daily_captured_revenue.sql`

The view stores a derived reporting result.

It becomes current when:

```sql
refresh materialized view daily_captured_revenue;
```

Changes to the underlying payment data do not automatically update the materialized view.


# Experiment cases

The experiment cases are located in:

`database/postgres/experiments/reporting_cases.sql`

The four reporting approaches were compared against:

1. a captured payment insert;
2. a failed payment insert;
3. `Failed -> Captured`;
4. `Captured -> Refunded`;
5. deletion or replacement of test data;
6. duplicate external payment delivery.

Detailed before/after observations are recorded in:

`docs/reporting-evidence.md`


# Reporting evidence

The experiment demonstrates that the four approaches have different freshness and correction behaviour.

## Direct query

The direct query recalculates from the authoritative transactional data.

Therefore corrections, updates, and deletes are visible on the next query.

## SQL function

The function has similar freshness behaviour because it also reads the authoritative base tables when called.

Its main advantage is centralising and reusing the SQL logic.

## Materialized view

The materialized view stores a snapshot.

It may therefore become stale after the underlying payment rows change.

Its rebuild path is explicit:

```sql
refresh materialized view daily_captured_revenue;
```

## Trigger summary

The supplied trigger reacts to a newly inserted captured payment.

However, it does not automatically handle every later change to payment state.

This can cause the summary table to disagree with the authoritative payment data.


# Captured disagreement

One important disagreement occurs after:

```text
Failed -> Captured
```

The direct query and SQL function immediately include the corrected payment.

The materialized view remains stale until refresh.

The supplied trigger summary does not add the corrected payment because the trigger only reacts to INSERT.

This demonstrates why derived reporting data needs an explicit freshness and correction strategy.


# Side-effect trace

The detailed side-effect trace is located in:

`docs/side-effect-trace.md`

A captured payment INSERT can cause:

```text
Application
    ↓
INSERT payment
    ↓
constraints / references
    ↓
payment trigger
    ↓
ticket -> trip -> route lookup
    ↓
daily_revenue_by_operator update
    ↓
commit
```

The reporting-table write is therefore an implicit side effect of the payment write.


# Responsibility matrix

The comparison is documented in:

`docs/responsibility-matrix.md`

The matrix compares:

- correctness;
- freshness;
- write cost;
- read cost;
- hidden side effects;
- coupling;
- rebuildability;
- initial backfill;
- observability;
- operational complexity.

The authoritative source remains the transactional payment data.


# Issue register

The issue register is located in:

`docs/issue-register.md`

The main documented issue is that the trigger-maintained summary can become inconsistent with the authoritative payment data.

The supplied trigger does not cover every correction path and does not backfill historical data.


# Decision record

The final recommendation is documented in:

`docs/decision-record.md`

For the current MobilityTicketing case:

- transactional tables remain the authority;
- direct query or SQL function is preferred when current data is required;
- a materialized view can be introduced when reporting performance requires a stored aggregate;
- the supplied trigger-maintained summary should not be treated as the primary reporting solution in its current form.

Every stored reporting copy must have:

- a clearly named authority;
- a freshness rule;
- a rebuild path.


# What the implementation proves

The experiment demonstrates that where reporting logic executes affects more than query syntax.

The choice affects:

- freshness;
- correction behaviour;
- write-side coupling;
- hidden side effects;
- recovery;
- operational complexity.

A stored aggregate can make reads cheaper, but it introduces responsibility for keeping the derived data correct.


# What remains outside this lecture

This lecture does not solve:

- concurrent ticket purchase;
- distributed payment capture;
- complete payment idempotency;
- final production reporting architecture.

These concerns are handled in later lectures.