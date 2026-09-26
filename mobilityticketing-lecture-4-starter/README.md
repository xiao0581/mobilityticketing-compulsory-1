# MobilityTicketing - Lecture 4

This repository contains the Lecture 4 database migration exercise for the MobilityTicketing project.

The purpose of the exercise is to change the ticket-to-product reference from:

```text
tickets.product_code -> products.code
```

to:

```text
tickets.product_id -> products.id
```

without breaking existing data or old application versions during the migration.

The exercise demonstrates a rolling database migration using an expand, backfill, verify and contract approach.

## Start the database

Requirements:

- Docker Desktop
- Docker Compose

Start PostgreSQL:

```powershell
docker compose up -d postgres
docker compose ps
```

To rebuild the database:

```powershell
docker compose down -v
docker compose up -d postgres
```

Database:

```text
Database: mobility
User: mobility
Password: mobility
```

## Initial data

The baseline contains at least two products and three tickets.

The original test tickets are:

```text
TICKET-1 | SINGLE | 36.00 DKK
TICKET-2 | SINGLE | 36.00 DKK
TICKET-3 | DAY    | 65.00 DKK
```

These values are used to verify that the migration does not change historical ticket prices or currencies.

## Migration files

The rolling migration is implemented in:

```text
database/postgres/migrations/
├── 030_expand_product_identity.sql
├── 031_backfill_ticket_product.sql
└── 032_require_ticket_product.sql
```

### 030 - Expand

Adds:

```text
products.id UUID
tickets.product_id UUID
```

while keeping the existing `tickets.product_code`.

This allows old and new application versions to coexist temporarily.

### 031 - Backfill

Existing tickets are updated by resolving:

```text
tickets.product_code
        ↓
products.code
        ↓
products.id
        ↓
tickets.product_id
```

The backfill only updates rows where `product_id` is null, making it safe to run repeatedly.

### 032 - Require product_id

After verification succeeds:

```text
tickets.product_id
```

becomes required.

The foreign key is also validated.

## Experiment scripts

The Lecture 4 experiment scripts are located in:

```text
database/postgres/experiments/lecture04/
```

They include:

```text
baseline.sql
bad_migration.sql
old_reader.sql
old_writer.sql
new_reader.sql
new_writer.sql
verify.sql
unsafe_change.sql
final_reader.sql
final_writer.sql
remove_legacy.sql
```

## Migration flow

The migration follows this sequence:

```text
Original schema
    ↓
Expand
    ↓
Support old and new readers/writers
    ↓
Backfill existing tickets
    ↓
Verify
    ↓
Make product_id required
    ↓
Stop old writers
    ↓
Move readers/writers to product_id
    ↓
Remove tickets.product_code
```

## Final state

Before migration:

```text
tickets.product_code -> products.code
```

After migration:

```text
tickets.product_id -> products.id
```

`products.code` remains available as a business-facing product code, but tickets no longer store it as their product reference.

## Documentation

Detailed implementation notes and experiment results are documented in:

```text
docs/lab.md
```

## Main lesson

Changing a populated database requires more than changing the final schema.

A safe migration must consider:

```text
existing data
old application versions
new application versions
backfill
verification
deployment order
removal of the old contract
```

The main pattern used in this exercise is:

```text
Expand -> Migrate -> Contract
```