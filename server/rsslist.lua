local core = require "sys.core"
local json = require "sys.json"
local dispatch = require "router"
local format = string.format
local find = string.find
local tool = require "tool"
local RSS = require "rssparse"
local gzip = require "gzip"
local db = require "db" .instance()
local pcall = pcall
local tonumber = tonumber
local write = require "http.server" . write

local limit_rss = assert(core.envget("limit_rss"), "limit_rss")
local limit_chapter = assert(core.envget("limit_chapter"), "limit_chapter")
local limit_update = assert(core.envget("limit_update"), "limit_update")
limit_rss = tonumber(limit_rss)
limit_chapter = tonumber(limit_chapter)

local function build_content(input)
	return  input ..
		[[<p>------------------------------</p>
		<p>网站RSS未全文输出</p>
		<p>请点击作者名，粘贴链接在浏览器查看"]]
end

local function rssload(content, chapter, guid)
	local count = #chapter
	local start = count
	local title = nil
	local link = nil
	local item = function(p)
		if p.link then
			p.link = p.link:match("([^%?]+)")
		end
		if p.guid then
			p.guid = p.guid:match("([^%?]+)")
		end
		if p.guid == guid then
			assert(false, p.guid)
		end
		if not p.content then
			local status, head, body = tool.httpget(p.link)
			if body then
				p.content = tool.escapehtml(body)
				core.sleep(100)
			end
		end
		if not p.content or p.content == "" then
			p.content = build_content(p.description)
		end
		count = count + 1
		chapter[count] = p
		if count >= 10 then
			assert(false, "finish")
		end
	end
	local channel = function(typ, t)
		if typ == "title" then
			title = t
		elseif typ == "link" then
			link = t
		else
			assert(false)
		end
	end
	local ok, err = pcall(RSS.parse, content, channel, item)
	core.log("RSS.parse", ok, err, count)
	return title, link
end
local dbk_subscribe = "rss:%s:subscribe"
local dbk_chapters = "rss:%s:chapters"
local dbk_chlist = "rss:%s:chlist"
local dbk_read = "rss:%s:read"
local dbk_update = "rss:update"

local function savechapters(uid, chapters, siteurl)
	local count = #chapters
	local dbklist = format(dbk_chlist, uid)
	local dbkchap = format(dbk_chapters, uid)
	local left = limit_chapter - count
	local dbreq = {}
	--evict
	local ok, res = db:lrange(dbklist, left, -1)
	if res and #res > 0 then
		local mi = 3
		local mark = {"hdel", format(dbk_read, uid)}
		for _, v in pairs(res) do
			mark[mi] = v
			mi = mi + 1
		end
		table.move(res, 1, #res, 3)
		res[1] = "hdel"
		res[2] = dbkchap
		dbreq[1] = res
		dbreq[2] = mark
		dbreq[3] = {"ltrim", dbklist, 0, left}
	end
	--save
	local now = core.now()
	local i, j = 2, 2
	local dbchlist = {"lpush",  dbklist}
	local dbchapter = {"hmset", dbkchap}
	for x = count, 1, -1 do
		local v = chapters[x]
		i = i + 1
		dbchlist[i] = format("%s=%s", v.link, siteurl)
		j = j + 1
		dbchapter[j] = v.link
		j = j + 1
		dbchapter[j] = json.encode(v)
	end
	dbreq[#dbreq + 1] = dbchlist
	dbreq[#dbreq + 1] = dbchapter
	local ok = db:pipeline(dbreq, dbreq)
	for i = 1, 4 do
		core.log(dbreq[i])
	end
end

local function refresh(uid)
	local now = core.now() // 1000
	local ok, val = db:hget(dbk_update, uid)
	if not val then
		val = 0
	else
		val = tonumber(val)
	end
	print("refresh", now, val, now - val)
	if now - val < 3600 * 4 then
		return
	end
	local dbksub = format(dbk_subscribe, uid)
	db:hset(dbk_update, uid, now)
	local ok, res = db:hgetall(dbksub)
	for i = 1, #res, 2 do
		local k = res[i]
		local v = json.decode(res[i + 1])
		local status, _, body = tool.httpget(k)
		if status == 200 then
			local chapters = {}
			local n = #chapters
			rssload(body, chapters, v.guid)
			if #chapters > n then
				v.guid = chapters[n + 1].guid
				db:hset(dbksub, k, json.encode(v))
			end
			if #chapters > 0 then
				savechapters(uid, chapters, v.link)
			end
		end
	end
end

dispatch["/rsslist/add"] = function(fd, req, body)
	local HEAD = {}
	local param = json.decode(body)
	local uid = param.uid
	local rss = param.rss
	local dbk = format(dbk_subscribe, uid)
	core.log(uid, rss, dbk)
	local ok, attr = db:hget(dbk, rss)
	if attr then
		local ack = [[{"errmsg":"要订阅的内容已存在"}]]
		return write(fd, 400, HEAD, ack)
	end
	local ok, n = db:hlen(dbk)
	if n > limit_rss then
		local ack = [[{"errmsg":"RSS源数量已达上限"}]]
		return write(fd, 400, HEAD, ack)
	end
	local status, head, body = tool.httpget(rss)
	if status ~= 200 then
		local ack = format([[
			{"errmsg":"获取RSS内容失败 错误码:%s"]],
			status)
		return write(fd, 400, HEAD, ack)
	end
	local chapters = {}
	local title, link = rssload(body, chapters)
	local attr = {
		title = title,
		link = link,
		guid = assert(chapters[1].guid)
	}
	savechapters(uid, chapters, link)
	db:hset(dbk, rss, json.encode(attr))
	--ack
	local ack = format('{"title":"%s", "rssid":"%s", "link":"%s"}', title, rss, link)
	core.log(ack)
	write(fd, 200, HEAD, ack)
end


dispatch["/rsslist/get"] = function(fd, req, body)
	local HEAD = {}
	local param = json.decode(body)
	local uid = param.uid
	local arr = {}
	local idx = 1
	local dbk = format(dbk_subscribe, uid)
	core.log("/rsslist/get uid:", uid, dbk)
	local ok, res = db:hgetall(dbk)
	assert(ok)
	for i = 1, #res, 2 do
		local k = res[i]
		local v = res[i + 1]
		local obj = json.decode(v)
		obj.rssid = k
		obj.update = nil
		arr[idx] = obj
		idx = idx + 1
	end
	local ack = json.encode(arr)
	core.log(ack)
	write(fd, 200, HEAD, ack)
end

dispatch["/rsslist/del"] = function(fd, req, body)
	local param = json.decode(body)
	local uid = param.uid
	local rssid = param.rssid
	local dbksub = format(dbk_subscribe, uid)
	local dbklist = format(dbk_chlist, uid)
	local ok, res = db:hget(dbksub, rssid)
	db:hdel(dbksub, rssid)
	local attr = json.decode(res)
	local ok, list = db:lrange(dbklist, 0, -1)
	if list and #list > 0 then
		local m, n  = 2, 2
		local remread = {"hdel", format(dbk_read, uid)}
		local remchap = {"hdel", format(dbk_chapters, uid)}
		local remlist = {"del", dbklist}
		local pushlist = {"rpush", dbklist}
		local siteurl = attr.link
		local find = string.find
		for i = 1, #list do
			local link = list[i]
			print("***", link, siteurl, find(link, siteurl))
			if find(link, siteurl) then
				n = n + 1
				remread[n] = link
				remchap[n] = link
			else
				m = m + 1
				pushlist[m] = link
			end
		end
		local dbreq = {
			remread, remchap, remlist
		}
		if #pushlist > 2 then
			dbreq[4] = pushlist
		end
		db:pipeline(dbreq, dbreq)
		for i = 1, 8 do
			core.log("/rsslist/del", dbreq[i])
		end
	end
	write(fd, 200, {}, "")
end

dispatch["/page/get"] = function(fd, req, body)
	local out = {}
	local param = json.decode(body)
	local uid = param.uid
	local idx = param.index
	refresh(uid)
	core.log("/page/get uid:", uid, "index:", idx, ":")
	local chapdbk = format(dbk_chapters, uid)
	local readdbk = format(dbk_read, uid)
	local ok, res = db:lrange(format(dbk_chlist, uid), idx, -1)
	if res and #res > 0 then
		local i = 1
		for k,v in pairs(res) do
			res[k] = v:match("([^=]+)")
		end
		local mark = {"hmget", readdbk}
		for i = 1, #res do
			mark[i + 2] = res[i]
		end
		table.move(res, 1, #res, 3)
		res[1] = "hmget"
		res[2] = chapdbk
		local dbreq = {res, mark}
		db:pipeline(dbreq, dbreq)
		local chapres = dbreq[2]
		local markres = dbreq[4]
		for k, v in pairs(chapres) do
			v = json.decode(v)
			core.log("/page/get uid:", uid, " idx:", i, v.title)
			out[i] = {
				title = v.title,
				cid = v.link,
				read = markres[k] and true or false,
			}
			i = i + 1
		end
	end
	local head = {}
	local body = json.encode(out)
	if #body > 512 then
		head[1] = "Content-Encoding: gzip"
		body = gzip.deflate(body)
	end
	write(fd, 200, head, body)
end

dispatch["/page/read"] = function(fd, req, body)
	local param = json.decode(body)
	local uid = param.uid
	local cid = param.cid
	local readdbk = format(dbk_read, uid)
	db:hset(readdbk, cid, "true")
	core.log('/page/read uid:', uid, 'cid:', cid)
	write(fd, 200, {}, "")
end

dispatch["/page/detail"] = function(fd, req, body)
	local param = json.decode(body)
	local uid = param.uid
	local cid = param.cid
	local dbk = format(dbk_chapters, uid)
	local ok, res = db:hget(dbk, cid)
	obj = json.decode(res)
	core.log("/page/detail uid:", uid, "cid:", cid)
	local body = format('{"content":"%s","author":"%s","date":"%s","link":"%s"}',
		tool.escape(obj.content),obj.author,obj.pubDate, obj.link)
	local head = {}
	if #body > 512 then
		head[1] = "Content-Encoding: gzip"
		body = gzip.deflate(body)
	end
	write(fd, 200, head, body)
end


