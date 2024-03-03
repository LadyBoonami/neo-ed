local lib = require "neo-ed.lib"

return function(state)
	local copy_cmd, paste_cmd, paste_filter

	if os.getenv("WAYLAND_DISPLAY") ~= "" then
		copy_cmd  = "wl-copy"
		paste_cmd = "wl-paste --no-newline"

	elseif os.getenv("DISPLAY") ~= "" then
		copy_cmd  = "xclip -i -selection clipboard"
		paste_cmd = "xclip -o -selection clipboard"

	else
		return

	end

	table.insert(state.cmds.range_line, {"^C$", function(m, a, b)
		local h <close> = io.popen(copy_cmd, "w")
		state.curr:inspect(function(_, l) h:write(l.text, "\n") end, a, b)
	end, "copy lines"})

	table.insert(state.cmds.range_line, {"^X$", function(m, a, b)
		state.curr:change(function(buf)
			local h <close> = io.popen(copy_cmd, "w")
			buf:inspect(function(_, l) h:write(l.text, "\n") end, a, b)
			buf:drop(a, b)
		end)
	end, "cut lines"})

	table.insert(state.cmds.line, {"^V$", function(m, a)
		state.curr:change(function(buf)
			local h <close> = io.popen(paste_cmd, "r")
			local tmp = {}
			for l in h:lines() do print(l); table.insert(tmp, {text = l}) end
			buf:append(tmp, a)
		end)
	end, "paste lines after"})
end
