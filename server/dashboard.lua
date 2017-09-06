local log = require "log"
local dispatch = require "router"
local format = string.format
local client = require "http.client"
local tool = require "tool"
local db = require "db" .instance()

dispatch["/dashboard/list"] = function(req, body, write)
	local HEAD = {}
	local ack = [=[
	[{"title": "你好",
	"subtitle": "我是副标题",
	"url":"https://www.baidu.com"
	}]
	]=]
	write(200, HEAD, ack)
end

