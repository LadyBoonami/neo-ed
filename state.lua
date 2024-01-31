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
	local sel_a = self.curr:sel_first()
	local sel_b = self.curr:sel_last ()
	local len   = self.curr:length   ()
	local pos   = self.curr:pos      ()

	local function file0(f, m)
		f(m)
	end

	local function pos1(f, m, a)
		a = a or pos
		if not (0 <= a and a <= len) then lib.error(a .. " not in range [0, " .. len .. "]") end
		f(m, a)
	end

	local function pos2(f, m, a, b)
		a = a or pos
		b = b or pos
		if not (0 <= a and a <= len) then lib.error(a .. " not in range [0, "           .. len .. "]") end
		if not (a <= b and b <= len) then lib.error(b .. " not in range [" .. a .. ", " .. len .. "]") end
		f(m, a, b)
	end

	local function local2(f, m, a, b)
		a = a or sel_a
		b = b or sel_b
		if not (0 <= a and a <= len) then lib.error(a .. " not in range [0, "           .. len .. "]") end
		if not (a <= b and b <= len) then lib.error(b .. " not in range [" .. a .. ", " .. len .. "]") end
		f(m, a, b)
	end

	local function global2(f, m, a, b)
		a = a or 1
		b = b or len
		if not (0 <= a and a <= len) then lib.error(a .. " not in range [0, "           .. len .. "]") end
		if not (a <= b and b <= len) then lib.error(b .. " not in range [" .. a .. ", " .. len .. "]") end
		f(m, a, b)
	end

	local function cmd2(a, b, s)
		local b_, s_ = lib.match{s = s, choose = self.cmds.addr.cont, def = function() end, args = {b}}
		if b_ then return cmd2(a, b_, s_) end

		if not lib.match{s = s, choose = self.cmds.range_global, def = function() return true end, wrap = global2, args = {a, b}} then return end
		if not lib.match{s = s, choose = self.cmds.range_local , def = function() return true end, wrap = local2 , args = {a, b}} then return end
		if not lib.match{s = s, choose = self.cmds.range_line  , def = function() return true end, wrap = pos2   , args = {a, b}} then return end

		lib.error("could not parse: " .. s)
	end

	local function cmd1(a, s)
		local a_, s_ = lib.match{s = s, choose = self.cmds.addr.cont, def = function() end, args = {a}}
		if a_ then return cmd1(a_, s_) end

		local s_ = s:match("^,(.*)$")
		if s_ then
			local b, s__ = lib.match{s = s_, choose = self.cmds.addr.prim, def = function() end}
			if b then return cmd2(a, b, s__) end
			return cmd2(a, nil, s_)
		end

		local s_ = s:match("^;(.*)$")
		if s_ then return cmd2(a, a, s_) end

		if not lib.match{s = s, choose = self.cmds.range_global, def = function() return true end, wrap = global2, args = {a, a}} then return end
		if not lib.match{s = s, choose = self.cmds.range_local , def = function() return true end, wrap = local2 , args = {a, a}} then return end
		if not lib.match{s = s, choose = self.cmds.range_line  , def = function() return true end, wrap = pos2   , args = {a, a}} then return end
		if not lib.match{s = s, choose = self.cmds.line        , def = function() return true end, wrap = pos1   , args = {a   }} then return end

		lib.error("could not parse: " .. s)
	end

	local function cmd0(s)
		local a, s_ = lib.match{s = s, choose = self.cmds.addr.prim, def = function() end}
		if a then return cmd1(a, s_) end

		if s:find("^,(.*)$") then return cmd1(nil, s) end

		if not lib.match{s = s, choose = self.cmds.file        , def = function() return true end, wrap = file0                         } then return end
		if not lib.match{s = s, choose = self.cmds.range_global, def = function() return true end, wrap = global2, args = {1    , len  }} then return end
		if not lib.match{s = s, choose = self.cmds.range_local , def = function() return true end, wrap = local2 , args = {sel_a, sel_b}} then return end
		if not lib.match{s = s, choose = self.cmds.range_line  , def = function() return true end, wrap = pos2   , args = {pos  , pos  }} then return end
		if not lib.match{s = s, choose = self.cmds.line        , def = function() return true end, wrap = pos1   , args = {pos         }} then return end

		lib.error("could not parse: " .. s)
	end

	self.curr_cmd = s
	cmd0(s)
	self.curr_cmd = nil
