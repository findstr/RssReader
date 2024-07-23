local core = require "core"
local env = require "core.env"
local waitgroup = require "core.sync.waitgroup"
local logger = require "core.logger"
local time = require "core.time"
local json = require "core.json"
local dispatch = require "server.router"
local format = string.format
local type = type
local tool = require "server.tool"
local RSS = require "server.rssparse"
local db = require "server.db" .instance()
local pcall = pcall
local tonumber = tonumber

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

local dbk_site_score = "site:score"			--zadd score site
local dbk_user_read = "user:%s:read"			--sadd url
local dbk_user_subscribe = "user:%s:subscribe" 		--sadd url
local site_chapters = {}

local function write(stream, status, header, body)
	stream:respond(status, header)
	stream:close(body)
end

local function clear_site(site)
	local chapters = site.chapters
	for _, url in pairs(chapters) do
		site_chapters[url] = nil
	end
end

local function rssload(rss, content)
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
		p.rssid = rss
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
	local min = math.min(#chapters_all, limit_chapter)
	for i = 1, min do
		local v = chapters_all[i]
		local url = v.link
		site_chapters[url] = v
		chapter_urls[#chapter_urls + 1] = url
	end
	local site = setmetatable({
		rssid = rss,
		title = title,
		link = link,
		update_time = time.now(),
		chapters = chapter_urls,
	}, {__gc = function(t)
		clear_site(t)
	end})
	logger.info("RSS.parse", ok, err, #chapter_urls)
	return site
end

local site_list = setmetatable({}, {
	__index = function(t, rss)
		local now = time.now()
		local status, _, body = tool.httpget(rss)
		if status ~= 200 then
			logger.error("http get", rss, status)
			return "RSS源无法访问"
		end
		local site = rssload(rss, body)
		t[rss] = site
		return site
	end
})

local function get_site(rss)
	local site = site_list[rss]
	if type(site) ~= "table" then
		return nil, site
	end
	local update_time = site.update_time or 0
	if time.now() > update_time + limit_update then
		core.fork(function()
			site_list[rss] = nil
			site = site_list[rss]
		end)
	end
	return site, nil
end


local function ref_rss_site(rss)
	local site, err = get_site(rss)
	if not site then
		return nil, err
	end
	db:zincrby(dbk_site_score, 1, rss)
	return site, nil
end

dispatch["/rsslist/add"] = function(stream, body)
	local HEAD = {}
	local param = json.decode(body)
	local uid = param.uid
	local rss = param.rss
	local dbk = format(dbk_user_subscribe, uid)
	logger.info(uid, rss, dbk)
	local ok, n = db:sismember(dbk, rss)
	if not ok or n > 0 then
		local ack = [[{"errmsg":"要订阅的内容已存在"}]]
		write(stream, 400, HEAD, ack)
		return
	end
	ok, n = db:scard(dbk)
	if not ok or n > limit_rss then
		local ack = [[{"errmsg":"RSS源数量已达上限"}]]
		return write(stream, 400, HEAD, ack)
	end
	local site, err = ref_rss_site(rss)
	if not site then
		local ack = format([[{"errmsg":%s"}]], err)
		return write(stream, 400, HEAD, ack)
	end
	db:sadd(dbk, rss)
	--ack
	local ack = format('{"title":"%s", "rssid":"%s", "link":"%s"}', site.title, rss, site.link)
	logger.info(ack)
	write(stream, 200, HEAD, ack)
end

local function get_site_list(urls)
	local err
	local site_list = {}
	local wg = waitgroup:create()
	for _, rss in pairs(urls) do
		wg:fork(function()
			local site, err = get_site(rss)
			if not site then
				logger.error("ref_rss_site", rss, err)
				err = format('{"errmsg":%s"}', err)
			else
				site_list[#site_list + 1] = site
			end
		end)
	end
	wg:wait()
	if err then
		return nil, err
	end
	return site_list, nil
end

dispatch["/rsslist/get"] = function(stream, body)
	local HEAD = {}
	local param = json.decode(body)
	local uid = param.uid
	local dbk = format(dbk_user_subscribe, uid)
	logger.info("/rsslist/get uid:", uid, dbk)
	local ok, res = db:smembers(dbk)
	assert(ok)
	local site_list, err = get_site_list(res)
	if not site_list then
		return write(stream, 400, HEAD, err)
	end
	local ack = json.encode(site_list)
	logger.info(ack)
	write(stream, 200, HEAD, ack)
end

dispatch["/rsslist/del"] = function(stream, body)
	local param = json.decode(body)
	local uid = param.uid
	local rssid = param.rssid
	local dbksub = format(dbk_user_subscribe, uid)
	local ok, n = db:srem(dbksub, rssid)
	if not ok or n == 0 then
		local ack = [[{"errmsg":"要删除的内容不存在"}]]
		return write(stream, 400, {}, ack)
	end
	db:zincrby(dbk_site_score, -1, rssid)
	local dbk_read = format(dbk_user_read, uid)
	local chapter_rem = {}
	local ok, read = db:smembers(dbk_read)
	if ok and read and #read > 0 then
		for _, v in pairs(read) do
			local chapter = site_chapters[v]
			if not chapter or chapter.rssid == rssid then
				chapter_rem[#chapter_rem + 1] = v
			end
		end
	end
	if #chapter_rem > 0 then
		db:srem(dbk_read, table.unpack(chapter_rem))
	end
	write(stream, 200, {}, "")
end

dispatch["/page/get"] = function(stream, body)
	local out = {}
	local param = json.decode(body)
	local uid = param.uid
	local idx = param.index
	logger.info("/page/get uid:", uid, "index:", idx, ":")
	local dbk_subscribe = format(dbk_user_subscribe, uid)
	local dbk_read = format(dbk_user_read, uid)
	local ok, read_list = db:smembers(dbk_read)
	if not ok then
		logger.error("db smembers", dbk_read, read_list)
		return write(stream, 400, {}, "")
	end
	local ok, site_urls = db:smembers(dbk_subscribe)
	if not ok then
		logger.error("db smembers", dbk_subscribe, site_urls)
		return write(stream, 400, {}, "")
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
	local site_list, err = get_site_list(site_urls)
	if not site_list then
		return write(stream, 400, {}, err)
	end
	for _, site in pairs(site_list) do
		local urls = site.chapters
		print("site", site.rssid, "url", #urls)
		for _, url in pairs(urls) do
			local chapter = site_chapters[url]
			if chapter then
				all_chapters[#all_chapters + 1] = chapter
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
	write(stream, 200, head, body)
end

dispatch["/page/read"] = function(stream, body)
	local param = json.decode(body)
	local uid = param.uid
	local cid = param.cid
	local readdbk = format(dbk_user_read, uid)
	db:sadd(readdbk, cid)
	logger.info('/page/read uid:', uid, 'cid:', cid)
	write(stream, 200, {}, "")
end

dispatch["/page/detail"] = function(stream, body)
	local param = json.decode(body)
	local uid = param.uid
	local cid = param.cid
	local obj = site_chapters[cid]
	if not obj then
		local ack = [[{"errmsg":"文章已过期"}]]
		logger.error("chapter not found", cid)
		return write(stream, 404, {}, ack)
	end
	logger.info("/page/detail uid:", uid, "cid:", cid)
	local body = format('{"content":"%s","author":"%s","date":"%s","link":"%s"}',
		tool.escape(obj.content),obj.author,obj.pubDate, obj.link)
	local head = {}
	write(stream, 200, head, body)
end


