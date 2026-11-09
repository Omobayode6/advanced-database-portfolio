-- Named CartIt sample. Safe to re-run after schema.sql.
-- Volume rows used for the execution-plan comparison are loaded separately
-- by portfolio-2-query-optimisation/seed-volume.sql.

SET search_path TO cartit, public;

INSERT INTO categories (name, parent_category_id) VALUES
  ('Electronics', NULL),
  ('Fashion', NULL),
  ('Home', NULL),
  ('Groceries', NULL);

INSERT INTO categories (name, parent_category_id)
SELECT child.name, parent.category_id
FROM (
  VALUES
    ('Laptops', 'Electronics'),
    ('Audio', 'Electronics'),
    ('Footwear', 'Fashion'),
    ('Clothing', 'Fashion'),
    ('Kitchen', 'Home')
) AS child (name, parent_name)
JOIN categories AS parent ON parent.name = child.parent_name;

INSERT INTO products (category_id, name, description)
SELECT c.category_id, p.name, p.description
FROM (
  VALUES
    ('Laptops', 'CartIt Laptop Pro', '14 to 16 inch laptop for work and study'),
    ('Laptops', 'CartIt Laptop Air', 'Lighter laptop with 8 GB RAM'),
    ('Audio', 'CartIt Buds', 'Wireless earbuds'),
    ('Footwear', 'CartIt Runner', 'Everyday running shoe'),
    ('Clothing', 'Ankara Shirt', 'Ready-to-wear Ankara shirt'),
    ('Fashion', 'CartIt Backpack', 'Laptop backpack'),
    ('Kitchen', 'Non-stick Pot Set', 'Three-piece pot set'),
    ('Home', 'LED Desk Lamp', 'Dimmable desk lamp'),
    ('Home', 'Queen Bed Sheet', 'Cotton queen sheet'),
    ('Groceries', 'Ofada Rice 5kg', 'Bag of Ofada rice'),
    ('Groceries', 'Groundnut Oil 2L', 'Bottle of groundnut oil'),
    ('Groceries', 'Instant Noodles Pack', 'Carton of instant noodles'),
    ('Electronics', 'CartIt Watch', 'Everyday smart watch'),
    ('Footwear', 'Limited Drop Sneaker', 'One-pair release used by the concurrency demo'),
    ('Kitchen', 'Ceramic Mug', 'Single ceramic mug')
) AS p (category_name, name, description)
JOIN categories AS c ON c.name = p.category_name;

INSERT INTO product_variants (product_id, sku, variant_name, list_price)
SELECT p.product_id, v.sku, v.variant_name, v.list_price
FROM (
  VALUES
    ('CartIt Laptop Pro', 'LAP-PRO-16', '16 GB / 512 GB', 980000.00),
    ('CartIt Laptop Pro', 'LAP-PRO-32', '32 GB / 1 TB', 1450000.00),
    ('CartIt Laptop Air', 'LAP-AIR-8', '8 GB / 256 GB', 720000.00),
    ('CartIt Buds', 'BUDS-BLK', 'Black', 45000.00),
    ('CartIt Buds', 'BUDS-WHT', 'White', 45000.00),
    ('CartIt Runner', 'SHOE-RUN-42', 'Size 42', 62000.00),
    ('CartIt Runner', 'SHOE-RUN-43', 'Size 43', 62000.00),
    ('Ankara Shirt', 'ANKARA-M', 'Medium', 18000.00),
    ('Ankara Shirt', 'ANKARA-L', 'Large', 18000.00),
    ('CartIt Backpack', 'BAG-PACK-OS', 'One size', 35000.00),
    ('Non-stick Pot Set', 'POT-SET-3', '3 piece', 28000.00),
    ('LED Desk Lamp', 'LAMP-LED-W', 'White', 15000.00),
    ('Queen Bed Sheet', 'SHEET-Q-GRY', 'Grey', 22000.00),
    ('Queen Bed Sheet', 'SHEET-Q-WHT', 'White', 22000.00),
    ('Ofada Rice 5kg', 'RICE-OFADA-5', '5 kg bag', 12500.00),
    ('Groundnut Oil 2L', 'OIL-GNT-2L', '2 litre', 9800.00),
    ('Instant Noodles Pack', 'NOODLES-40', '40 pack', 7500.00),
    ('CartIt Watch', 'WATCH-BLK', 'Black', 54000.00),
    ('Limited Drop Sneaker', 'DEMO-LAST-UNIT', 'Size 42', 88000.00),
    ('Ceramic Mug', 'MUG-CER-GRN', 'Green', 4500.00)
) AS v (product_name, sku, variant_name, list_price)
JOIN products AS p ON p.name = v.product_name;

