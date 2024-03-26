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
	if v == nil then
		if self.base then
			v = self.base:get(k)
		else
			v = self.state.conf_defs[k].def
		end
	end
	lib.assert(v ~= nil, "unknown config option: " .. k)
	return v
end

function mt.__index:get_path()
	if self.path then return self.path end
	if self.base then return self.base:get_path() end
end

function mt.__index:path_read()
	local path = assert(self:get_path(), "no path associated, cannot read file")

	lib.hook(self.state.hooks.read_pre, self, path)

	local h <close> = io.open(path, "r")
	local chunks = {}
	while h do
		local chunk = h:read("L")
		if not chunk then break end
		table.insert(chunks, chunk)
	end
	for _, f in ipairs(self.state.filters.read) do chunks = f(chunks, self) end

	lib.hook(self.state.hooks.read_post, self, path)

	return table.concat(chunks)
end

function mt.__index:path_write(s)
	local path = assert(self:get_path(), "no path associated, cannot write file")

	lib.hook(self.state.hooks.write_pre, self, path)

	local chunks = {}
	for chunk in s:gmatch("[^\n]*\n") do table.insert(chunks, chunk) end
	for i = #self.state.filters.write, 1, -1 do chunks = self.state.filters.write[i](chunks, self) end
	local h <close> = io.open(path, "w")
	for _, v in ipairs(chunks) do h:write(v) end

	lib.hook(self.state.hooks.write_post, self)
end

function mt.__index:set(k, v)
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

	self.data[k] = (def.on_set or function(_, v) return v end)(self, parse_val(v))
	if def.drop_cache then self:drop_cache() end
end

function mt.__index:set_base(s)
	self.base = s
end

function mt.__index:set_buffer(b)
	self.buffer = b
end

function mt.__index:show(k)
	local v = self:get(k)

	if type(v) == "boolean" then return v and "y" or "n" end
	if type(v) == "number"  then return tostring(v)      end
	if type(v) == "string"  then return v                end
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
