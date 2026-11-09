import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'
import { MongoMemoryServer } from 'mongodb-memory-server'
import { MongoClient } from 'mongodb'

const here = path.dirname(fileURLToPath(import.meta.url))
const products = JSON.parse(fs.readFileSync(path.join(here, 'data', 'products.json'), 'utf8'))
const lines = []

function log(message = '') {
  console.log(message)
  lines.push(message)
}

log('# CartIt product documents')
log(`# ${new Date().toISOString()}`)
log('# Embedded MongoDB. Nothing is written to Supabase.')
log('')

const mongod = await MongoMemoryServer.create({
  instance: { launchTimeout: 60000 },
})
const client = new MongoClient(mongod.getUri())

try {
  await client.connect()
  const catalog = client.db('cartit').collection('products')
  const inserted = await catalog.insertMany(products)
  log(`Inserted ${inserted.insertedCount} product documents`)

  await catalog.createIndex({ category: 1, inStock: 1 })
  await catalog.createIndex({ sku: 1 }, { unique: true })

  const laptops = await catalog
    .find(
      {
        category: 'Electronics',
        inStock: true,
        'attributes.ramGb': { $gte: 16 },
      },
      { projection: { _id: 0, sku: 1, name: 1, price: 1, attributes: 1 } }
    )
    .toArray()

  log('')
  log('In-stock electronics with at least 16 GB RAM:')
  log(JSON.stringify(laptops, null, 2))

  const updated = await catalog.updateOne(
    { sku: 'LAP-PRO-16' },
    { $set: { 'attributes.storageGb': 1024, price: 1010000 } }
  )
  log('')
  log(`Updated LAP-PRO-16. Matched ${updated.matchedCount}, modified ${updated.modifiedCount}.`)

  const laptop = await catalog.findOne(
    { sku: 'LAP-PRO-16' },
    { projection: { _id: 0, sku: 1, price: 1, attributes: 1 } }
  )
  log(JSON.stringify(laptop, null, 2))

  const shoe = await catalog.findOne(
    { sku: 'SHOE-RUN-42' },
    { projection: { _id: 0, sku: 1, attributes: 1 } }
  )
  log('')
  log('The shoe document has no ramGb field. The laptop document has no size field.')
  log(JSON.stringify(shoe, null, 2))
} finally {
  await client.close()
  await mongod.stop()
}

const evidencePath = path.join(here, 'evidence', 'catalog-output.txt')
fs.mkdirSync(path.dirname(evidencePath), { recursive: true })
fs.writeFileSync(evidencePath, lines.join('\n') + '\n')
log('')
log(`Wrote ${path.relative(path.resolve(here, '..'), evidencePath)}`)
