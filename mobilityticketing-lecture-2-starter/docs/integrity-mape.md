# Lecture 2 Integrity Map

This integrity map describes the main business rules for the MobilityTicketing database in Lecture 2.

The purpose is to identify:

- which rules can be enforced directly by PostgreSQL constraints;
- which rules require uniqueness rules;
- which rules depend on multiple rows, transactions, or external systems;
- which rules are currently ambiguous and require a domain decision;
- which part of the system currently owns each rule;
- what happens when an invalid write is attempted.

## Evidence

The implementation and tests can be found in:

- `database/postgres/migrations/011_ticketing_integrity.sql`
- `database/postgres/experiments/constraints_should_succeed.sql`
- `database/postgres/experiments/constraints_should_fail.sql`


## Integrity map

| Invariant | Classification | Current owner | Affected tables / columns | Database protection | Successful evidence | Failed evidence | Expected failure | Remaining limitation |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Trip capacity cannot be negative | Directly enforceable with a column or table constraint | PostgreSQL | `trips.capacity` | `NOT NULL` and `CHECK (capacity >= 0)` | Valid trip update | Fail tests 1 and 3 | `23502` / `23514` | Does not handle concurrent reservations |
| Reserved seats cannot be negative | Directly enforceable with a column or table constraint | PostgreSQL | `trips.reserved_seats` | `NOT NULL` and `CHECK (reserved_seats >= 0)` | Valid trip update | Fail tests 2 and 4 | `23502` / `23514` | Does not handle concurrent purchases |
| Reserved seats cannot exceed capacity | Directly enforceable with a column or table constraint | PostgreSQL | `trips.capacity`, `trips.reserved_seats` | `CHECK (reserved_seats <= capacity)` | Valid trip update | Fail test 5 | `23514` | Concurrent transactions may still race for the last seat |
| A ticket must reference an existing user | Directly enforceable with a column or table constraint | PostgreSQL | `tickets.user_id` | Foreign key to `users(id)` | Valid ticket insert | Fail test 9 | `23503` | Does not decide whether a disabled user may purchase |
| A ticket must reference an existing trip | Directly enforceable with a column or table constraint | PostgreSQL | `tickets.trip_id` | Foreign key to `trips(id)` | Valid ticket insert | Fail test 10 | `23503` | Does not determine whether the trip is still bookable |
| A ticket must reference an existing product | Directly enforceable with a column or table constraint | PostgreSQL | `tickets.product_code` | Foreign key to `products(code)` | Valid ticket insert | Fail test 11 | `23503` | Does not guarantee that the ticket price equals the current product price |
| Ticket price cannot be negative | Directly enforceable with a column or table constraint | PostgreSQL | `tickets.price` | `CHECK (price >= 0)` | Valid ticket insert | Fail test 12 | `23514` | Pricing and discount calculation are outside this constraint |
| Ticket currency must be present and consistently represented | Directly enforceable with a column or table constraint | PostgreSQL | `tickets.currency` | `NOT NULL` and uppercase three-character CHECK | Valid ticket with `DKK` | Fail tests 8 and 13 | `23502` / `23514` | Does not verify that the value is a real ISO currency |
| Ticket code must support unambiguous lookup | Enforceable with a unique or exclusion rule | PostgreSQL | `tickets.ticket_code` | `NOT NULL` and `UNIQUE (ticket_code)` | Valid unique ticket code | Fail tests 6 and 14 | `23502` / `23505` | Ticket-code generation is outside the constraint |
| Ticket status must come from a known set | Directly enforceable with a column or table constraint | PostgreSQL | `tickets.status` | `NOT NULL` and CHECK for `Active`, `Validated`, `Cancelled`, `Expired` | Valid ticket with `Active` | Fail tests 7 and 15 | `23502` / `23514` | Does not enforce valid status transitions |
| Ticket validity end cannot be earlier than its start | Directly enforceable with a column or table constraint | PostgreSQL | `tickets.valid_from_utc`, `tickets.valid_to_utc` | `CHECK (valid_to_utc >= valid_from_utc)` | Valid ticket time range | Fail test 16 | `23514` | Does not define the required validity duration |
| A payment must reference an existing ticket | Directly enforceable with a column or table constraint | PostgreSQL | `payments.ticket_id` | `NOT NULL` and foreign key to `tickets(id)` | Valid payment insert | Fail tests 17 and 22 | `23502` / `23503` | Does not guarantee that an external gateway captured the payment |
| A payment must reference an existing user | Directly enforceable with a column or table constraint | PostgreSQL | `payments.user_id` | Foreign key to `users(id)` | Valid payment insert | Fail test 21 | `23503` | Does not verify that payment user and ticket user are the same |
| Payment amount cannot be negative | Directly enforceable with a column or table constraint | PostgreSQL | `payments.amount` | `NOT NULL` and `CHECK (amount >= 0)` | Valid payment insert | Fail tests 18 and 23 | `23502` / `23514` | Does not guarantee that payment amount equals ticket price |
| Payment currency must be present and consistently represented | Directly enforceable with a column or table constraint | PostgreSQL | `payments.currency` | `NOT NULL` and uppercase three-character CHECK | Valid payment with `DKK` | Fail tests 19 and 24 | `23502` / `23514` | Does not guarantee that payment and ticket currencies match |
| Payment status must come from a known set | Directly enforceable with a column or table constraint | PostgreSQL | `payments.status` | `NOT NULL` and CHECK for `Pending`, `Captured`, `Failed`, `Refunded` | Valid payment with `Captured` | Fail tests 20 and 25 | `23502` / `23514` | Does not enforce valid payment-status transitions |
| External payment reference must not be recorded twice | Enforceable with a unique or exclusion rule | PostgreSQL | `payments.external_payment_reference` | `UNIQUE (external_payment_reference)` | Valid unique payment reference | Fail test 26 | `23505` | Coordination with the external gateway still requires workflow logic |
| A validation must refer to an existing ticket | Directly enforceable with a column or table constraint | PostgreSQL | `validations.ticket_id`, `validations.ticket_code` | Composite foreign key to `tickets(id, ticket_code)` | Valid validation insert | Fail tests 27, 28 and 29 | `23502` / `23503` | Does not determine whether the ticket is currently valid for travel |
| A validation must not combine one ticket ID with another ticket's code | Directly enforceable with a column or table constraint | PostgreSQL | `validations.ticket_id`, `validations.ticket_code` | Composite foreign key `(ticket_id, ticket_code)` | Matching ID and code | Fail test 29 | `23503` | Validation-result logic is outside this constraint |
| Product price cannot be negative | Directly enforceable with a column or table constraint | PostgreSQL | `products.price` | `CHECK (price >= 0)` | Valid product update | Fail test 31 | `23514` | Does not define pricing or discount rules |
| Product currency must be present and consistently represented | Directly enforceable with a column or table constraint | PostgreSQL | `products.currency` | `NOT NULL` and uppercase three-character CHECK | Valid product with `DKK` | Fail tests 30 and 32 | `23502` / `23514` | Does not verify that the value is a real ISO currency |
| Concurrent purchase of the final available seat must not oversell capacity | Dependent on more than one row or an external system | Transaction layer | `trips.reserved_seats`, ticket-purchase transaction | Row-level CHECK protects the final row state | Not solved in Lecture 2 | Not solved in Lecture 2 | N/A | Requires transaction isolation, locking, or an atomic update |
| External payment capture must agree with the local payment state | Dependent on more than one row or an external system | Application / payment workflow | `payments` and external payment provider | Local constraints only | Not solved in Lecture 2 | Not solved in Lecture 2 | N/A | PostgreSQL cannot know whether an external gateway actually captured a payment |
| Whether a disabled user may purchase a ticket | Currently ambiguous and requiring a domain decision | Domain / application | `users.is_disabled`, `tickets.user_id` | No purchase-policy constraint in Lecture 2 | Not implemented | Not implemented | N/A | Business policy must first be decided |
| Valid transitions between ticket statuses | Currently ambiguous and requiring a domain decision | Domain / application | `tickets.status` | Allowed values are constrained, transitions are not | Allowed values tested | Invalid value tested | `23514` for unknown value | Valid transitions such as `Active -> Validated` require a workflow decision |


