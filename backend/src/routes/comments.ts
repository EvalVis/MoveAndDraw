import { Router, Request, Response } from 'express'
import { Pool } from 'pg'
import { OAuth2Client } from 'google-auth-library'

const router = Router()
let pool: Pool
let oauthClient: OAuth2Client

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
  return payload?.name ?? null
}

interface SaveCommentBody {
  drawingId: number
  content: string
}

router.post('/save', async (req: Request, res: Response) => {
  const authHeader = req.headers.authorization
  if (!authHeader?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing token' })
    return
  }

  const token = authHeader.slice(7)
  const username = await verifyToken(token)
  if (!username) {
    res.status(401).json({ error: 'Invalid token' })
    return
  }

  const { drawingId, content } = req.body as SaveCommentBody

  const result = await getPool().query(
    `INSERT INTO drawings.comments (drawing_id, username, content) VALUES ($1, $2, $3) RETURNING id, created_at`,
    [drawingId, username, content]
  )

  res.status(201).json({
    id: result.rows[0].id,
    drawingId,
    username,
    content,
    createdAt: result.rows[0].created_at
  })
})

router.get('/view', async (req: Request, res: Response) => {
  const authHeader = req.headers.authorization
  if (!authHeader?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing token' })
    return
  }

  const token = authHeader.slice(7)
  const username = await verifyToken(token)
  if (!username) {
    res.status(401).json({ error: 'Invalid token' })
    return
  }

  const drawingId = req.query.drawingId

  const result = await getPool().query(
    `SELECT id, username, content, created_at FROM drawings.comments WHERE drawing_id = $1 ORDER BY created_at DESC`,
    [drawingId]
  )

  const comments = result.rows.map(row => ({
    id: row.id,
    username: row.username,
    content: row.content,
    createdAt: row.created_at
  }))

  res.json(comments)
})

export default router

