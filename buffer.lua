local posix = require "posix"
local lib = require "neo-ed.lib"

local mt = {
	__index = {},
}

-- Buffer element fields:
--  - text: line contents
--  - prev: previous element, if not after current buffer position
--  - next: next element, if not before current buffer position
--  - nprev: number of elements before this, if not after current buffer position
--  - nnext: number of elements after this, if not before current buffer position

function mt.__index:addr(s, loc)
	local function cont(a, s)
		local a_, s_ = lib.match{s = s, choose = self.state.cmds.addr.cont, def = function() end, args = {a}}
		if a_ then return cont(a_, s_) end
		if s == "" then return a end
		lib.error("could not parse: " .. s)
	end

	local a, s_ = lib.match{s = s, choose = self.state.cmds.addr.prim, def = function() end}
	if a then
		a = cont(a, s_)
		if loc then
			local sel_a = self:sel_first()
			local sel_b = self:sel_last ()
			if not (sel_a <= a and a <= sel_b) then lib.error(a .. " not in range [" .. sel_a .. ", " .. sel_b .. "]") end
		end
		return a
	end
	lib.error("could not parse: " .. s)
end

function mt.__index:all()
	return self:extract()
end

function mt.__index:append(lines, pos)
	if pos then self:seek(pos) end
	for _, l in ipairs(lines) do self:insert(l) end
end

-- Create an undo point, then apply function `f` that changes the buffer. If `f` fails, roll back the changes.
function mt.__index:change(f)
	if self._changing then f(self) else
		self._changing = true
		self:undo_point()
		local ok, err = xpcall(f, lib.traceback, self)
		self._changing = nil
		if not ok then
			self:undo()
			lib.error(err)
		end
		self:diff()
	end
end

-- Close the buffer. Fail if modified since last save and `force` is not set.
function mt.__index:close(force)
	if self.modified and not force then lib.error("buffer modified") end
	lib.hook(self.state.hooks.close, self)
	table.remove(self.state.files, self.id)
	self.state:closed()
end

-- Delete the current element, making the next (or alternatively previous) element the new buffer position.
function mt.__index:delete()
	if self.curr.nprev == -1 then lib.error("cannot delete index 0") end

	local ret = lib.dup(self.curr)

	if self.curr.next then
		local tmp = lib.dup(self.curr.next)
		tmp.prev  = self.curr.prev
		tmp.nprev = self.curr.nprev
		self.curr = tmp

	elseif self.curr.prev then
		local tmp = lib.dup(self.curr.prev)
		tmp.next  = self.curr.next
		tmp.nnext = self.curr.nnext
		self.curr = tmp

	else
		self.curr = false

	end

	ret.prev  = nil
	ret.next  = nil
	ret.nprev = nil
	ret.nnext = nil
	ret.hide  = nil

	return ret
end