## Important invariants not solved by simple constraints

### Concurrent seat reservation

The database guarantees for a single row that:

`reserved_seats <= capacity`

For example:

```text
capacity = 100
reserved_seats = 80
```

is valid, while:

```text
capacity = 100
reserved_seats = 101
```

is rejected.

However, this constraint alone does not solve concurrency.

Two transactions may both observe that one seat is available before either transaction finishes.

The CHECK constraint protects the final row state, but a transaction or concurrency-control strategy is still required.

This problem is intentionally left for the transactions lecture.


### External payment capture

PostgreSQL can enforce that local payment records are internally consistent.

For example, it can ensure that:

- the referenced ticket exists;
- the amount is non-negative;
- the currency format is valid;
- the payment status is from the allowed set;
- the external payment reference is unique.

However, PostgreSQL cannot independently prove that an external payment provider successfully captured the payment.

The workflow crosses multiple systems:

```text
Application
    ↓
PostgreSQL
    ↓
External payment provider
```

Successful, failed, delayed, and repeated responses therefore require transaction and workflow design.


### Disabled-user purchase policy

The database can prove through a foreign key that a user exists.

It cannot by itself answer:

> Is a disabled user allowed to purchase a new ticket?

Lecture 2 does not make that domain decision.

The rule remains owned by the domain/application layer until the business behaviour is defined.


