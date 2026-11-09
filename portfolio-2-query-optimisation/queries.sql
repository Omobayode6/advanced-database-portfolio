-- CartIt business queries.
-- Run after schema.sql, seed.sql, and (for a realistic heavy report) seed-volume.sql.

SET search_path TO cartit, public;

-- Admin question: which products earned money in the first quarter of 2026?
-- Pending checkouts are excluded. The money used is the snapshotted unit price.
SELECT
  p.name AS product,
  SUM(oi.qty) AS units_sold,
  SUM(oi.qty * oi.unit_price) AS revenue_ngn
FROM order_items AS oi
JOIN orders AS o ON o.order_id = oi.order_id
JOIN product_variants AS v ON v.variant_id = oi.variant_id
JOIN products AS p ON p.product_id = v.product_id
WHERE o.status IN ('paid', 'packed', 'shipped', 'delivered')
  AND o.placed_at >= TIMESTAMP '2026-01-01 00:00+01'
  AND o.placed_at < TIMESTAMP '2026-04-01 00:00+01'
GROUP BY p.name
ORDER BY revenue_ngn DESC;

-- Admin question: which checkouts are still unpaid after two days?
SELECT
  o.order_id,
  c.full_name,
  c.email,
  o.placed_at,
  o.status
FROM orders AS o
JOIN customers AS c ON c.customer_id = o.customer_id
WHERE o.status = 'pending_payment'
  AND o.placed_at < now() - INTERVAL '2 days'
ORDER BY o.placed_at;

-- Warehouse question: which stocked variants are down to five units or fewer?
-- Zero means that warehouse does not carry the variant. Those rows are not a restock alert.
SELECT
  v.sku,
  p.name AS product,
  v.variant_name,
  w.code AS warehouse,
  s.qty_on_hand
FROM stock_levels AS s
JOIN product_variants AS v ON v.variant_id = s.variant_id
JOIN products AS p ON p.product_id = v.product_id
JOIN warehouses AS w ON w.warehouse_id = s.warehouse_id
WHERE s.qty_on_hand BETWEEN 1 AND 5
ORDER BY s.qty_on_hand, v.sku, w.code;

-- Shopper question: Ada's orders, newest first, with the price she was charged.
SELECT
  o.order_id,
  o.placed_at,
  o.status,
  oi.product_name,
  oi.sku,
  oi.qty,
  oi.unit_price
FROM customers AS c
JOIN orders AS o ON o.customer_id = c.customer_id
JOIN order_items AS oi ON oi.order_id = o.order_id
WHERE c.email = 'ada.okonkwo@cartit.test'
ORDER BY o.placed_at DESC, oi.order_item_id;

-- Heavy report used again in explain.sql.
-- March 2026 paid revenue for Lagos delivery addresses, by product.
-- Keep this SELECT text identical to the one inside explain.sql.
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
