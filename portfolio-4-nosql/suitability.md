# Why CartIt uses a document for the catalog

The relational tables in Portfolio 1 are the right place for orders, payments, stock, and shopper accounts. A sale has to point at a real variant, a real warehouse, and a real amount of money. Foreign keys and `CHECK` constraints earn their keep there.

The product page is a different shape. A shoe has a size and a colour. A laptop has RAM, storage, and a screen size. A shirt has a fabric. Putting every possible fact into `product_variants` means a wide table full of empty columns: `ram_gb` is meaningless on a mug, and `size` is meaningless on groundnut oil. The other relational habit is an attribute table (`variant_id`, `attribute_name`, `attribute_value`) where every value is text and every filter is an extra join. "In-stock laptops with at least 16 GB of RAM" becomes a join back to the same table, plus a cast.

A document keeps the attributes that belong to that product inside the product:

- `LAP-PRO-16` stores `attributes.ramGb` and `attributes.storageGb`
- `SHOE-RUN-42` stores `attributes.size` and `attributes.colour`
- neither document has the other's fields

The script in [catalog.js](catalog.js) loads six of those documents into MongoDB, asks for in-stock electronics with `attributes.ramGb` of at least 16, and then changes the 16 GB laptop's storage from 512 GB to 1 TB without touching the shoe. The 8 GB laptop is in stock and is excluded. The 32 GB laptop has enough RAM and is excluded because `inStock` is false.

This catalog does not replace `products` and `product_variants`. Checkout still needs a stable SKU, a numeric price, and a stock row. A practical CartIt split is: documents for the product page, and the relational variant row for the SKU that an order line points at. The SKU is the shared identifier.

## The other models, applied to CartIt and not implemented here

The brief asks for one implemented model. The other three are here so the choice is explicit.

**Key-value.** An open cart that only needs to survive while the shopper is on the site can be one value under the key `cart:{customerId}`. Redis-style storage is a good fit for that short-lived blob. It is a poor fit for revenue reports and for a payment that must commit with a stock decrease. Those stay in PostgreSQL.

**Column.** A finance export of "units and revenue by product by month" is a wide analytical table, scanned by column. That is a warehouse, loaded from the relational orders after the fact. It is a poor place to lock the last sneaker.

**Graph.** "Shoppers who bought the Laptop Pro also bought the backpack" is a walk from a product node across order edges to other product nodes. A graph database fits that recommendation question. It is extra machinery for stock and payments, which are ordinary rows.

Documents win for the catalog because the shape of the attributes changes with the product, and the query in the script names a nested field directly.
