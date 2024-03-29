local posix = require "posix"
local lib = require "neo-ed.lib"

local mt = {
	__index = {},
}

local function mkcache()
	return {
		content = {},
		cursor  = {},
	}
end

function mt.__index:addr(s)
	local function wrap_prim(f, m) return f(self, m) end
	local function wrap_cont(f, m, a) return f(self, m, a) end

	local function cont(a, s)
		local a_, s_ = lib.match{s = s, choose = self.state.cmds.addr.cont, def = function() end, wrap = wrap_cont, args = {a}}
		if a_ then return cont(a_, s_) end
		if s == "" then return a end
		lib.error("could not parse: " .. s)
	end

	local a, s_ = lib.match{s = s, choose = self.state.cmds.addr.prim, wrap = wrap_prim, def = function() end}
	if a then
		return cont(a, s_)
	end
	lib.error("could not parse: " .. s)
end

function mt.__index:all(data)
	data = data or self.data
	return self:extract(nil, nil, data)
end

function mt.__index:append(lines, pos)
	for _, l in ipairs(lines) do lib.assert(l.text) end
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
			self:undo(nil, true)
			lib.error(err)
		end
		self:diff_show(self:diff())
	end
	self.modified = true
end

-- Close the buffer. Fail if modified since last save and `force` is not set.
function mt.__index:close(force)
	if self.modified and not force then lib.error("buffer modified") end

	lib.hook(self.state.hooks.close, self)
	table.remove(self.state.files, self.id)
	self.state:closed()
end

function mt.__index:cmd(s)
	local sel_a = self:sel_first()
	local sel_b = self:sel_last ()
	local len   = self:length   ()
	local pos   = self:pos      ()
	local cmds  = self.state.cmds

	local function file0(f, m)
		f(self, m)
	end

	local function pos1(f, m, a)
		if not (0 <= a and a <= len) then lib.error(a .. " not in range [0, " .. len .. "]") end
		f(self, m, a)
	end

	local function pos2(f, m, a, b)
		a = a or sel_a
		b = b or sel_b
		if not (0 <= a and a <= len) then lib.error(a .. " not in range [0, "           .. len .. "]") end
		if not (a <= b and b <= len) then lib.error(b .. " not in range [" .. a .. ", " .. len .. "]") end
		f(self, m, a, b)
	end

	local function local2(f, m, a, b)
		a = a or sel_a
		b = b or sel_b
		if not (0 <= a and a <= len) then lib.error(a .. " not in range [0, "           .. len .. "]") end
		if not (a <= b and b <= len) then lib.error(b .. " not in range [" .. a .. ", " .. len .. "]") end
		f(self, m, a, b)
	end

	local function global2(f, m, a, b)
		a = a or sel_a
		b = b or sel_b
		if not (0 <= a and a <= len) then lib.error(a .. " not in range [0, "           .. len .. "]") end
		if not (a <= b and b <= len) then lib.error(b .. " not in range [" .. a .. ", " .. len .. "]") end
		f(self, m, a, b)
	end

	local function prim(f, m) return f(self, m) end
	local function cont(f, m, a) return f(self, m, a) end
	local range = prim

	local function cmd2(a, b, s)
		s = s:match("^%s*(.*)$")

		local b_, s_ = lib.match{s = s, choose = cmds.addr.cont, def = function() end, wrap = cont, args = {b}}
		if b_ then return cmd2(a, b_, s_) end

		if not lib.match{s = s, choose = cmds.range_global, def = function() return true end, wrap = global2, args = {a, b}} then return end
		if not lib.match{s = s, choose = cmds.range_local , def = function() return true end, wrap = local2 , args = {a, b}} then return end
		if not lib.match{s = s, choose = cmds.range_line  , def = function() return true end, wrap = pos2   , args = {a, b}} then return end

		lib.error("could not parse: " .. s)
	end

	local function cmd1(a, s)
		s = s:match("^%s*(.*)$")

		local a_, s_ = lib.match{s = s, choose = cmds.addr.cont, def = function() end, wrap = cont, args = {a}}
		if a_ then return cmd1(a_, s_) end

		local s_ = s:match("^,(.*)$")
		if s_ then
			local b, s__ = lib.match{s = s_, choose = cmds.addr.prim, wrap = prim, def = function() end}
			if b then return cmd2(a, b, s__) end
			return cmd2(a, nil, s_)
		end

		local s_ = s:match("^;(.*)$")
		if s_ then return cmd2(a, a, s_) end

		if not lib.match{s = s, choose = cmds.range_global, def = function() return true end, wrap = global2, args = {a, a}} then return end
		if not lib.match{s = s, choose = cmds.range_local , def = function() return true end, wrap = local2 , args = {a, a}} then return end
		if not lib.match{s = s, choose = cmds.range_line  , def = function() return true end, wrap = pos2   , args = {a, a}} then return end
		if not lib.match{s = s, choose = cmds.line        , def = function() return true end, wrap = pos1   , args = {a   }} then return end

		lib.error("could not parse: " .. s)
	end

	local function cmd0(s)
		s = s:match("^%s*(.*)$")

		local a, b, s_ = lib.match{s = s, choose = cmds.addr.range, wrap = range, def = function() end}
		if a then return cmd2(a, b, s_) end

		local a, s_ = lib.match{s = s, choose = cmds.addr.prim, wrap = prim, def = function() end}
		if a then return cmd1(a, s_) end

		if s:find("^,(.*)$") then return cmd1(nil, s) end

		if not lib.match{s = s, choose = cmds.file        , def = function() return true end, wrap = file0                         } then return end
		if not lib.match{s = s, choose = cmds.range_global, def = function() return true end, wrap = global2, args = {1    , len  }} then return end
		if not lib.match{s = s, choose = cmds.range_local , def = function() return true end, wrap = local2 , args = {sel_a, sel_b}} then return end
		if not lib.match{s = s, choose = cmds.range_line  , def = function() return true end, wrap = pos2   , args = {pos  , pos  }} then return end
		if not lib.match{s = s, choose = cmds.line        , def = function() return true end, wrap = pos1   , args = {pos         }} then return end

		lib.error("could not parse: " .. s)
	end

	self.curr_cmd = s
	cmd0(s)
	self.curr_cmd = nil
