local core = require "sys.core"
local dns = require "sys.dns"
local redis = require "sys.db.redis"
local M = {}
local db

function M.start()
	local err
	local name = core.envget("dbip")
	local port = core.envget("dbport")
	print("db start", name, port)
	local addr = dns.resolve(name)
	print("dbport", addr, port)
	db, err= redis:connect {
		addr = string.format("%s:%s", addr, port),
		db = 12,
	}
	assert(db, err)
end

function M.instance()
	return db
end

return M

