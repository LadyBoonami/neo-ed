return function(state)
	table.insert(state.cmds.range_local, {"^$", function(m, a, b)
		local lines = {}
		for i = a, b do lines[i] = true end
		state.curr:print(lines)
	end, "print code listing (use the print pipeline)"})

	table.insert(state.cmds.range_line, {"^l$", function(m, a, b)
		local lines = {}
		for i = a, b do lines[i] = true end
		state.curr:print(lines)
		state.curr:seek(b)
	end, "print code listing (use the print pipeline)"})

	table.insert(state.cmds.range_line, {"^n$", function(m, a, b)
		state.curr:inspect(function(n, l) print(n, l.text) end, a, b)
		state.curr:seek(b)
	end, "print lines with line numbers"})

	table.insert(state.cmds.range_line, {"^p$", function(m, a, b)
		state.curr:inspect(function(n, l) print(l.text) end, a, b)
		state.curr:seek(b)
	end, "print raw lines"})
end
