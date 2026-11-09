# Normalisation

CartIt started from the kind of spreadsheet a small shop already has: one row tries to hold the shopper, the address, every product in the order, the payment, and the tracking number.

| order | shopper | email | city | product 1 | sku 1 | price 1 | qty 1 | product 2 | sku 2 | price 2 | qty 2 | payment | tracking |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1001 | Ada Okonkwo | ada.okonkwo@cartit.test | Lagos | CartIt Laptop Pro | LAP-PRO-16 | 980000 | 1 | CartIt Runner | SHOE-RUN-42 | 62000 | 1 | card | CT-ADA-1 |

That row is convenient to type and awkward to query. Adding a third product means adding more columns. A shopper who moves means hunting down every old order. A price change means deciding whether history should change too.

## First normal form

First normal form removes repeating groups. Product 1 and product 2 are the same kind of fact, so they become rows in a line table, not extra columns. Each line holds one variant, one quantity, and one price. The order, the shopper, and the address stay beside the line only while the design is still flat.

## Second normal form

Assume the line's key is `(order_id, sku)`. Quantity depends on the whole key. The shopper's name and city depend only on `order_id`. Those columns do not belong on the line. Splitting `orders` from `order_items` removes that partial dependency.

`sku` also determines the catalog product name and the current list price. Those catalog facts move to `product_variants` and `products`, keyed by the variant.

## Third normal form

In the order row that is left, city and street are not really facts about the order. They are facts about an address, and the address belongs to a shopper. A shopper can have more than one address, and can change the default address later. `addresses` is its own table. `orders.shipping_address_id` points at the address used for that delivery.

The same pass separates categories, warehouses, stock, carts, payments, and shipments. Each non-key column in those tables describes the key of that table:

- `email` determines the shopper's name and phone
- `sku` determines the variant name and the current list price
- `(warehouse_id, variant_id)` determines the quantity on hand
- `tracking_number` determines the carrier and the shipment status

## The snapshot that is deliberately not "fully normalised" away

`order_items` still stores `product_name`, `sku`, and `unit_price`. On the day of the sale, those values are copied from the variant. After the sale they mean something else: the name and the price the shopper was charged.

If the only price in the database were `product_variants.list_price`, an admin changing today's price would rewrite last March's revenue. The copy on the line is a fact about the sale. Once it is copied, `sku` no longer determines `unit_price`, because the catalog can move while the invoice stays still. That is why the column stays.

`schema.sql` still has a foreign key from the line to `product_variants`, so the sale points at a real variant. The snapshot columns are the historical record.

## Constraints that protect the normalised tables

- Primary keys on every table, plus alternate keys on email, SKU, warehouse code, and tracking number
- Foreign keys so an order cannot point at a missing shopper, address, or warehouse
- `CHECK` rules so stock cannot go negative, quantities must be positive, and status values stay inside a fixed list
- One default address per shopper, and one open cart per shopper

Portfolio 2 adds indexes that exist to make reports faster. Those indexes are not part of the logical model.
