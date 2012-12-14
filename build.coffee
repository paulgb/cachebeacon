
marked = require 'marked'
fs = require 'fs'
jade = require 'jade'

mdContent = fs.readFileSync('index.md').toString()
jadeMarkup = fs.readFileSync('index.jade').toString()

bodyContent = marked(mdContent)
htmlContent = jade.compile(jadeMarkup)({content: bodyContent})

fs.writeFileSync('index.html', htmlContent)

