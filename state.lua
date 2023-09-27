local lib = require "ned.lib"

local mt = {
	__index = {},
}

function mt.__index:closed()
	self.curr = self.files[self.curr.id] or self.files[self.curr.id - 1]
	if not self.curr then os.exit(0) end
	for i, v in ipairs(self.files) do v.id = i end
end

function mt.__index:cmd(s, ctx)
	ctx = ctx or {}
	local cmds = {}
	for _, v in ipairs(self.cmds.fst      ) do table.insert(cmds, v) end
	for _, v in ipairs(self.cmds.fst_post ) do table.insert(cmds, v) end
	for _, v in ipairs(self.cmds.snd      ) do table.insert(cmds, v) end
	for _, v in ipairs(self.cmds.snd_post ) do table.insert(cmds, v) end
	for _, v in ipairs(self.cmds.main     ) do table.insert(cmds, v) end
	for _, v in ipairs(self.cmds.main_post) do table.insert(cmds, v) end
	lib.match(s, cmds, ctx)
end

function mt.__index:load(path)
	local ret = require "ned.buffer" (self, path)
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
					f.mode,
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

		local ok, cmd = pcall(lib.readline, "> ")

		if not ok then
			self.msg = "failed to read input: " .. cmd
		elseif not cmd then self:quit()
		elseif cmd == "" then ;
		else
			local ok, status = xpcall(self.cmd, debug.traceback, self, cmd)
			if not ok then
				self.msg = "command failed: " .. status
			end
		end
	end
end

function mt.__index:quit()
	for _, v in ipairs(self.files) do v:close() end
	os.exit(0)
end

return function(files)
	local ret = setmetatable({}, mt)

	ret.cmds = {
		fst       = {},
		fst_post  = {},
		snd       = {},
		snd_post  = {},
		main      = {},
		main_post = {},
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

	local confdir = os.getenv("XDG_CONFIG_HOME")
	if not confdir and os.getenv("SUDO_USER") then
		local l = io.popen("getent passwd " .. lib.shellesc(os.getenv("SUDO_USER"))):read("l")
		confdir = l:match("^[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:([^:]*):") .. "/.config"
	end
	if not confdir then
		confdir = os.getenv("HOME") .. "/.config"
	end
	ret.config_file = confdir .. "/ned/config.lua"

	local f, err = loadfile(ret.config_file)
	if not f then
		print("error loading config file: " .. err)
		lib.readline("")
	else
		local ok, err = xpcall(f, debug.traceback, ret)
		if not ok then
			print("error running config file: " .. err)
			lib.readline("")
		end
	end

	if files then
		for _, v in ipairs(files) do
			    if type(v) == "string" then ret:load(v     )
			elseif type(v) == "table"  then ret:load(v.name)
			end
		end
	else
		ret:load()
	end

	return ret
end
