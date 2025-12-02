import express, { Request, Response } from 'express'
import dotenv from 'dotenv'
import cors from 'cors'
import drawingsRouter from './src/routes/drawings'

dotenv.config()

const app = express()
const port = process.env.PORT

app.use(cors())
app.use(express.json())
app.use('/drawings', drawingsRouter)

app.get('/ping', (req: Request, res: Response) => {
  res.send('Pong')
})

app.listen(port, () => {
  console.log(`Server started on port ${port}`)
})


