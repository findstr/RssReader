local core = require "core"
local logger = require "core.logger"
local env = require "core.env"
local server = require "core.http"
local db = require "server.db"
local dispatch = require "server.router"
dispatch["/"] = function(stream)
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
	stream:respond(200, head)
	stream:close(body)
end

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
	local tool = require "server.tool"
	tool.httpget("https://coolshell.cn/feed")
	--tool.httpget("https://blog.gotocoding.com/feed")


	local err = env.load("server/rssd.conf")
	assert(not err, err)
	print("RssReader startup", env.get("listen"))
	db.start()
	require "server.userinfo"
	require "server.rsslist"
	server.listen {
		tls = true,
		port = assert(env.get("listen")),
		certs = {
			{
				cert = "/home/findstrx/letsencrypt/cert.pem",
				cert_key = "/home/findstrx/letsencrypt/key.pem",
			},
		},
		handler = function(stream)
			local header = stream.header
			local body = stream:readall()
			logger.info(stream.path)
			logger.info(stream.version)
			local host = header["host"]
			if host == "gotocoding.com" then
				stream:respond(404, {"Content-Type: text/html"})
				stream:close(domain_html)
				return
			end
			local c = dispatch[stream.path]
			if c then
				c(stream, body)
				return
			else
				print("Unsupport uri", stream.uri)
				stream:respond(404, {"Content-Type: text/plain"})
				stream:close("404 Page Not Found")
			end
		end
	}
end)