INSERT INTO warehouses (code, name, city, region) VALUES
  ('LOS-1', 'Lagos Fulfilment Centre', 'Lagos', 'South-West'),
  ('ABJ-1', 'Abuja Fulfilment Centre', 'Abuja', 'North-Central'),
  ('PHC-1', 'Port Harcourt Fulfilment Centre', 'Port Harcourt', 'South-South');

-- Default stock is healthy. A few rows are deliberately low for the stock query
-- and for the two checkout scripts.
INSERT INTO stock_levels (warehouse_id, variant_id, qty_on_hand)
SELECT
  w.warehouse_id,
  v.variant_id,
  CASE
    WHEN v.sku = 'DEMO-LAST-UNIT' AND w.code = 'LOS-1' THEN 1
    WHEN v.sku = 'DEMO-LAST-UNIT' THEN 0
    WHEN v.sku = 'OIL-GNT-2L' AND w.code = 'LOS-1' THEN 3
    WHEN v.sku = 'MUG-CER-GRN' AND w.code = 'LOS-1' THEN 10
    WHEN v.sku = 'MUG-CER-GRN' AND w.code = 'ABJ-1' THEN 4
    WHEN v.sku = 'BAG-PACK-OS' AND w.code = 'LOS-1' THEN 40
    ELSE 20 + (v.variant_id % 8)
  END
FROM warehouses AS w
CROSS JOIN product_variants AS v;

INSERT INTO customers (full_name, email, phone) VALUES
  ('Ada Okonkwo', 'ada.okonkwo@cartit.test', '+2348010000001'),
  ('Chinedu Bello', 'chinedu.bello@cartit.test', '+2348010000002'),
  ('Fatima Yusuf', 'fatima.yusuf@cartit.test', '+2348010000003'),
  ('Tunde Adeyemi', 'tunde.adeyemi@cartit.test', '+2348010000004'),
  ('Ngozi Eze', 'ngozi.eze@cartit.test', '+2348010000005'),
  ('Ibrahim Sule', 'ibrahim.sule@cartit.test', '+2348010000006'),
  ('Amaka Nwosu', 'amaka.nwosu@cartit.test', '+2348010000007'),
  ('Segun Lawal', 'segun.lawal@cartit.test', '+2348010000008'),
  ('Demo Success', 'demo.success@cartit.test', '+2348010000101'),
  ('Demo Fail', 'demo.fail@cartit.test', '+2348010000102'),
  ('Race One', 'race.one@cartit.test', '+2348010000201'),
  ('Race Two', 'race.two@cartit.test', '+2348010000202');

