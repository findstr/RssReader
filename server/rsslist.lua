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
	local title = nil
	local link = nil
	local item = function(p)
		if p.guid == guid then
			assert(false, p.guid)
		end
		if not p.content then
			local status, head, body = tool.httpget(p.link)
			print("+", status, head, body)
			if body then
				p.content = tool.escapehtml(body)
				core.sleep(100)
			end
		end
		if not p.content then
			p.content = build_content(p.description)
		end
		print(":", p.guid, p.content)
		count = count + 1
		chapter[count] = p
		if count > limit_chapter then
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
local dbk_markread = "rss:%s:markread"
local dbk_update = "rss:update"

local function savechapters(uid, chapters)
	local count = #chapters
	local dbklist = format(dbk_chlist, uid)
	local dbkchap = format(dbk_chapters, uid)
	local left = limit_chapter - count
	local dbreq = {}
	--evict
	local ok, res = db:zrange(dbklist, 0, left)
	if res and #res > 0 then
		table.move(res, 1, #res, 3)
		res[1] = "hdel"
		res[2] = dbkchap
		dbreq[1] = res
	end
	dbreq[#dbreq + 1] = {"zrem", dbklist, 0, left}
	--save
	local now = core.now()
	local i, j = 2, 2
	local dbchlist = {"zadd",  dbklist}
	local dbchapter = {"hmset", dbkchap}
	for x = count, 1, -1 do
		local v = chapters[x]
		i = i + 1
		dbchlist[i] = now
		i = i + 1
		dbchlist[i] = v.guid
		j = j + 1
		dbchapter[j] = v.guid
		j = j + 1
		dbchapter[j] = json.encode(v)
	end
	dbreq[#dbreq + 1] = dbchlist
	dbreq[#dbreq + 1] = dbchapter
	local ok = db:pipeline(dbreq, dbreq)
	for i = 1, 4 do
		print(dbreq[i])
	end
end

local function refresh(uid)
	local now = core.now()
	local ok, val = db:hget(dbk_update, uid)
	if not val then
		val = 0
	else
		val = tonumber(val)
	end
	if now - val < 3600 * 4 then
		return
	end
	local chapters = {}
	local dbksub = format(dbk_subscribe, uid)
	db:hset(dbk_update, now)
	local ok, res = db:hgetall(dbksub)
	for i = 1, #res, 2 do
		local k = res[i]
		local v = json.decode(res[i + 1])
		local status, _, body = tool.httpget(k)
		if status == 200 then
			local n = #chapters
			rssload(body, chapters, v.guid)
			if #chapters > n then
				v.guid = chapters[n + 1].guid
				db:hset(dbksub, k, json.encode(v))
			end
		end
	end
	if #chapters > 0 then
		savechapters(uid, chapters)
	end
end

dispatch["/rsslist/add"] = function(fd, req, body)
	local HEAD = {}
	local param = json.decode(body)
	local uid = param.uid
	local rss = param.rss
	local dbk = format(dbk_subscribe, uid)
	print(uid, rss, dbk)
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
	savechapters(uid, chapters)
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
	local dbk = format(dbk_subscribe, uid)
	local ok, attr = db:hdel(dbk, rssid)
	write(fd, 200, {}, "")
end

dispatch["/page/get"] = function(fd, req, body)
	local out = {}
	local param = json.decode(body)
	local uid = param.uid
	local idx = param.index
	refresh(uid)
	core.log("/page/get uid:", uid, "index:", idx, ":")
	local dbk = format(dbk_chapters, uid)
	local readdbk = format(dbk_markread, uid)
	local ok, res = db:zrevrange(format(dbk_chlist, uid), idx, -1)
	print(":", dbk, ok, res)
	if res and #res > 0 then
		local i = 1
		local mark = {"hmget", readdbk}
		for i = 1, #res do
			mark[#mark + 1] = res[i]
		end
		table.move(res, 1, #res, 3)
		res[1] = "hmget"
		res[2] = dbk
		local dbreq = {res, mark}
		db:pipeline(dbreq, dbreq)
		print(":", dbreq[1], dbreq[2], dbreq[3], dbreq[4])
		local chapres = dbreq[2]
		local markres = dbreq[4]
		for k, v in pairs(chapres) do
			v = json.decode(v)
			core.log("/page/get uid:", uid, " idx:", i, v.title)
			out[i] = format([[{"title":"%s","cid":"%s","read":%s}]],
				v.title, v.guid, markres[k] and "true" or "false")
			i = i + 1
		end
	end
	local head = {}
	local body = format("[%s]", table.concat(out, ","))
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
	local readdbk = format(dbk_markread, uid)
	print(readdbk, db:hset(readdbk, cid, true))
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
	core.log("/page/detail uid:", uid, "cid:", cid, obj.content)
	local body = format('{"content":"%s","author":"%s","date":"%s","link":"%s"}',
		tool.escape(obj.content),obj.author,obj.pubDate, obj.link)
	local head = {}
	if #body > 512 then
		head[1] = "Content-Encoding: gzip"
		body = gzip.deflate(body)
	end
	write(fd, 200, head, body)
end


