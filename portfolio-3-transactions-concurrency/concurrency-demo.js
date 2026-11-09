import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import dotenv from 'dotenv'
import pg from 'pg'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
dotenv.config({ path: path.join(root, '.env') })

if (!process.env.DATABASE_URL) {
  console.error('DATABASE_URL is missing. Copy .env.example to .env and paste the Supabase direct connection string.')
  process.exit(1)
}

const lines = []
function log(message = '') {
  console.log(message)
  lines.push(message)
}

const useSsl = !/localhost|127\.0\.0\.1/.test(process.env.DATABASE_URL)

function newClient() {
  return new pg.Client({
    connectionString: process.env.DATABASE_URL,
    ssl: useSsl ? { rejectUnauthorized: false } : undefined,
  })
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

function makeBarrier(count) {
  let arrived = 0
  const waiting = []
  return function wait() {
    arrived += 1
    if (arrived >= count) {
      arrived = 0
      while (waiting.length) waiting.shift()()
      return Promise.resolve()
    }
    return new Promise((resolve) => waiting.push(resolve))
  }
}

const setup = newClient()
await setup.connect()
await setup.query('SET search_path TO cartit, public')

const variant = await setup.query(
  `SELECT variant_id, list_price, sku FROM product_variants WHERE sku = 'DEMO-LAST-UNIT'`
)
const warehouse = await setup.query(
  `SELECT warehouse_id FROM warehouses WHERE code = 'LOS-1'`
)
const buyers = await setup.query(
  `SELECT c.customer_id, c.email, a.address_id
   FROM customers c
   JOIN addresses a ON a.customer_id = c.customer_id AND a.is_default
   WHERE c.email IN ('race.one@cartit.test', 'race.two@cartit.test')
   ORDER BY c.email`
)

if (variant.rowCount !== 1 || warehouse.rowCount !== 1 || buyers.rowCount !== 2) {
  console.error('Run npm run db:schema and npm run db:seed before this demo.')
  await setup.end()
  process.exit(1)
}

const variantId = variant.rows[0].variant_id
const listPrice = variant.rows[0].list_price
const warehouseId = warehouse.rows[0].warehouse_id
const buyerByEmail = Object.fromEntries(buyers.rows.map((row) => [row.email, row]))

log('# CartIt concurrency demo')
log(`# ${new Date().toISOString()}`)
log('# SKU DEMO-LAST-UNIT at warehouse LOS-1 starts at quantity 1.')
log('')

await reset(setup)
log('## Lost update (no row lock)')
log('Both sessions read 1, then both write 0 and insert a paid order.')
const bothReadUnsafe = makeBarrier(2)
await Promise.all([
  unsafeSale('race.one@cartit.test', bothReadUnsafe),
  unsafeSale('race.two@cartit.test', bothReadUnsafe),
])
await printStock('After the lost update')

await reset(setup)
log('')
log('## Row lock (SELECT FOR UPDATE)')
log('The second session waits, then sees 0 and does not sell.')
await Promise.all([
  lockedSale('race.one@cartit.test'),
  lockedSale('race.two@cartit.test'),
])
await printStock('After the locked checkout')

await reset(setup)
log('')
log('## Repeatable read')
log('Session A reads the row. Session B sells the unit and commits. Session A then tries to update the same row.')
await repeatableReadConflict()
await printStock('After the repeatable-read conflict')

await setup.end()

const evidencePath = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  'evidence',
  'concurrency-output.txt'
)
fs.mkdirSync(path.dirname(evidencePath), { recursive: true })
fs.writeFileSync(evidencePath, lines.join('\n') + '\n')
log('')
log(`Wrote ${path.relative(root, evidencePath)}`)

async function reset(client) {
  await client.query('BEGIN')
  await client.query(
    `DELETE FROM orders
     WHERE customer_id IN (
       SELECT customer_id FROM customers
       WHERE email IN ('race.one@cartit.test', 'race.two@cartit.test')
     )`
  )
  await client.query(
    `UPDATE stock_levels
     SET qty_on_hand = 1
     WHERE warehouse_id = $1 AND variant_id = $2`,
    [warehouseId, variantId]
  )
  await client.query('COMMIT')
}

async function printStock(label) {
  const stock = await setup.query(
    `SELECT qty_on_hand FROM stock_levels WHERE warehouse_id = $1 AND variant_id = $2`,
    [warehouseId, variantId]
  )
  const sales = await setup.query(
    `SELECT c.email, o.order_id, o.status
     FROM orders o
     JOIN customers c ON c.customer_id = o.customer_id
     WHERE c.email IN ('race.one@cartit.test', 'race.two@cartit.test')
     ORDER BY c.email, o.order_id`
  )
  log(`${label}: qty_on_hand=${stock.rows[0].qty_on_hand}, paid orders=${sales.rowCount}`)
  for (const sale of sales.rows) {
    log(`  ${sale.email} order ${sale.order_id} (${sale.status})`)
  }
}

