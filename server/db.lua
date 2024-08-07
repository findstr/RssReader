local env = require "core.env"
local dns = require "core.dns"
local redis = require "core.db.redis"
local M = {}
local db

function M.start()
	local err
	local name = env.get("dbaddr")
	local port = env.get("dbport")
	print("db start", name, port)
	local addr = dns.lookup(name, dns.A)
	print("dbport", addr, port)
	db, err= redis:connect {
		addr = string.format("%s:%s", addr, port),
		db = 13,
	}
	assert(db, err)
end

function M.instance()
	return db
end

return M

