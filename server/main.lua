local core = require "sys.core"
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
		"Content-Encoding: gzip",
		"Content-Type: text/html",
	}
	write(fd, 200, head, gzip.deflate(body))
end

local tool = require "tool"

core.start(function()
	print("RssReader startup")
	db.start()
	require "userinfo"
	require "rsslist"
	server.listen {
		port = assert(core.envget("listen")),
		handler = function(req)
			local sock = req.sock
			core.log(req.uri)
			core.log(req.version)
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

