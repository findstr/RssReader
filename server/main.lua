local core = require "sys.core"
local dns = require "sys.dns"
local server = require "http.server"
local client = require "http.client"
local gzip = require "gzip"
local db = require "db"
local dispatch = require "router"
local write = server.write
dispatch["/"] = function(fd, reqeust, body)
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
	dns.server("223.5.5.5:53")
	db.start()
	require "userinfo"
	require "rsslist"
	server.listen(assert(core.envget("listen")), function(fd, request, body)
		core.log(request.uri)
		core.log(request.version)
		local c = dispatch[request.uri]
		if c then
			c(fd, request, body)
			return
		else
			print("Unsupport uri", request.uri)
			write(fd, 404,
				{"Content-Type: text/plain"},
				"404 Page Not Found")
		end
	end)
end)

