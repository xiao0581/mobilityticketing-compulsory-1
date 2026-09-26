# Lecture 4 - Rolling product identity migration

## Purpose

The purpose of this lab is to change how tickets reference products.

Originally:

```text
tickets.product_code -> products.code
```

The new design uses:

```text
tickets.product_id -> products.id
```

The important part is performing the change without breaking existing data or old application versions halfway through the migration.


# Step 1 - Baseline

The development database was rebuilt from the existing schema and seed data.

The baseline contains at least two products and three tickets.

The original tickets used for verification are:

```text
TICKET-1 | SINGLE | 36.00 | DKK
TICKET-2 | SINGLE | 36.00 | DKK
TICKET-3 | DAY    | 65.00 | DKK
```

The following query checks whether every existing ticket references a product that exists:

```sql
select t.id, t.product_code
from tickets t
left join products p on p.code = t.product_code
where t.product_code is null
   or p.code is null;
```

Expected result:

```text
0 rows
```

This proves that the existing product references are valid before the migration starts.

The ticket IDs, product codes, prices and currencies were recorded so they could be compared after migration.


# Step 2 - Unsafe migration

An intentionally unsafe migration was tested first.

It attempted to:

```text
remove product_code
add product_id
make product_id NOT NULL immediately
```

The migration failed with:

```text
ERROR: column "product_id" of relation "tickets" contains null values
```

This is expected.

Existing tickets do not yet have a `product_id`, so PostgreSQL cannot make the new column required immediately.

The migration would also break old application code that still expects:

```text
tickets.product_code
```

The experiment demonstrates why changing a populated database is different from creating a new database.


# Step 3 - Expand the schema

The first real migration is:

```text
database/postgres/migrations/030_expand_product_identity.sql
```

It adds a UUID identity to products:

```text
products.id
```

Existing products receive generated UUID values.

The product ID is then configured as:

```text
DEFAULT gen_random_uuid()
NOT NULL
UNIQUE
```

The migration also adds:

```text
tickets.product_id
```

with a foreign key to:

```text
products.id
```

At this stage `tickets.product_id` is intentionally nullable.

The existing:

```text
tickets.product_code
```

is still present.

This creates the compatibility period where the database supports both old and new application versions.


# Step 4 - Support both application versions

During the migration, tickets temporarily contain both:

```text
product_code
product_id
```


## Old writer

The old writer inserts a ticket using only:

```text
product_code
```

It does not know that `product_id` exists.

This still works during the expand phase because `product_id` is nullable.


## Old reader

The old reader continues to read tickets through:

```text
tickets.product_code
```

The old query still works because the old column has not been removed.


## New writer

The new writer receives a:

```text
product_id
```

It finds the corresponding product and derives the product code from that product row.

The caller therefore does not independently provide:

```text
product_code
```

During the compatibility period the writer stores both:

```text
product_id
product_code
```

using values from the same product.


## New reader

The new reader must work both before and after backfill.

It uses:

```sql
select t.id,
       coalesce(p_new.id, p_old.id) as resolved_product_id,
       t.price,
       t.currency
from tickets t
left join products p_new
  on p_new.id = t.product_id
left join products p_old
  on t.product_id is null
 and p_old.code = t.product_code
order by t.id;
```

If the ticket already contains `product_id`, the new reference is used.

If `product_id` is still null, the reader temporarily resolves the product using `product_code`.

This allows the new reader to work before every historical ticket has been backfilled.


# Product identity mismatch test

A direct SQL insert was tested where:

```text
product_code = SINGLE
```

while:

```text
product_id = ID belonging to DAY
```

Both values can individually reference valid products.

The database currently does not guarantee that the two values identify the same product.

The new writer avoids this problem by deriving the product code from the product selected using `product_id`.

This shows the difference between protection provided by the writer and protection provided directly by database constraints.


# Step 5 - Backfill existing tickets

The backfill migration is:

```text
database/postgres/migrations/031_backfill_ticket_product.sql
```

The update is:

```sql
update tickets t
set product_id = p.id
from products p
where t.product_id is null
  and p.code = t.product_code;
```

The important condition is:

```text
product_id IS NULL
```

Only tickets that have not yet been migrated are updated.


## Safe rerun

The backfill was executed again after the existing tickets had been updated.

The result was:

```text
UPDATE 0
```

This demonstrates that the backfill is safe to run repeatedly.


## Late old writer

A new ticket was inserted using `old_writer.sql` after the migration had already started.

The ticket initially contained:

```text
product_code = SINGLE
product_id   = NULL
```

The backfill was executed again.

The ticket received the correct product UUID.

Running the backfill once more returned:

```text
UPDATE 0
```

This simulates an old application instance continuing to write during the migration window.


# Verification

The verification query is:

```sql
select t.id, t.product_code, t.product_id
from tickets t
left join products p on p.id = t.product_id
where t.product_id is null
   or p.id is null
   or t.product_code is distinct from p.code;
```

Before continuing the migration, the result should be:

```text
0 rows
```

This verifies that:

```text
every ticket has product_id
product_id references an existing product
product_code and product_id identify the same product
```

The original tickets were also compared with the baseline.

They remain:

