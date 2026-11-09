# CartIt case study

CartIt is a simulated Nigerian online store. It is not a real company. The same store is used for the design, the SQL, the transactions, the document catalog, and the distributed-database discussion.

CartIt sells laptops, audio gear, clothes, shoes, home goods, and a small grocery range. Shoppers browse a catalog, keep a cart, pay, and track delivery. Staff buy stock into three warehouses and ship from the warehouse closest to the order.

Prices are in Nigerian naira. The sample calendar sits in 2026.

## Users

- **Shopper.** Creates an account, saves a delivery address, adds variants to a cart, pays, and follows the shipment.
- **Store admin.** Adds products and variants, changes a catalog price, reviews unpaid orders, and reads revenue by product.
- **Warehouse officer.** Reads stock in one building, packs a paid order, and records the carrier and tracking number.

## Data the database stores

- People and the address an order should use
- Categories, products, and sellable variants (a laptop with 16 GB RAM and the same laptop with 32 GB are different variants)
- How many units of each variant sit in Lagos, Abuja, and Port Harcourt
- Open carts
- Orders, the price actually charged, payments, and delivery

## Operations the database supports

- Add a product and a variant
- Place an order and reduce stock
- Undo the whole checkout when the payment is declined
- Stop two shoppers from buying the last unit
- Update stock after a delivery arrives at a warehouse
- Track a shipment from the label to delivery
- Report revenue, old unpaid orders, and variants that are almost gone

Four extra accounts exist only so the later scripts have a clean fixture: `demo.success@cartit.test`, `demo.fail@cartit.test`, `race.one@cartit.test`, and `race.two@cartit.test`. The eight named shoppers (Ada Okonkwo through Segun Lawal) are the business sample.
