local m = {}

local posix = require "posix"

m.profile_hooks = false
m.trace = false

local rl = require "readline"
rl.set_readline_name("ned")
rl.set_options{
	auto_add   = false,
	completion = false,
	histfile   = "",
	keeplines  = 10,
}

function m.assert(pred, msg)
	if not pred then m.error(msg) end
	return pred
end

function m.dup(t, n)
	n = n or 1

	local ret = {}
	for k, v in pairs(t) do
		if type(v) == "table" and n > 1 then ret[k] = m.dup(v, n - 1) else ret[k] = v end
	end
	return ret
end

function m.error(msg)
	error(msg, m.trace and 2 or 0)
end

function m.filter(tbl, val, ...)
	local prof = m.profiler("filter " .. tbl.name)

	for _, f in ipairs(tbl) do
		local info = debug.getinfo(f, "S")
		local curr = ("%s:%s-%s"):format(info.short_src, info.linedefined, info.lastlinedefined)

		prof:start(curr)
		local ok, msg = xpcall(f, m.traceback, val, ...)
		prof:stop()
		if ok then val = msg else print(("%s failed: %s"):format(curr, msg)) end
	end

	if m.trace then prof:print() end
	return val
end

function m.find_nth(s, pat, n)
	local ret = 0
	for i = 1, n do
		ret = s:find(pat, ret + 1)
		if not ret then return nil end
	end
	return ret
end

function m.have_executable(name)
	return os.execute("which " .. m.shellesc(name) .. " >/dev/null 2>&1")
end

function m.hook(tbl, ...)
	local prof = m.profiler("hook " .. tbl.name)

	for _, f in ipairs(tbl) do
		local info = debug.getinfo(f, "S")
		local curr = ("%s:%s-%s"):format(info.short_src, info.linedefined, info.lastlinedefined)

		prof:start(curr)
		local ok, msg = xpcall(f, m.traceback, ...)
		prof:stop()
		if not ok then print(("%s failed: %s"):format(curr, msg)) end
	end

	if m.trace then prof:print() end
end

function m.id(...)
	return ...
end

function m.match(args)
	args.args = args.args or {}
	args.def  = args.def  or function(s) m.error("could not parse: " .. s) end
	args.wrap = args.wrap or function(f, ...) return f(...) end

	for _, v in ipairs(args.choose) do
		local r = {args.s:match(v[1])}
		if r[1] then return args.wrap(v[2], r, table.unpack(args.args)) end
	end
	return args.def(args.s, table.unpack(args.args))
end

local space_lookup = {" "}
for i = 2, 10 do space_lookup[i] = space_lookup[i - 1] .. space_lookup[i - 1] end

function m.pad(s, l, padRight)
	for i = #space_lookup, 1, -1 do
		if utf8.len(s) + utf8.len(space_lookup[i]) <= l then
			s = padRight and s .. space_lookup[i] or space_lookup[i] .. s
		end
	end
	return s
end

function m.patesc(s)
	return s:gsub("[%^$()%%.[%]*+%-?]", "%%%1")
end

function m.pipe(cmd, stdin)
	local pu = posix.unistd

	local p2c_r, p2c_w = pu.pipe()
	local c2p_r, c2p_w = pu.pipe()

	local p = pu.fork()
	if p == 0 then
		pu.close(p2c_w)
		pu.close(c2p_r)

		pu.dup2(p2c_r, 0)
		pu.dup2(c2p_w, 1)

		pu.close(p2c_r)
		pu.close(c2p_w)

		m.assert(pu.execp("/bin/sh", {"-c", cmd}))

	else
		pu.close(p2c_r)
		pu.close(c2p_w)

		pu.write(p2c_w, stdin)
		pu.close(p2c_w)

		local ret = {}
		while true do
			local s = pu.read(c2p_r, 1024)
			if type(s) ~= "string" or s == "" then break end
			table.insert(ret, s)
		end

		pu.close(c2p_r)
		local _, status, id = posix.sys.wait.wait(p)
		if status ~= "exited" or id ~= 0 then m.error("command " .. status .. " " .. tostring(id)) end

		return table.concat(ret)

	end
end

local profmt = {
	__index = {
		start = function(self, name)
			table.insert(self.steps, {name = name, start = os.clock()})
		end,
		stop = function(self)
			self.steps[#self.steps].stop = os.clock()
		end,
		print = function(self)
			print("Sequence for " .. self.name .. ":")
			for _, v in ipairs(self.steps) do
				print(("%7.1f ms  %s"):format((v.stop - v.start) * 1000, v.name))
			end
			print(("%7.1f ms  %s"):format((os.clock() - self.created) * 1000, "total"))
		end,
	}
}
function m.profiler(name)
	return setmetatable({name = name, steps = {}, created = os.clock()}, profmt)
end

function m.print_doc(s)
	print((s
		:gsub("\t", "")
		:gsub("\n$", "")
		:gsub("%*%*([^\n]-)%*%*", "\x1b[1m%1\x1b[0m")
		:gsub("__([^\n]-)__", "\x1b[4m%1\x1b[0m")
		:gsub("`([^\n]-)`", "\x1b[33m%1\x1b[0m")
	))
end

function m.readline(prompt, ac)
	if not posix.unistd.isatty(0) then
		local r = io.stdin:read("l")
		print(prompt .. (r or ""))
		return r
	end

	if ac then for _, v in ipairs(ac) do rl.add_history(v) end end
	local r = rl.readline(prompt)
	if r == "" then print("") end
	return r
end

function m.realpath(path)
	local h <close> = io.popen("realpath --canonicalize-missing " .. m.shellesc(path))
	return h:read("l")
end

function m.shellesc(s)
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

function m.traceback(s)
	if m.stacktraces then return debug.traceback(s, 2) else return s end
end

return m
