return function(state)
	table.insert(state.print.post, 1, function(lines)
		for i, l in ipairs(lines) do lines[i].text = l.text .. "\x1b[34m·\x1b[0m" end
	end)
end
