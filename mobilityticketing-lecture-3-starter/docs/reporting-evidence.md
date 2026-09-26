# Lecture 3 Reporting Evidence

## Purpose

This document records the behaviour of the four reporting approaches used for daily captured revenue:

1. Direct query
2. SQL function
3. Materialized view
4. Trigger-maintained summary table

The `payments` table is treated as the authority. The materialized view and summary table are derived reporting data.

## Baseline

The initial seed contains two captured payments:

- `PAYMENT-1`: 36 DKK for `OP-METRO`
- `PAYMENT-2`: 36 DKK for `OP-BUS`

The direct query therefore returns:

```text
OP-BUS    | 2026-04-29 | 36 | 1
OP-METRO  | 2026-04-29 | 36 | 1
```

The SQL function reads the same base tables and returns the same current result.

After refreshing the materialized view, it also contains the same result.

The trigger-maintained table initially contains no historical rows because the trigger was created after the seed payments were inserted.

This demonstrates the initial-backfill problem.

---

## Case 1 - Insert a Captured payment

A new 36 DKK captured payment is inserted for `TICKET-1`.

### Expected source result

Metro captured revenue becomes:

```text
36 + 36 = 72 DKK
```

### Behaviour

| Approach | Result |
| --- | --- |
| Direct query | 72 DKK |
| SQL function | 72 DKK |
| Materialized view | Still 36 DKK until refresh |
| Trigger summary | Adds the new 36 DKK payment |

The direct query and function immediately see the current base-table state.

The materialized view becomes stale because it is not automatically refreshed.

The trigger processes the new INSERT, but it still does not contain the historical seed payment.

---

## Case 2 - Insert a Failed payment

A 50 DKK payment with status `Failed` is inserted.

A failed payment must not contribute to captured revenue.

### Behaviour

| Approach | Behaviour |
| --- | --- |
| Direct query | No revenue change |
| SQL function | No revenue change |
| Materialized view | Still stale |
| Trigger summary | No change |

The trigger explicitly ignores payments whose status is not `Captured`.

---

## Case 3 - Correct Failed to Captured

The 50 DKK failed payment is changed to:

```text
Failed -> Captured
```

The authoritative base tables now contain an additional 50 DKK captured payment.

### Behaviour

| Approach | Behaviour |
| --- | --- |
| Direct query | Includes the additional 50 DKK |
| SQL function | Includes the additional 50 DKK |
| Materialized view | Does not change until refresh |
| Trigger summary | Does not add the 50 DKK |

The trigger is defined only for:

```text
AFTER INSERT
```

It therefore does not react to the UPDATE.

This is an example where the reporting approaches disagree.

---

## Case 4 - Correct Captured to Refunded

The test captured payment is changed from:

```text
Captured -> Refunded
```

The payment should no longer contribute to captured revenue.

### Behaviour

| Approach | Behaviour |
| --- | --- |
| Direct query | Removes the refunded payment from the calculation |
| SQL function | Removes the refunded payment from the calculation |
| Materialized view | Remains stale until refresh |
| Trigger summary | Does not reverse the previously added amount |

The trigger summary therefore contains reporting state that is no longer justified by the authoritative payment row.

---

## Case 5 - Delete test data

The corrected payment is deleted.

### Behaviour

| Approach | Behaviour |
| --- | --- |
| Direct query | Immediately reflects the deletion |
| SQL function | Immediately reflects the deletion |
| Materialized view | Changes only after refresh |
| Trigger summary | Does not react to DELETE |

The current trigger implementation has no DELETE handling.

---

## Case 6 - Duplicate external payment delivery

A new payment is inserted using an already existing:

```text
external_payment_reference = gateway-capture-0001
```

The Lecture 3 starter schema does not enforce uniqueness on this field.

Therefore the duplicate can be stored.

### Consequence

The direct query and function treat the duplicate row as authoritative data and include it in revenue.

The trigger also processes the new captured INSERT and increases the summary.

This demonstrates that reporting logic cannot repair incorrect authoritative data.

Duplicate prevention or idempotency must be handled closer to payment ingestion.

---

## Materialized view refresh

Before refresh:

```text
base tables -> current
function    -> current
materialized view -> stale
```

After:

```sql
refresh materialized view daily_captured_revenue;
```

the materialized view is rebuilt from the authoritative base tables and becomes current again.

This gives the materialized view a clear rebuild path.

---

## Example disagreement

A useful disagreement occurs after:

```text
Failed -> Captured
```

The direct query and SQL function immediately include the corrected payment.

The trigger summary does not include it because the supplied trigger only handles INSERT.

The materialized view also remains stale until explicitly refreshed.

This shows that stored derived reporting data requires explicit rules for freshness and correction handling.