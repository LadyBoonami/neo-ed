return function(state)
	table.insert(state.cmds.file, {":set +([^ =]+)=(.+)$", function(m)
		state.curr.conf:set(m[1], m[2])
	end, "set configuration value"})

	table.insert(state.cmds.file, {":set +([^ ]+)$", function(m)
		print(m[1] .. "=" .. state.curr.conf:get(m[1]))
	end, "print configuration value"})

	table.insert(state.cmds.file, {":set$", function()
		local t = {}
		for k in pairs(state.conf_defs) do table.insert(t, k) end
		table.sort(t)
		for _, k in ipairs(t) do
			print("# " .. state.conf_defs[k].descr)
			print(k .. "=" .. state.curr.conf:show(k))
			print()
		end
	end, "print all configuration values"})
end
