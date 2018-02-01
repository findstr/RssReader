local core = require "sys.core"
local dispatch = require "router"
local format = string.format
local find = string.find
local tool = require "tool"
local RSS = require "rssparse"
local gzip = require "gzip"
local db = require "db" .instance()
local userinfo = require "userinfo"
local pcall = pcall

local limit_rss = assert(core.envget("limit_rss"), "limit_rss")
local limit_chapter = assert(core.envget("limit_chapter"), "limit_chapter")
local limit_update = assert(core.envget("limit_update"), "limit_update")
limit_rss = tonumber(limit_rss)
limit_chapter = tonumber(limit_chapter)

local dbk_rss_index = "rss:%s:index"
local dbk_rss_siteid = "rss:%s:siteid"
local dbk_rss_idsite = "rss:%s:idsite"
local dbk_rss_chlist = "rss:%s:chlist"	--zset
--"*hset title/link"
local dbk_rss_site = "rss:%s:site:%s"
-- "*hset title/link/pubdate/content/read
local dbk_rss_chapter = "rss:%s:chapter:%s"

local function build_content(input)
	return  input ..
		[[<p>------------------------------</p>
		<p>网站RSS未全文输出</p>
		<p>请点击作者名，粘贴链接在浏览器查看"]]
end

local function rss_read(content)
	local count = 0
	local title = nil
	local link = nil
	local chapter = {}
	local item = function(p)
		count = count + 1
		chapter[count] = p
		if not p.content then
			local status, head, body = tool.httpget(p.link)
			if body then
				p.content = tool.escapehtml(body)
				core.sleep(1000)
			end
		end
		if not p.content then
			p.content = build_content(p.description)
		end
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
	if not ok then
		assert(count > 0, "RSS源解析失败")
	end
	return chapter, count, link, title
end

local function chapter_save(uid, rssid, chapterid, chapter)
	local cmd = {}
	local out = {}
	local chlist_cmd = {
		"zadd",
		format(dbk_rss_chlist, uid),
	}
	local i = 1
	local chlist_i = 3
	-- "*hset title/link/pubdate/content/read"
	for _, v in pairs(chapter) do
		local one = {}
		local id = type(rssid) == "number" and rssid or rssid[i]
		cmd[i] = one
		i = i + 1
		one[1] = "hmset"
		one[2] = format(dbk_rss_chapter, uid, chapterid)
		chlist_cmd[chlist_i] = id
		chlist_i = chlist_i + 1
		chlist_cmd[chlist_i] = chapterid
		chlist_i = chlist_i + 1
		local j = 3
		for dbk, dbv in pairs(v) do
			one[j] = dbk
			j = j + 1
			one[j] = dbv
			j = j + 1
		end
		core.log("chapter_save", chapterid, v.title, v.link)
		chapterid = chapterid - 1
	end
	if #chlist_cmd > 2 then
		cmd[i] = chlist_cmd
	end
	if #cmd > 0 then
		db:pipeline(cmd, out)
		for i = 1, #out, 2 do
			assert(out[i], out[i + 1])
		end
	end
end

local function rss_add(uid, dbk_siteid, rss,  content)
	local chapter, count, link, title = rss_read(content)
	local dbk_idsite = format(dbk_rss_idsite, uid)
	--alloc id
	local dbk_index = format(dbk_rss_index, uid)
	local ok, rssid = db:incr(dbk_index)
	assert(ok, rssid)
	rssid = tonumber(rssid)
	local ok = db:set(dbk_index, rssid + count)
	assert(ok)
	--save rss
	local ok, err = db:hset(dbk_siteid, rss, rssid)
	assert(ok, err)
	local ok, err = db:hset(dbk_idsite, rssid, rss)
	assert(ok, err)
	local ok, err = db:hmset(format(dbk_rss_site, uid, rssid),
				"title", title,
				"link", link)
	assert(ok, err)
	core.log("/rsslist/add", rss, rssid)
	chapter_save(uid, rssid, rssid + count, chapter)
	return title, rssid, link
end

dispatch["/rsslist/add"] = function(req, body, write)
	local HEAD = {}
	local param = {}
	tool.jsondecode(body, param)
	local uid = param.uid
	local rss = param.rss
	local dbk_siteid = format(dbk_rss_siteid, uid)
	--check exist
	core.log("/rsslist/add uid:", param.uid, dbk_siteid, rss)
	local ok, rssid = db:hget(dbk_siteid, rss)
	if ok then
		local ack = [[{"errmsg":"要订阅的内容已存在"}]]
		return write(400, HEAD, ack)
	end
	--check if max
	local ok, num = db:hlen(dbk_siteid)
	if not ok or tonumber(num) > limit_rss then
		local ack = [[{"errmsg":"RSS源数量已达上限"}]]
		return write(400, HEAD, ack)
	end
	--fetch rss xml
	print("rss", rss)
	local status, head, body = tool.httpget(rss)
	if status ~= 200 then
		local ack = format([[{"errmsg":"获取RSS内容失败 错误码:%s"]], status)
		return write(400, HEAD, ack)
	end
	--parse rss xml
	local ok, title, rssid, link = pcall(rss_add, uid, dbk_siteid, rss, body)
	if not ok then
		local ack = format([[{"errmsg":"保存RSS文章失败 错误码:%s"}]], title)
		return write(400, HEAD, ack)
	end
	--ack
	local ack = format('{"title":"%s", "rssid":"%s", "link":"%s"}', title, rssid, link)
	core.log(ack)
	write(200, HEAD, ack)
end


dispatch["/rsslist/get"] = function(req, body, write)
	local HEAD = {}
	local param = {}
	tool.jsondecode(body, param)
	local uid = param.uid
	local arr = {}
	local idx = 1
	local dbk = format(dbk_rss_idsite, uid)
	core.log("/rsslist/get uid:", uid, dbk)
	local ok, res = db:hgetall(dbk)
	assert(ok)
	for i = 1, #res, 2 do
		local rssid = res[i]
		local dbk = format(dbk_rss_site, uid, rssid)
		core.log("dbk", dbk)
		local ok, rss = db:hmget(dbk, "title", "link")
		assert(ok, rsstitle)
		arr[idx] = format('{"title":"%s","link":"%s","rssid":"%s"}',
				rss[1], rss[2], rssid)
		idx = idx + 1
	end
	local ack = format('[%s]', table.concat(arr, ","))
	core.log(ack)
	write(200, HEAD, ack)
end

dispatch["/rsslist/del"] = function(req, body, write)
	local param = {}
	tool.jsondecode(body, param)
	local uid = param.uid
	local rssid = param.rssid
	core.log("/rsslist/del uid:", uid, "rssid:", rssid)
	local dbk_siteid = format(dbk_rss_siteid, uid)
	local dbk_idsite = format(dbk_rss_idsite, uid)
	local ok, rssurl = db:hget(dbk_idsite, rssid)
	assert(ok, rssurl)
	--getall chapter
	local ok, chaplist = db:zrangebyscore(
		format(dbk_rss_chlist, uid), rssid, rssid)
	assert(ok, chaplist)
	if type(chaplist) ~= "table" then
		chaplist = {chaplist}
	end
	--clear rss_url
	local cmd = {}
	local out = {}
	local del_chapter = {"del"}
	local del_chlist = {"zremrangebyscore",
		format(dbk_rss_chlist, uid), rssid, rssid}
	cmd[1] = {"hdel", dbk_siteid, rssurl}
	cmd[2] = {"hdel", dbk_idsite, rssid}
	cmd[3] = {"del", format(dbk_rss_site, uid, rssid)}
	cmd[4] = del_chapter
	cmd[5] = del_chlist
	local i = 2
	for _, v in pairs(chaplist) do
		del_chapter[i] = format(dbk_rss_chapter, uid, v)
		i = i + 1
	end
	db:pipeline(cmd, out)
	for i = 1, #out, 2 do
		assert(out[i], out[i + 1])
	end
	write(200, {}, "")
end

dispatch["/page/get"] = function(req, body, write)
	local param = {}
	tool.jsondecode(body, param)
	local uid = param.uid
	local idx = param.index
	local out = {}
	core.log("/page/get uid:", uid, "index:", idx)
	local dbk_chlist = format(dbk_rss_chlist, uid)
	local ok, res = db:zrange(dbk_chlist, 0, -1)
	assert(ok, res)
	if type(res) ~= "table" then
		res = {res}
	end
	table.sort(res, function(a, b)
		local x = tonumber(a)
		local y = tonumber(b)
		return x > y
	end)
	local i = 1
	for _, v in pairs(res) do
		local dbk = format(dbk_rss_chapter, uid, v)
		local ok, tbl = db:hmget(dbk, "title", "read")
		assert(tbl)
		local title = tbl[1]
		local read = tbl[2] and true or false
		if title then
			title = tool.escapejson(title)
			out[i] = format([[{"title":"%s","cid":"%s","read":%s}]],
					title, v, read)
			i = i + 1
		else
			core.log("/page/get skip", dbk, v)
		end
	end
	local head = {}
	local body = format("[%s]", table.concat(out, ","))
	if #body > 512 then
		head[1] = "Content-Encoding: gzip"
		body = gzip.deflate(body)
	end
	write(200, head, body)
end

dispatch["/page/read"] = function(req, body, write)
	local param = {}
	tool.jsondecode(body, param)
	local uid = param.uid
	local cid = param.cid
	core.log('/page/read uid:', uid, 'cid:', cid)
	local dbk = format(dbk_rss_chapter, uid, cid)
	db:hset(dbk, "read", "true")
	write(200, {}, "")
end

dispatch["/page/detail"] = function(req, body, write)
	local param = {}
	tool.jsondecode(body, param)
	local uid = param.uid
	local cid = param.cid
	local needcontent = param.content == "true"
	print("body", body)
	core.log("/page/detail uid:", uid, "cid:", cid, "needcontent:", needcontent)
	local dbk = format(dbk_rss_chapter, uid, cid)
	local content_key
	if not needcontent then
		content_key = "description"
	else
		content_key = "content"
	end
	local ok, res = db:hmget(dbk, content_key, "author", "pubDate", "link")
	for k, v in pairs(res) do
		if not v then
			res[k] = "nil"
		end
	end
	if not needcontent then
		res[1] = build_content(res[1])
	end
	print("res[1]", content_key)
	local body = format('{"content":"%s","author":"%s","date":"%s","link":"%s"}',
		tool.escapejson(res[1]),
		tool.escapejson(res[2]),
		tool.escapejson(res[3]),
		tool.escapejson(res[4]))
	local head = {}
	if #body > 512 then
		head[1] = "Content-Encoding: gzip"
		body = gzip.deflate(body)
	end
	write(200, head, body)
end


local dbk_rss_siteid = "rss:%s:siteid"
local dbk_rss_chlist = "rss:%s:chlist"	--zset
-- "*hset title/link/pubdate/content/read
local dbk_rss_chapter = "rss:%s:chapter:%s"


local function update_one(uid)
	local cmd_i = 1
	local cmd_ch_chid = {}
	local cmd_ch_guid = {}
	--collect chapter
	local rss_ch = {}	--[rssid] = {}array
	local chid_tag = {}	--[chid] = tag
	local dbk_chlist = format(dbk_rss_chlist, uid)
	local ok, chaplist = db:zrange(dbk_chlist, 0, -1, "WITHSCORES")
	assert(ok, chaplist)
	for i = 1, #chaplist, 2 do
		local chid = chaplist[i]
		local rssid = chaplist[i + 1]
		local rss = rss_ch[rssid]
		if not rss then
			rss = {}
			rss_ch[rssid] = {}
		end
		cmd_ch_guid[cmd_i] = {
			"hget",
			format(dbk_rss_chapter, uid, chid),
			"guid",
		}
		cmd_ch_chid[cmd_i] = chid
		cmd_i = cmd_i + 1
		chid_tag[chid] = "old"
		rss[#rss + 1] = chid
	end
	--collect chapter guid
	local ch_clear = {}
	local guid_list = {}
	local guid_chid = {}
	db:pipeline(cmd_ch_guid, guid_list)
	local j = 1
	for i = 1, #cmd_ch_chid do
		local chid = cmd_ch_chid[i]
		local ok = guid_list[j]
		j = j + 1
		local guid = guid_list[j]
		j = j + 1
		if ok then
			guid_chid[guid] = chid
		else
			ch_clear[chid] = true
		end
	end
	--collect rss
	local chapter_new = {}
	local chapter_rss = {}
	local chapter_new_count = 0
	local dbk = format(dbk_rss_siteid, uid)
	local ok, rss_ = db:hgetall(dbk)
	assert(ok, rss_)
	for i = 1, #rss_, 2 do
		local url = rss_[i]
		local rssid = rss_[i + 1]
		core.log("update uid:", dbk, " url", url, rssid)
		local status, head, body = tool.httpget(url)
		if status ~= 200 then
			core.log("page_update", status, head, body)
		else
			local chapter = rss_read(body)
			for i = 1, #chapter do
				local item = chapter[i]
				local chid = guid_chid[item.guid]
				if not chid_tag[chid] then	--create new
					chapter_new_count = chapter_new_count + 1
					chapter_new[chapter_new_count] = item
					chapter_rss[chapter_new_count] = rssid
				else
					local chid = assert(guid_chid[item.guid], item.guid)
					chid_tag[chid] = "new"
				end
			end
		end
	end
	--create new chapter
	local dbk_index = format(dbk_rss_index, uid)
	local ok, id = db:get(dbk_index)
	assert(ok, id)
	id = tonumber(id)
	local endid = chapter_new_count + id
	db:set(dbk_index, endid)
	chapter_save(uid, chapter_rss, endid, chapter_new)
	for i = 1, chapter_new_count do
		chid_tag[endid] = "new"
		local rssid = chapter_rss[i]
		local tbl = rss_ch[rssid]
		if tbl then
			tbl[#tbl + 1] = tostring(endid)
			endid = endid - 1
		end
	end
	--update db
	local rem_i = 0
	local rem_chid = {}
	local zrem_i = 2
	local cmd_zrem = {
		"zrem",
		format(dbk_rss_chlist, uid),
	}
	local cmd_del = {}
	for rssid, rss in pairs(rss_ch) do
		table.sort(rss, function(a, b)
			return a > b
		end)
		for i = limit_chapter, #rss do
			local chid = rss[i]
			rss[i] = nil
			rem_i = rem_i + 1
			rem_chid[rem_i] = chid
			zrem_i = zrem_i + 1
			cmd_zrem[zrem_i] = chid
			core.log("rem", chid)
			cmd_del[#cmd_del + 1] = {"del", format(dbk_rss_chapter, uid, i)}
		end
	end
	for chid, _ in pairs(ch_clear) do
		rem_i = rem_i + 1
		rem_chid[rem_i] = chid
		zrem_i = zrem_i + 1
		cmd_zrem[zrem_i] = chid
		core.log("rem", chid)
	end
	if #cmd_zrem > 2 then
		cmd_del[#cmd_del + 1] = cmd_zrem
	end
	if #cmd_del > 0 then
		local ok, n = db:pipeline(cmd_del, out)
		for i = 1, #out, 2 do
			assert(out[i], out[i + 1])
		end
	end
end

local function page_update()
	core.log("update start")
	local ok, user = core.pcall(userinfo.getall)
	if not ok then
		core.log(user)
	end
	local safe = core.pcall
	for i = 1, #user do
		local uid = user[i]
		core.log("update user:", uid)
		local ok, err = safe(update_one, uid)
		if not ok then
			core.log(err)
		end
	end
	core.log("update finish")
	core.timeout(limit_update, page_update)
end

core.start(page_update)

