# MobilityTicketing - Compulsory Assignment 1

This repository contains the work from Lectures 1–4 of the MobilityTicketing database project.

Each lecture folder contains its own detailed README, SQL implementation and supporting documentation.

## Setup

Each lecture has its own Docker Compose configuration.

Open the relevant lecture folder and run:

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

## Lecture 1 - Relational modelling

Folder:

`mobilityticketing-lecture-1-starter`

Main work:

- relational schema
- seed data
- ER diagram
- route and timetable queries
- modelling assumptions and functional dependency

Useful files:

- `docs/lab.md`
- `database/postgres/003_queries.sql`

One important modelling choice is using:

```text
(route_id, stop_sequence)
```

as the key of `route_stops`, allowing the same stop to occur more than once on a route.

---

## Lecture 2 - Database integrity

Folder:

`mobilityticketing-lecture-2-starter`

Main work:

- integrity map
- PostgreSQL constraints
- successful write tests
- rejected write tests

Useful files:

- `docs/lab.md`
- `docs/integrity-mape.md`
- `database/postgres/migrations/011_ticketing_integrity.sql`
- `database/postgres/experiments/constraints_should_succeed.sql`
- `database/postgres/experiments/constraints_should_fail.sql`

The database enforces rules such as:

```text
reserved_seats <= capacity
price >= 0
valid foreign keys
unique ticket codes
valid statuses
```

---

## Lecture 3 - Reporting logic

Folder:

`mobilityticketing-lecture-3-starter`

Main work:

- direct query
- SQL function
- materialized view
- trigger-maintained summary
- comparison of reporting approaches

Useful files:

- `docs/lab.md`
- `docs/reporting-evidence.md`
- `docs/responsibility-matrix.md`
- `database/postgres/migrations/`

The experiments show that direct queries and functions read current base data, while materialized views can become stale until refreshed.

The trigger experiment also demonstrates the risks of hidden side effects and incomplete correction handling.

---

## Lecture 4 - Schema migration

Folder:

`mobilityticketing-lecture-4-starter`

Main work:

- expanding from `product_code` to `product_id`
- old/new reader and writer compatibility
- backfill
- verification
- final removal of the old reference

Useful files:

- `docs/lab.md`
- `database/postgres/migrations/030_expand_product_identity.sql`
- `database/postgres/migrations/031_backfill_ticket_product.sql`
- `database/postgres/migrations/032_require_ticket_product.sql`
- `database/postgres/experiments/lecture04/`

The migration follows:

```text
Expand -> Backfill -> Verify -> Contract
```

and preserves existing ticket prices and currencies.

---

## Two decisions worth discussing

### 1. Database constraints as the final integrity boundary

Important invariants are enforced in PostgreSQL rather than relying only on application validation.

This means invalid persisted states are rejected regardless of which application or script performs the write.

### 2. Staged product identity migration

The product reference was migrated gradually instead of immediately dropping `product_code`.

This allows old and new application versions to coexist while existing data is backfilled and verified.

---

## Limitation / open question

The current constraints do not solve every concurrency problem.

For example, two concurrent ticket purchases may both attempt to reserve the final available seat.

This requires transaction and concurrency-control design beyond a simple row-level constraint.