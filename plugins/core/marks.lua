local lib = require "neo-ed.lib"

return function(state)
	table.insert(state.cmds.line, {"^k(%l?)$", function(m, a)
		state.curr:map(function(_, l) l.mark = m[1] ~= "" and m[1] or nil end, a, a)
	end, "mark line"})

	table.insert(state.cmds.addr.prim, {"^'(%l)(.*)$", function(m)
		return (
			state.curr:scan(function(n, l) return l.mark == m[1] and n or nil end)
			or lib.error("mark not found: '" .. m[1])
		), m[2]
	end, "first line with mark"})

	table.insert(state.cmds.addr.cont, {"^'(%l)(.*)$", function(m, base)
		return (
			state.curr:scan(function(n, l) return l.mark == m[1] and n or nil end, base + 1)
			or lib.error("mark not found: " .. tostring(base) .. "'" .. m[1])
		), m[2]
	end, "first line with mark after"})

	table.insert(state.cmds.addr.cont, {"^`(%l)(.*)$", function(m, base)
		return (
			state.curr:scan_r(function(n, l) return l.mark == m[1] and n or nil end, base - 1)
			or lib.error("mark not found: " .. tostring(base) .. "`" .. m[1])
		), m[2]
	end, "last line with mark before"})

	table.insert(state.print.post, function(lines)
		for _, l in ipairs(lines) do
			if l.mark then l.text = l.text .. " \x1b[43;30m " .. l.mark .. " \x1b[0m" end
		end
	end)
end
