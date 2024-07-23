local core = require "core"
local logger = require "core.logger"
local env = require "core.env"
local dispatch = require "server.router"
local format = string.format
local tool = require "server.tool"
local db = require "server.db" .instance()
local dbk_account_id = "account:id"
local dbk_account_weid = "account:weid"
local dbk_account_uid = "account:uid"

local function genid()
	local ok, id = db:incr(dbk_account_id)
	assert(ok, id)
	if id == 1 then
		id = "10000"
		db:set(dbk_account_id, id)
	end
	return id
end

local appid = assert(env.get("appid"), "appid")
local secret = assert(env.get("secret"), "secret")
local fmt_weid_url = 'https://api.weixin.qq.com/sns/jscode2session?appid=%s&secret=%s&js_code=%s&grant_type=authorization_code'

local function weid(code)
	local ack = {}
	local status, header, body = tool.httpget(format(fmt_weid_url,appid, secret, code))
	logger.info(body)
	tool.jsondecode(body, ack)
	return ack.openid
end

local ack_getuid = '{"uid": %s}'
dispatch["/userinfo/getid"] = function(stream, body)
	local head = {}
	local code = stream.form['code']
	local wid = weid(code)
	local ok, uid = db:hget(dbk_account_weid, wid)
	logger.info("/userinfo/getid", code, uid, wid)
	if not ok or not uid then
		uid = genid()
		db:hset(dbk_account_weid, wid, uid)
		db:hset(dbk_account_uid, uid, wid)
	end
	stream:respond(200, head)
	stream:close(format(ack_getuid, uid))
end

---------------module
local M = {}

function M.getall()
	local out = {}
	local ok, res = db:hgetall(dbk_account_uid)
	if not ok then
		logger.info(res)
		return out
	end
	local outi = 1
	for i = 1, #res, 2 do
		out[outi] = res[i]
		outi = outi + 1
	end
	return out
end

core.start(function()
	M.getall()
end)

return M