end

function mt.__index:load(path)
	local ret = require "neo-ed.buffer" (self, path)
	table.insert(self.files, ret)
	table.sort(self.files, function(a, b) return (a.path or "") < (b.path or "") end)
	for i, f in ipairs(self.files) do f.id = i end
	self.curr = ret
	return ret
end

function mt.__index:main()
	while true do
		print()
		local w = #tostring(#self.files)
		for i, f in ipairs(self.files) do
			print(("%s%" .. tostring(w) .. "d%s \x1b[33m%s\x1b[0m: \x1b[32m%s\x1b[0m mode, \x1b[32m%s\x1b[0m encoding%s, \x1b[34m%d\x1b[0m lines%s"):format(
				i == self.curr.id and "[" or " ",
				i,
				i == self.curr.id and "]" or " ",
				f.path,
				f.conf.mode,
				f.conf.charset,
				f.conf.crlf and " (DOS line endings)" or "",
				f:length(),
				f.modified and ", \x1b[35mmodified\x1b[0m" or ""
			))
		end
		if self.msg then
			print("\x1b[31m" .. self.msg .. "\x1b[0m")
			self.msg = nil
		end

		local ok, cmd = pcall(lib.readline, "> ", self.history)

		if not ok then
			self.msg = "failed to read input: " .. cmd
		elseif not cmd then
			local ok, status = xpcall(self.quit, lib.traceback, self)
			if not ok then self.msg = status end
		else
			if cmd ~= "" then table.insert(self.history, cmd) end
			local ok, status = xpcall(self.cmd, lib.traceback, self, cmd)
			if not ok then self.msg = status end
		end
	end
end

function mt.__index:path_hdl(s)
	local s_ = s:match("^!(.*)$")
	if s_ then return assert(io.popen(s_, "r")) end
	return assert(io.open(self:path_resolve(s), "r"))
end

function mt.__index:path_resolve(s)
	local s_ = s:match("^@(.*)$")
	if s_ then s = assert(self:pick_file(s_ ~= "" and s_ or nil)) end
	local h <close> = io.popen("realpath --relative-base=. " .. lib.shellesc(s), "r")
	return h:read("l")
end

function mt.__index:pick(choices)
	print("Select an option using the arrow keys.")
	return lib.readline(">> ", choices)
end

function mt.__index:pick_file(base)
	base = base or "."
	if posix.sys.stat.S_ISDIR(assert(posix.sys.stat.stat(base)).st_mode) == 0 then return base end
	local paths = {}
	for f in posix.dirent.files(base) do table.insert(paths, base .. "/" .. f) end
	table.sort(paths)
	return self:pick_file(self:pick(paths))
end

function mt.__index:quit(force)
	while self.files[1] do self.files[1]:close(force) end
end

return function(files)
	local ret = setmetatable({}, mt)

	ret.cmds = {
		addr = {
			prim = {},
			cont = {},
		},
		line = {},
		range_line = {},
		range_local = {},
		range_global = {},
		file = {},
	}

	ret.files = {}

	ret.filters = {
		read  = {},
		write = {},
	}

	ret.hooks = {
		close      = {},
		diff_pre   = {},
		diff_post  = {},
		input_post = {},
		load_pre   = {},
		load_post  = {},
		print_pre  = {},
		print_post = {},
		save_pre   = {},
		save_post  = {},
		undo_point = {},
	}

	ret.protocols = {}

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
			local ok, err = xpcall(f, lib.traceback, ret)
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

	ret.curr:print()

	return ret
end
