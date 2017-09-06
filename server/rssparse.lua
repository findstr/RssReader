local SLAXML = require "slaxml"
local M = {}

function M.parse(content, channel, item)
	local one = nil
	local key = nil
	local need = {
		["channel"] = "channel",
		["title"] = "title",
		["guid"] = "guid",
		["link"] = "link",
		["pubDate"] = "pubDate",
		["description"] = "description",
		["content:encoded"] = "content",
		["dc:creator"] = "author",
	}

	local parser = SLAXML:parser {
		startElement = function(name, nsURI, nsPrefix)
			if nsPrefix then
				name = nsPrefix .. ":" .. name
			end
			if name == "item" then
				one = {}
			else
				key = need[name]
			end
		end,
		closeElement = function(name, nsURI)
			if name == "item" then
				item(one)
				one = nil
			end
			key = nil
		end,
		text = function(text)
			if one and key then
				one[key] = text
			elseif key == "title" or key == "link" then
				channel(key, text)
			end
		end,
	}
	parser:parse(content, {stripWhitespace=true})
end
--[[
local f = io.open("feed.xml", "r")
local content = f:read("all")
M.parse(content, function(item)
	print("标题:", item.title)
	print("描述:", item.description)
	print("内容:", item.pubDate)
	return false
end)
]]--
return M

