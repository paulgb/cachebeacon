
url = require 'url'
target_urls = require './target_urls'
dns = require 'native-dns'
httpProxy = require 'http-proxy'

intercept_domains = []

UPSTREAM_DNS = process.env.UPSTREAM_DNS or '8.8.8.8'
PUBLIC_IP = process.env.PUBLIC_IP or '127.0.0.1'
DNS_TTL = 60
DNS_TIMEOUT = 1000
DNS_PORT = 53
HTTP_PORT = 80

for target_url in target_urls
  {hostname, path} = url.parse(target_url)
  if hostname not in intercept_domains
    intercept_domains.push hostname

console.log intercept_domains

server = httpProxy.createServer (req, res, proxy) ->
  full_url = "http://#{req.headers['host']}#{req.url}"
  console.log full_url
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
  if req.question[0].name in intercept_domains
    console.log "Intercepting DNS request for #{req.question[0].name}"
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