INSERT INTO addresses (customer_id, line1, city, state, country, is_default)
SELECT c.customer_id, a.line1, a.city, a.state, 'Nigeria', true
FROM (
  VALUES
    ('ada.okonkwo@cartit.test', '14 Admiralty Way, Lekki', 'Lagos', 'Lagos'),
    ('chinedu.bello@cartit.test', '8 Gana Street, Maitama', 'Abuja', 'FCT'),
    ('fatima.yusuf@cartit.test', '22 Zoo Road', 'Kano', 'Kano'),
    ('tunde.adeyemi@cartit.test', '5 Ring Road', 'Ibadan', 'Oyo'),
    ('ngozi.eze@cartit.test', '17 Ogui Road', 'Enugu', 'Enugu'),
    ('ibrahim.sule@cartit.test', '3 Ahmadu Bello Way', 'Kaduna', 'Kaduna'),
    ('amaka.nwosu@cartit.test', '11 Aba Road', 'Port Harcourt', 'Rivers'),
    ('segun.lawal@cartit.test', '9 Bode Thomas, Surulere', 'Lagos', 'Lagos'),
    ('demo.success@cartit.test', '1 Demo Close', 'Lagos', 'Lagos'),
    ('demo.fail@cartit.test', '2 Demo Close', 'Lagos', 'Lagos'),
    ('race.one@cartit.test', '1 Race Lane', 'Lagos', 'Lagos'),
    ('race.two@cartit.test', '2 Race Lane', 'Lagos', 'Lagos')
) AS a (email, line1, city, state)
JOIN customers AS c ON c.email = a.email;

-- One completed sale. The line copies the catalog price at this moment.
WITH new_order AS (
  INSERT INTO orders (customer_id, shipping_address_id, warehouse_id, status, placed_at)
  SELECT c.customer_id, a.address_id, w.warehouse_id, 'paid', TIMESTAMP '2026-02-12 10:30+01'
  FROM customers AS c
  JOIN addresses AS a ON a.customer_id = c.customer_id AND a.is_default
  JOIN warehouses AS w ON w.code = 'LOS-1'
  WHERE c.email = 'ada.okonkwo@cartit.test'
  RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, product_name, sku, unit_price, qty)
SELECT n.order_id, v.variant_id, p.name, v.sku, v.list_price, 1
FROM new_order AS n
JOIN product_variants AS v ON v.sku = 'LAP-PRO-16'
JOIN products AS p ON p.product_id = v.product_id;

WITH new_order AS (
  INSERT INTO orders (customer_id, shipping_address_id, warehouse_id, status, placed_at)
  SELECT c.customer_id, a.address_id, w.warehouse_id, 'delivered', TIMESTAMP '2026-03-20 15:10+01'
  FROM customers AS c
  JOIN addresses AS a ON a.customer_id = c.customer_id AND a.is_default
  JOIN warehouses AS w ON w.code = 'LOS-1'
  WHERE c.email = 'ada.okonkwo@cartit.test'
  RETURNING order_id, placed_at
)
INSERT INTO order_items (order_id, variant_id, product_name, sku, unit_price, qty)
SELECT n.order_id, v.variant_id, p.name, v.sku, v.list_price, 1
FROM new_order AS n
JOIN product_variants AS v ON v.sku = 'SHOE-RUN-42'
JOIN products AS p ON p.product_id = v.product_id;

WITH new_order AS (
  INSERT INTO orders (customer_id, shipping_address_id, warehouse_id, status, placed_at)
  SELECT c.customer_id, a.address_id, w.warehouse_id, 'paid', TIMESTAMP '2026-01-18 09:00+01'
  FROM customers AS c
  JOIN addresses AS a ON a.customer_id = c.customer_id AND a.is_default
  JOIN warehouses AS w ON w.code = 'ABJ-1'
  WHERE c.email = 'chinedu.bello@cartit.test'
  RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, product_name, sku, unit_price, qty)
SELECT n.order_id, v.variant_id, p.name, v.sku, v.list_price, 1
FROM new_order AS n
JOIN product_variants AS v ON v.sku = 'ANKARA-M'
JOIN products AS p ON p.product_id = v.product_id;

WITH new_order AS (
  INSERT INTO orders (customer_id, shipping_address_id, warehouse_id, status, placed_at)
  SELECT c.customer_id, a.address_id, w.warehouse_id, 'pending_payment', TIMESTAMP '2026-11-01 18:40+01'
  FROM customers AS c
  JOIN addresses AS a ON a.customer_id = c.customer_id AND a.is_default
  JOIN warehouses AS w ON w.code = 'ABJ-1'
  WHERE c.email = 'chinedu.bello@cartit.test'
  RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, product_name, sku, unit_price, qty)
