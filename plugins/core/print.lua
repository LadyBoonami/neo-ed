return function(state)
	table.insert(state.cmds.range_local, {"^$", function(buf, m, a, b)
		local lines = {}
		for i = a, b do lines[i] = true end
		buf:print(lines)
	end, "print code listing (use the print pipeline)"})

	table.insert(state.cmds.range_line, {"^l$", function(buf, m, a, b)
		local lines = {}
		for i = a, b do lines[i] = true end
		buf:print(lines)
		buf:seek(b)
	end, "print code listing (use the print pipeline)"})

	table.insert(state.cmds.range_line, {"^n$", function(buf, m, a, b)
		buf:inspect(function(n, l) print(n, l.text) end, a, b)
		buf:seek(b)
	end, "print lines with line numbers"})

	table.insert(state.cmds.range_line, {"^p$", function(buf, m, a, b)
		buf:inspect(function(n, l) print(l.text) end, a, b)
		buf:seek(b)
	end, "print raw lines"})
end
