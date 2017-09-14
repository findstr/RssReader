local gmatch = string.gmatch
local gsub = string.gsub
local format = string.format
local client = require "http.client"
local gzip = require "gzip"
local M = {}

local function encode(str)
	local tbl = {
		['"'] = '\\"',
		["\\"] = "\\\\",
		["/"] = "\\/",
		["\n"] = "\\n",
		["\r"] = "\\r",
		["\t"] = "\\t",
		["\f"] = "\\f",
		["\b"] = "\\b",
	}
	return gsub(str, '["\\\n\r\t\f\b/]', tbl)
end

function M.jsondecode(src, out)
	for k, v in gmatch(src, '"([^",]+)":"-([^"{},]+)"-') do
		out[k] = v
	end
end

function M.jsonencode(input)
	local buff = {}
	local i = 2
	buff[1] = "{"
	for k, v in pairs(input) do
		buff[i] = format('"%s":"%s"', encode(k), encode(v))
		i = i + 1
	end
	buff[i] = "}"
	return table.concat(buff)
end

M.escapejson = encode

function M.httpget(url, header)
	header = header or  {}
	header[#header + 1] = "Accept-Encoding: gzip, deflate"
	local status, head, body, ver = client.GET(url)
	if head and head["Content-Encoding"] == "gzip" then
		body = gzip.inflate(body)
	end
	return status, head, body, ver
end

return M

