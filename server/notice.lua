local core = require "sys.core"
local client = require "http.client"
local tool = require "tool"
local dispatch = require "router"

local format = string.format

local M = {}
local token = nil
local token_expire = 0
local appid = assert(core.envget("appid"), "appid")
local tempid = assert(core.envget("template"), "template")
local secret = assert(core.envget("secret"), "secret")
local fmt_token_url = 'https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=%s&secret=%s'

local function fetchtoken()
	local now = core.now()
	if now < token_expire then
		return token
	end
	local ack = {}
	local status, header, body = tool.httpget(format(fmt_token_url,appid, secret))
	core.log(body)
	tool.jsondecode(body, ack)
	token = ack.access_token
	token_expire = tonumber(ack.expires_in) + now
	return token
end
local fmt_send_url = 'https://api.weixin.qq.com/cgi-bin/message/wxopen/template/send?access_token=%s'

local fmt_temp = [[{"touser":"%s","template_id": "%s","page": "index",]]..
		[["form_id": "%s",]] ..
  		[["data": {"keyword1": {"value": "hello","color": "#173177"},]]..
      		[["keyword2": {"value": "world","color": "#173177"}},]] ..
		[["emphasis_keyword": "keyword1.DATA"}]]

function M.notice()
	local token = fetchtoken()
	local url = format(fmt_send_url, token)
	local req = format(fmt_temp,
		"hello",
		tempid,
		"world")
	local status, header, body = client.POST(url, nil, req)
	print(status, header, body)
end

dispatch["/notice/subscribe"] = function(req, body, write)
	print("req", body)
end

return M

