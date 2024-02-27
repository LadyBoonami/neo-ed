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

function mt.__index:all(data)
	data = data or self.data
	return self:extract(nil, nil, data)
end

function mt.__index:append(lines, pos)
	for _, l in ipairs(lines) do lib.assert(l.text) end
	if pos then self:seek(pos) end
	for _, l in ipairs(lines) do self:insert(l) end
end

function mt.__index:conf_show(k)
	local v = self.conf[k]
	lib.assert(v ~= nil, "unknown config option: " .. k)

	if type(v) == "boolean" then return v and "y" or "n" end
	if type(v) == "number"  then return tostring(v)      end
	if type(v) == "string"  then return v                end
	lib.error("cannot show setting of type " .. type(v))
end

function mt.__index:conf_set(k, v)
	assert(type(v) == "string")

	local def = lib.assert(self.state.conf_defs[k], "unknown config option: " .. k)

	local function parse_val(s)
		if def.type == "boolean" then
			if s == "y" then return true  end
			if s == "Y" then return true  end
			if s == "n" then return false end
			if s == "N" then return false end
			if s == "1" then return true  end
			if s == "0" then return false end
			lib.error("could not parse boolean: " .. s)

		elseif def.type == "number" then
			return lib.assert(tonumber(s), "could not parse number: " .. s)

		elseif def.type == "string" then
			return s

		end
	end

	self.conf[k] = (def.on_set or function(_, v) return v end)(self, parse_val(v))
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
		self:diff_show()
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
	if self.data.curr.nprev == -1 then lib.error("cannot delete index 0") end

	if self.data.curr.next then
		local newdata = {}
		newdata.curr       = lib.dup(self.data.curr.next)
		newdata.curr.prev  = self.data.curr.prev
		newdata.curr.nprev = self.data.curr.nprev
		self.data          = newdata

	elseif self.data.curr.prev then
		local newdata = {}
		newdata.curr       = lib.dup(self.data.curr.prev)
		newdata.curr.next  = self.data.curr.next
		newdata.curr.nnext = self.data.curr.nnext
		newdata.curr.cache = {}
		self.data          = newdata

	end
end

