local lib = require "neo-ed.lib"

return function(state)
	table.insert(state.cmds.addr.prim, {"^/(.-)/(.*)$", function(buf, m)
		return (
			buf:scan(function(n, l) return l.text:find(m[1]) and n or nil end)
			or lib.error("pattern not found: /" .. m[1] .. "/")
		), m[2]
	end, "first matching line"})

	table.insert(state.cmds.addr.cont, {"^/(.-)/(.*)$", function(buf, m, a)
		return (
			   buf:scan(function(n, l) return l.text:find(m[1]) and n or nil end, a + 1)
			or buf:scan(function(n, l) return l.text:find(m[1]) and n or nil end, nil, a)
			or lib.error("pattern not found: " .. tostring(a) .. "/" .. m[1] .. "/")
		), m[2]
	end, "first matching line after"})

	table.insert(state.cmds.addr.cont, {"^\\(.-)\\(.*)$", function(buf, m, a)
		return (
			   buf:scan_r(function(n, l) return l.text:find(m[1]) and n or nil end, a - 1)
			or buf:scan_r(function(n, l) return l.text:find(m[1]) and n or nil end, nil, a)
			or lib.error("pattern not found: " .. tostring(a) .. "\\" .. m[1] .. "\\")
		), m[2]
	end, "last matching line before"})
end
