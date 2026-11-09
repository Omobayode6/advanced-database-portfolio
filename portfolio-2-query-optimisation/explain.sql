-- Before-and-after plans for the March Lagos revenue report.
-- Run seed-volume.sql first. On the twelve named shoppers alone, PostgreSQL often
-- sequential-scans both versions because the tables fit in one page.

SET search_path TO cartit, public;

DROP INDEX IF EXISTS idx_orders_placed_at;
DROP INDEX IF EXISTS idx_orders_customer_id;
DROP INDEX IF EXISTS idx_orders_shipping_address_id;
DROP INDEX IF EXISTS idx_orders_status_placed_at;
DROP INDEX IF EXISTS idx_addresses_city;
DROP INDEX IF EXISTS idx_order_items_order_id;
DROP INDEX IF EXISTS idx_order_items_variant_id;
DROP INDEX IF EXISTS idx_payments_order_id;
DROP INDEX IF EXISTS idx_stock_variant;

ANALYZE orders, order_items, addresses, products, product_variants;

EXPLAIN (ANALYZE, BUFFERS)
SELECT
  a.city,
  p.name AS product,
  COUNT(DISTINCT o.order_id) AS orders,
  SUM(oi.qty * oi.unit_price) AS revenue_ngn
FROM orders AS o
JOIN addresses AS a ON a.address_id = o.shipping_address_id
JOIN order_items AS oi ON oi.order_id = o.order_id
JOIN product_variants AS v ON v.variant_id = oi.variant_id
JOIN products AS p ON p.product_id = v.product_id
WHERE o.placed_at >= TIMESTAMP '2026-03-01 00:00+01'
  AND o.placed_at < TIMESTAMP '2026-04-01 00:00+01'
  AND a.city = 'Lagos'
  AND o.status IN ('paid', 'packed', 'shipped', 'delivered')
GROUP BY a.city, p.name
ORDER BY revenue_ngn DESC;

CREATE INDEX idx_orders_placed_at ON orders (placed_at);
CREATE INDEX idx_orders_customer_id ON orders (customer_id);
CREATE INDEX idx_orders_shipping_address_id ON orders (shipping_address_id);
CREATE INDEX idx_orders_status_placed_at ON orders (status, placed_at);
CREATE INDEX idx_addresses_city ON addresses (city);
CREATE INDEX idx_order_items_order_id ON order_items (order_id);
CREATE INDEX idx_order_items_variant_id ON order_items (variant_id);
CREATE INDEX idx_payments_order_id ON payments (order_id);
CREATE INDEX idx_stock_variant ON stock_levels (variant_id);

ANALYZE orders, order_items, addresses, products, product_variants;

EXPLAIN (ANALYZE, BUFFERS)
SELECT
  a.city,
  p.name AS product,
  COUNT(DISTINCT o.order_id) AS orders,
  SUM(oi.qty * oi.unit_price) AS revenue_ngn
FROM orders AS o
JOIN addresses AS a ON a.address_id = o.shipping_address_id
JOIN order_items AS oi ON oi.order_id = o.order_id
JOIN product_variants AS v ON v.variant_id = oi.variant_id
JOIN products AS p ON p.product_id = v.product_id
WHERE o.placed_at >= TIMESTAMP '2026-03-01 00:00+01'
  AND o.placed_at < TIMESTAMP '2026-04-01 00:00+01'
  AND a.city = 'Lagos'
  AND o.status IN ('paid', 'packed', 'shipped', 'delivered')
GROUP BY a.city, p.name
ORDER BY revenue_ngn DESC;
