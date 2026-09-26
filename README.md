# Compulsory Assignment 1 Review Guide

## Submitted commit

Exact submitted commit:

`PASTE-COMMIT-HASH-HERE`

## Setup and reset instructions

The repository contains the work from Lectures 1–4 in separate folders.

```text
lecture-1/
lecture-2/
lecture-3/
lecture-4/
```

Each lecture contains its own Docker Compose setup.

From the relevant lecture folder:

```bash
docker compose up -d
docker compose ps
```

To reset the database:

```bash
docker compose down -v
docker compose up -d
```

---

## Where to find the work

### Lecture 1 - Introduction to Databases

Main work:

- relational model
- workload map
- schema and seed data
- route and timetable queries

Useful files:

- `lecture-1/docs/lab.md`
- `lecture-1/database/postgres/`

One modelling decision was the key of `route_stops`.

The relation uses:

```text
(route_id, stop_sequence)
```

instead of `(route_id, stop_id)`.

This allows the same stop to appear more than once on a route, for example on a circular route.

The queries demonstrate how the model supports upcoming trips, ordered stops and routes with no trips.

---

### Lecture 2 - SQL Operations

Main work:

- integrity map
- database constraints
- successful-write tests
- rejected-write tests

Useful files:

- `lecture-2/docs/integrity-map.md`
- `lecture-2/docs/lab.md`
- `lecture-2/database/postgres/migrations/011_ticketing_integrity.sql`
- `lecture-2/database/postgres/experiments/constraints_should_succeed.sql`
- `lecture-2/database/postgres/experiments/constraints_should_fail.sql`

Examples of enforced rules include:

```text
reserved_seats <= capacity
price >= 0
valid foreign keys
unique ticket codes
valid ticket and payment statuses
```

The failed-write tests show that PostgreSQL rejects invalid persisted states even when application validation is absent.

---

### Lecture 3 - SQL Programmability

Main work:

- direct reporting query
- SQL function
- materialized view
- trigger-maintained summary
- reporting comparison

Useful files:

- `lecture-3/database/postgres/queries/base_revenue.sql`
- `lecture-3/database/postgres/migrations/020_reporting_function.sql`
- `lecture-3/database/postgres/migrations/021_daily_revenue_trigger.sql`
- `lecture-3/database/postgres/migrations/022_daily_captured_revenue.sql`
- `lecture-3/docs/lab.md`

The experiments show different freshness behaviour.

The direct query and SQL function read current base-table data.

The materialized view can become stale until it is refreshed.

The supplied trigger summary can become incorrect or incomplete when changes such as updates, refunds, deletes or historical backfill are not handled.

---

### Lecture 4 - Schema Migration

Main work:

- product-identity migrations
- old/new readers and writers
- backfill
- compatibility checks
- verification
- removal of the old reference

Useful files:

- `lecture-4/database/postgres/migrations/030_expand_product_identity.sql`
- `lecture-4/database/postgres/migrations/031_backfill_ticket_product.sql`
- `lecture-4/database/postgres/migrations/032_require_ticket_product.sql`
- `lecture-4/database/postgres/experiments/lecture04/`
- `lecture-4/docs/lab.md`

The migration changes:

```text
tickets.product_code -> products.code
```

to:

```text
tickets.product_id -> products.id
```

using:

```text
Expand -> Backfill -> Verify -> Contract
```

Old and new readers/writers can coexist during the compatibility period.

The backfill is rerunnable, and the original ticket prices and currencies remain unchanged.

---

## Two decisions worth discussing

### 1. Database constraints as the final integrity boundary

Important invariants are enforced in PostgreSQL instead of relying only on application validation.

The alternative would be application-only validation.

Database constraints were chosen because multiple applications may write to the database, and the database should prevent invalid persisted states regardless of the writer.

Evidence:

`lecture-2/database/postgres/migrations/011_ticketing_integrity.sql`

### 2. Staged product-identity migration

The product reference was migrated gradually instead of dropping `product_code` and immediately requiring `product_id`.

The direct destructive approach failed on existing data and would break old application versions.

The staged approach provides a compatibility period, backfill and verification before the old reference is removed.

Evidence:

`lecture-4/database/postgres/migrations/`

---

## One limitation / open question

The current database constraints do not solve every concurrent business rule.

For example, preventing overselling when several ticket purchases happen at the same time requires transaction and concurrency control beyond a simple check constraint.

A next step would be to investigate atomic updates, locking or transaction isolation for seat reservation.