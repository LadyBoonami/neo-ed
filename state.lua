local posix = require "posix"
local lib   = require "neo-ed.lib"

local mt = {
	__index = {},
}

function mt.__index:add_conf(name, data)
	lib.assert(data.type == "boolean" or data.type == "number" or data.type == "string", "invalid config data type for config key " .. name .. ": " .. data.type)
	lib.assert(type(data.def) == data.type, "data default does not match declared type")
	lib.assert(type(data.descr) == "string", "descr must have type string")

	self.conf_defs[name] = data
end

function mt.__index:check_executable(name, consequence)
	local ok = lib.have_executable(name)
	if not ok then self:warn("missing executable " .. name .. ", " .. consequence) end
	return ok
end

function mt.__index:closed()
	self.curr = self.files[self.curr.id] or self.files[self.curr.id - 1]
	if not self.curr then os.exit(0) end
	for i, v in ipairs(self.files) do v.id = i end
end

function mt.__index:err(s)
	table.insert(self.errors, s)
end

function mt.__index:get_conf_for(path)
	path = path and self:path_resolve(path)
	local ret = require "neo-ed.conf" (self, path)
	return ret
end

function mt.__index:info(s)
	table.insert(self.msgs, s)
end

function mt.__index:load(path)
	local ret = require "neo-ed.buffer" (self, path)
	table.insert(self.files, ret)
	table.sort(self.files, function(a, b) return (a:get_path() or "") < (b:get_path() or "") end)
	for i, f in ipairs(self.files) do f.id = i end
	self.curr = ret
	return ret
end

function mt.__index:main()
	while true do
		print()
		local w = #tostring(#self.files)
		for i, f in ipairs(self.files) do
			print(("%s%" .. tostring(w) .. "d%s \x1b[33m%s\x1b[0m: \x1b[34m%d\x1b[0m lines%s"):format(
				i == self.curr.id and "[" or " ",
				i,
				i == self.curr.id and "]" or " ",
				f:get_path(),
				f:length(),
				f.modified and ", \x1b[35mmodified\x1b[0m" or ""
			))
		end

		for _, v in ipairs(self.msgs    ) do print("\x1b[47;30m INFO \x1b[0m  "            .. v             ) end
		for _, v in ipairs(self.warnings) do print("\x1b[43;30m WARNING \x1b[0m  \x1b[33m" .. v .. "\x1b[0m") end
		for _, v in ipairs(self.errors  ) do print("\x1b[41;30m ERROR \x1b[0m  \x1b[31m"   .. v .. "\x1b[0m") end
		self.msgs     = {}
		self.warnings = {}
		self.errors   = {}

		local ok, cmd = pcall(lib.readline, "> ", self.history)

		if not ok then
			self.msg = "failed to read input: " .. cmd
		elseif not cmd then
			local ok, status = xpcall(self.quit, lib.traceback, self)
			if not ok then self:err(status) end
		else
			if cmd ~= "" then table.insert(self.history, cmd) end
			local ok, status = xpcall(self.curr.cmd, lib.traceback, self.curr, cmd)
			if not ok then self:err(status) end
		end
	end
end

function mt.__index:path_resolve(s)
	local s_ = s:match("^@(.*)$")
	if s_ then s = lib.assert(self:pick_file(s_ ~= "" and s_ or nil)) end
	local h <close> = io.popen("realpath --relative-base=. " .. lib.shellesc(s), "r")
	return h:read("l")
end

function mt.__index:pick(choices)
	print("Select an option using the arrow keys.")
	return lib.readline(">> ", choices)
end

function mt.__index:pick_file(base)
	base = base or "."
	if posix.sys.stat.S_ISDIR(lib.assert(posix.sys.stat.stat(base)).st_mode) == 0 then return base end
	local paths = {}
	for f in posix.dirent.files(base) do table.insert(paths, base .. "/" .. f) end
	table.sort(paths)
	return self:pick_file(self:pick(paths))
end

function mt.__index:quit(force)
	while self.files[1] do self.files[1]:close(force) end
end

