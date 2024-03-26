local lib = require "neo-ed.lib"

return function(state)
	table.insert(state.cmds.line, {"^F(%d*)$", function(buf, m, a)
		local w = nil
		if m[1] ~= "" then w = 2*tonumber(m[1]) end
		if not w and os.execute("which tput >/dev/null 2>&1") then w = tonumber(lib.pipe("tput lines", "")) - 3 - #buf.state.files end
		if not w then w = 20 end
		buf:select(math.max(1, a - (w // 2)), math.min(a + (w - w//2), buf:length()))
		buf:seek(a)
		buf:print()
	end, "mark line as current and focus lines around"})

	table.insert(state.cmds.range_global, {"^S$", function(buf, m, a, b)
		buf:select(a, b)
		buf:print()
	end, "select lines"})
end
