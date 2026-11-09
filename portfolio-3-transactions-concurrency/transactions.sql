-- Checkout as a transaction.
-- Success commits an order, a snapshotted line, a captured payment, a stock decrease, and a closed cart.
-- A declined payment is raised inside place_order. The DO block catches it and undoes that work.
-- Re-running this file puts the two demo carts and their stock back to the seed baseline first.

SET search_path TO cartit, public;

CREATE OR REPLACE FUNCTION place_order(
  p_customer_id bigint,
  p_warehouse_id bigint,
  p_payment_method text,
  p_force_fail boolean DEFAULT false
) RETURNS bigint
LANGUAGE plpgsql
SET search_path = cartit, public
AS $$
DECLARE
  v_order_id bigint;
  v_address_id bigint;
  v_total numeric(12, 2);
  v_qty integer;
  rec record;
BEGIN
  SELECT address_id
  INTO v_address_id
  FROM addresses
  WHERE customer_id = p_customer_id
    AND is_default
  LIMIT 1;

  IF v_address_id IS NULL THEN
    RAISE EXCEPTION 'No default address for customer %', p_customer_id;
  END IF;

  INSERT INTO orders (customer_id, shipping_address_id, warehouse_id, status)
  VALUES (p_customer_id, v_address_id, p_warehouse_id, 'pending_payment')
  RETURNING order_id INTO v_order_id;

  FOR rec IN
    SELECT ci.variant_id, ci.qty, v.list_price, v.sku, p.name AS product_name
    FROM carts AS c
    JOIN cart_items AS ci ON ci.cart_id = c.cart_id
    JOIN product_variants AS v ON v.variant_id = ci.variant_id
    JOIN products AS p ON p.product_id = v.product_id
    WHERE c.customer_id = p_customer_id
      AND c.status = 'open'
  LOOP
    SELECT qty_on_hand
    INTO v_qty
    FROM stock_levels
    WHERE warehouse_id = p_warehouse_id
      AND variant_id = rec.variant_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'No stock row for variant %', rec.variant_id;
    END IF;

    UPDATE stock_levels
    SET qty_on_hand = qty_on_hand - rec.qty
    WHERE warehouse_id = p_warehouse_id
      AND variant_id = rec.variant_id
      AND qty_on_hand >= rec.qty;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Insufficient stock for variant %', rec.variant_id;
    END IF;

    INSERT INTO order_items (order_id, variant_id, product_name, sku, unit_price, qty)
    VALUES (v_order_id, rec.variant_id, rec.product_name, rec.sku, rec.list_price, rec.qty);
  END LOOP;

  SELECT COALESCE(SUM(qty * unit_price), 0)
  INTO v_total
  FROM order_items
  WHERE order_id = v_order_id;

  IF v_total = 0 THEN
    RAISE EXCEPTION 'Cart is empty';
  END IF;

  IF p_force_fail THEN
    INSERT INTO payments (order_id, amount, status, method)
    VALUES (v_order_id, v_total, 'failed', p_payment_method);
    RAISE EXCEPTION 'Payment declined';
  END IF;

  INSERT INTO payments (order_id, amount, status, method, paid_at)
  VALUES (v_order_id, v_total, 'captured', p_payment_method, now());

  UPDATE orders
  SET status = 'paid'
  WHERE order_id = v_order_id;

  UPDATE carts
  SET status = 'checked_out', updated_at = now()
  WHERE customer_id = p_customer_id
    AND status = 'open';

  RETURN v_order_id;
END;
$$;

DELETE FROM orders
WHERE customer_id IN (
  SELECT customer_id
  FROM customers
  WHERE email IN ('demo.success@cartit.test', 'demo.fail@cartit.test')
);

UPDATE carts
SET status = 'open', updated_at = now()
WHERE customer_id IN (
  SELECT customer_id
  FROM customers
  WHERE email IN ('demo.success@cartit.test', 'demo.fail@cartit.test')
);

UPDATE stock_levels AS s
SET qty_on_hand = 40
FROM product_variants AS v, warehouses AS w
WHERE s.variant_id = v.variant_id
  AND s.warehouse_id = w.warehouse_id
  AND v.sku = 'BAG-PACK-OS'
  AND w.code = 'LOS-1';

UPDATE stock_levels AS s
SET qty_on_hand = 10
FROM product_variants AS v, warehouses AS w
WHERE s.variant_id = v.variant_id
  AND s.warehouse_id = w.warehouse_id
  AND v.sku = 'MUG-CER-GRN'
  AND w.code = 'LOS-1';

BEGIN;

SELECT place_order(
  (SELECT customer_id FROM customers WHERE email = 'demo.success@cartit.test'),
  (SELECT warehouse_id FROM warehouses WHERE code = 'LOS-1'),
  'card',
  false
);

COMMIT;

SELECT
  'after_commit' AS step,
  v.sku,
  s.qty_on_hand,
  cart.status AS cart_status,
  o.order_id,
  o.status AS order_status,
  pay.status AS payment_status,
  oi.unit_price
FROM customers AS c
JOIN carts AS cart ON cart.customer_id = c.customer_id
JOIN stock_levels AS s ON s.warehouse_id = (SELECT warehouse_id FROM warehouses WHERE code = 'LOS-1')
JOIN product_variants AS v ON v.variant_id = s.variant_id AND v.sku = 'BAG-PACK-OS'
LEFT JOIN orders AS o ON o.customer_id = c.customer_id
LEFT JOIN payments AS pay ON pay.order_id = o.order_id
LEFT JOIN order_items AS oi ON oi.order_id = o.order_id
WHERE c.email = 'demo.success@cartit.test';

DO $$
DECLARE
  v_message text;
BEGIN
  BEGIN
    PERFORM place_order(
      (SELECT customer_id FROM customers WHERE email = 'demo.fail@cartit.test'),
      (SELECT warehouse_id FROM warehouses WHERE code = 'LOS-1'),
      'card',
      true
    );
    v_message := 'unexpected success';
  EXCEPTION
    WHEN OTHERS THEN
      v_message := SQLERRM;
  END;

  CREATE TEMP TABLE IF NOT EXISTS checkout_log (
    step text,
    detail text
  );
  DELETE FROM checkout_log;
  INSERT INTO checkout_log (step, detail) VALUES ('rollback', v_message);
END;
$$;

SELECT step, detail FROM checkout_log;

SELECT
  'after_rollback' AS step,
  v.sku,
  s.qty_on_hand,
  cart.status AS cart_status,
  COUNT(o.order_id) AS orders_kept
FROM customers AS c
JOIN carts AS cart ON cart.customer_id = c.customer_id
JOIN stock_levels AS s ON s.warehouse_id = (SELECT warehouse_id FROM warehouses WHERE code = 'LOS-1')
JOIN product_variants AS v ON v.variant_id = s.variant_id AND v.sku = 'MUG-CER-GRN'
LEFT JOIN orders AS o ON o.customer_id = c.customer_id
WHERE c.email = 'demo.fail@cartit.test'
GROUP BY v.sku, s.qty_on_hand, cart.status;
