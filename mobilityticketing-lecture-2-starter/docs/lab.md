# Lecture 2 implementation lab: Make invalid states difficult to store

## Purpose

Strengthen the initial PostgreSQL schema for ticket purchase and validation. The focus is not API validation. The focus is what the database can guarantee when writes arrive from different applications, scripts, or future services.

## Starting point

The course starter infrastructure contains a deliberately weak schema for trips, products, tickets, payments, and validations. It accepts several states that conflict with the MobilityTicketing case.

Read the supplied DDL before changing anything. Add constraints through a new migration. Do not edit the starter DDL.

## Tasks

1. Extract at least ten domain invariants from the scenario and schema.
2. Classify each invariant as one of:
   - directly enforceable with a column or table constraint;
   - enforceable with a unique or exclusion rule;
   - dependent on more than one row or an external system;
   - currently ambiguous and requiring a domain decision.
3. Implement the constraints that belong in this lecture.
4. Write negative tests that attempt invalid inserts or updates.
5. Record at least two important invariants that cannot be solved by a simple constraint. Keep them for the transactions lecture.

## Minimum invariants to consider

- Capacity cannot be negative.
- Reserved seats cannot be negative or greater than capacity.
- Ticket price and payment amount cannot be negative.
- Currency must be present and consistently represented.
- Ticket codes must support unambiguous lookup.
- A payment must refer to an existing ticket.
- A validation must refer to an existing ticket.
- A ticket validity end cannot be earlier than its start.
- Status values must come from a known set.
- An external payment reference should not be recorded twice when it represents one captured payment.
- A validation must not combine the identifier of one ticket with the code of another.

## Required evidence

For every implemented invariant, include:

- the rule in plain language;
- the DDL used to enforce it;
- one write that succeeds;
- one write that fails;
- the database error or result that demonstrates enforcement.

Assert PostgreSQL SQLSTATE codes in automated tests where possible. Matching an English error string is brittle and language-dependent.

## State-transition trace

Trace ticket purchase and ticket validation at the row and relationship level. Describe which rows are inserted or updated and which references must already exist. Do not analyse concurrency yet.

## Delete and update behaviour

Inspect the relationships for historical tickets, payments, and validations. For each relationship, state whether deletion should be restricted, cascaded, soft-deleted, or governed by a retention policy. Also state whether an update should be allowed or rejected when it would change historical meaning.

## Integrity map

Create an integrity map that connects each business rule to its current owner, affected tables, expected failure behaviour, and remaining limitation.

## Important boundary

A row-level check can protect `reserved_seats <= capacity` for one row. It cannot arbitrate two concurrent purchases that both observe the same remaining capacity. Do not claim that this migration solves that race.

Payment capture across an external gateway and PostgreSQL also needs workflow design. A disabled-user purchase rule may be a domain or transaction policy depending on the case decision. Classify these limits explicitly.


# Implementation evidence

## Integrity map

The completed integrity map is available in:

`docs/integrity-map.md`

The map records:

- the business invariant;
- the required classification;
- the current owner of the rule;
- affected tables and columns;
- the database protection used;
- successful-write evidence;
- failed-write evidence;
- expected failure behaviour;
- remaining limitations.

It contains more than ten invariants covering trips, tickets, payments, validations, products, transaction boundaries, external payment processing, and unresolved domain policies.


## Integrity migration

The implemented migration is located in:

`database/postgres/migrations/011_ticketing_integrity.sql`

The starter DDL is left unchanged.

The migration strengthens the existing schema using:

- `NOT NULL`
- `CHECK`
- `FOREIGN KEY`
- `UNIQUE`
- composite foreign-key constraints

Examples include:

```text
capacity >= 0
reserved_seats >= 0
reserved_seats <= capacity
price >= 0
valid_to_utc >= valid_from_utc
```

Foreign keys prevent ticketing rows from referring to non-existing related records.

Unique constraints protect identifiers such as ticket codes and external payment references.


## Successful write evidence

Successful tests are located in:

`database/postgres/experiments/constraints_should_succeed.sql`

The file demonstrates that valid data remains writable after applying the integrity migration.

The successful examples include:

- updating a trip with a valid capacity and reserved-seat count;
- updating a product with a positive price and valid `DKK` currency;
- inserting a valid ticket referencing an existing user, trip, and product;
- inserting a valid payment referencing an existing user and ticket;
- inserting a valid validation with a matching ticket ID and ticket code.

The tests demonstrate that the constraints reject invalid states without preventing legitimate writes.

The successful test is rolled back at the end so that it can be executed repeatedly.


## Failed write evidence

Negative tests are located in:

`database/postgres/experiments/constraints_should_fail.sql`

The file intentionally attempts invalid inserts and updates.

The tests include:

- NULL values in required columns;
- negative capacity;
- negative reserved seats;
- reserved seats greater than capacity;
- non-existing foreign-key references;
- negative ticket prices;
- negative payment amounts;
- invalid currencies;
- duplicate ticket codes;
- duplicate external payment references;
- invalid ticket and payment statuses;
- invalid ticket validity periods;
- mismatched ticket IDs and ticket codes;
- invalid product prices and currencies.

The expected result is that PostgreSQL rejects these writes.

Expected SQLSTATE codes include:

```text
23502 = NOT NULL violation
23503 = FOREIGN KEY violation
23505 = UNIQUE violation
23514 = CHECK violation
```

The errors are expected and provide evidence that PostgreSQL is enforcing the invariants.


# State-transition trace

## Ticket purchase

Before purchasing a ticket, the following rows must already exist:

```text
User
Trip
Product
```

The relationship can be represented as:

