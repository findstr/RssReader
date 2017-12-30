local core = require "sys.core"
local dns = require "sys.dns"
local server = require "http.server"
local client = require "http.client"
local gzip = require "gzip"
local db = require "db"
local dispatch = require "router"

dispatch["/"] = function(reqeust, body, write)
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
	write(200, head, gzip.deflate(body))
end

local tool = require "tool"

core.start(function()
	dns.server("223.5.5.5:53")
	db.start()
	require "userinfo"
	require "rsslist"
	server.listen(assert(core.envget("listen")), function(request, body, write)
		core.log(request.uri)
		core.log(request.version)
		local c = dispatch[request.uri]
		if c then
			c(request, body, write)
		else
			print("Unsupport uri", request.uri)
			write(404,
				{"Content-Type: text/plain"},
				"404 Page Not Found")
		end
	end)
end)