### Ticket status transitions

The database restricts ticket status to:

```text
Active
Validated
Cancelled
Expired
```

This prevents unknown values.

However, it does not determine whether transitions such as:

```text
Expired -> Active
```

or:

```text
Cancelled -> Validated
```

should be allowed.

That is a workflow/domain rule rather than a simple value constraint.


## Two important invariants for review

### 1. Reserved seats cannot exceed capacity

The rule is:

`reserved_seats <= capacity`

It is enforced using a CHECK constraint.

This state is valid:

```text
capacity = 80
reserved_seats = 60
```

This state is invalid:

```text
capacity = 80
reserved_seats = 90
```

PostgreSQL rejects the second state because it violates the CHECK constraint.

The important limitation is that the CHECK constraint alone does not solve the race condition where two transactions attempt to purchase the final seat at the same time.


### 2. Ticket ID and ticket code must belong to the same ticket

A validation contains:

```text
ticket_id
ticket_code
```

The database uses a composite foreign key:

```text
(validations.ticket_id, validations.ticket_code)
        ↓
(tickets.id, tickets.ticket_code)
```

Suppose the database contains:

```text
TICKET-1 -> CODE-M2-0001
TICKET-2 -> CODE-5C-0001
```

This combination is valid:

```text
TICKET-1 + CODE-M2-0001
```

This combination is invalid:

```text
TICKET-1 + CODE-5C-0001
```

Although both values exist individually, they do not identify the same ticket.

The composite foreign key therefore rejects the invalid combination.


## Successful and failed write evidence

### Successful writes

`constraints_should_succeed.sql` demonstrates valid writes for:

- trip capacity and reserved seats;
- product price and currency;
- ticket references, price, currency, status, code, and validity period;
- payment references, amount, currency, status, and external reference;
- matching ticket ID and ticket code in a validation.

All of these writes should succeed.

The test transaction is rolled back at the end so that the file can be executed repeatedly.


### Failed writes

`constraints_should_fail.sql` intentionally attempts invalid writes.

Examples include:

- NULL required values;
- negative capacity;
- negative reserved seats;
- reserved seats greater than capacity;
- references to non-existing users, trips, products, or tickets;
- negative prices and payment amounts;
- invalid currency representation;
- duplicate ticket codes;
- duplicate external payment references;
- invalid status values;
- invalid ticket validity periods;
- mismatched ticket ID and ticket code.

Expected PostgreSQL SQLSTATE codes include:

```text
23502 = NOT NULL violation
23503 = FOREIGN KEY violation
23505 = UNIQUE violation
23514 = CHECK violation
```

