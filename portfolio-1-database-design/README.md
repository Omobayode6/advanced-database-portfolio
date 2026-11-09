# Portfolio 1 — Database design and modelling

CartIt is the case study for every portfolio in this repository. This folder is the relational design the later SQL, transactions, and cloud notes all use.

## Files

- [01-case-study.md](01-case-study.md) — organisation, users, data, and operations
- [02-er-diagram.md](02-er-diagram.md) — entities, keys, and the diagram
- [schema.sql](schema.sql) — tables, keys, and constraints
- [seed.sql](seed.sql) — named shoppers, catalog, stock, and past orders
- [04-normalisation.md](04-normalisation.md) — 1NF, 2NF, 3NF, and the order-line snapshot

## How to run

From the repository root, after you have copied `.env.example` to `.env` and pasted your own Supabase session-pooler URI:

```bash
npm run db:schema
npm run db:seed
```

`schema.sql` drops and recreates the `cartit` schema. It does not drop other schemas in the Supabase project.

In the Supabase SQL editor, paste `schema.sql`, run it, then paste `seed.sql` and run that. A check that the load worked:

```sql
SET search_path TO cartit, public;
SELECT COUNT(*) AS customers FROM customers;
SELECT COUNT(*) AS products FROM products;
SELECT sku, qty_on_hand
FROM stock_levels s
JOIN product_variants v ON v.variant_id = s.variant_id
JOIN warehouses w ON w.warehouse_id = s.warehouse_id
WHERE w.code = 'LOS-1' AND v.sku = 'DEMO-LAST-UNIT';
```

Expect 12 customers, 15 products, and a quantity of 1 for `DEMO-LAST-UNIT` in Lagos.