SELECT n.order_id, v.variant_id, p.name, v.sku, v.list_price, 1
FROM new_order AS n
JOIN product_variants AS v ON v.sku = 'RICE-OFADA-5'
JOIN products AS p ON p.product_id = v.product_id;

WITH new_order AS (
  INSERT INTO orders (customer_id, shipping_address_id, warehouse_id, status, placed_at)
  SELECT c.customer_id, a.address_id, w.warehouse_id, 'delivered', TIMESTAMP '2026-08-02 12:15+01'
  FROM customers AS c
  JOIN addresses AS a ON a.customer_id = c.customer_id AND a.is_default
  JOIN warehouses AS w ON w.code = 'ABJ-1'
  WHERE c.email = 'fatima.yusuf@cartit.test'
  RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, product_name, sku, unit_price, qty)
SELECT n.order_id, v.variant_id, p.name, v.sku, v.list_price, 1
FROM new_order AS n
JOIN product_variants AS v ON v.sku = 'POT-SET-3'
JOIN products AS p ON p.product_id = v.product_id;

WITH new_order AS (
  INSERT INTO orders (customer_id, shipping_address_id, warehouse_id, status, placed_at)
  SELECT c.customer_id, a.address_id, w.warehouse_id, 'pending_payment', TIMESTAMP '2026-10-28 08:05+01'
  FROM customers AS c
  JOIN addresses AS a ON a.customer_id = c.customer_id AND a.is_default
  JOIN warehouses AS w ON w.code = 'LOS-1'
  WHERE c.email = 'tunde.adeyemi@cartit.test'
  RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, product_name, sku, unit_price, qty)
SELECT n.order_id, v.variant_id, p.name, v.sku, v.list_price, 1
FROM new_order AS n
JOIN product_variants AS v ON v.sku = 'LAMP-LED-W'
JOIN products AS p ON p.product_id = v.product_id;

WITH new_order AS (
  INSERT INTO orders (customer_id, shipping_address_id, warehouse_id, status, placed_at)
  SELECT c.customer_id, a.address_id, w.warehouse_id, 'shipped', TIMESTAMP '2026-05-05 11:45+01'
  FROM customers AS c
  JOIN addresses AS a ON a.customer_id = c.customer_id AND a.is_default
  JOIN warehouses AS w ON w.code = 'PHC-1'
  WHERE c.email = 'ngozi.eze@cartit.test'
  RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, product_name, sku, unit_price, qty)
SELECT n.order_id, v.variant_id, p.name, v.sku, v.list_price, 1
FROM new_order AS n
JOIN product_variants AS v ON v.sku = 'WATCH-BLK'
JOIN products AS p ON p.product_id = v.product_id;

WITH new_order AS (
  INSERT INTO orders (customer_id, shipping_address_id, warehouse_id, status, placed_at)
  SELECT c.customer_id, a.address_id, w.warehouse_id, 'paid', TIMESTAMP '2026-09-12 16:20+01'
  FROM customers AS c
  JOIN addresses AS a ON a.customer_id = c.customer_id AND a.is_default
  JOIN warehouses AS w ON w.code = 'ABJ-1'
  WHERE c.email = 'ibrahim.sule@cartit.test'
  RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, product_name, sku, unit_price, qty)
SELECT n.order_id, v.variant_id, p.name, v.sku, v.list_price, 2
FROM new_order AS n
JOIN product_variants AS v ON v.sku = 'NOODLES-40'
JOIN products AS p ON p.product_id = v.product_id;

