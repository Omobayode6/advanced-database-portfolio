# CartIt on more than one database server

The Supabase project that hosts this portfolio is one PostgreSQL database in one region. Portfolio 1's schema, the reports, and the checkout transaction all run there. This note describes how CartIt would be split and copied if that single database stopped being enough, and what the live Supabase project is evidence of.

## What the single database already gives CartIt

One primary database can commit the backpack checkout in `place_order`: the order, the line, the payment, and the stock decrease succeed or fail together. Backups and a hosted connection string are the cloud part. They are not sharding, and they are not a second copy that serves reads.

Say that plainly in the LMS write-up. Claiming the student project is sharded would be false.

## Replication: a copy for browsing, the primary for checkout

Most CartIt traffic is people reading products, prices, and "how many are left". Those reads can go to a **replica**, a copy that follows the primary.

The copy is allowed to be a little late. A product page can show yesterday's review count, or a stock figure that is a second behind, and the shopper is not harmed. The checkout is different. `place_order` and the last-sneaker lock must run on the **primary**. A replica that still says `qty_on_hand = 1` after the primary has sold the unit will sell the sneaker twice if checkout trusts it.

CartIt's rule:

- catalog and "low stock" dashboards may read a replica
- `SELECT … FOR UPDATE` on `stock_levels`, the order insert, and the payment insert run on the primary
- the price copied onto `order_items.unit_price` is the primary's price at commit time, so a lagging replica cannot freeze an old price into the sale

If the replica falls behind during a sale, shoppers may see a laptop as available and then get "insufficient stock" at payment. That message is the consistent outcome. Selling the unit twice is the outcome this design refuses.

## Sharding: orders split by warehouse region

A shard is a split of the rows, not a copy. CartIt's natural split is `warehouses.region`:

- South-West orders (Lagos, `LOS-1`) live on one shard
- North-Central orders (Abuja, `ABJ-1`) live on another
- South-South orders (Port Harcourt, `PHC-1`) live on a third

The shard key is the region because a warehouse officer's day is local: pack Lagos orders from the Lagos shard. `orders.warehouse_id` decides the shard. Payment rows stay on the **same** shard as their order, so the commit in `place_order` is still one local transaction. Putting payments on a different shard would mean a distributed transaction for every checkout.

Product and variant rows are small and needed everywhere, so they are copied onto every shard. The SKU on the order line still snapshots the name and the price. Stock for a variant stays on the shard of the warehouse that holds it. Lagos does not lock Abuja's stock row.

The cost shows up in the March revenue report from Portfolio 2. That report adds up every region. A sharded CartIt has to ask every shard and merge the totals. The single Supabase database answers it with one query. Sharding is justified when one region's writes no longer fit, not because the report looks advanced.

Shopper accounts are the awkward piece. Ada can live in Lagos and order from the Lagos warehouse today, then order something that only Abuja has. Two workable choices:

- keep `customers` and `addresses` on every shard (a small table, copied), and create the order on the warehouse's shard
- keep shoppers on one directory database, and store `customer_id` on the order without a cross-shard foreign key

The portfolio schema uses a real foreign key because it runs on one database. A sharded deployment would have to drop the cross-shard foreign key and check the shopper in the application, or keep shoppers copied to every shard.

## Consistency, availability, and a network split

When the network between Lagos and Abuja misbehaves, CartIt cannot have every property at once.

Checkout chooses **consistency**. If the primary for that region cannot be sure the stock row is current, it refuses the sale. A second shopper does not get the last sneaker. The screen can say the payment did not complete. That matches the rollback already demonstrated: a declined or uncertain payment leaves stock unchanged.

Catalog browsing chooses **availability**. If a replica is reachable, it serves the product page even when it cannot check the other region's primary. The page can be slightly stale. The buy button still has to talk to the primary before money moves.

A partition is not an outage of the whole shop. Abuja checkout can continue on the Abuja shard while Lagos is unreachable. What fails is a report, or a cart, that needs both.

## How this maps back to the SQL you already have

- `stock_levels` with primary key `(warehouse_id, variant_id)` is the row the primary locks
- `orders.warehouse_id` is the shard key
- `order_items.unit_price` is the value that must be taken from the primary, not from a stale product page
- the lost-update demo is the bug replication lag recreates, if two regions both believe they hold the last unit

## What the Supabase project shows

The live project is one primary in `eu-west-2`. Rerun steps are in the repository README. The project home is in [screenshots/project-home.png](screenshots/project-home.png). This file is the design for the step beyond that single node.