function mt.__index:diff()
	local cmd = os.execute("which git >/dev/null 2>&1")
		and "git diff --no-index --color %s %s | tail -n +5"
		or  "diff -u %s %s | tail -n +3"

	local pa = (os.getenv("HOME") or "/tmp") .. "/.ned-old"
	local pb = (os.getenv("HOME") or "/tmp") .. "/.ned-new"
	local ha = posix.fcntl.open(pa, posix.fcntl.O_WRONLY | posix.fcntl.O_CREAT, 6*8*8)
	local hb = posix.fcntl.open(pb, posix.fcntl.O_WRONLY | posix.fcntl.O_CREAT, 6*8*8)
	self:inspect(function(_, l) posix.unistd.write(ha, l.text); posix.unistd.write(ha, "\n") end, nil, nil, self.history[#self.history].curr)
	self:inspect(function(_, l) posix.unistd.write(hb, l.text); posix.unistd.write(hb, "\n") end                                            )
	posix.unistd.close(ha)
	posix.unistd.close(hb)

	os.execute((cmd):format(lib.shellesc(pa), lib.shellesc(pb)))

	posix.unistd.unlink(pa)
	posix.unistd.unlink(pb)
end

function mt.__index:drop(first, last)
	self:seek(last )
	self:seek(first)
	for _ = first, last do self:delete() end
end

function mt.__index:extract(first, last)
	first = first or 1
	last  = last  or self:length()

	local ret = {}
	self:inspect(function(_, l)
		local tmp = lib.dup(l)
		tmp.prev  = nil
		tmp.next  = nil
		tmp.nprev = nil
		tmp.nnext = nil
		table.insert(ret, tmp)
	end, first, last)
	return ret
end

function mt.__index:get_input(ac)
	local ret = lib.readline("", ac)
	if ret then
		for _, f in ipairs(self.state.hooks.input_post) do ret = f(ret, self) end
	end
	return ret
end

-- Insert the given element after the current buffer position, making it the new buffer position.
function mt.__index:insert(elem)
	elem = lib.dup(elem)

	local prev = lib.dup(self.curr)
	elem.prev  = prev
	elem.next  = prev.next
	elem.nprev = prev.nprev + 1
	elem.nnext = prev.nnext
	prev.next  = nil
	prev.nnext = nil
	self.curr  = elem
end

-- Apply a function to each line number and corresponding element. THIS FUNCTION MAY NOT CHANGE THE ELEMENT!
function mt.__index:inspect(f, first, last, elem)
	if not first then first = 1         end
	if not last  then last  = 1/0       end
	if not elem  then elem  = self.curr end

	local function head(elem)
		if elem then
			head(elem.prev)
			local n = elem.nprev + 1
			if first <= n and n <= last then f(elem.nprev + 1, elem) end
		end
	end

	local function tail(elem, n)
		if elem then
			if first <= n and n <= last then f(n, elem) end
			tail(elem.next, n + 1)
		end
	end

	head(elem.prev)
	if first <= elem.nprev + 1 and elem.nprev + 1 <= last then f(elem.nprev + 1, elem) end
	tail(elem.next, elem.nprev + 2)
end

-- Apply a function to each line number and corresponding element in reverse order. THIS FUNCTION MAY NOT CHANGE THE ELEMENT!
function mt.__index:inspect_r(f, first, last, elem)
	if not first then first = 1/0       end
	if not last  then last  = 1         end
	if not elem  then elem  = self.curr end

	local function head(elem)
		if elem then
			local n = elem.nprev + 1
			if first >= n and n >= last then f(elem.nprev + 1, elem) end
			head(elem.prev)
		end
	end

	local function tail(elem, n)
		if elem then
			tail(elem.next, n + 1)
			if first >= n and n >= last then f(n, elem) end
		end
	end

	tail(elem.next, elem.nprev + 2)
	if first >= elem.nprev + 1 and elem.nprev + 1 >= last then f(elem.nprev + 1, elem) end
	head(elem.prev)
end

-- Return the total number of lines in the buffer.
function mt.__index:length()
	return self.curr.nprev + 1 + self.curr.nnext
end

function mt.__index:map(f, first, last)
	if not first then first = 1             end
	if not last  then last  = self:length() end

	if not (1 <= first and first <= self:length()) then lib.error(first .. " not in range [1, " .. self:length() .. "]") end
	if not (1 <= last  and last  <= self:length()) then lib.error(last  .. " not in range [1, " .. self:length() .. "]") end

	if first > last then return end

	local function head(elem)
		if elem and first <= elem.nprev + 1 then
			local prev = head(elem.prev)
			elem = lib.dup(elem)
			elem.prev = prev
			if elem.nprev + 1 <= last then f(elem.nprev + 1, elem) end
		end
		return elem
	end

	local function tail(elem, n)
		if elem and n <= last then
			local next = tail(elem.next, n + 1)
			elem = lib.dup(elem)
			elem.next = next
			if first <= n then f(n, elem) end
		end
		return elem
	end

	self.curr = lib.dup(self.curr)
	self.curr.prev = head(self.curr.prev)
	self.curr.next = tail(self.curr.next, self.curr.nprev + 2)
	if first <= self.curr.nprev + 1 and self.curr.nprev + 1 <= last then f(self.curr.nprev + 1, self.curr) end
end

function mt.__index:modify(f, pos)
	pos = pos or self:pos()
	self:map(f, pos, pos)
end

-- TODO: can this be done without cloning the entire buffer?
function mt.__index:print(lines)
	if not lines then
		lines = {}
		for i = self:sel_first(), self:sel_last() do lines[i] = true end
	end

	local all = self:all()

	lib.hook(self.state.hooks.print_pre, self, all, lines)

	local function go(f)
		local ok, r = xpcall(f, lib.traceback, all, self)
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
		if lines[i] then
			io.stdout:write(("\x1b[%sm%" .. tostring(w) .. "d\x1b[0;33m│\x1b[0m%s\n"):format(i == self:pos() and "43;30" or "33", i, l.text))
		end
	end

	lib.hook(self.state.hooks.print_post, self, all, lines)
end

function mt.__index:pos()
	return self.curr.nprev + 1
end

function mt.__index:save(path)
	if path then self:set_path(path) end

	lib.hook(self.state.hooks.save_pre, self)

	if self.conf.trim then
		self:map(function(_, l) l.text = l.text:match("^(.-)%s*$") end)
	end

	local s = {}
	self:inspect(function(n, l) table.insert(s, l.text) end)
	if self.conf.end_nl then table.insert(s, "") end
	s = table.concat(s, "\n")
	for i = #self.state.filters.write, 1, -1 do s = self.state.filters.write[i](s, self) end

	lib.match{s = self.path, choose = self.state.protocols,
		def = function(p, s) local h <close> = io.open(p, "w"); h:write(s) end,
		wrap = function(t, p, s) t.write(p, s) end,
		args = {s}
	}

	self.modified = false
	for _, v in ipairs(self.history) do v.modified = true end

	lib.hook(self.state.hooks.save_post, self)
end

function mt.__index:scan(f, first, last)
	first = first or 1
	last  = last  or self:length()

	local ret = nil
	self:inspect(function(n, l) if ret == nil then ret = f(n, l) end end, first, last)
	return ret
end

function mt.__index:scan_r(f, first, last)
	first = first or self:length()
	last  = last  or 1

	local ret = nil
	self:inspect_r(function(n, l) if ret == nil then ret = f(n, l) end end, first, last)
	return ret
end

function mt.__index:seek(n)
	if not (0 <= n and n <= self:length()) then lib.error("seek out of range: " .. n .. " not in [0, " .. self:length() .. "]") end

	while n > self:pos() and self.curr.next do
		local prev = lib.dup(self.curr     )
		local curr = lib.dup(self.curr.next)

		curr.prev  = prev
		curr.nprev = prev.nprev + 1
		curr.hide  = nil

		prev.next  = nil
		prev.nnext = nil

		self.curr = curr
	end

	while n < self:pos() and self.curr.prev do
		local next = lib.dup(self.curr     )
		local curr = lib.dup(self.curr.prev)

		curr.next  = next
		curr.nnext = next.nnext + 1
		curr.hide  = nil

		next.prev  = nil
		next.nprev = nil

		self.curr = curr
	end
end

function mt.__index:select(first, last)
	local oldfirst = self:sel_first()
	local oldlast  = self:sel_last ()
	self:seek(last)
	self:map(
		function(n, l) l.hide = not (first <= n and n <= last) end,
		math.min(oldfirst, first),
		math.max(oldlast , last )
	)
end

function mt.__index:sel_first()
	return self:scan(function(n, l) return not l.hide and n or nil end) or 1
end

function mt.__index:sel_last()
	return self:scan_r(function(n, l) return not l.hide and n or nil end) or self:length()
end

function mt.__index:set_path(path)
	path = self.state:path_resolve(path)

	local bypath = {}
	for _, v in ipairs(self.state.files) do
		if v.path then bypath[lib.realpath(v.path)] = true end
	end

	local canonical = lib.realpath(path)
	if bypath[canonical] then lib.error("already opened: " .. canonical) end

	self.path = path
end

function mt.__index:undo(n)
	n = n or #self.history
	if not self.history[n] then lib.error("undo point not found") end
	while #self.history > n do table.remove(self.history) end
	local h = table.remove(self.history)
	for k, v in pairs(h) do self[k] = v end
end

function mt.__index:undo_point()
	local state = {
		curr     = self.curr,
		modified = self.modified,
		__cmd    = self.state.curr_cmd,
	}

	lib.hook(self.state.hooks.undo_point, self, state)
	table.insert(self.history, state)
	self.modified = true
end

return function(state, path)
	local ret = setmetatable({}, mt)
	ret.curr = {nprev = -1, nnext = 0}

	ret.state = state

	ret.history  = {}
	ret.modified = false

	ret.conf = {
		charset = "utf-8",
		crlf    = false,
		end_nl  = true ,
		indent  = 4    ,
		tab2spc = false,
		tabs    = 4    ,
		trim    = false,
	}

	if path then ret:set_path(path) end

	lib.hook(ret.state.hooks.load_pre, ret)

	if path then
		local s = lib.match{s = ret.path, choose = state.protocols,
			def = function(p) local h <close> = io.open(p, "r"); return h and h:read("a") or "" end,
			wrap = function(t, p) return t.read(p) end
		}

		for _, f in ipairs(ret.state.filters.read) do s = f(s, ret) end
		for l in s:gmatch("[^\n]*") do ret:insert({text = l}) end
		if ret.curr.text == "" then ret:delete() end
	end

	lib.hook(ret.state.hooks.load_post, ret)

	return ret
end

----------------------------------------------------------------------------------------------------
--[[

]]
