local core = require "sys.core"
local redis = require "sys.db.redis"
local M = {}
local db

function M.start()
	local err
	db, err= redis:connect {
		addr = assert(core.envget("dbport")),
		db = 12,
	}
	assert(db, err)
end

function M.instance()
	return db
end

return M

