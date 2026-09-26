# Lecture 3 Responsibility Matrix

The `payments` table is the authority for captured-payment information.

Reporting objects are derived from the transactional tables.

| Concern | Direct query | SQL function | Materialized view | Trigger summary |
| --- | --- | --- | --- | --- |
| Authority | Base tables | Base tables | Base tables | Base tables |
| Stores derived result | No | No | Yes | Yes |
| Freshness | Current at query time | Current at function execution | Current only after refresh | Immediate only for handled trigger events |
| Correction handling | Automatic through recalculation | Automatic through recalculation | Requires refresh | Must explicitly handle every correction type |
| INSERT handling | Current automatically | Current automatically | Stale until refresh | Captured INSERT handled |
| UPDATE handling | Current automatically | Current automatically | Stale until refresh | Not handled by supplied trigger |
| DELETE handling | Current automatically | Current automatically | Stale until refresh | Not handled by supplied trigger |
| Read cost | Higher | Similar to direct query | Low | Low |
| Write cost | Low | Low | Low for normal transaction writes | Higher because reporting work happens during payment write |
| Hidden side effects | Very low | Low | Low | High |
| Coupling | Low | Moderate database dependency | Moderate | High |
| Rebuildability | No rebuild required | No rebuild required | Clear: `REFRESH MATERIALIZED VIEW` | Requires explicit backfill/rebuild logic |
| Initial backfill | Automatic on query | Automatic on query | Refresh | Missing from supplied implementation |
| Operational complexity | Low | Low | Moderate | High |
| Observability | Query is explicit | Function call is explicit | Refresh must be observable | Side effect occurs implicitly during payment write |

## Direct query

The direct query is simple and always calculates from the authoritative transactional data.

Its main disadvantage is that aggregation work happens every time the report is requested.

## SQL function

The SQL function centralises the query logic and makes reuse easier.

It does not solve reporting performance by itself because it still reads and aggregates the base tables when called.

## Materialized view

The materialized view stores a derived reporting result.

Reads are cheap, but freshness becomes an explicit operational responsibility.

Its main advantage is that it has a clear rebuild path:

```sql
refresh materialized view daily_captured_revenue;
```

## Trigger-maintained summary

The trigger provides cheap reads and can react immediately to selected writes.

However, it introduces hidden write-side behaviour.

The supplied implementation handles only captured INSERT operations.

It does not handle:

- initial backfill;
- Failed -> Captured;
- Captured -> Refunded;
- DELETE;
- correction of amount/date/ticket;
- other future payment lifecycle changes.

This makes correctness dependent on every possible write path being handled correctly.