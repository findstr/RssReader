local core = require "sys.core"
local env = require "sys.env"
local logger = require "sys.logger"
local time = require "sys.time"
local json = require "sys.json"
local dispatch = require "router"
local format = string.format
local find = string.find
local tool = require "tool"
local RSS = require "rssparse"
local db = require "db" .instance()
local pcall = pcall
local tonumber = tonumber
local write = require "http.server" . write

local limit_rss = assert(env.get("limit_rss"), "limit_rss")
local limit_chapter = assert(env.get("limit_chapter"), "limit_chapter")
local limit_update = assert(env.get("limit_update"), "limit_update")
limit_rss = tonumber(limit_rss)
limit_chapter = tonumber(limit_chapter)
limit_update = tonumber(limit_update)

local function build_content(input)
	return  input ..
		[[<p>------------------------------</p>
		<p>网站RSS未全文输出</p>
		<p>请点击作者名，粘贴链接在浏览器查看"]]
end

local function rssload(site, content)
	local title = nil
	local link = nil
	local chapters_all = {}
	local chapter_urls = {}
	local item = function(p)
		if p.link then
			p.link = p.link:match("([^%?]+)")
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
		chapters_all[#chapters_all + 1] = p
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
	table.sort(chapters_all, function(a, b)
		return a.pubDate > b.pubDate
	end)
	local min = math.min(#chapters_all, limit_chapter)
	local chapters = {}
	for i = 1, min do
		local v = chapters_all[i]
		chapters[#chapters+1] = v.link
		chapters[#chapters+1] = json.encode(v)
		chapter_urls[#chapter_urls + 1] = v.link
	end
	if not site then
		site = {
			title = title,
			link = link,
			update_time = time.now(),
			chapters = chapter_urls,
		}
	else
		site.title = title
		site.link = link
		site.update_time = time.now()
		site.chapters = chapter_urls
	end
	logger.info("RSS.parse", ok, err, #chapters)
	return site, chapters
end

local dbk_site_list = "site:list"	        	--hset site desc
local dbk_site_score = "site:score"			--zadd score site
local dbk_site_chapters = "site:chapters"		--hset url content
local dbk_user_read = "user:%s:read"			--sadd url
local dbk_user_subscribe = "user:%s:subscribe" 		--sadd url

local function update_rss_site(rss)
	local status, _, body = tool.httpget(rss)
	if status ~= 200 then
		logger.error("http get", dbk_site_list, rss, status)
		return nil, "RSS源无法访问"
	end
	local ok, site = db:hget(dbk_site_list, rss)
	if not ok then
		logger.error("db hget", dbk_site_list, rss, site)
		return nil, "RSS源无法访问"
	end
	if site then
		site = json.decode(site)
		local chapters = site.chapters
		if chapters and #chapters > 0 then
			db:hmdel(dbk_site_chapters, table.unpack(chapters))
		end
	end
	local site, chapters = rssload(site, body)
	if not site then
		logger.error("rssload", rss, chapters)
		return nil, "RSS源无法访问"
	end
	db:hmset(dbk_site_chapters, table.unpack(chapters))
	db:hset(dbk_site_list, rss, json.encode(site))
	return site, nil
end

local function ref_rss_site(rss)
	local site, err = update_rss_site(rss)
	if not site then
		return nil, err
	end
	db:zincrby(dbk_site_score, 1, rss)
	return site, nil
end

local function load_rss_chapters(rss) 
	local ok, site_str = db:hget(dbk_site_list, rss)
	if not ok then
		logger.error("db hget", dbk_site_list, rss, site_str)
		return nil, "数据库无法访问"
	end
	local site = json.decode(site_str)
	if not site then
		logger.error("json decode", dbk_site_list, rss, site_str)
		return nil, "数据库无法访问"
	end
	local update_time = site.update_time or 0
	local now = time.now()
	if now - update_time > limit_update then
		local err
		site, err = update_rss_site(rss)
		if not site then
			return nil, err
		end
	end
	local chapters = site.chapters
	if not chapters or #chapters == 0 then
		return {}, nil
	end
	local ok, res = db:hmget(dbk_site_chapters, table.unpack(chapters))
	if not ok then
		logger.error("db hmget", dbk_site_chapters, table.unpack(chapters))
		return nil, "数据库无法访问"
	end
	return res, nil
end

dispatch["/rsslist/add"] = function(req)
	local HEAD = {}
	local fd = req.sock
	local body = req.body
	local param = json.decode(body)
	local uid = param.uid
	local rss = param.rss
	local dbk = format(dbk_user_subscribe, uid)
	logger.info(uid, rss, dbk)
	local ok, n = db:sismember(dbk, rss)
	if not ok or n > 0 then
		local ack = [[{"errmsg":"要订阅的内容已存在"}]]
		return write(fd, 400, HEAD, ack)
	end
	ok, n = db:scard(dbk)
	if not ok or n > limit_rss then
		local ack = [[{"errmsg":"RSS源数量已达上限"}]]
		return write(fd, 400, HEAD, ack)
	end
	local site, err = ref_rss_site(rss)
	if not site then
		local ack = format([[{"errmsg":%s"}]], err)
		return write(fd, 400, HEAD, ack)
	end
	db:sadd(dbk, rss)
	--ack
	local ack = format('{"title":"%s", "rssid":"%s", "link":"%s"}', site.title, rss, site.link)
	logger.info(ack)
	write(fd, 200, HEAD, ack)
end


dispatch["/rsslist/get"] = function(req)
	local fd = req.sock
	local body = req.body
	local HEAD = {}
	local param = json.decode(body)
	local uid = param.uid
	local arr = {}
	local idx = 1
	local dbk = format(dbk_user_subscribe, uid)
	logger.info("/rsslist/get uid:", uid, dbk)
	local ok, res = db:smembers(dbk)
	assert(ok)
	local site_list
	if res and #res > 0 then
		ok, site_list = db:hmget(dbk_site_list, table.unpack(res))
	end
	if not ok then
		logger.error("db hmget", dbk_site_list, table.unpack(res))
		local ack = format([[{"errmsg":%s"}]], err)
		return write(fd, 400, HEAD, ack)
	end
	if site_list and #site_list > 0 then
		for i = 1, #site_list do
			local site = json.decode(site_list[i])
			site.rssid = res[i]
			arr[idx] = site
			idx = idx + 1
		end
	end
	local ack = json.encode(arr)
	logger.info(ack)
	write(fd, 200, HEAD, ack)
end

dispatch["/rsslist/del"] = function(req)
	local fd = req.sock
	local body = req.body
	local param = json.decode(body)
	local uid = param.uid
	local rssid = param.rssid
	local dbksub = format(dbk_user_subscribe, uid)
	local ok, n = db:srem(dbksub, rssid)
	if not ok or n == 0 then
		local ack = [[{"errmsg":"要删除的内容不存在"}]]
		return write(fd, 400, {}, ack)
	end
	db:zincrby(dbk_site_score, -1, rssid)
	local chapters, err = load_rss_chapters(rssid)
	if not chapters then
		local ack = format([[{"errmsg":%s"}]], err)
		return write(fd, 400, {}, ack)
	end
	local chapter_set = {}
	for _, v in pairs(chapters) do
		v = json.decode(v)
		chapter_set[v.link] = true
	end
	local dbk_read = format(dbk_user_read, uid)
	local chapter_rem = {}
	local ok, read = db:smembers(dbk_read)
	if ok and read and #read > 0 then
		for _, v in pairs(read) do
			if chapter_set[v] then
				chapter_rem[#chapter_rem + 1] = v
			end
		end
	end
	if #chapter_rem > 0 then
		db:srem(dbk_read, table.unpack(chapter_rem))
	end
	write(fd, 200, {}, "")
end

dispatch["/page/get"] = function(req)
	local out = {}
	local fd = req.sock
	local body = req.body
	local param = json.decode(body)
	local uid = param.uid
	local idx = param.index
	logger.info("/page/get uid:", uid, "index:", idx, ":")
	local dbk_subscribe = format(dbk_user_subscribe, uid)
	local dbk_read = format(dbk_user_read, uid)
	local ok, read_list = db:smembers(dbk_read)
	if not ok then
		logger.error("db smembers", dbk_read, read_list)
		return write(fd, 400, {}, "")
	end
	local ok, site_urls = db:smembers(dbk_subscribe)
	if not ok then
		logger.error("db smembers", dbk_subscribe, site_urls)
		return write(fd, 400, {}, "")
	end
	local read_set = {}
	if read_list and #read_list > 0 then
		for _, v in pairs(read_list) do
			read_set[v] = true
		end
	end
	local all_chapters = {}
	table.sort(site_urls, function(a, b)
		return a > b
	end)
	for _, site_url in pairs(site_urls) do
		local chapters, err = load_rss_chapters(site_url)
		if not chapters then
			logger.error("load_rss_chapters", site_url, chapters)
			return write(fd, 400, {}, "")
		end
		if chapters then
			local list = {}
			for i, v in pairs(chapters) do
				local v = json.decode(v)
				list[#list+1] = v
			end
			table.sort(list, function(a, b)
				return a.pubDate > b.pubDate
			end)
			for _, v in pairs(list) do
				all_chapters[#all_chapters + 1] = v
			end
		end
	end
	for k, v in pairs(all_chapters) do
		logger.info("/page/get uid:", uid, " idx:", k, v.title)
		out[#out + 1] = {
			title = v.title,
			cid = v.link,
			read = read_set[v.link] or false,
		}
	end
	local head = {}
	local body = json.encode(out)
	write(fd, 200, head, body)
end

dispatch["/page/read"] = function(req)
	local fd = req.sock
	local body = req.body
	local param = json.decode(body)
	local uid = param.uid
	local cid = param.cid
	local readdbk = format(dbk_user_read, uid)
	db:sadd(readdbk, cid)
	logger.info('/page/read uid:', uid, 'cid:', cid)
	write(fd, 200, {}, "")
end

dispatch["/page/detail"] = function(req)
	local fd = req.sock
	local body = req.body
	local param = json.decode(body)
	local uid = param.uid
	local cid = param.cid
	local ok, res = db:hget(dbk_site_chapters, cid)
	local obj = json.decode(res)
	logger.info("/page/detail uid:", uid, "cid:", cid)
	local body = format('{"content":"%s","author":"%s","date":"%s","link":"%s"}',
		tool.escape(obj.content),obj.author,obj.pubDate, obj.link)
	local head = {}
	write(fd, 200, head, body)
end


