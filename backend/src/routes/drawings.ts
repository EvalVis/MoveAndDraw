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

interface Segment {
  points: number[][]
  color: string
}

interface SaveDrawingBody {
  title: string
  segments: Segment[]
}

router.post('/save', async (req: Request, res: Response) => {
  const authHeader = req.headers.authorization
  if (!authHeader?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing token' })
    return
  }

  const token = authHeader.slice(7)
  const owner = await verifyToken(token)
  if (!owner) {
    res.status(401).json({ error: 'Invalid token' })
    return
  }

  const { title, segments } = req.body as SaveDrawingBody

  const allPoints = segments.flatMap(s => s.points)
  const polygonPoints = allPoints.map(([lng, lat]) => `${lng} ${lat}`).join(', ')
  const closedPolygon = `${polygonPoints}, ${allPoints[0][0]} ${allPoints[0][1]}`
  const wkt = `SRID=4326;MULTIPOLYGON(((${closedPolygon})))`

  const result = await getPool().query(
    `INSERT INTO drawings.drawings (owner, title, drawing, segments) VALUES ($1, $2, ST_GeomFromEWKT($3), $4) RETURNING drawing_id`,
    [owner, title, wkt, JSON.stringify(segments)]
  )

  const drawingId = result.rows[0].drawing_id
  await getPool().query(
    `INSERT INTO drawings.likes (drawing_id, like_count) VALUES ($1, 0)`,
    [drawingId]
  )

  res.status(201).json({ success: true })
})

router.get('/view', async (req: Request, res: Response) => {
  const authHeader = req.headers.authorization
  if (!authHeader?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing token' })
    return
  }

  const token = authHeader.slice(7)
  const owner = await verifyToken(token)
  if (!owner) {
    res.status(401).json({ error: 'Invalid token' })
    return
  }

  const result = await getPool().query(
    `SELECT d.id, d.drawing_id, d.title, d.segments, d.created_at, COALESCE(l.like_count, 0) as like_count
     FROM drawings.drawings d
     LEFT JOIN drawings.likes l ON d.drawing_id = l.drawing_id
     WHERE d.owner = $1 
     ORDER BY d.created_at DESC`,
    [owner]
  )

  const drawings = result.rows.map(row => ({
    id: row.id,
    drawingId: row.drawing_id,
    title: row.title,
    segments: row.segments,
    likeCount: row.like_count,
    createdAt: row.created_at
  }))

  res.json(drawings)
})

router.post('/like/:drawingId', async (req: Request, res: Response) => {
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

  const { drawingId } = req.params

  const result = await getPool().query(
    `UPDATE drawings.likes SET like_count = like_count + 1 WHERE drawing_id = $1 RETURNING like_count`,
    [drawingId]
  )

  if (result.rowCount === 0) {
    res.status(404).json({ error: 'Drawing not found' })
    return
  }

  res.json({ likeCount: result.rows[0].like_count })
})

export default router

