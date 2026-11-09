-- Extra completed orders so EXPLAIN has enough rows to prefer an index.
-- These rows are historical report data. They are inserted as already paid.
-- They do not pass through checkout and they do not change stock.
-- Re-running deletes the previous volume shoppers and loads them again.
-- The named shoppers from seed.sql are left in place.

SET search_path TO cartit, public;

DELETE FROM customers
WHERE email LIKE 'volume%@cartit.test';

INSERT INTO customers (full_name, email, phone)
SELECT
  'Volume Customer ' || i,
  'volume' || i || '@cartit.test',
  '+234809' || lpad(i::text, 7, '0')
FROM generate_series(1, 4000) AS s (i);

INSERT INTO addresses (customer_id, line1, city, state, country, is_default)
SELECT
  c.customer_id,
  i || ' Volume Street',
  (ARRAY['Lagos', 'Abuja', 'Kano', 'Ibadan', 'Enugu', 'Port Harcourt'])[1 + (i % 6)],
  (ARRAY['Lagos', 'FCT', 'Kano', 'Oyo', 'Enugu', 'Rivers'])[1 + (i % 6)],
  'Nigeria',
  true
FROM customers AS c
JOIN LATERAL (
  SELECT substring(c.email FROM 'volume([0-9]+)')::int AS i
) AS parsed ON true
WHERE c.email LIKE 'volume%@cartit.test';

INSERT INTO orders (customer_id, shipping_address_id, warehouse_id, status, placed_at)
SELECT
  c.customer_id,
  a.address_id,
  w.warehouse_id,
  'paid',
  TIMESTAMP '2026-01-01 08:00+01'
    + (((abs(hashtext(c.email)) + n * 17) % 300) * INTERVAL '1 day')
    + (n * INTERVAL '2 hours')
FROM customers AS c
JOIN addresses AS a ON a.customer_id = c.customer_id AND a.is_default
JOIN warehouses AS w ON w.code = CASE a.city
  WHEN 'Abuja' THEN 'ABJ-1'
  WHEN 'Port Harcourt' THEN 'PHC-1'
  ELSE 'LOS-1'
END
CROSS JOIN generate_series(1, 2) AS n
WHERE c.email LIKE 'volume%@cartit.test';

WITH variants AS (
  SELECT
    v.variant_id,
    v.sku,
    v.list_price,
    v.product_id,
    (row_number() OVER (ORDER BY v.variant_id) - 1) AS rn,
    count(*) OVER () AS variant_count
  FROM product_variants AS v
  WHERE v.sku <> 'DEMO-LAST-UNIT'
)
INSERT INTO order_items (order_id, variant_id, product_name, sku, unit_price, qty)
SELECT
  o.order_id,
  v.variant_id,
  p.name,
  v.sku,
  v.list_price,
  1
FROM orders AS o
JOIN customers AS c ON c.customer_id = o.customer_id
JOIN variants AS v ON v.rn = (o.order_id % v.variant_count)
JOIN products AS p ON p.product_id = v.product_id
WHERE c.email LIKE 'volume%@cartit.test';

ANALYZE customers, addresses, orders, order_items, product_variants, products;
