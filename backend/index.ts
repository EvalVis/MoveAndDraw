import express, { Request, Response } from 'express'

const app = express()
const port = 3000

app.get('/ping', (req: Request, res: Response) => {
  res.send('Pong')
})

app.listen(port, () => {
  console.log(`Server started on port ${port}`)
})


