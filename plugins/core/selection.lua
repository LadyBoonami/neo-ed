local lib = require "neo-ed.lib"

return function(state)
	table.insert(state.cmds.line, {"^F(%d*)$", function(m, a)
		local w = nil
		if m[1] ~= "" then w = 2*tonumber(m[1]) end
		if not w and os.execute("which tput >/dev/null 2>&1") then w = tonumber(lib.pipe("tput lines", "")) - 3 - #state.files end
		if not w then w = 20 end
		state.curr:select(math.max(1, a - (w // 2)), math.min(a + (w - w//2), state.curr:length()))
		state.curr:seek(a)
		state.curr:print()
	end, "mark line as current and focus lines around"})

	table.insert(state.cmds.range_global, {"^S$", function(m, a, b)
		state.curr:select(a, b)
		state.curr:print()
	end, "select lines"})
end
