local m = {}

local posix = require "posix"

local rl = require "readline"
rl.set_readline_name("ned")
rl.set_options{
	auto_add  = false,
	histfile  = "",
	keeplines = 10,
}
rl.set_complete_function(function(text, from, to)
	rl.set_completion_append_character("")
	return {text:sub(from, to) .. "\t"}
end)

function m.hook(h, ...)
	for _, f in ipairs(h) do f(...) end
end

function m.match(s, tbl, ...)
	for _, v in ipairs(tbl) do
		local r = {s:match(v[1])}
		if r[1] then return v[2](..., table.unpack(r)) end
	end
	error("could not parse: " .. s)
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
		posix.sys.wait.wait(p)

		return table.concat(ret)

	end
end

function m.readline(prompt, ac)
	if ac then for i = #ac, 1, -1 do rl.add_history(ac[i]) end end
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

return m
