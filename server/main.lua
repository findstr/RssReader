local core = require "sys.core"
local json = require "sys.json"
local logger = require "sys.logger"
local env = require "sys.env"
local dns = require "sys.dns"
local server = require "http.server"
local client = require "http.client"
local gzip = require "gzip"
local db = require "db"
local dispatch = require "router"
local write = server.write
dispatch["/"] = function(request)
	local fd = request.sock
	local body = [[
		<html>
			<head>Hello Stupid</head>
			<body>
				<form action="upload" method="POST">
				<input type="text" name="Hello"/>
				<input type="submit" name="submit"/>
				</form>
			</body>
		</html>
	]]
	local head = {
	--	"Content-Encoding: gzip",
		"Content-Type: text/html",
	}
	write(fd, 200, head, body)
end

local tool = require "tool"

local domain_html = [[
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta nameviewport" content="width=device-width, initial-scale=1.0">
  <title>重归混沌</title>
  <style>
    body {
      font-family: "Arial", sans-serif;
      background-color: #f5f5f5;
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    header {
      background-color: #24292e;
      color: #ffffff;
      padding: 10px 20px;
      text-align: center;
    }
    footer {
      position: absolute;
      bottom: 0;
      width: 100%;
      background-color: #24292e;
      color: #ffffff;
      text-align: center;
      padding: 10px 0;
    }
  </style>
</head>
<body>
  <header>
    <h1>重归混沌</h1>
  </header>
  <div style="text-align: center; margin-top: 50px;">
    <p>师法天地，道法自然</p>
  </div>
  <footer><a href="https://beian.miit.gov.cn" style="color: #ffffff; text-decoration: none;" target="_blank">沪ICP备2024045号</a></footer>
</body>
</html>
]]


core.start(function()
	print("RssReader startup")
	db.start()
	require "userinfo"
	require "rsslist"
	server.listen {
		tls_port = assert(env.get("listen")),
		tls_certs = {
			{
				cert = "/home/findstrx/letsencrypt/weixin.pem",
				cert_key = "/home/findstrx/letsencrypt/weixin.key",
			},

			{
				cert = "/home/findstrx/letsencrypt/cert.pem",
				cert_key = "/home/findstrx/letsencrypt/key.pem",
			},
		},
		handler = function(req)
			local sock = req.sock
			logger.info(req.uri)
			logger.info(req.version)
			print("uri", req.uri)
			local host = req.header["host"]
			if host == "gotocoding.com" then
				write(req.sock, 404, {"Content-Type: text/html"}, domain_html)
				return
			end
			local c = dispatch[req.uri]
			if c then
				c(req)
				return
			else
				print("Unsupport uri", req.uri)
				write(req.sock, 404,
					{"Content-Type: text/plain"},
					"404 Page Not Found")
			end
		end
	}
end)

