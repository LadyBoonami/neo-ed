local lib = require "neo-ed.lib"

return function(state)
	table.insert(state.cmds.addr.prim, {"^/(.-)/(.*)$", function(m)
		return (
			state.curr:scan(function(n, l) return l.text:find(m[1]) and n or nil end)
			or lib.error("pattern not found: /" .. m[1] .. "/")
		), m[2]
	end, "first matching line"})

	table.insert(state.cmds.addr.cont, {"^/(.-)/(.*)$", function(m, base)
		return (
			   state.curr:scan(function(n, l) return l.text:find(m[1]) and n or nil end, base + 1)
			or state.curr:scan(function(n, l) return l.text:find(m[1]) and n or nil end, nil, base)
			or lib.error("pattern not found: " .. tostring(base) .. "/" .. m[1] .. "/")
		), m[2]
	end, "first matching line after"})

	table.insert(state.cmds.addr.cont, {"^\\(.-)\\(.*)$", function(m, base)
		return (
			   state.curr:scan_r(function(n, l) return l.text:find(m[1]) and n or nil end, base - 1)
			or state.curr:scan_r(function(n, l) return l.text:find(m[1]) and n or nil end, nil, base)
			or lib.error("pattern not found: " .. tostring(base) .. "\\" .. m[1] .. "\\")
		), m[2]
	end, "last matching line before"})
end
