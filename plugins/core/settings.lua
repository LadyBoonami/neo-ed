return function(state)
	table.insert(state.cmds.file, {":set +([^ =]+)=(.+)$", function(buf, m)
		buf.conf:set(m[1], m[2], ":set command")
	end, "set configuration value"})

	table.insert(state.cmds.file, {":set +([^ =]+)$", function(buf, m)
		print(m[1] .. "=" .. buf.conf:get(m[1]))
	end, "print configuration value"})

	table.insert(state.cmds.file, {":set$", function(buf)
		local t = {}
		for k in pairs(buf.state.conf_defs) do table.insert(t, k) end
		table.sort(t)
		for _, k in ipairs(t) do
			local v, origin = buf.conf:show(k)
			print(("%s# %s%s"):format("\x1b[36m", buf.state.conf_defs[k].descr, "\x1b[0m"))
			print(("%s# Current value origin: %s%s"):format("\x1b[36m", origin, "\x1b[0m"))
			print(("%s=%s%s%s"):format(
				k,
				origin == ":set command" and "\x1b[30;41m" or origin ~= "default value" and "\x1b[30;42m" or "",
				v,
				"\x1b[0m"
			))
			print()
		end
	end, "print all configuration values"})

	table.insert(state.cmds.file, {":reset +([^ =]+)$", function(buf, m)
		buf.conf:reset(m[1])
	end, "reset configuration value to file / default value"})
end
