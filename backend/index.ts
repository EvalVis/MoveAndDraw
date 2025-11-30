import express, { Request, Response } from 'express'
import dotenv from 'dotenv'

dotenv.config()

const app = express()
const port = process.env.PORT

app.get('/ping', (req: Request, res: Response) => {
  res.send('Pong')
})

app.listen(port, () => {
  console.log(`Server started on port ${port}`)
})


