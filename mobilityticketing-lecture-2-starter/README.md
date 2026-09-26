# MobilityTicketing: Lecture 2

This repository contains the completed Lecture 2 implementation for the MobilityTicketing project.

The focus of Lecture 2 is database integrity: turning business rules into PostgreSQL constraints and demonstrating that valid writes succeed while invalid writes are rejected.

## Start the database

Requirements:

- Docker Desktop with Compose

Start PostgreSQL:

```bash
docker compose up -d
```

The database is available at:

- Host: `localhost`
- Port: `5432`
- Database: `mobility`
- User: `mobility`
- Password: `mobility`

To recreate the database from an empty data directory:

```bash
docker compose down -v
docker compose up -d
```

## Apply the integrity migration

```bash
docker compose exec -T postgres psql -U mobility -d mobility < database/postgres/migrations/011_ticketing_integrity.sql
```

The migration adds database constraints for:

- trip capacity and reserved seats
- ticket references and validity
- ticket codes and statuses
- prices and currencies
- payment references and statuses
- validation ticket identity
- product prices and currencies

## Test the constraints

### Successful writes

```bash
docker compose exec -T postgres psql -U mobility -d mobility < database/postgres/experiments/constraints_should_succeed.sql
```

These writes should succeed because they satisfy the database constraints.

### Rejected writes

```bash
docker compose exec -T postgres psql -U mobility -d mobility < database/postgres/experiments/constraints_should_fail.sql
```

The errors in this test are expected. They demonstrate that PostgreSQL rejects data that violates CHECK, FOREIGN KEY, UNIQUE, or NOT NULL constraints.

## Important limitations

The integrity migration protects individual database states, but it does not solve all business problems.

For example:

- `reserved_seats <= capacity` does not by itself solve concurrent purchases of the final available seat.
- PostgreSQL cannot guarantee that an external payment provider actually captured a payment.
- Whether a disabled user may purchase a ticket remains a domain or transaction policy.

These cases require additional transaction, workflow, or application logic.

## Files

- `compose.yaml`: PostgreSQL infrastructure.
- `database/postgres/init/`: baseline schema and seed data.
- `database/postgres/migrations/011_ticketing_integrity.sql`: integrity constraints migration.
- `database/postgres/experiments/constraints_should_succeed.sql`: valid write tests.
- `database/postgres/experiments/constraints_should_fail.sql`: invalid write tests.
- `docs/integrity-map.md`: business invariants, database protection, limitations, and review evidence.
- `docs/lab.md`: Lecture 2 assignment requirements.