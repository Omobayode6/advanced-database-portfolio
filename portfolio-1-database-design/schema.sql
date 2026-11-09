-- CartIt operational schema for MIT 8103.
-- Re-running this file drops and recreates the cartit schema only.
-- It does not drop the rest of a Supabase project.
-- Performance indexes live in portfolio-2-query-optimisation/indexes.sql.
-- The unique indexes in this file are constraints, not tuning experiments.

DROP SCHEMA IF EXISTS cartit CASCADE;
CREATE SCHEMA cartit;
SET search_path TO cartit, public;

COMMENT ON SCHEMA cartit IS
  'Simulated CartIt e-commerce database. Shoppers, catalog, stock, carts, orders, payments, and delivery.';

CREATE TABLE customers (
  customer_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  full_name text NOT NULL,
  email text NOT NULL UNIQUE,
  phone text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE addresses (
  address_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id bigint NOT NULL REFERENCES customers (customer_id) ON DELETE CASCADE,
  line1 text NOT NULL,
  city text NOT NULL,
  state text NOT NULL,
  country text NOT NULL DEFAULT 'Nigeria',
  is_default boolean NOT NULL DEFAULT false
);

-- A shopper can keep several addresses, and exactly one of them is the default.
CREATE UNIQUE INDEX uq_one_default_address
  ON addresses (customer_id)
  WHERE is_default;

CREATE TABLE categories (
  category_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name text NOT NULL UNIQUE,
  parent_category_id bigint REFERENCES categories (category_id)
);

CREATE TABLE products (
  product_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  category_id bigint NOT NULL REFERENCES categories (category_id),
  name text NOT NULL,
  description text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (category_id, name)
);

CREATE TABLE product_variants (
  variant_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  product_id bigint NOT NULL REFERENCES products (product_id) ON DELETE CASCADE,
  sku text NOT NULL UNIQUE,
  variant_name text NOT NULL,
  list_price numeric(12, 2) NOT NULL CHECK (list_price >= 0),
  active boolean NOT NULL DEFAULT true
);

CREATE TABLE warehouses (
  warehouse_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  city text NOT NULL,
  region text NOT NULL CHECK (
    region IN (
      'South-West',
      'North-Central',
      'South-South',
      'North-West',
      'South-East',
      'North-East'
    )
  )
);

CREATE TABLE stock_levels (
  warehouse_id bigint NOT NULL REFERENCES warehouses (warehouse_id),
  variant_id bigint NOT NULL REFERENCES product_variants (variant_id),
  qty_on_hand integer NOT NULL CHECK (qty_on_hand >= 0),
  PRIMARY KEY (warehouse_id, variant_id)
);

CREATE TABLE carts (
  cart_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id bigint NOT NULL REFERENCES customers (customer_id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'checked_out', 'abandoned')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX uq_one_open_cart
  ON carts (customer_id)
  WHERE status = 'open';

CREATE TABLE cart_items (
  cart_id bigint NOT NULL REFERENCES carts (cart_id) ON DELETE CASCADE,
  variant_id bigint NOT NULL REFERENCES product_variants (variant_id),
  qty integer NOT NULL CHECK (qty > 0),
  PRIMARY KEY (cart_id, variant_id)
);

CREATE TABLE orders (
  order_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id bigint NOT NULL REFERENCES customers (customer_id) ON DELETE CASCADE,
  shipping_address_id bigint NOT NULL REFERENCES addresses (address_id),
  warehouse_id bigint NOT NULL REFERENCES warehouses (warehouse_id),
  status text NOT NULL CHECK (
    status IN ('pending_payment', 'paid', 'packed', 'shipped', 'delivered', 'cancelled')
  ),
  placed_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE order_items (
  order_item_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id bigint NOT NULL REFERENCES orders (order_id) ON DELETE CASCADE,
  variant_id bigint NOT NULL REFERENCES product_variants (variant_id),
  -- Snapshots. Catalog edits after the sale must not rewrite this order.
  product_name text NOT NULL,
  sku text NOT NULL,
  unit_price numeric(12, 2) NOT NULL CHECK (unit_price >= 0),
  qty integer NOT NULL CHECK (qty > 0)
);

CREATE TABLE payments (
  payment_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id bigint NOT NULL REFERENCES orders (order_id) ON DELETE CASCADE,
  amount numeric(12, 2) NOT NULL CHECK (amount > 0),
  status text NOT NULL CHECK (status IN ('pending', 'captured', 'failed')),
  method text NOT NULL CHECK (method IN ('card', 'transfer', 'wallet')),
  paid_at timestamptz
);

CREATE TABLE shipments (
  shipment_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_id bigint NOT NULL UNIQUE REFERENCES orders (order_id) ON DELETE CASCADE,
  carrier text NOT NULL,
  tracking_number text NOT NULL UNIQUE,
  status text NOT NULL CHECK (
    status IN ('label_created', 'in_transit', 'out_for_delivery', 'delivered', 'exception')
  ),
  shipped_at timestamptz,
  delivered_at timestamptz,
  CHECK (status <> 'delivered' OR delivered_at IS NOT NULL)
);
