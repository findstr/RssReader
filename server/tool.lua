local gmatch = string.gmatch
local gsub = string.gsub
local format = string.format
local time = require "core.time"
local client = require "core.http"
local gzip = require "gzip"
local M = {}

local function encode(str)
	local tbl = {
		['"'] = '\\"',
		["\\"] = "\\\\",
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

M.escape = encode

M.escapehtml = function(input)
	local tbl = {
		"<script[^<]+</script>",
		"<ins [^<]+</ins>",
	}
	input = gsub(input, tbl[1], "")
	return gsub(input, tbl[2], "")
end
function M.httpget(url, header)
	local ack = client.GET(url, {
		["accept-encoding"] = "gzip, deflate"
	})
	local header = ack.header
	if header and header["content-encoding"] == "gzip" then
		ack.body = gzip.inflate(ack.body)
	end
	return ack.status, ack.head, ack.body, ack.ver
end

return M

