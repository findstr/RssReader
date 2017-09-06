local log = require "log"
local core = require "silly.core"
local env = require "silly.env"
local server = require "http.server"
local client = require "http.client"
local db = require "db"
local dispatch = require "router"

log.print = print

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
		"Content-Type: text/html",
		}

	write(200, head, body)
end


core.start(function()
	db.start()
	require "userinfo"
	require "dashboard"
	server.listen(assert(env.get("listen")), function(request, body, write)
		log.print(request.uri)
		log.print(request.version)
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