The resulting errors are expected and demonstrate that PostgreSQL rejects invalid states.


## State-transition trace

### Ticket purchase

The following rows must already exist:

```text
User
Trip
Product
```

A simplified purchase flow is:

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
5. The ticket must satisfy its code, status, price, currency, and validity constraints.
6. A payment may then be inserted referencing the ticket and user.
7. The trip's `reserved_seats` value may be updated as part of the purchase.

The database ensures that the resulting trip row satisfies:

`reserved_seats <= capacity`

Concurrency behaviour is intentionally left for the transactions lecture.


### Ticket validation

A simplified validation flow is:

```text
Ticket
   ↓
Validation
```

The ticket must already exist.

The validation contains:

```text
ticket_id
ticket_code
```

The pair must identify the same ticket.

The composite foreign key prevents the identifier of one ticket from being combined with the code of another.

The current database also restricts the set of ticket status values, but it does not enforce valid transitions between those values.


## Delete and update behaviour

Historical ticketing, payment, and validation data should generally be preserved.

### Tickets

Tickets can be referenced by payments and validations.

Deletion should therefore be restricted when historical dependent records exist.

If a ticket is no longer usable, changing its status to:

`Cancelled`

is preferable to physically deleting it.

Ticket IDs and ticket codes should generally not be changed after dependent historical records exist because that would change historical meaning.


### Payments

Payments represent financial history.

Captured payments should normally be retained.

Deleting a captured payment should not cascade automatically.

A refund should be represented as an explicit business process rather than removing the original payment history.


### Validations

Validation rows represent evidence that a ticket was checked.

These records should normally be retained for historical and audit purposes.

They should not automatically disappear if another related record changes.


### Users

Historical tickets and payments may reference users.

If a user should no longer use the system, disabling the user is preferable to deleting the row.

This preserves historical references.


### Trips

Existing tickets may reference trips.

A trip with historical ticket activity should normally be cancelled or marked inactive rather than physically deleted.


### Products

Historical tickets may reference products.

A product may be discontinued without deleting the row.

Keeping the product preserves the historical meaning of old tickets.


## Issue register

### Issue 1 - Concurrent seat reservation

**Evidence:**  
`reserved_seats <= capacity` is protected by a CHECK constraint.

**Problem:**  
Two transactions may both observe the final available seat.

**Consequence:**  
A CHECK constraint alone does not define how concurrent booking transactions are coordinated.

**Possible improvement:**  
Use transaction isolation, locking, or an atomic reservation operation.

**Open question:**  
Which concurrency strategy provides the correct balance between consistency and performance?


### Issue 2 - External payment capture

**Evidence:**  
Payments have foreign keys, CHECK constraints, status restrictions, and unique external payment references.

**Problem:**  
The database cannot know whether an external payment provider successfully captured the payment.

**Consequence:**  
The local database and external payment system may temporarily disagree.

**Possible improvement:**  
Use an explicit payment workflow with idempotency and transaction handling.

**Open question:**  
How should delayed, failed, or repeated payment confirmations be handled?


### Issue 3 - Ticket status transitions

**Evidence:**  
The database restricts ticket status to:

```text
Active
Validated
Cancelled
Expired
```

**Problem:**  
The CHECK constraint restricts values but does not restrict transitions.

For example:

```text
Expired -> Active
```

is not currently prevented.

**Possible improvement:**  
Introduce domain/application logic or another state-transition mechanism if strict transitions become necessary.

**Open question:**  
Which ticket-state transitions should be considered valid?


## Conclusion

The Lecture 2 migration improves database integrity by enforcing important business invariants close to the stored data.

PostgreSQL can reliably enforce:

- required values;
- valid value ranges;
- referential integrity;
- uniqueness;
- validity-period relationships;
- allowed status values;
- consistency between ticket IDs and ticket codes.

However, simple constraints cannot completely solve:

- concurrent ticket purchases;
- external payment workflows;
- authorization or disabled-user policy;
- valid workflow state transitions.

These require additional transaction, application, or domain-level design.