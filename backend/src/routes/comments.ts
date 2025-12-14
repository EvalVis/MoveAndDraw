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

interface TokenPayload {
  userId: string
  name: string
}

async function verifyToken(token: string): Promise<TokenPayload | null> {
  const ticket = await getOAuthClient().verifyIdToken({
    idToken: token,
    audience: process.env.GOOGLE_OAUTH2_SERVER_CLIENT_ID,
  })
  const payload = ticket.getPayload()
  if (!payload?.sub || !payload?.name) return null
  return { userId: payload.sub, name: payload.name }
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
  const user = await verifyToken(token)
  if (!user) {
    res.status(401).json({ error: 'Invalid token' })
    return
  }

  const { drawingId, content } = req.body as SaveCommentBody

  if (!content || typeof content !== 'string' || content.trim().length === 0) {
    res.status(400).json({ error: 'Comment content is required' })
    return
  }

  if (content.length > 1000) {
    res.status(400).json({ error: 'Comment too long' })
    return
  }

  if (!drawingId || typeof drawingId !== 'number') {
    res.status(400).json({ error: 'Invalid drawing ID' })
    return
  }

  const drawingResult = await getPool().query(
    `SELECT comments_enabled FROM drawings.drawings WHERE id = $1`,
    [drawingId]
  )

  if (drawingResult.rowCount === 0) {
    res.status(404).json({ error: 'Drawing not found' })
    return
  }

  if (!drawingResult.rows[0].comments_enabled) {
    res.status(403).json({ error: 'Comments are disabled for this drawing' })
    return
  }

  const artistNameResult = await getPool().query(
    `SELECT artist_name FROM "user".artist_name WHERE user_id = $1`,
    [user.userId]
  )
  const artistName = artistNameResult.rows[0]?.artist_name ?? user.name

  const result = await getPool().query(
    `INSERT INTO drawings.comments (drawing_id, artist_name, content) VALUES ($1, $2, $3) RETURNING id, created_at`,
    [drawingId, artistName, content.trim()]
  )

  res.status(201).json({
    id: result.rows[0].id,
    drawingId,
    artistName,
    content: content.trim(),
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
  const user = await verifyToken(token)
  if (!user) {
    res.status(401).json({ error: 'Invalid token' })
    return
  }

  const drawingId = req.query.drawingId
  const page = Math.max(1, parseInt(req.query.page as string) || 1)
  const limit = 10
  const offset = (page - 1) * limit

  const countResult = await getPool().query(
    `SELECT COUNT(*) as total FROM drawings.comments WHERE drawing_id = $1`,
    [drawingId]
  )
  const total = parseInt(countResult.rows[0].total)
  const totalPages = Math.ceil(total / limit)

  const result = await getPool().query(
    `SELECT id, artist_name, content, created_at FROM drawings.comments WHERE drawing_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
    [drawingId, limit, offset]
  )

  const comments = result.rows.map(row => ({
    id: row.id,
    artistName: row.artist_name,
    content: row.content,
    createdAt: row.created_at
  }))

  res.json({ comments, page, totalPages, total })
})

export default router