function mt.__index:diff(fst, snd)
	-- based on https://en.wikipedia.org/wiki/Wagner%E2%80%93Fischer_algorithm

	fst = fst or self.history[#self.history].data
	snd = snd or self.data

	local fst_lines = self:all(fst)
	local snd_lines = self:all(snd)

	local fst_printed = self:print_lines(fst)
	local snd_printed = self:print_lines(snd)

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

function mt.__index:diff_show(ctx, fst, snd)
	ctx = ctx or 3

	local d = self:diff(fst, snd, true)
	local w = math.max(#tostring(self:length()), #tostring(self:length(self.history[#self.history].data)))
	local filler = ("."):rep(w)
	local sep = (" "):rep(80)
	if os.execute("which tput >/dev/null 2>&1") then sep = (" "):rep(tonumber(lib.pipe("tput cols", ""))) end

	for i = 1, #d do
		local show = false
		if d[i].op ~= "=" then show = true end
		for j = 1, ctx do
			if d[i + j] and d[i + j].op ~= "=" then show = true end
			if d[i - j] and d[i - j].op ~= "=" then show = true end
		end

		if show then
			if not d[i-1] or d[i-1].op ~= d[i].op then
				    if d[i].op == "+" then print(("%s%s%s"):format("\x1b[42m", sep, "\x1b[0m"))
				elseif d[i].op == "-" then print(("%s%s%s"):format("\x1b[41m", sep, "\x1b[0m"))
				end
			end

			    if d[i].op == "+" then print(("%s%" .. tostring(w) .. "d%s│%s%s"):format("\x1b[42;30m", d[i].nsnd, "\x1b[0;33m", "\x1b[0m", d[i].pretty))
			elseif d[i].op == "-" then print(("%s%" .. tostring(w) .. "s%s│%s%s"):format("\x1b[41;30m", ""       , "\x1b[0;33m", "\x1b[0m", d[i].pretty))
			else                       print(("%s%" .. tostring(w) ..   "d│%s%s"):format("\x1b[33m"   , d[i].nsnd,               "\x1b[0m", d[i].pretty))
			end

			if not d[i+1] or d[i+1].op ~= d[i].op then
				    if d[i].op == "+" then print(("%s%s%s"):format("\x1b[42m", sep, "\x1b[0m"))
				elseif d[i].op == "-" then print(("%s%s%s"):format("\x1b[41m", sep, "\x1b[0m"))
				end
			end

		elseif d[i + ctx + 1] and d[i + ctx + 1].op ~= "=" or d[i - ctx - 1] and d[i - ctx - 1].op ~= "=" then
			print(("%s%s│%s"):format("\x1b[33m", filler, "\x1b[0m"))

		end
	end
end

function mt.__index:drop(first, last)
	self:seek(last )
	self:seek(first)
	for _ = first, last do self:delete() end
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

-- Insert the given element after the current buffer position, making it the new buffer position.
function mt.__index:insert(elem)
	lib.assert(elem.text)

	local newdata = {curr = lib.dup(elem)}
	local newprev = lib.dup(self.data.curr)
	newdata.curr.prev  = newprev
	newdata.curr.next  = newprev.next
	newdata.curr.nprev = newprev.nprev + 1
	newdata.curr.nnext = newprev.nnext
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

	local printed = self:print_lines()

	lib.hook(self.state.hooks.print_pre, self, printed, lines)

	local w = #tostring(#printed)
	for i, l in ipairs(printed) do
		if lines[i] then
			io.stdout:write(("\x1b[%sm%" .. tostring(w) .. "d\x1b[0;33m│\x1b[0m%s\n"):format(i == self:pos() and "43;30" or "33", i, l.text))
		end
	end

	lib.hook(self.state.hooks.print_post, self, printed, lines)
end

function mt.__index:print_lines(data)
	data = data or self.data
	if data.printed then return data.printed end

	local prof = lib.profiler("print pipeline")

	prof:start("preparations")
	local ret = self:all(data)
	prof:stop()

	local function go(f)
		local info = debug.getinfo(f, "S")

		prof:start(info.short_src .. ":" .. info.linedefined .. "-" .. info.lastlinedefined)
		local ok, err = xpcall(f, lib.traceback, ret, self)
		prof:stop()

		if not ok then self.state:warn("print function failed: " .. info.short_src .. ":" .. info.linedefined .. "-" .. info.lastlinedefined .. ": " .. err) end
	end

	for _, f in ipairs(self.state.print.pre ) do go(f) end
	go(self.state.print.highlight)
	for _, f in ipairs(self.state.print.post) do go(f) end

	data.printed = ret

--	prof:print()

	return ret
end

function mt.__index:pos()
	return self.data.curr.nprev + 1
end

function mt.__index:save(path)
	if path then self:set_path(path) end

	lib.hook(self.state.hooks.save_pre, self)

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

	while n > self:pos() and self.data.curr.next do
		local newdata = {curr = lib.dup(self.data.curr.next)}
		local newprev =         lib.dup(self.data.curr     )

		newdata.curr.prev  = newprev
		newdata.curr.nprev = newprev.nprev + 1
		newdata.curr.hide  = nil
		newdata.printed    = self.data.printed

		newprev.next  = nil
		newprev.nnext = nil

		self.data = newdata
	end

	while n < self:pos() and self.data.curr.prev do
		local newdata = {curr = lib.dup(self.data.curr.prev)}
		local newnext =         lib.dup(self.data.curr     )

		newdata.curr.next  = newnext
		newdata.curr.nnext = newnext.nnext + 1
		newdata.curr.hide  = nil
		newdata.printed    = self.data.printed

		newnext.prev  = nil
		newnext.nprev = nil

		self.data = newdata
	end
end

function mt.__index:select(first, last)
	local oldfirst = self:sel_first()
	local oldlast  = self:sel_last ()
	local printed  = self.data.printed
	self:seek(last)
	self:map(
		function(n, l) l.hide = not (first <= n and n <= last) end,
		math.min(oldfirst, first),
		math.max(oldlast , last )
	)
	self.data.printed = printed
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

	self.path     = path
	self.modified = true
end

function mt.__index:undo(n)
	n = n or #self.history
	if not self.history[n] then lib.error("undo point not found") end

	self:diff_show(nil, self.data, self.history[n].data)

	while #self.history > n do table.remove(self.history) end
	local h = table.remove(self.history)
	for k, v in pairs(h) do self[k] = v end
end

function mt.__index:undo_point()
	local state = {
		data     = self.data,
		modified = self.modified,
		__cmd    = self.state.curr_cmd,
	}

	lib.hook(self.state.hooks.undo_point, self, state)
	table.insert(self.history, state)
	self.modified = true
end

return function(state, path)
	local ret = setmetatable({}, mt)
	ret.data = {curr = {nprev = -1, nnext = 0, cache = {}}}

	ret.state = state

	ret.history  = {}
	ret.modified = false

	ret.conf = {}
	for k, v in pairs(state.conf_defs) do ret.conf[k] = v.def end

	if path then
		ret:set_path(path)
		ret.modified = false
	end

	lib.hook(ret.state.hooks.load_pre, ret)

	if path then
		local s = lib.match{s = ret.path, choose = state.protocols,
			def = function(p) local h <close> = io.open(p, "r"); return h and h:read("a") or "" end,
			wrap = function(t, p) return t.read(p) end
		}

		for _, f in ipairs(ret.state.filters.read) do s = f(s, ret) end
		for l in s:gmatch("[^\n]*") do ret:insert({text = l}) end
		if ret.data.curr.text == "" then ret:delete() end
	end

	lib.hook(ret.state.hooks.load_post, ret)

	return ret
end
