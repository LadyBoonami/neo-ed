local lib = require "neo-ed.lib"

local mt = {
	__index = {},
}

function mt.__index:drop_cache()
	if self.buffer then self.buffer:drop_cache() end
	if self.base   then self.base  :drop_cache() end
end

function mt.__index:load()
	if self.path then lib.hook(self.state.hooks.conf_load, self, self:get_path()) end
end

function mt.__index:get(k)
	local v = self.data[k]
	if self.data[k] then return self.data[k].value, self.data[k].origin end
	if self.base then return self.base:get(k) end
	if self.state.conf_defs[k] then return self.state.conf_defs[k].def, "default value" end
	lib.error("unknown config option: " .. k)
end

function mt.__index:get_path()
	if self.path then return self.path end
	if self.base then return self.base:get_path() end
end

function mt.__index:path_read()
	local path = assert(self:get_path(), "no path associated, cannot read file")

	lib.hook(self.state.hooks.read_pre, self, path)

	local h <close> = io.open(path, "r")
	local ret = lib.filter(self.state.filters.read, h:read("a"), self)

	lib.hook(self.state.hooks.read_post, self, path)

	return ret
end

function mt.__index:path_write(s)
	local path = assert(self:get_path(), "no path associated, cannot write file")

	lib.hook(self.state.hooks.write_pre, self, path)

	s = lib.filter(self.state.filters.write, s, self)
	local h <close> = io.open(path, "w")
	h:write(s)

	lib.hook(self.state.hooks.write_post, self)
end

function mt.__index:reset(k)
	local def = self.state.conf_defs[k]
	if not def then lib.error("unknown config option: " .. k) end

	if def.drop_cache then self:drop_cache() end

	if self.data[k] ~= nil then self.data[k] = nil; return end
	if self.base           then self.base:reset(k); return end
end

function mt.__index:set(k, v, origin)
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

	self.data[k] = {value = (def.on_set or function(_, v) return v end)(self, parse_val(v)), origin = origin or "unknown"}
	if def.drop_cache then self:drop_cache() end
end

function mt.__index:set_base(s)
	self.base = s
end

function mt.__index:set_buffer(b)
	self.buffer = b
end

function mt.__index:show(k)
	local v, origin = self:get(k)

	if type(v) == "boolean" then return v and "y" or "n", origin end
	if type(v) == "number"  then return tostring(v)     , origin end
	if type(v) == "string"  then return v               , origin end
	lib.error("cannot show setting of type " .. type(v))
end

return function(state, path)
	if path then
		path = state:path_resolve(path)

		local bypath = {}
		for _, v in ipairs(state.files) do
			if v.path then bypath[lib.realpath(v.path)] = true end
		end

		local canonical = lib.realpath(path)
		if bypath[canonical] then lib.error("already opened: " .. canonical) end
	end

	local ret = setmetatable({}, mt)

	ret.state = state
	ret.path  = path
	ret.data  = {}

	ret:load()
	return ret
end
