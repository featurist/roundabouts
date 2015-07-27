express = require 'express'
fs = require 'fs'

app = express ()

app.use (express.static 'public')

app.get '/modules/*' @(req, res)
  fs.readFile "#(__dirname)/public/index.html" 'utf8' @(err, html)
    res.send(html)

app.listen (process.env.PORT || 3001)