end

-- Delete the current element, making the next (or alternatively previous) element the new buffer position.
function mt.__index:delete()
	if self.data.curr.nprev == -1 then lib.error("cannot delete index 0") end

	if self.data.curr.next then
		local newdata = {}
		newdata.curr       = lib.dup(self.data.curr.next)
		newdata.curr.prev  = self.data.curr.prev
		newdata.curr.nprev = self.data.curr.nprev
		newdata.cache      = mkcache()
		self.data          = newdata

	elseif self.data.curr.prev then
		local newdata = {}
		newdata.curr       = lib.dup(self.data.curr.prev)
		newdata.curr.next  = self.data.curr.next
		newdata.curr.nnext = self.data.curr.nnext
		newdata.cache      = mkcache()
		self.data          = newdata

	end
end

function mt.__index:diff(fst, snd)
	-- based on https://en.wikipedia.org/wiki/Wagner%E2%80%93Fischer_algorithm

	fst = fst or self.history[#self.history].data
	snd = snd or self.data

	local fst_lines = self:all(fst)
	local snd_lines = self:all(snd)

	local fst_printed = self:print_data(fst)
	local snd_printed = self:print_data(snd)

	return self:diff_lines(fst_lines, snd_lines, fst_printed, snd_printed)
end

function mt.__index:diff_lines(fst_lines, snd_lines, fst_printed, snd_printed)
	if not fst_lines   then fst_lines, fst_printed = self:all(data), self:print_data(data) end
	if not snd_lines   then snd_lines, snd_printed = self:all(data), self:print_data(data) end
	if not fst_printed then fst_printed = lib.dup(fst_lines, 2); self:print_lines(fst_printed) end
	if not snd_printed then snd_printed = lib.dup(snd_lines, 2); self:print_lines(snd_printed) end

	local function mkkeep(i, j, dist) return {dist = dist, op = "=", text = fst_lines[i].text, pretty = fst_printed[i].text, nfst = i, nsnd = j} end
	local function mkadd (i, j, dist) return {dist = dist, op = "+", text = snd_lines[j].text, pretty = snd_printed[j].text,           nsnd = j} end
	local function mksub (i, j, dist) return {dist = dist, op = "-", text = fst_lines[i].text, pretty = fst_printed[i].text, nfst = i          } end

	local m = {}

	-- determine lower bound for quadratic algorithm (don't have to compare equal lines)
	local lb = 1
	local seq_start = {}
	while fst_lines[lb] and snd_lines[lb] and fst_lines[lb].text == snd_lines[lb].text do
		table.insert(seq_start, mkkeep(lb, lb, 0))
		lb = lb + 1
	end

	-- determine upper bound for quadratic algorithm (we don't know the final distance yet, so we use -1 as a placeholder)
	local ubfst = #fst_lines
	local ubsnd = #snd_lines
	local seq_end = {}
	while ubfst > lb and ubsnd > lb and fst_lines[ubfst].text == snd_lines[ubsnd].text do
		table.insert(seq_end, mkkeep(ubfst, ubsnd, -1))
		ubfst = ubfst - 1
		ubsnd = ubsnd - 1
	end

	-- actual core algorithm, calculate Levenshtein distance for sub-sequences and record some extra info
	for i = lb - 1, ubfst do
		m[i] = {}

		for j = lb - 1, ubsnd do

			-- base cases
			    if i == lb - 1 and j == lb - 1 then m[i][j] = {dist = 0, op = false}
			elseif i == lb - 1                 then m[i][j] = mkadd(i, j, m[i][j-1].dist + 1)
			elseif j == lb - 1                 then m[i][j] = mksub(i, j, m[i-1][j].dist + 1)

			else
				local keep = fst_lines[i].text == snd_lines[j].text and m[i-1][j-1].dist or math.huge
				local add  = m[i][j-1].dist + 1
				local sub  = m[i-1][j].dist + 1
				local min  = math.min(keep, add, sub)

				    if min == keep and m[i-1][j-1].op == "=" then m[i][j] = mkkeep(i, j, keep)
				elseif min == add  and m[i  ][j-1].op == "+" then m[i][j] = mkadd (i, j, add )
				elseif min == sub  and m[i-1][j  ].op == "-" then m[i][j] = mksub (i, j, sub )
				elseif min == keep                           then m[i][j] = mkkeep(i, j, keep)
				elseif min == add                            then m[i][j] = mkadd (i, j, add )
				elseif min == sub                            then m[i][j] = mksub (i, j, sub )
				end
			end
		end
	end

	local tmp = {}
	local i = ubfst
	local j = ubsnd

	-- reconstruct optimal sequence of operations from core matrix, output will be in reverse order
	while m[i][j].op do
		table.insert(tmp, m[i][j])

		    if m[i][j].op == "+" then    j =        j - 1
		elseif m[i][j].op == "-" then i    = i - 1
		else                          i, j = i - 1, j - 1
		end
	end

	-- assemble final order from trivial prefix, suffix, and the matrix part we just traced
	local ret = {}

	for _, v in ipairs(seq_start) do table.insert(ret, v) end

	for i = #tmp, 1, -1 do table.insert(ret, tmp[i]) end

	local dist = ret[#ret].dist
	for i = #seq_end, 1, -1 do
		seq_end[i].dist = dist	-- fill in actual distance
		table.insert(ret, seq_end[i])
	end

	return ret
end

function mt.__index:diff_show(d, ctx)
	ctx = ctx or 3

	lib.hook(self.state.hooks.print_pre, self)

	local wn = #tostring(#d)
	local filler = ("."):rep(wn)

	local wt = 80
	if os.execute("which tput >/dev/null 2>&1") then wt = tonumber(lib.pipe("tput cols", "")) end
	local sep = ("▄"):rep(wt)

	for i = 1, #d do
		local show = false
		if d[i].op ~= "=" then show = true end
		for j = 1, ctx do
			if d[i + j] and d[i + j].op ~= "=" then show = true end
			if d[i - j] and d[i - j].op ~= "=" then show = true end
		end

		if show then
			if not d[i-1] or d[i-1].op ~= d[i].op then
				    if d[i].op == "+" then print(("%s%s%s"):format("\x1b[32m", sep, "\x1b[0m"))
				elseif d[i].op == "-" then print(("%s%s%s"):format("\x1b[31m", sep, "\x1b[0m"))
				end
			end

			    if d[i].op == "+" then print(("%s%" .. tostring(wn) .. "d%s│%s%s"):format("\x1b[42;30m", d[i].nsnd, "\x1b[0;33m", "\x1b[0m", d[i].pretty))
			elseif d[i].op == "-" then print(("%s%" .. tostring(wn) .. "s%s│%s%s"):format("\x1b[41;30m", ""       , "\x1b[0;33m", "\x1b[0m", d[i].pretty))
			else                       print(("%s%" .. tostring(wn) ..   "d│%s%s"):format("\x1b[33m"   , d[i].nsnd,               "\x1b[0m", d[i].pretty))
			end

			if not d[i+1] or d[i+1].op ~= d[i].op then
				    if d[i].op == "+" then print(("%s%s%s"):format("\x1b[7;32m", sep, "\x1b[0m"))
				elseif d[i].op == "-" then print(("%s%s%s"):format("\x1b[7;31m", sep, "\x1b[0m"))
				end
			end

		elseif d[i + ctx + 1] and d[i + ctx + 1].op ~= "=" or d[i - ctx - 1] and d[i - ctx - 1].op ~= "=" then
			print(("%s%s│%s"):format("\x1b[33m", filler, "\x1b[0m"))

		end
	end

	lib.hook(self.state.hooks.print_post, self)
end

function mt.__index:drop(first, last)
	first = first or 1
	last  = last  or self:length()

	self:seek(last )
	self:seek(first)
	for _ = first, last do self:delete() end
end

function mt.__index:drop_cache()
	function go(data)
		data.cache.content = {}
		data.cache.cursor  = {}
	end

	go(self.data)
	for i, v in ipairs(self.history) do go(v.data) end
end

function mt.__index:extract(first, last, data)
	data  = data  or self.data
	first = first or 1
	last  = last  or self:length(data)

	local ret = {}
	self:inspect(function(_, l)
		local tmp = lib.dup(l)
		tmp.prev  = nil
		tmp.next  = nil
		tmp.nprev = nil
		tmp.nnext = nil
		table.insert(ret, tmp)
	end, first, last, data)
	return ret
end

function mt.__index:get_input(history)
	local ret = lib.readline("", history)
	if ret then
		for _, f in ipairs(self.state.hooks.input_post) do ret = f(ret, self) end
	end
	return ret
end

function mt.__index:get_path()
	return self.conf:get_path()
end

-- Insert the given element after the current buffer position, making it the new buffer position.
function mt.__index:insert(elem)
	lib.assert(elem.text)

	local newdata = {curr = lib.dup(elem)}
	local newprev = lib.dup(self.data.curr)
	newdata.curr.prev  = newprev
	newdata.curr.next  = newprev.next
	newdata.curr.nprev = newprev.nprev + 1
	newdata.curr.nnext = newprev.nnext
	newdata.cache      = mkcache()
	newprev.next       = nil
	newprev.nnext      = nil
	self.data          = newdata
end

-- Apply a function to each line number and corresponding element. THIS FUNCTION MAY NOT CHANGE THE ELEMENT!
function mt.__index:inspect(f, first, last, data)
	if not data  then data  = self.data         end
	if not first then first = 1                 end
	if not last  then last  = self:length(data) end

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

	head(data.curr.prev)
	if first <= data.curr.nprev + 1 and data.curr.nprev + 1 <= last then f(data.curr.nprev + 1, data.curr) end
	tail(data.curr.next, data.curr.nprev + 2)
end

-- Apply a function to each line number and corresponding element in reverse order. THIS FUNCTION MAY NOT CHANGE THE ELEMENT!
function mt.__index:inspect_r(f, first, last, data)
	if not data  then data  = self.data         end
	if not first then first = self:length(data) end
	if not last  then last  = 1                 end

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

	tail(data.curr.next, data.curr.nprev + 2)
	if first >= data.curr.nprev + 1 and data.curr.nprev + 1 >= last then f(data.curr.nprev + 1, data.curr) end
	head(data.curr.prev)
end

-- Return the total number of lines in the buffer.
function mt.__index:length(data)
	data = data or self.data
	return data.curr.nprev + 1 + data.curr.nnext
end

function mt.__index:load(path, force)
	if self.modified and not force then lib.error("buffer modified") end

	if path then self:set_path(path) end

	lib.hook(self.state.hooks.load_pre, self)

	if self:length() > 0 then self:drop() end

	local s = self.conf:path_read()
	for l in s:gmatch("[^\n]*") do self:insert({text = l}) end
	if self.data.curr.text == "" then self:delete() end

	self.modified = false

	lib.hook(self.state.hooks.load_post, self)
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

	local newdata = {curr = lib.dup(self.data.curr)}
	newdata.curr.prev = head(newdata.curr.prev)
	newdata.curr.next = tail(newdata.curr.next, newdata.curr.nprev + 2)
	newdata.cache     = mkcache()
	if first <= newdata.curr.nprev + 1 and newdata.curr.nprev + 1 <= last then f(newdata.curr.nprev + 1, newdata.curr) end
	self.data = newdata
end

function mt.__index:modify(f, pos)
	pos = pos or self:pos()
	self:map(f, pos, pos)
end

function mt.__index:print(lines)
	if not lines then
		lines = {}
		for i = self:sel_first(), self:sel_last() do lines[i] = true end
	end

	local printed = self:print_data()

	lib.hook(self.state.hooks.print_pre, self)

	local w = #tostring(#printed)
	for i, l in ipairs(printed) do
		if lines[i] then
			io.stdout:write(("\x1b[%sm%" .. tostring(w) .. "d\x1b[0;33m│\x1b[0m%s\n"):format(i == self:pos() and "43;30" or "33", i, l.text))
		end
	end

	lib.hook(self.state.hooks.print_post, self)
end

function mt.__index:print_data(data)
	data = data or self.data
	if data.cache.content.printed then return data.cache.content.printed end

	local ret = self:all(data)
	self:print_lines(ret)
	data.cache.content.printed = ret
	return ret
end

function mt.__index:print_lines(lines)
	local prof = lib.profiler("print pipeline")

	local function go(f)
		local info = debug.getinfo(f, "S")

		prof:start(info.short_src .. ":" .. info.linedefined .. "-" .. info.lastlinedefined)
		local ok, err = xpcall(f, lib.traceback, lines, self)
		prof:stop()

		if not ok then self.state:warn("print function failed: " .. info.short_src .. ":" .. info.linedefined .. "-" .. info.lastlinedefined .. ": " .. err) end
	end

	for _, f in ipairs(self.state.print.pre ) do go(f) end
	go(self.state.print.highlight)
	for _, f in ipairs(self.state.print.post) do go(f) end

--	prof:print()
end

function mt.__index:pos()
	return self.data.curr.nprev + 1
end

function mt.__index:save(path, first, last)
	if path and not self:get_path() then self:set_path(path) end
	first = first or 1
	last  = last  or self:length()

	local default_write = not path and first == 1 and last == self:length()

	if default_write then lib.hook(self.state.hooks.save_pre, self) end

	local s = {}
	self:inspect(function(n, l) table.insert(s, l.text) end, first, last)
	table.insert(s, "")
	s = table.concat(s, "\n")
	; (path and self.state:get_conf_for(path) or self.conf):path_write(s)

	if default_write then
		self.modified = false
		for _, v in ipairs(self.history) do v.modified = true end
	end

	if default_write then lib.hook(self.state.hooks.save_post, self) end
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

	while n > self:pos() and self.data.curr.next do
		local newdata = {curr = lib.dup(self.data.curr.next)}
		local newprev =         lib.dup(self.data.curr     )

		newdata.curr.prev     = newprev
		newdata.curr.nprev    = newprev.nprev + 1
		newdata.curr.hide     = nil
		newdata.cache         = mkcache()
		newdata.cache.content = self.data.cache.content

		newprev.next  = nil
		newprev.nnext = nil

		self.data = newdata
	end

	while n < self:pos() and self.data.curr.prev do
		local newdata = {curr = lib.dup(self.data.curr.prev)}
		local newnext =         lib.dup(self.data.curr     )

		newdata.curr.next     = newnext
		newdata.curr.nnext    = newnext.nnext + 1
		newdata.curr.hide     = nil
		newdata.cache         = mkcache()
		newdata.cache.content = self.data.cache.content

		newnext.prev  = nil
		newnext.nprev = nil

		self.data = newdata
	end
end

function mt.__index:select(first, last)
	local oldfirst = self:sel_first()
	local oldlast  = self:sel_last ()
	local ccache   = self.data.cache.content
	self:seek(last)
	self:map(
		function(n, l) l.hide = not (first <= n and n <= last) end,
		math.min(oldfirst, first),
		math.max(oldlast , last )
	)
	self.data.cache.content = ccache
end

function mt.__index:sel_first()
	return self:scan(function(n, l) return not l.hide and n or nil end) or 1
end

function mt.__index:sel_last()
	return self:scan_r(function(n, l) return not l.hide and n or nil end) or self:length()
end

function mt.__index:set_path(path)
	path = self.state:path_resolve(path)

	local old_path = self:get_path()
	local conf = self.state:get_conf_for(path)
	conf:set_buffer(self)
	self.conf:set_base(conf)
	self.modified = true
	self:drop_cache()

	lib.hook(self.state.hooks.path_post, self, old_path)
end

function mt.__index:undo(n, quiet)
	n = n or #self.history
	if not self.history[n] then lib.error("undo point not found") end

	if not quiet then self:diff_show(self:diff(self.data, self.history[n].data)) end

	while #self.history > n do table.remove(self.history) end
	local h = table.remove(self.history)
	for k, v in pairs(h) do self[k] = v end
end

function mt.__index:undo_point()
	local state = {
		data     = self.data,
		modified = self.modified,
		__cmd    = self.curr_cmd,
	}

	lib.hook(self.state.hooks.undo_point, self, state)
	table.insert(self.history, state)
end

return function(state, path)
	local ret = setmetatable({}, mt)
	ret.data = {curr = {nprev = -1, nnext = 0}, cache = mkcache()}

	ret.state = state

	ret.history  = {}
	ret.modified = false

	ret.conf = require "neo-ed.conf" (state)

	if path then ret:load(path, true) end

	return ret
end
