import express, { Request, Response, NextFunction } from 'express'
import dotenv from 'dotenv'
import cors from 'cors'
import drawingsRouter from './src/routes/drawings'
import commentsRouter from './src/routes/comments'
import userRouter from './src/routes/user'

dotenv.config()

const app = express()
const port = process.env.PORT

app.use(cors())
app.use(express.json({ limit: '100kb' }))
app.use('/drawings', drawingsRouter)
app.use('/drawings/comments', commentsRouter)
app.use('/user', userRouter)

app.get('/ping', (req: Request, res: Response) => {
  res.send('Pong')
})

app.use((err: Error, req: Request, res: Response, next: NextFunction) => {
  console.error('Unhandled error:', err.message)
  res.status(500).json({ error: 'Internal server error' })
})

app.listen(port, () => {
  console.log(`Server started on port ${port}`)
})


