local posix = require "posix"
local lib   = require "neo-ed.lib"

local mt = {
	__index = {},
}

function mt.__index:closed()
	self.curr = self.files[self.curr.id] or self.files[self.curr.id - 1]
	if not self.curr then os.exit(0) end
	for i, v in ipairs(self.files) do v.id = i end
end

function mt.__index:cmd(s)
	local function file0(f, m)
		f(m)
	end

	local function local1(f, m, a)
		a = a - #self.curr.prev
		assert(0 <= a and a <= #self.curr.curr, #self.curr.prev .. " <= " .. (#self.curr.prev + a) .. " <= " .. (#self.curr.prev + #self.curr.curr))
		f(m, a)
	end

	local function local2(f, m, a, b)
		a = a and a - #self.curr.prev or 1
		b = b and b - #self.curr.prev or #self.curr.curr
		assert(0 <= a and a <= #self.curr.curr,  #self.curr.prev      .. " <= " .. (#self.curr.prev + a) .. " <= " .. (#self.curr.prev + #self.curr.curr))
		assert(a <= b and b <= #self.curr.curr, (#self.curr.prev + a) .. " <= " .. (#self.curr.prev + b) .. " <= " .. (#self.curr.prev + #self.curr.curr))
		f(m, a, b)
	end

	local function global2(f, m, a, b)
		local n = #self.curr.prev + #self.curr.curr + #self.curr.next
		a = a or 1
		b = b or n
		assert(0 <= a and a <= n,     "0 <= " .. a .. " <= " .. n)
		assert(a <= b and b <= n, a .. " <= " .. b .. " <= " .. n)
		f(m, a, b)
	end

	local function cmd2(a, b, s)
		local b_, s_ = lib.match(s, self.cmds.addr.cont, function() end, nil, b)
		if b_ then return cmd2(a, b_, s_) end

		if not lib.match(s, self.cmds.range_global, function() return true end, global2, a, b) then return end
		if not lib.match(s, self.cmds.range_local, function() return true end, local2, a, b) then return end

		error("could not parse: " .. s)
	end

	local function cmd1(a, s)
		local a_, s_ = lib.match(s, self.cmds.addr.cont, function() end, nil, a)
		if a_ then return cmd1(a_, s_) end

		local s_ = s:match("^,(.*)$")
		if s_ then
			local b, s__ = lib.match(s_, self.cmds.addr.prim, function() end, nil)
			if b then return cmd2(a, b, s__) end
			return cmd2(a, nil, s_)
		end

		local s_ = s:match("^;(.*)$")
		if s_ then return cmd2(a, a, s_) end

		if not lib.match(s, self.cmds.range_global, function() return true end, global2, a, a) then return end
		if not lib.match(s, self.cmds.range_local, function() return true end, local2, a, a) then return end
		if not lib.match(s, self.cmds.line, function() return true end, local1, a) then return end

		error("could not parse: " .. s)
	end

	local function cmd0(s)
		local a, s_ = lib.match(s, self.cmds.addr.prim, function() end, nil)
		if a then return cmd1(a, s_) end

		if s:find("^,(.*)$") then return cmd1(nil, s) end

		if not lib.match(s, self.cmds.file, function() return true end, file0) then return end
		if not lib.match(s, self.cmds.range_global, function() return true end, global2, 1, #self.curr.prev + #self.curr.curr + #self.curr.next) then return end
		if not lib.match(s, self.cmds.range_local, function() return true end, local2, #self.curr.prev + 1, #self.curr.prev + #self.curr.curr) then return end
		if not lib.match(s, self.cmds.line, function() return true end, local1, #self.curr.prev + #self.curr.curr) then return end

		error("could not parse: " .. s)
	end

	return cmd0(s)
end

function mt.__index:load(path)
	local ret = require "neo-ed.buffer" (self, path)
	table.insert(self.files, ret)
	ret.id = #self.files
	self.curr = ret
	return ret
end

function mt.__index:main()
	while true do
		if not self.skip_print then
			lib.hook(self.hooks.print_pre, self)
			local lines = {}
			for i = #self.curr.prev + 1, #self.curr.prev + #self.curr.curr do lines[i] = true end
			self.curr:print(lines)
			lib.hook(self.hooks.print_post, self)

			print()
			local w = #tostring(#self.files)
			for i, f in ipairs(self.files) do
				print(("%s%" .. tostring(w) .. "d%s \x1b[33m%s\x1b[0m: \x1b[32m%s\x1b[0m mode, \x1b[34m%d\x1b[0m lines%s"):format(
					i == self.curr.id and "[" or " ",
					i,
					i == self.curr.id and "]" or " ",
					f.path,
					f.conf.ext.mode,
					#f.prev + #f.curr + #f.next,
					f.modified and ", \x1b[35mmodified\x1b[0m" or ""
				))
			end
		end
		self.skip_print = nil

		if self.msg then
			print("\x1b[31m" .. self.msg .. "\x1b[0m")
			self.msg = nil
		end

		local ok, cmd = pcall(lib.readline, "> ", self.history)

		if not ok then
			self.msg = "failed to read input: " .. cmd
		elseif not cmd then self:quit()
		elseif cmd == "" then ;
		else
			table.insert(self.history, cmd)
			local ok, status = xpcall(self.cmd, debug.traceback, self, cmd)
			if not ok then
				self.msg = "command failed: " .. status
			end
		end
	end
end

function mt.__index:quit(force)
	for _, v in ipairs(self.files) do v:close(force) end
	os.exit(0)
end

return function(files)
	local ret = setmetatable({}, mt)

	ret.cmds = {
		addr = {
			prim = {},
			cont = {},
		},
		line = {},
		range_local = {},
		range_global = {},
		file = {},
	}

	ret.files = {}

	ret.hooks = {
		close      = {},
		load       = {},
		print_pre  = {},
		print_post = {},
		save_pre   = {},
		save_post  = {},
		undo_point = {},
	}

	ret.print = {
		pre       = {},
		highlight = function(lines) return lines end,
		post      = {},
	}

	ret.history = {}

	local confdir = os.getenv("XDG_CONFIG_HOME")
	if not confdir and os.getenv("SUDO_USER") then
		local l = io.popen("getent passwd " .. lib.shellesc(os.getenv("SUDO_USER"))):read("l")
		confdir = l:match("^[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:([^:]*):") .. "/.config"
	end
	if not confdir then
		confdir = os.getenv("HOME") .. "/.config"
	end
	ret.config_file = confdir .. "/neo-ed/config.lua"

	local ok, _, errno = posix.unistd.access(ret.config_file, "r")
	if not ok and errno == posix.errno.ENOENT then
		while true do
			local r = lib.readline("No configuration file found. Create a default? (y/n) ")
			if r == "n" then
				require("neo-ed.plugins").core(ret)
				break
			else
				assert(os.execute("mkdir -p " .. lib.shellesc(confdir .. "/neo-ed"), "cannot create config dir"))
				local h <close> = io.open(ret.config_file, "w")
				h:write((require("neo-ed.default_config")))
				print("Default configuration file has been created at " .. ret.config_file)
				print("Use command :config to edit it anytime, then :reload to apply changes.")
				lib.readline("Press Enter to continue ... ")
				ok = true
				break
			end
		end
	end

	if ok then
		local f, err = loadfile(ret.config_file)
		if not f then
			print("error loading config file: " .. err)
			lib.readline("Press Enter to continue ... ")
		else
			local ok, err = xpcall(f, debug.traceback, ret)
			if not ok then
				print("error running config file: " .. err)
				lib.readline("Press Enter to continue ... ")
			end
		end
	end

	if files and files[1] then
		for _, v in ipairs(files) do
			    if type(v) == "string" then ret:load(v     )
			elseif type(v) == "table"  then ret:load(v.path); ret:cmd(v.cmd)
			end
		end
	else
		ret:load()
	end

	return ret
end
