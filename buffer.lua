local posix = require "posix"
local lib = require "neo-ed.lib"

local mt = {
	__index = {},
}

function mt.__index:addr(s, loc)
	local function cont(a, s)
		local a_, s_ = lib.match(s, self.state.cmds.addr.cont, function() end, nil, a)
		if a_ then return cont(a_, s_) end
		if s == "" then return a end
		error("could not parse: " .. s)
	end

	local a, s_ = lib.match(s, self.state.cmds.addr.prim, function() end, nil)
	if a then
		a = cont(a, s_)
		if loc then
			a = a - #self.prev
			assert(0 <= a and a <= #self.curr, #self.prev .. " <= " .. (#self.prev + a) .. " <= " .. (#self.prev + #self.curr))
		end
		return a
	end
	error("could not parse: " .. s)
end

function mt.__index:all()
	local ret = {}
	for _, l in ipairs(self.prev) do table.insert(ret, l) end
	for _, l in ipairs(self.curr) do table.insert(ret, l) end
	for _, l in ipairs(self.next) do table.insert(ret, l) end
	return ret
end

function mt.__index:change(f)
	if self._changing then f() else
		self._changing = true
		self:undo_point()
		local ok, err = xpcall(f, debug.traceback, self)
		self._changing = nil
		if not ok then
			self:undo()
			error(err)
		end
		self:diff()
	end
end

function mt.__index:close(force)
	if self.modified and not force then error("buffer modified") end
	lib.hook(self.state.hooks.close, self)
	table.remove(self.state.files, self.id)
	self.state:closed()
end

function mt.__index:diff()
	local pa = (os.getenv("HOME") or "/tmp") .. "/.ned-old"
	local pb = (os.getenv("HOME") or "/tmp") .. "/.ned-new"
	local ha = posix.fcntl.open(pa, posix.fcntl.O_WRONLY | posix.fcntl.O_CREAT, 5*8*8)
	local hb = posix.fcntl.open(pb, posix.fcntl.O_WRONLY | posix.fcntl.O_CREAT, 5*8*8)
	for _, l in ipairs(self.history[#self.history].curr) do posix.unistd.write(ha, l); posix.unistd.write(ha, "\n") end
	for _, l in ipairs(self.curr                       ) do posix.unistd.write(hb, l); posix.unistd.write(hb, "\n") end
	posix.unistd.close(ha)
	posix.unistd.close(hb)
	os.execute("diff -u --color=always " .. lib.shellesc(pa) .. " " .. lib.shellesc(pb) .. " | tail -n +3")
	posix.unistd.unlink(pa)
	posix.unistd.unlink(pb)
end

function mt.__index:extract(a, b)
	local ret = {}
	for i = b, a, -1 do ret[i - a + 1] = table.remove(self.curr, i) end
	return ret
end

function mt.__index:focus(first, last)
	local tmp = self:all()

	self.prev = {}
	self.curr = {}
	self.next = {}

	for i, l in ipairs(tmp) do
		local t = (i < first) and self.prev or (i <= last) and self.curr or self.next
		table.insert(t, l)
	end
end

function mt.__index:insert(a, tbl)
	print("insert", a, #tbl)
	for i, l in ipairs(tbl) do table.insert(self.curr, a + i, l) end
end

function mt.__index:print(lines)
	lib.hook(self.state.hooks.print_pre, self)

	if not lines then
		lines = {}
		for i = 1, #self.curr do lines[#self.prev + i] = true end
	end

	local all = self:all()

	local function go(f)
		local ok, r = xpcall(f, debug.traceback, all, self)
		if ok then
			if not r then
				local info = debug.getinfo(f, "S")
				print("print function failed to produce output: " .. info.short_src .. ":" .. info.linedefined .. "-" .. info.lastlinedefined)
			else
				all = r
			end
		else
			local info = debug.getinfo(f, "S")
			print("print function failed: " .. info.short_src .. ":" .. info.linedefined .. "-" .. info.lastlinedefined .. ": " .. r)
		end
	end

	for _, f in ipairs(self.state.print.pre ) do go(f) end
	go(self.state.print.highlight)
	for _, f in ipairs(self.state.print.post) do go(f) end

	local w = #tostring(#all)
	for i, l in ipairs(all) do
		if lines[i] then io.stdout:write(("%" .. tostring(w) .. "d│%s\n"):format(i, l)) end
	end

	lib.hook(self.state.hooks.print_post, self)
end

function mt.__index:replace(a, b, tbl)
	self:extract(a, b)
	self:insert(a - 1, tbl)
end

function mt.__index:save(path)
	if path then self:set_path(path) end

	lib.hook(self.state.hooks.save_pre, self)

	if self.conf.trim then
		for i, l in ipairs(self.prev) do self.prev[i] = l:match("^(.-)%s*$") end
		for i, l in ipairs(self.curr) do self.curr[i] = l:match("^(.-)%s*$") end
		for i, l in ipairs(self.next) do self.next[i] = l:match("^(.-)%s*$") end
	end

	local h = io.open(self.path, "w")
	local all = self:all()
	for _, l in ipairs(all) do
		h:write(l)
		if i ~= #all or self.conf.end_nl then h:write(self.conf.crlf and "\r\n" or "\n") end
	end
	h:close()

	self.modified = false
	for _, v in ipairs(self.history) do v.modified = true end

	lib.hook(self.state.hooks.save_post, self)
end

function mt.__index:set_path(path)
	local bypath = {}
	for _, v in ipairs(self.state.files) do
		if v.name then bypath[lib.realpath(v.name)] = true end
	end

	local canonical = lib.realpath(path)
	if bypath[canonical] then error("already opened: " .. canonical) end

	self.path = path
end

function mt.__index:undo()
	local h = table.remove(self.history)
	if not h then error("no undo point found") end
	for k, v in pairs(h) do self[k] = v end
end

function mt.__index:undo_point()
	local state = {
		prev = {table.unpack(self.prev)},
		curr = {table.unpack(self.curr)},
		next = {table.unpack(self.next)},
		modified = self.modified,
	}
	lib.hook(self.state.hooks.undo_point, self)
	table.insert(self.history, state)
	self.modified = true
end

return function(state, path)
	local ret = setmetatable({}, mt)
	ret.prev = {}
	ret.curr = {}
	ret.next = {}

	ret.state = state

	if path then
		ret:set_path(path)

		local h <close> = io.open(path, "r")
		if h then
			for l in h:lines() do table.insert(ret.curr, l) end
		end
	end

	ret.history  = {}
	ret.modified = false

	ret.conf = {
		crlf    = false,
		end_nl  = true ,
		indent  = 4    ,
		tab2spc = false,
		tabs    = 4    ,
		trim    = false,
	}
	ret.conf.ext = {}

	lib.hook(ret.state.hooks.load, ret)

	return ret
end