```text
TICKET-1 | SINGLE | 36.00 | DKK
TICKET-2 | SINGLE | 36.00 | DKK
TICKET-3 | DAY    | 65.00 | DKK
```

The historical ticket price is therefore preserved.

For example:

```text
TICKET-3 = 65.00 DKK
```

remains unchanged even if the current DAY product price is different.


# Step 6 - Make product_id required

Before making `product_id` required, a ticket with:

```text
product_id = NULL
```

was deliberately created.

The migration:

```text
database/postgres/migrations/032_require_ticket_product.sql
```

was then executed.

It failed because the database still contained a ticket without `product_id`.

This failure is useful.

The database prevents the migration from completing before all data satisfies the new contract.

The missing product ID was then repaired using the backfill.

Verification was executed again and returned:

```text
0 rows
```

The migration was then executed successfully.

It:

```text
validates tickets_product_id_fk
sets tickets.product_id NOT NULL
```

At this point every ticket must contain a valid `product_id`.


## Old writer after NOT NULL

The old writer only knows how to provide:

```text
product_code
```

After `product_id` becomes required, an old-writer insert fails because it does not provide a product ID.

This establishes the cutover point where old writer versions must no longer be running.


# Step 7 - Remove the old reference

The new writer was changed so it no longer writes:

```text
tickets.product_code
```

The new reader was also changed to join products only through:

```text
tickets.product_id -> products.id
```


## Final reader

The final reader uses:

```sql
join products p
    on p.id = t.product_id
```

It may still display:

```text
products.code
```

but it no longer reads `tickets.product_code`.


## Final writer

The final writer inserts tickets using:

```text
product_id
```

and no longer depends on the ticket-level product code.


## Legacy NOT NULL observation

When the final writer first stopped supplying `product_code`, the insert failed because the old column was still:

```text
NOT NULL
```

This showed that the old database contract still affected the new application contract.

The old requirement was removed during the final transition so the ID-only writer could operate before the legacy column was dropped.


## Dependency check

Before dropping `tickets.product_code`, dependencies must be checked.

Possible dependencies include:

```text
views
functions
queries
tests
application code
```

`CASCADE` should not be used simply to make PostgreSQL remove unknown dependencies automatically.

Dependencies should instead be understood and migrated deliberately.


## Removing product_code

When readers and writers no longer depend on:

```text
tickets.product_code
```

the old column can be removed.

The final relationship is:

```text
tickets.product_id -> products.id
```

`products.code` remains available as a business-facing product code.


# Compatibility overview

| Migration phase | Old reader | Old writer | New reader | New writer |
| --- | --- | --- | --- | --- |
| Original schema | Works | Works | Not deployed | Not deployed |
| After expand | Works | Works | Works | Works |
| After backfill | Works | Works | Works | Works |
| product_id required | Works while old column exists | Fails | Works | Works |
| product_code removed | Fails | Fails | Works | Works |


# Rollout order

A safe deployment order is:

```text
1. Expand database schema
2. Deploy compatible new reader
3. Deploy compatible new writer
4. Run backfill
5. Run verification
6. Stop old writers
7. Make product_id required
8. Move fully to product_id
9. Remove tickets.product_code
```


# Step 8 - EF Core comparison

This project uses SQL migrations directly rather than EF Core.

An equivalent EF Core migration could generate structural changes such as:

```text
add products.id
add tickets.product_id
create foreign key
change product_id to required
remove product_code
```

A simplified example could look like:

```csharp
protected override void Up(MigrationBuilder migrationBuilder)
{
    migrationBuilder.AddColumn<Guid>(
        name: "id",
        table: "products",
        type: "uuid",
        nullable: true);

    migrationBuilder.AddColumn<Guid>(
        name: "product_id",
        table: "tickets",
        type: "uuid",
        nullable: true);

    migrationBuilder.CreateIndex(
        name: "IX_tickets_product_id",
        table: "tickets",
        column: "product_id");

    migrationBuilder.AddForeignKey(
        name: "FK_tickets_products_product_id",
        table: "tickets",
        column: "product_id",
        principalTable: "products",
        principalColumn: "id");
}
```

A migration tool can understand model and schema differences.

For example, it can generate:

```text
new columns
foreign keys
indexes
nullability changes
column removal
```

However, it cannot automatically know the safe rollout process.

The developer still needs to understand:

```text
how existing product_code values map to product_id
when the backfill should run
that the backfill must be safe to rerun
that old writers may still create rows
when old writers have been stopped
when product_id can safely become required
when product_code can safely be removed
that historical ticket price and currency must not change
```

The tool can generate SQL, but it cannot determine all migration decisions from the final model alone.


# Conclusion

The exercise changed the ticket product reference from:

```text
tickets.product_code
```

to:

```text
tickets.product_id
```

without replacing the database contract in one destructive operation.

The main migration pattern was:

```text
Expand
    ↓
Compatibility period
    ↓
Backfill
    ↓
Verify
    ↓
Require new reference
    ↓
Contract
```

The main lesson is that database migration is not only a schema problem.

It is also a problem of:

```text
existing data
compatibility
deployment order
verification
recovery
```

A populated database therefore requires a staged migration rather than an immediate replacement of the old schema.