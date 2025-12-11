import { Router, Request, Response } from 'express'
import { Pool } from 'pg'
import { OAuth2Client } from 'google-auth-library'

const router = Router()
let pool: Pool
let oauthClient: OAuth2Client

const INK_PER_HOUR = 100
const INK_CAP = 5000
const INITIAL_INK = 1000

function getPool() {
  if (!pool) {
    pool = new Pool({ connectionString: process.env.DATABASE_URL })
  }
  return pool
}

function getOAuthClient() {
  if (!oauthClient) {
    oauthClient = new OAuth2Client(process.env.GOOGLE_OAUTH2_SERVER_CLIENT_ID)
  }
  return oauthClient
}

async function verifyToken(token: string): Promise<string | null> {
  const ticket = await getOAuthClient().verifyIdToken({
    idToken: token,
    audience: process.env.GOOGLE_OAUTH2_SERVER_CLIENT_ID,
  })
  const payload = ticket.getPayload()
  return payload?.sub ?? null
}

router.post('/login', async (req: Request, res: Response) => {
  const authHeader = req.headers.authorization
  if (!authHeader?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing token' })
    return
  }

  const token = authHeader.slice(7)
  const userId = await verifyToken(token)
  if (!userId) {
    res.status(401).json({ error: 'Invalid token' })
    return
  }

  await getPool().query(
    `INSERT INTO drawings.user_ink (user_id, ink, last_updated)
     VALUES ($1, $2, NOW())
     ON CONFLICT (user_id) DO NOTHING`,
    [userId, INITIAL_INK]
  )

  res.json({ success: true })
})

router.get('/ink', async (req: Request, res: Response) => {
  const authHeader = req.headers.authorization
  if (!authHeader?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing token' })
    return
  }

  const token = authHeader.slice(7)
  const userId = await verifyToken(token)
  if (!userId) {
    res.status(401).json({ error: 'Invalid token' })
    return
  }

  const result = await getPool().query(
    `UPDATE drawings.user_ink SET
       ink = LEAST(ink + FLOOR(EXTRACT(EPOCH FROM (NOW() - last_updated)) / 3600) * $2, $3),
       last_updated = CASE
         WHEN FLOOR(EXTRACT(EPOCH FROM (NOW() - last_updated)) / 3600) > 0 THEN NOW()
         ELSE last_updated
       END
     WHERE user_id = $1
     RETURNING ink`,
    [userId, INK_PER_HOUR, INK_CAP]
  )

  if (result.rowCount === 0) {
    res.status(404).json({ error: 'User not found' })
    return
  }

  res.json({ ink: result.rows[0].ink })
})

export default router
