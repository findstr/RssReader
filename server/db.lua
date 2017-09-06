local env = require "silly.env"
local core = require "silly.core"
local redis = require "redis"
local M = {}
local db

function M.start()
	local err
	db, err= redis:connect {
		addr = assert(env.get("dbport"))
	}
	assert(db, err)
end

function M.instance()
	return db
end

return M

