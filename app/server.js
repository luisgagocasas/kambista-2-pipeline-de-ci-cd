import express from 'express'
import { fileURLToPath } from 'url'
import path from 'path'
const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const app = express()
const port = process.env.PORT || 3000
app.get('/healthz', (req, res) => {
  res.status(200).send('ok')
})
app.use(express.static(__dirname))
app.listen(port, '0.0.0.0', () => {})
