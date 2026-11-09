# Reading the CartIt execution plans

PostgreSQL does not run a query by walking the SQL text from top to bottom. The planner builds a tree of steps. `EXPLAIN` prints that tree. `EXPLAIN (ANALYZE, BUFFERS)` runs the query and adds the time and the pages actually touched.

The figures below are taken from [evidence/explain.txt](evidence/explain.txt), produced by `npm run db:explain` on the Supabase database after [seed-volume.sql](seed-volume.sql).

## Results from my run

Before the extra indexes:

- Node on `orders`: Seq Scan on orders o
- Startup cost / total cost: 0.00..235.20
- Actual time: 0.010..1.885
- Shared buffers hit / read: shared hit=75 read=0
- Rows removed by the `placed_at` filter: 7214

After the extra indexes:

- Node on `orders`: Index Scan using idx_orders_status_placed_at on orders o
- Startup cost / total cost: 0.28..64.37
- Actual time: 0.070..0.572
- Shared buffers hit / read: shared hit=730 read=5
- Index name: `idx_orders_status_placed_at`. The same plan also used `idx_addresses_city` (bitmap index scan for Lagos) and `idx_order_items_order_id` (index scan from each order to its lines).

Did the index help on this database? Yes. The whole query's `Execution Time` fell from 5.003 ms to 2.271 ms. The first plan read `orders` with a sequential scan and threw away 7,214 rows that were outside March or not in a completed status. The second plan did not have a "rows removed" line on `orders`, because `idx_orders_status_placed_at` already limited the scan to paid, packed, shipped, and delivered orders in March. The buffer count on that `orders` node went up, from shared hit=75 to shared hit=730 read=5, because the index pages are counted as well. The clock still improved.

## What this Supabase plan did

After the volume load, the first plan scanned `orders` and `addresses` sequentially and threw away the rows outside March and outside Lagos. The second plan used:

- `Index Scan` on `idx_orders_status_placed_at` for completed orders in March
- `Bitmap Index Scan` on `idx_addresses_city` for Lagos
- `Index Scan` on `idx_order_items_order_id` to find each order's lines

`idx_orders_placed_at` was created in the same script. The planner chose the status-and-date index instead, because the query filters on both `status` and `placed_at`.

## How to read a node

A **sequential scan** on `orders` means PostgreSQL reads the order pages and throws away rows that fail the date or status test. With about eight thousand volume orders plus the named ones, most rows are outside March, so a sequential scan does a lot of throwing away.

An **index scan** or a **bitmap index scan** on `idx_orders_placed_at` (or `idx_orders_status_placed_at`) means PostgreSQL uses the date index to visit March first. A bitmap scan is common when many rows match: it builds a map of matching pages, then reads those pages.

`idx_addresses_city` can do the same job for `a.city = 'Lagos'`. `idx_order_items_order_id` supports the join from each surviving order to its lines. Without that index, the planner may scan `order_items` for every order.

`customers.email` is already unique, so Ada's history query has an index before this portfolio adds anything. The March report does not filter by email, which is why the new indexes are about dates, cities, and foreign keys.

## When an index is a poor trade

On the twelve named shoppers alone, both plans are often sequential scans. The table fits in a page or two, and reading it outright is cheaper than walking an index. That result is still worth keeping: it shows the planner costing the choices, not a rule that "indexes always win".

Indexes also slow down inserts and updates, because each new order must be added to `idx_orders_placed_at` and the other order indexes. CartIt can afford that. Orders are written once at checkout. The March revenue report is read whenever an admin opens it.

`CREATE INDEX CONCURRENTLY` is the production form, because it does not block writes for the whole build. This portfolio uses plain `CREATE INDEX` so the script still runs inside the Supabase SQL editor, which often wraps a script in a single transaction. `CONCURRENTLY` is not allowed there.

## What to say if the two times are close

Buffer counts tell the truth when the clock does not. A plan that reads fewer pages is the better plan even if both finish in a few milliseconds on a tiny cloud database. Quote the `Buffers:` line and the scan type from your file, not a generic claim that the index was faster.
