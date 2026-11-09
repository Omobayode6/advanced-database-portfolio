import fs from 'fs'
import path from 'path'
import { fileURLToPath, pathToFileURL } from 'url'
import dotenv from 'dotenv'
import pg from 'pg'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
dotenv.config({ path: path.join(root, '.env') })

async function main() {
  const args = process.argv.slice(2)
  const outFlag = args.indexOf('--out')
  const outPath = outFlag >= 0 ? args[outFlag + 1] : null
  const fileArg = args.find((arg, index) => {
    if (arg.startsWith('--')) return false
    if (outFlag >= 0 && index === outFlag + 1) return false
    return true
  })

  if (!fileArg) {
    console.error('Usage: node scripts/apply-sql.js <file.sql> [--out evidence.txt]')
    process.exit(1)
  }

  if (!process.env.DATABASE_URL) {
    console.error('DATABASE_URL is missing. Copy .env.example to .env and paste the Supabase direct connection string.')
    process.exit(1)
  }

  const sqlPath = path.resolve(root, fileArg)
  const sql = fs.readFileSync(sqlPath, 'utf8')
  const statements = splitSql(sql).filter((statement) => !isSkippable(statement))

  const chunks = []
  function emit(line = '') {
    console.log(line)
    chunks.push(line)
  }

  const useSsl = !/localhost|127\.0\.0\.1/.test(process.env.DATABASE_URL)
  const client = new pg.Client({
    connectionString: process.env.DATABASE_URL,
    ssl: useSsl ? { rejectUnauthorized: false } : undefined,
  })

  client.on('notice', (notice) => {
    emit(`NOTICE: ${notice.message}`)
  })

  await client.connect()

  try {
    emit(`# ${path.relative(root, sqlPath)}`)
    emit(`# ${new Date().toISOString()}`)
    emit('')

    for (const statement of statements) {
      emit('---')
      emit(statement.trim())
      emit('')
      const result = await client.query(statement)
      emit(formatResult(result))
      emit('')
    }
  } catch (error) {
    emit(`ERROR: ${error.message}`)
    await client.query('ROLLBACK').catch(() => {})
    process.exitCode = 1
  } finally {
    await client.end()
    if (outPath) {
      const target = path.resolve(root, outPath)
      fs.mkdirSync(path.dirname(target), { recursive: true })
      fs.writeFileSync(target, chunks.join('\n') + '\n')
      console.error(`Wrote ${path.relative(root, target)}`)
    }
  }
}

const isDirectRun = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href
if (isDirectRun) {
  await main()
}

function formatResult(result) {
  if (Array.isArray(result)) {
    return result.map((entry) => formatResult(entry)).join('\n')
  }
  if (result.rows?.length && Object.prototype.hasOwnProperty.call(result.rows[0], 'QUERY PLAN')) {
    return result.rows.map((row) => row['QUERY PLAN']).join('\n')
  }
  if (result.rows?.length) {
    const preview = result.rows.slice(0, 50)
    const suffix = result.rows.length > 50 ? `\n... ${result.rows.length - 50} more rows` : ''
    return `${result.command} ${result.rowCount}\n${JSON.stringify(preview, null, 2)}${suffix}`
  }
  return `${result.command ?? 'OK'} ${result.rowCount ?? ''}`.trim()
}

export function isSkippable(statement) {
  const withoutBlocks = statement.replace(/\/\*[\s\S]*?\*\//g, '')
  return withoutBlocks
    .split('\n')
    .every((line) => !line.trim() || line.trim().startsWith('--'))
}

export function splitSql(source) {
  const statements = []
  let current = ''
  let i = 0

  while (i < source.length) {
    if (source[i] === '-' && source[i + 1] === '-') {
      const end = source.indexOf('\n', i)
      const slice = end === -1 ? source.slice(i) : source.slice(i, end + 1)
      current += slice
      i += slice.length
      continue
    }

    if (source[i] === '/' && source[i + 1] === '*') {
      const end = source.indexOf('*/', i + 2)
      const slice = end === -1 ? source.slice(i) : source.slice(i, end + 2)
      current += slice
      i += slice.length
      continue
    }

    if (source[i] === "'") {
      current += source[i]
      i += 1
      while (i < source.length) {
        current += source[i]
        if (source[i] === "'" && source[i + 1] === "'") {
          current += source[i + 1]
          i += 2
          continue
        }
        if (source[i] === "'") {
          i += 1
          break
        }
        i += 1
      }
      continue
    }

    const tag = matchDollar(source, i)
    if (tag) {
      const end = source.indexOf(tag, i + tag.length)
      const slice = end === -1 ? source.slice(i) : source.slice(i, end + tag.length)
      current += slice
      i += slice.length
      continue
    }

    if (source[i] === ';') {
      const trimmed = current.trim()
      if (trimmed) statements.push(trimmed)
      current = ''
      i += 1
      continue
    }

    current += source[i]
    i += 1
  }

  const tail = current.trim()
  if (tail) statements.push(tail)
  return statements
}

function matchDollar(source, index) {
  if (source[index] !== '$') return null
  const match = source.slice(index).match(/^\$[A-Za-z0-9_]*\$/)
  return match ? match[0] : null
}