async function unsafeSale(email, bothHaveRead) {
  const buyer = buyerByEmail[email]
  const client = newClient()
  await client.connect()
  try {
    await client.query('SET search_path TO cartit, public')
    await client.query('BEGIN ISOLATION LEVEL READ COMMITTED')
    const current = await client.query(
      `SELECT qty_on_hand FROM stock_levels WHERE warehouse_id = $1 AND variant_id = $2`,
      [warehouseId, variantId]
    )
    const qty = current.rows[0].qty_on_hand
    log(`${email} read qty ${qty}`)
    await bothHaveRead()
    if (qty < 1) {
      await client.query('ROLLBACK')
      log(`${email} rolled back because the first read was empty`)
      return
    }
    await recordSale(client, buyer)
    await client.query(
      `UPDATE stock_levels SET qty_on_hand = $1 WHERE warehouse_id = $2 AND variant_id = $3`,
      [qty - 1, warehouseId, variantId]
    )
    await client.query('COMMIT')
    log(`${email} committed and set stock to ${qty - 1}`)
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {})
    log(`${email} failed: ${error.message}`)
  } finally {
    await client.end()
  }
}

async function lockedSale(email) {
  const buyer = buyerByEmail[email]
  const client = newClient()
  await client.connect()
  try {
    await client.query('SET search_path TO cartit, public')
    await client.query('BEGIN ISOLATION LEVEL READ COMMITTED')
    const current = await client.query(
      `SELECT qty_on_hand
       FROM stock_levels
       WHERE warehouse_id = $1 AND variant_id = $2
       FOR UPDATE`,
      [warehouseId, variantId]
    )
    const qty = current.rows[0].qty_on_hand
    log(`${email} locked the row and read qty ${qty}`)
    await sleep(400)
    if (qty < 1) {
      await client.query('ROLLBACK')
      log(`${email} rolled back. The unit was already sold.`)
      return
    }
    await recordSale(client, buyer)
    await client.query(
      `UPDATE stock_levels
       SET qty_on_hand = qty_on_hand - 1
       WHERE warehouse_id = $1 AND variant_id = $2`,
      [warehouseId, variantId]
    )
    await client.query('COMMIT')
    log(`${email} committed the only sale`)
  } catch (error) {
    await client.query('ROLLBACK').catch(() => {})
    log(`${email} failed: ${error.message}`)
  } finally {
    await client.end()
  }
}

async function recordSale(client, buyer) {
  const order = await client.query(
    `INSERT INTO orders (customer_id, shipping_address_id, warehouse_id, status)
     VALUES ($1, $2, $3, 'paid')
     RETURNING order_id`,
    [buyer.customer_id, buyer.address_id, warehouseId]
  )
  const orderId = order.rows[0].order_id
  await client.query(
    `INSERT INTO order_items (order_id, variant_id, product_name, sku, unit_price, qty)
     VALUES ($1, $2, 'Limited Drop Sneaker', 'DEMO-LAST-UNIT', $3, 1)`,
    [orderId, variantId, listPrice]
  )
  await client.query(
    `INSERT INTO payments (order_id, amount, status, method, paid_at)
     VALUES ($1, $2, 'captured', 'card', now())`,
    [orderId, listPrice]
  )
}

async function repeatableReadConflict() {
  const writer = newClient()
  const reader = newClient()
  await writer.connect()
  await reader.connect()
  try {
    await reader.query('SET search_path TO cartit, public')
    await writer.query('SET search_path TO cartit, public')
    await reader.query('BEGIN ISOLATION LEVEL REPEATABLE READ')
    const seen = await reader.query(
      `SELECT qty_on_hand FROM stock_levels WHERE warehouse_id = $1 AND variant_id = $2`,
      [warehouseId, variantId]
    )
    log(`Session A (repeatable read) saw qty ${seen.rows[0].qty_on_hand}`)

    await writer.query('BEGIN')
    await writer.query(
      `UPDATE stock_levels SET qty_on_hand = 0 WHERE warehouse_id = $1 AND variant_id = $2`,
      [warehouseId, variantId]
    )
    await writer.query('COMMIT')
    log('Session B committed qty 0')

    try {
      await reader.query(
        `UPDATE stock_levels
         SET qty_on_hand = qty_on_hand - 1
         WHERE warehouse_id = $1 AND variant_id = $2`,
        [warehouseId, variantId]
      )
      await reader.query('COMMIT')
      log('Session A committed. This database did not reject the write.')
    } catch (error) {
      log(`Session A was rejected: ${error.message}`)
      await reader.query('ROLLBACK').catch(() => {})
    }
  } finally {
    await writer.end()
    await reader.end()
  }
}
