local log = require "log"
local dispatch = require "router"
local format = string.format
local client = require "http.client"
local tool = require "tool"
local db = require "db" .instance()

local dbk_account_id = "account:id"
local dbk_account_weid = "account:weid"
local dbk_account_uid = "account:uid"

local function genid()
	local ok, id = db:get(dbk_account_id)
	if ok then
		return id
	end
	db:set(dbk_account_id, 10000)
	ok, id = db:incr(dbk_account_id)
	assert(ok, id)
	return id
end

local fmt_weid_url = 'https://api.weixin.qq.com/sns/jscode2session?appid=wx738bb0a8533b90b3&secret=63cf77f077dfcef07b70d82772e23972&js_code=%s&grant_type=authorization_code'

local function weid(code)
	local ack = {}
	local status, header, body = client.GET(format(fmt_weid_url, code))
	log.print(body)
	tool.jsondecode(body, ack)
	return ack.openid
end

local ack_getuid = '{"uid": %s}'
dispatch["/userinfo/getid"] = function(req, body, write)
	local head = {}
	local code = req.form['code']
	local wid = weid(code)
	local ok, uid = db:hget(dbk_account_weid, wid)
	if not ok then
		uid = genid()
		db:hset(dbk_account_weid, wid, uid)
		db:hset(dbk_account_uid, uid, weid)
	end
	log.print("/userinfo/getid", code, uid)
	write(200, head, format(ack_getuid, uid))
end