function mt.__index:warn(s)
	table.insert(self.warnings, s)
end

return function(files)
	local ret = setmetatable({}, mt)

	ret.cmds = {
		addr = {
			prim  = {},
			cont  = {},
			range = {},
		},
		line         = {},
		range_line   = {},
		range_local  = {},
		range_global = {},
		file         = {},
	}

	ret.files = {}

	ret.filters = {
		read  = {},
		write = {},
	}

	ret.hooks = {
		-- buffer based
		close      = {}, -- triggered before closing a buffer
		input_post = {}, -- ???
		load_pre   = {}, -- triggered before loading buffer contents
		load_post  = {}, -- triggered after loading buffer contents
		path_post  = {}, -- triggered after setting or changing the path of a buffer, additionally receives the old name
		print_pre  = {}, -- triggered before printing code
		print_post = {}, -- triggered after printing code
		save_pre   = {}, -- triggered before saving a buffer to a file
		save_post  = {}, -- triggered after saving a buffer to a file
		undo_point = {}, -- triggered before inserting an undo point

		-- conf based
		conf_load  = {}, -- triggered when reading config for a path
		read_pre   = {}, -- triggered before reading a file
		read_post  = {}, -- triggered after reading a file
		write_pre  = {}, -- triggered before writing a file
		write_post = {}, -- triggered after writing a file
	}

	ret.print = {
		pre       = {},
		highlight = function(lines) return lines end,
		post      = {},
	}

	ret.history = {}

	ret.conf_defs = {}

	ret.msgs     = {}
	ret.errors   = {}
	ret.warnings = {}

	ret:add_conf("indent" , {type = "number" , def = 4      , descr = "indentation depth step (spaces)"           , drop_cache = true})
	ret:add_conf("tab2spc", {type = "boolean", def = false  , descr = "indent using spaces, convert tabs on entry", drop_cache = true})
	ret:add_conf("tabs"   , {type = "number" , def = 4      , descr = "tab width"                                 , drop_cache = true})

	local confdir = os.getenv("XDG_CONFIG_HOME")
	if not confdir and os.getenv("SUDO_USER") then
		local l = io.popen("getent passwd " .. lib.shellesc(os.getenv("SUDO_USER"))):read("l")
		confdir = l:match("^[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:([^:]*):") .. "/.config"
	end
	if not confdir then
		confdir = os.getenv("HOME") .. "/.config"
	end
	ret.config_dir = confdir .. "/neo-ed"
	ret.init_file = ret.config_dir .. "/init.lua"

	local ok, _, errno = posix.unistd.access(ret.init_file, "r")
	if not ok and errno == posix.errno.ENOENT then
		while true do
			local r = lib.readline("No initialization file found. Create file with defaults (y) or just use the defaults (n) ? (y/n) ")
			if r == "n" then
				require("neo-ed.plugins").def(ret)
				break
			else
				lib.assert(os.execute("mkdir -p " .. lib.shellesc(confdir .. "/neo-ed"), "cannot create config dir"))
				local h <close> = io.open(ret.init_file, "w")
				h:write('local state = ...', '\n')
				h:write('local plugins = require "neo-ed.plugins"', '\n')
				h:write('', '\n')
				h:write('-- enable default plugins', '\n')
				h:write('plugins.def(state)', '\n')
				print("Default initialization file has been created at " .. ret.init_file)
				lib.readline("Press Enter to continue ... ")
				ok = true
				break
			end
		end
	end

	if ok then
		local f, err = loadfile(ret.init_file)
		if not f then
			print("error loading init file: " .. err)
			lib.readline("Press Enter to continue ... ")
		else
			local ok, err = xpcall(f, lib.traceback, ret)
			if not ok then
				print("error running init file: " .. err)
				lib.readline("Press Enter to continue ... ")
			end
		end
	end

	if files and files[1] then
		for _, v in ipairs(files) do
			    if type(v) == "string" then ret:load(v     )
			elseif type(v) == "table"  then ret:load(v.path):cmd(v.cmd)
			end
		end
	else
		ret:load()
	end

	ret.curr:print()

	return ret
end
