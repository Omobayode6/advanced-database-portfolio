# CartIt — MIT 8103 Advanced Database Portfolio

**Course:** MIT 8103 Advanced Database Systems, 2026/2027, first semester
**Student:** Omobayode Festus Osinubi
**Student ID:** 301900904
**Case study:** CartIt, a simulated Nigerian online shop
**GitHub:** https://github.com/Omobayode6/advanced-database-portfolio
**Database:** PostgreSQL on Supabase, project `advanced-database-portfolio`, region `eu-west-2`

CartIt sells laptops, clothes, home goods, and a small grocery range from warehouses in Lagos, Abuja, and Port Harcourt. This repository is the database behind that shop: the relational design, the SQL, the transactions, a document catalog, and a note on how the same database would be copied and split. It is not a storefront.

## What is in each folder

| Folder | What a marker will find |
| --- | --- |
| `portfolio-1-database-design/` | Case study, ER diagram, `schema.sql`, `seed.sql`, normalisation notes |
| `portfolio-2-query-optimisation/` | Five business queries, the volume load, indexes, both execution plans, and the reading of those plans |
| `portfolio-3-transactions-concurrency/` | Committed checkout, rolled-back payment, and the two-session race for the last sneaker |
| `portfolio-4-nosql/` | MongoDB product documents and why a shoe and a laptop do not share one set of columns |
| `portfolio-5-distributed-cloud/` | Replication and sharding design, Supabase setup, and the screenshot folder |
| `docs/` | LMS summary, full reflection, and AI-use declaration |

Evidence already produced from the Supabase project and from the local document script:

- `portfolio-2-query-optimisation/evidence/query-results.txt`
- `portfolio-2-query-optimisation/evidence/explain.txt`
- `portfolio-3-transactions-concurrency/evidence/transactions.txt`
- `portfolio-3-transactions-concurrency/evidence/concurrency-output.txt`
- `portfolio-4-nosql/evidence/catalog-output.txt`

Screenshots, in `portfolio-5-distributed-cloud/screenshots/`:

- `project-home.png` — Supabase project home, region `eu-west-2`
- `cartit-table-list.png` — the `cartit` tables
- `Ada’s-orders.png` — Ada Okonkwo's two orders
- `backpack-commit-and-mug-rollback.png` — backpack stock 39, mug stock 10

## How to rerun it

Requirements: Node 20 or newer, and the Supabase connection string in `.env` at the repository root. `.env` is not committed.

The direct host `db.<project-ref>.supabase.co` is IPv6-only. On an IPv4-only network, use the session pooler URI instead (port 5432, user `postgres.<project-ref>`). Do not use the transaction pooler on port 6543. The last-sneaker demo needs one connection to hold its row lock.

```bash
npm install
npm run db:schema
npm run db:seed
npm run db:volume
npm run db:queries
npm run db:explain
npm run db:transactions
npm run concurrency
npm run nosql
```

`db:schema` drops and recreates the `cartit` schema only. `db:volume` adds 4,000 shoppers so the execution plan has enough rows to consider an index. Those extra orders are loaded as already paid and do not change stock. `npm run nosql` does not use Supabase. The first run downloads a MongoDB binary.

The tables are in the `cartit` schema. In the Supabase SQL editor:

```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'cartit'
ORDER BY table_name;
```

## How the pieces connect

A cart becomes an order inside one transaction. The line stores the price charged that day, stock goes down, and a payment is stored. A declined payment removes the whole checkout, and the stock count stays as it was. Two shoppers then try to buy the last unit of `DEMO-LAST-UNIT` in Lagos. Without a lock, both get a paid order. With `SELECT … FOR UPDATE`, only one does.

Product pages are documents, because a shoe has a size and a laptop has RAM. Orders stay in PostgreSQL and still point at a SKU.

Catalog browsing may read a replica. Checkout and the stock lock stay on the primary. A larger CartIt would shard orders by warehouse region. This student database is one Supabase primary. The shard design is written in `portfolio-5-distributed-cloud/architecture.md`. It is not claimed to be running.
