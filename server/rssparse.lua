local SLAXML = require "slaxml"
local iconv = require "iconv"
local M = {}

local gsub = string.gsub
local gmatch = string.gmatch
local match = string.match
local format = string.format
local find = string.find

local pool = {}
setmetatable(pool, {__mode="kv"})

local function rss2_0(content, channel, item)
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

	local _, stop = find(content, "?>")
	assert(stop, content)
	local hdr = content:sub(1, stop)
	local encoding = match(hdr, 'encoding="([^"]+)"')
	assert(encoding, hdr)
	encoding = string.lower(encoding)
	if encoding ~= "utf-8" then
		local cd = iconv.open("utf-8", encoding)
		content, err = cd:iconv(content)
		assert(content, err)
	end
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
				if not one.guid then
					one.guid = one.link
				end
				one.pubDate = gsub(one.pubDate, "%+%d+", "")
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

local function atom(content, channel, item)
	local one = nil
	local lastkey = nil
	local key = nil
	local author = nil
	local need = {
		["channel"] = "channel",
		["title"] = "title",
		["id"] = "guid",
		["link"] = "link",
		["updated"] = "pubDate",
		["summary"] = "description",
		["content"] = "content",
		["author"] = "author",
	}

	local _, stop = find(content, "?>")
	assert(stop, content)
	local hdr = content:sub(1, stop)
	local encoding = match(hdr, 'encoding="([^"]+)"')
	assert(encoding, hdr)
	encoding = string.lower(encoding)
	if encoding ~= "utf-8" then
		local cd = iconv.open("utf-8", encoding)
		content, err = cd:iconv(content)
		assert(content, err)
	end

	local parser = SLAXML:parser {
		startElement = function(name, nsURI, nsPrefix)
			if nsPrefix then
				name = nsPrefix .. ":" .. name
			end
			if name == "entry" then
				one = {}
			else
				lastkey = key
				key = need[name]
			end
		end,
		closeElement = function(name, nsURI)
			if name == "entry" then
				if not one.guid then
					one.guid = one.link
				end
				if not one.author then
					one.author = author
				end
				local Y, M, D, H, M, S = match(one.pubDate,
					"(%d+)%-(%d+)%-(%d+)T(%d+):(%d+):(%d+)")
				one.pubDate = format("%s-%s-%s %s:%s:%s",
					Y, M, D, H, M, S)
				item(one)
				one = nil
			end
			key = nil
			if lastkey == need[name] then
				lastkey = nil
			end
		end,
		attribute  = function(name,value,nsURI,nsPrefix)
			if nsPrefix then
				name = nsPrefix .. ":" .. name
			end
			if key == "link" and name == "href" then
				if one then
					one["link"] = value
				else
					channel("link", value)
				end
			end
                end,
		text = function(text)
			if one and key then
				one[key] = text
			elseif lastkey == "author" then
				if one then
					one["author"] = text
				else
					author = text
				end
			elseif key == "title" then
				channel(key, text)
			end
		end,
	}
	parser:parse(content, {stripWhitespace=true})
end

function M.parse(content, channel, item)
	if find(content, "<rss") then
		rss2_0(content, channel, item)
	else
		atom(content, channel, item)
	end
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

