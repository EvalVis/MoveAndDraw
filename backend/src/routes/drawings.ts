import { Router, Request, Response } from 'express'
import { Pool } from 'pg'

const router = Router()
let pool: Pool

function getPool() {
  if (!pool) {
    pool = new Pool({ connectionString: process.env.DATABASE_URL })
  }
  return pool
}

interface SaveDrawingBody {
  owner: string
  title: string
  drawing: number[][]
}

router.post('/save', async (req: Request, res: Response) => {
  const { owner, title, drawing } = req.body as SaveDrawingBody

  const polygonPoints = drawing.map(([lng, lat]) => `${lng} ${lat}`).join(', ')
  const closedPolygon = `${polygonPoints}, ${drawing[0][0]} ${drawing[0][1]}`
  const wkt = `SRID=4326;MULTIPOLYGON(((${closedPolygon})))`

  await getPool().query(
    `INSERT INTO drawings.drawings (owner, title, drawing) VALUES ($1, $2, ST_GeomFromEWKT($3))`,
    [owner, title, wkt]
  )

  res.status(201).json({ success: true })
})

export default router