```text
User ─────┐
Trip ─────┼──> Ticket
Product ──┘
               ↓
            Payment
```

The sequence is:

1. The user must already exist.
2. The trip must already exist.
3. The product must already exist.
4. A new ticket is inserted referencing the user, trip, and product.
5. The ticket must contain a valid ticket code, price, currency, status, and validity period.
6. A payment may then be inserted referencing the ticket and user.
7. The trip's `reserved_seats` value may be updated as part of the purchase.

The database checks:

- user existence;
- trip existence;
- product existence;
- ticket-code uniqueness;
- allowed ticket status;
- non-negative price;
- currency representation;
- validity period ordering.

The payment must reference an existing ticket and satisfy its own amount, currency, status, and uniqueness constraints.

The database also ensures that the resulting trip row satisfies:

`reserved_seats <= capacity`

Concurrency behaviour is intentionally left for the transactions lecture.


## Ticket validation

A ticket must exist before it can be validated.

The relationship is:

```text
Ticket
   ↓
Validation
```

The validation contains:

```text
ticket_id
ticket_code
```

The pair must identify the same existing ticket.

For example:

```text
TICKET-1 -> CODE-M2-0001
TICKET-2 -> CODE-5C-0001
```

This is valid:

```text
TICKET-1 + CODE-M2-0001
```

This is invalid:

```text
TICKET-1 + CODE-5C-0001
```

Both individual values exist, but the combination does not identify one ticket.

The composite foreign key:

```text
(validations.ticket_id, validations.ticket_code)
        ↓
(tickets.id, tickets.ticket_code)
```

prevents the mismatched identity from being stored.

The database restricts the allowed ticket-status values but does not currently enforce which transitions between statuses are valid.


# Delete and update behaviour

Historical ticketing information should generally be preserved.

## Tickets

Tickets may be referenced by:

- payments;
- validations.

Deleting a ticket with historical dependent records should therefore be restricted.

If a ticket should no longer be usable, changing its status to:

`Cancelled`

is preferable to physically deleting it.

Ticket IDs and codes should generally not be changed after historical records reference them because that could change historical meaning.


## Payments

Payments represent financial history.

Captured payment records should normally be retained.

A payment should not disappear automatically through cascading deletion.

If money is returned, a refund or another explicit financial process should represent the change rather than deleting the original payment.


## Validations

Validation records provide historical evidence that a ticket was checked.

They should normally be retained for audit and historical purposes.

They should not automatically disappear when another related row changes.


## Users

Tickets and payments may reference users.

When a user should no longer use the system, disabling the user is preferable to deleting the historical row.


## Trips

Tickets may reference historical trips.

A trip with ticketing activity should generally be cancelled or made inactive rather than physically deleted.


## Products

Tickets may reference historical products.

A product may be discontinued, but keeping the original product record preserves the historical meaning of tickets that reference it.


# Important invariants not solved by simple constraints

## Concurrent seat reservation

The row-level rule:

`reserved_seats <= capacity`

is enforced by PostgreSQL.

For example:

```text
capacity = 100
reserved_seats = 80
```

is valid.

This state:

```text
capacity = 100
reserved_seats = 101
```

is rejected.

However, the rule does not solve the case where two transactions both observe the final available seat before either completes.

Transaction and concurrency-control logic is therefore still required.


## External payment capture

PostgreSQL can ensure local payment consistency.

For example:

- the referenced ticket exists;
- the amount is non-negative;
- currency is consistently represented;
- status comes from the allowed set;
- external payment references are unique.

However, PostgreSQL cannot independently verify whether an external payment gateway actually captured the payment.

The workflow crosses:

```text
Application
    ↓
PostgreSQL
    ↓
External payment provider
```

This requires additional transaction and workflow design.


## Disabled-user purchase policy

The database can prove that a referenced user exists.

It does not currently determine whether a user with:

`is_disabled = true`

may purchase a new ticket.

This remains a domain-policy decision.


## Ticket status transitions

The database restricts ticket status values to:

```text
Active
Validated
Cancelled
Expired
```

However, it does not determine which transitions between those values are legal.

For example:

```text
Expired -> Active
```

or:

```text
Cancelled -> Validated
```

may require additional domain rules.


# Two invariants selected for review

## 1. Reserved seats cannot exceed capacity

The invariant is:

`reserved_seats <= capacity`

It is protected by a CHECK constraint.

A valid state:

```text
capacity = 50
reserved_seats = 40
```

is accepted.

An invalid state:

```text
capacity = 50
reserved_seats = 60
```

is rejected.

This demonstrates a rule that PostgreSQL can enforce directly.

The remaining limitation is concurrency.


## 2. Ticket ID and ticket code must belong to the same ticket

A validation uses:

```text
ticket_id
ticket_code
```

A foreign key on `ticket_id` alone would prove that the ticket exists, but would not prove that the supplied ticket code belongs to the same ticket.

The composite foreign key:

```text
(ticket_id, ticket_code)
```

ensures that both values identify the same ticket.

This prevents mismatched ticket identities from being stored.


# What the implementation proves

The Lecture 2 implementation demonstrates that PostgreSQL can enforce important domain invariants independently of the application performing the write.

The database protects:

- required values;
- valid ranges;
- referential integrity;
- uniqueness;
- ticket validity periods;
- allowed status values;
- ticket identity consistency.

Valid writes remain possible while invalid writes are rejected.


# What remains outside the database constraints

The current migration does not completely solve:

- concurrent seat reservation;
- distributed payment workflows;
- disabled-user purchase policy;
- legal workflow status transitions;
- application-level authorization.

These require additional transaction, application, or domain design.