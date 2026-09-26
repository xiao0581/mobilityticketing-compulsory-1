# Lecture 3 Decision Record

## Decision

For the current MobilityTicketing case, use the transactional tables as the authority and prefer:

- a direct query or SQL function when current data is required;
- a materialized view when reporting performance requires a stored aggregate.

Do not use the supplied trigger-maintained summary as the primary reporting design in its current form.

## Authority

The authoritative data remains:

`payments`

together with the relationships through:

```text
payments
-> tickets
-> trips
-> routes
```

Reporting tables or materialized views are derived data and must not become a second independent source of truth.

## Why not rely on the trigger summary?

The experiment shows that the supplied trigger handles only one path:

```text
INSERT payment with status = Captured
```

It does not correctly handle:

- existing historical payments;
- Failed -> Captured;
- Captured -> Refunded;
- deletion;
- other corrections.

Supporting all of these cases increases write-side complexity and hidden coupling.

A simple payment write unexpectedly becomes responsible for maintaining reporting state.

## Why use a direct query or function?

Both approaches calculate from authoritative data.

Corrections automatically affect the next query.

There is no separate aggregate copy that must be synchronised.

A function is useful when the same reporting logic should be reused and centrally defined.

## Why consider a materialized view?

If the direct aggregation becomes too expensive, a materialized view provides cheaper reads while keeping a clear relationship to the authoritative data.

Its freshness rule is explicit:

> The materialized view is current only after refresh.

Its rebuild path is also explicit:

```sql
refresh materialized view daily_captured_revenue;
```

This makes recovery easier to understand than an incrementally maintained summary table.

## Freshness rule

For a materialized view, the system must define how stale the report is allowed to be.

For example, it could be refreshed:

```text
every few minutes
after a reporting batch
before a finance report is generated
```

The exact schedule is an operational requirement rather than something hidden inside transactional payment writes.

## Duplicate delivery

The Lecture 3 starter schema allows a duplicate external payment reference.

If duplicate payment data enters the authoritative table, every reporting approach can produce an incorrect business result.

Therefore duplicate prevention or idempotent payment ingestion belongs before reporting aggregation.

## Recovery

If the materialized reporting result is suspected to be incorrect:

```text
authoritative payments
        ↓
refresh/rebuild
        ↓
reporting copy
```

The derived result can be discarded and recreated.

## Final rationale

The recommendation prioritises:

- correctness;
- explicit ownership;
- correction behaviour;
- observability;
- simple recovery;
- reduced hidden coupling.

Performance optimisation should be introduced only when reporting workload demonstrates that the direct calculation is too expensive.