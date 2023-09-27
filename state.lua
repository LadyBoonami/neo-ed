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

function mt.__index:quit()
	for _, v in ipairs(self.files) do v:close() end
	os.exit(0)
end

return function()
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
		save_pre   = {},
		save_post  = {},
		undo_point = {},
	}

	ret.print = {
		pre       = {},
		highlight = function(lines) return lines end,
		post      = {},
	}

	return ret
end
