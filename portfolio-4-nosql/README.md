# Portfolio 4 — NoSQL and a document catalog

CartIt's product pages do not share one set of columns. This folder stores a shoe, a shirt, and three laptops as MongoDB documents and runs a nested query against them.

The relational schema from Portfolio 1 stays the system of record for orders and stock. The document catalog is the product-page model.

## Files

- [data/products.json](data/products.json) — six catalog documents
- [catalog.js](catalog.js) — starts an in-memory MongoDB, inserts the documents, queries, and updates one nested field
- [suitability.md](suitability.md) — why documents fit this data, and how key-value, column, and graph would fit other CartIt jobs

## How to run

From the repository root:

```bash
npm run nosql
```

The first run downloads a MongoDB binary. Later runs reuse it. The script writes `evidence/catalog-output.txt`, and that output is already saved there.

No Supabase connection is required. The script does not read `DATABASE_URL`.

## What the output should show

- 6 documents inserted
- one laptop in the query result: `LAP-PRO-16`
- `LAP-AIR-8` absent, because 8 GB is below 16
- `LAP-PRO-32` absent, because it is not in stock
- after the update, `LAP-PRO-16` has `storageGb` 1024 and price 1010000
- the size-42 shoe still has `size` and `colour`, and no RAM field
