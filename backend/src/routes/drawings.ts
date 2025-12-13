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
  name: string
  userId: string
}

async function verifyToken(token: string): Promise<TokenPayload | null> {
  const ticket = await getOAuthClient().verifyIdToken({
    idToken: token,
    audience: process.env.GOOGLE_OAUTH2_SERVER_CLIENT_ID,
  })
  const payload = ticket.getPayload()
  if (!payload?.name || !payload?.sub) return null
  return { name: payload.name, userId: payload.sub }
}

interface Segment {
  points: number[][]
  color: string
}

interface SaveDrawingBody {
  title: string
  segments: Segment[]
  commentsEnabled: boolean
  isPublic: boolean
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

  const { title, segments, commentsEnabled, isPublic } = req.body as SaveDrawingBody

  const totalPoints = segments.reduce((sum, seg) => sum + seg.points.length, 0)

  const inkResult = await getPool().query(
    `UPDATE "user".ink SET ink = ink - $2
     WHERE user_id = $1 AND ink >= $2
     RETURNING ink`,
    [user.userId, totalPoints]
  )

  if (inkResult.rowCount === 0) {
    res.status(400).json({ error: 'Not enough ink' })
    return
  }

  await getPool().query(
    `INSERT INTO drawings.drawings (artist_name, owner_id, title, segments, comments_enabled, is_public) VALUES ($1, $2, $3, $4, $5, $6)`,
    [user.name, user.userId, title, JSON.stringify(segments), commentsEnabled, isPublic]
  )

  res.status(201).json({ success: true, inkRemaining: inkResult.rows[0].ink })
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

  const sort = req.query.sort as string || 'newest'
  const search = req.query.search as string || ''
  const mine = req.query.mine === 'true'
  const page = Math.max(1, parseInt(req.query.page as string) || 1)
  const limit = 10
  const offset = (page - 1) * limit

  let orderClause: string
  switch (sort) {
    case 'popular':
      orderClause = 'ORDER BY like_count DESC, d.created_at DESC'
      break
    case 'unpopular':
      orderClause = 'ORDER BY like_count ASC, d.created_at DESC'
      break
    case 'oldest':
      orderClause = 'ORDER BY d.created_at ASC'
      break
    default:
      orderClause = 'ORDER BY d.created_at DESC'
  }

  const visibilityClause = mine
    ? 'd.owner_id = $1'
    : '(d.is_public = TRUE OR d.owner_id = $1)'

  const searchClause = search
    ? 'AND (d.artist_name ILIKE $2 OR d.title ILIKE $2)'
    : ''
  const baseParams = search
    ? [user.userId, `%${search}%`]
    : [user.userId]

  const countResult = await getPool().query(
    `SELECT COUNT(DISTINCT d.id) as total
     FROM drawings.drawings d
     WHERE ${visibilityClause} ${searchClause}`,
    baseParams
  )
  const total = parseInt(countResult.rows[0].total)
  const totalPages = Math.ceil(total / limit)

  const limitParam = baseParams.length + 1
  const offsetParam = baseParams.length + 2
  const params = [...baseParams, limit, offset]

  const result = await getPool().query(
    `SELECT d.id, d.artist_name, d.owner_id, d.title, d.segments, d.comments_enabled, d.is_public, d.created_at,
            COUNT(l.user_id) as like_count,
            EXISTS(SELECT 1 FROM drawings.likes WHERE drawing_id = d.id AND user_id = $1) as is_liked
     FROM drawings.drawings d
     LEFT JOIN drawings.likes l ON d.id = l.drawing_id
     WHERE ${visibilityClause} ${searchClause}
     GROUP BY d.id
     ${orderClause}
     LIMIT $${limitParam} OFFSET $${offsetParam}`,
    params
  )

  const drawings = result.rows.map(row => ({
    id: row.id,
    artistName: row.artist_name,
    isOwner: row.owner_id === user.userId,
    title: row.title,
    segments: row.segments,
    commentsEnabled: row.comments_enabled,
    isPublic: row.is_public,
    likeCount: parseInt(row.like_count),
    isLiked: row.is_liked,
    createdAt: row.created_at
  }))

  res.json({ drawings, page, totalPages, total })
})

router.post('/like/:id', async (req: Request, res: Response) => {
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

  const { id } = req.params

  const existing = await getPool().query(
    `SELECT 1 FROM drawings.likes WHERE drawing_id = $1 AND user_id = $2`,
    [id, user.userId]
  )

  if (existing.rowCount && existing.rowCount > 0) {
    await getPool().query(
      `DELETE FROM drawings.likes WHERE drawing_id = $1 AND user_id = $2`,
      [id, user.userId]
    )
  } else {
    await getPool().query(
      `INSERT INTO drawings.likes (drawing_id, user_id) VALUES ($1, $2)`,
      [id, user.userId]
    )
  }

  const countResult = await getPool().query(
    `SELECT COUNT(*) as like_count FROM drawings.likes WHERE drawing_id = $1`,
    [id]
  )

  const isLiked = !(existing.rowCount && existing.rowCount > 0)

  res.json({ likeCount: parseInt(countResult.rows[0].like_count), isLiked })
})

export default router
