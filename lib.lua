local m = {}

local posix = require "posix"

m.profile_hooks = false
m.stacktraces = false

local rl = require "readline"
rl.set_readline_name("ned")
rl.set_options{
	auto_add   = false,
	completion = false,
	histfile   = "",
	keeplines  = 10,
}

function m.dup(t)
	local ret = {}
	for k, v in pairs(t) do ret[k] = v end
	return ret
end

function m.error(msg)
	error(msg, m.stacktraces and 2 or 0)
end

function m.find_nth(s, pat, n)
	local ret = 0
	for i = 1, n do
		ret = s:find(pat, ret + 1)
		if not ret then return nil end
	end
	return ret
end

function m.hook(h, ...)
	if m.trace then
		local info = debug.getinfo(2, "S")
		print("Hook " .. info.short_src .. ":" .. info.linedefined .. "-" .. info.lastlinedefined)
	end

	for _, f in ipairs(h) do
		local before = posix.sys.time.gettimeofday()
		local ok, msg = xpcall(f, m.traceback, ...)
		local after = posix.sys.time.gettimeofday()
		if not ok then print("hook failed: " .. msg) end

		if m.profile_hooks then
			local info = debug.getinfo(f, "S")
			local delta = (after.tv_sec + after.tv_usec / 1000000) - (before.tv_sec + before.tv_usec / 1000000)
			print("    " .. info.short_src .. ":" .. info.linedefined .. "-" .. info.lastlinedefined .. ":" .. delta)
		end
	end
end

function m.id(...)
	return ...
end

function m.match(s, tbl, def, wrap, ...)
	def  = def  or function(s) m.error("could not parse: " .. s) end
	wrap = wrap or function(f, ...) return f(...) end

	for _, v in ipairs(tbl) do
		local r = {s:match(v[1])}
		if r[1] then return wrap(v[2], r, ...) end
	end
	return def(s, ...)
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

		assert(pu.execp("/bin/sh", {"-c", cmd}))

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