WITH new_order AS (
  INSERT INTO orders (customer_id, shipping_address_id, warehouse_id, status, placed_at)
  SELECT c.customer_id, a.address_id, w.warehouse_id, 'paid', TIMESTAMP '2026-04-03 13:00+01'
  FROM customers AS c
  JOIN addresses AS a ON a.customer_id = c.customer_id AND a.is_default
  JOIN warehouses AS w ON w.code = 'PHC-1'
  WHERE c.email = 'amaka.nwosu@cartit.test'
  RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, product_name, sku, unit_price, qty)
SELECT n.order_id, v.variant_id, p.name, v.sku, v.list_price, 1
FROM new_order AS n
JOIN product_variants AS v ON v.sku = 'BUDS-BLK'
JOIN products AS p ON p.product_id = v.product_id;

WITH new_order AS (
  INSERT INTO orders (customer_id, shipping_address_id, warehouse_id, status, placed_at)
  SELECT c.customer_id, a.address_id, w.warehouse_id, 'paid', TIMESTAMP '2026-06-15 19:30+01'
  FROM customers AS c
  JOIN addresses AS a ON a.customer_id = c.customer_id AND a.is_default
  JOIN warehouses AS w ON w.code = 'LOS-1'
  WHERE c.email = 'segun.lawal@cartit.test'
  RETURNING order_id
)
INSERT INTO order_items (order_id, variant_id, product_name, sku, unit_price, qty)
SELECT n.order_id, v.variant_id, p.name, v.sku, v.list_price, 1
FROM new_order AS n
JOIN product_variants AS v ON v.sku = 'SHEET-Q-GRY'
JOIN products AS p ON p.product_id = v.product_id;

INSERT INTO payments (order_id, amount, status, method, paid_at)
SELECT o.order_id, SUM(oi.qty * oi.unit_price), 'captured', 'card', o.placed_at
FROM orders AS o
JOIN order_items AS oi ON oi.order_id = o.order_id
WHERE o.status IN ('paid', 'packed', 'shipped', 'delivered')
GROUP BY o.order_id, o.placed_at;

INSERT INTO shipments (order_id, carrier, tracking_number, status, shipped_at, delivered_at)
SELECT o.order_id, s.carrier, s.tracking_number, s.status, s.shipped_at, s.delivered_at
FROM (
  VALUES
    ('ada.okonkwo@cartit.test', TIMESTAMP '2026-03-20 15:10+01', 'DHL', 'CT-ADA-20260320', 'delivered', TIMESTAMP '2026-03-21 09:00+01', TIMESTAMP '2026-03-23 14:12+01'),
    ('fatima.yusuf@cartit.test', TIMESTAMP '2026-08-02 12:15+01', 'GIG Logistics', 'CT-FAT-20260802', 'delivered', TIMESTAMP '2026-08-02 17:00+01', TIMESTAMP '2026-08-05 11:40+01'),
    ('ngozi.eze@cartit.test', TIMESTAMP '2026-05-05 11:45+01', 'GIG Logistics', 'CT-NGO-20260505', 'in_transit', TIMESTAMP '2026-05-06 08:30+01', NULL::timestamptz)
) AS s (email, placed_at, carrier, tracking_number, status, shipped_at, delivered_at)
JOIN customers AS c ON c.email = s.email
JOIN orders AS o ON o.customer_id = c.customer_id AND o.placed_at = s.placed_at;

-- Checkout fixtures. The transaction script resets these carts and stock levels.
INSERT INTO carts (customer_id, status)
SELECT customer_id, 'open'
FROM customers
WHERE email IN ('demo.success@cartit.test', 'demo.fail@cartit.test');

INSERT INTO cart_items (cart_id, variant_id, qty)
SELECT cart.cart_id, v.variant_id, 1
FROM carts AS cart
JOIN customers AS c ON c.customer_id = cart.customer_id
JOIN product_variants AS v ON v.sku = CASE c.email
  WHEN 'demo.success@cartit.test' THEN 'BAG-PACK-OS'
  WHEN 'demo.fail@cartit.test' THEN 'MUG-CER-GRN'
END
WHERE c.email IN ('demo.success@cartit.test', 'demo.fail@cartit.test');
