local core = require "sys.core"
local dispatch = require "router"
local format = string.format
local tool = require "tool"
local db = require "db" .instance()
local write = require "http.server" . write
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

local appid = assert(core.envget("appid"), "appid")
local secret = assert(core.envget("secret"), "secret")
local fmt_weid_url = 'https://api.weixin.qq.com/sns/jscode2session?appid=%s&secret=%s&js_code=%s&grant_type=authorization_code'

local function weid(code)
	local ack = {}
	local status, header, body = tool.httpget(format(fmt_weid_url,appid, secret, code))
	core.log(body)
	tool.jsondecode(body, ack)
	return ack.openid
end

local ack_getuid = '{"uid": %s}'
dispatch["/userinfo/getid"] = function(req)
	local fd = req.sock
	local body = req.body
	local head = {}
	local code = req.form['code']
	local wid = weid(code)
	local ok, uid = db:hget(dbk_account_weid, wid)
	core.log("/userinfo/getid", code, uid, wid)
	if not ok or not uid then
		uid = genid()
		db:hset(dbk_account_weid, wid, uid)
		db:hset(dbk_account_uid, uid, wid)
	end
	write(fd, 200, head, format(ack_getuid, uid))
end

---------------module
local M = {}

function M.getall()
	local out = {}
	local ok, res = db:hgetall(dbk_account_uid)
	if not ok then
		core.log(res)
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

