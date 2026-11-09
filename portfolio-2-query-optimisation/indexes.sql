-- Performance indexes for CartIt reports.
-- schema.sql already indexes primary keys and UNIQUE columns (including customers.email and product_variants.sku).
-- These extra indexes are created again inside explain.sql so the before/after plans are comparable.
-- Plain CREATE INDEX is used on purpose. CREATE INDEX CONCURRENTLY cannot run inside a transaction,
-- and the Supabase SQL editor often wraps a script in one.

SET search_path TO cartit, public;

CREATE INDEX IF NOT EXISTS idx_orders_placed_at ON orders (placed_at);
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders (customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_shipping_address_id ON orders (shipping_address_id);
CREATE INDEX IF NOT EXISTS idx_orders_status_placed_at ON orders (status, placed_at);
CREATE INDEX IF NOT EXISTS idx_addresses_city ON addresses (city);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items (order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_variant_id ON order_items (variant_id);
CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments (order_id);
CREATE INDEX IF NOT EXISTS idx_stock_variant ON stock_levels (variant_id);

ANALYZE customers, addresses, products, product_variants, orders, order_items, payments, stock_levels;
