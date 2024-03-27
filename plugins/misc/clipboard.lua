local lib = require "neo-ed.lib"

return function(state)
	local copy_cmd, paste_cmd, paste_filter

	local function c(buf, m, a, b)
		local h <close> = io.popen(copy_cmd, "w")
		buf:inspect(function(_, l) h:write(l.text, "\n") end, a, b)
	end

	local function x(buf, m, a, b)
		buf:change(function(buf)
			local h <close> = io.popen(copy_cmd, "w")
			buf:inspect(function(_, l) h:write(l.text, "\n") end, a, b)
			buf:drop(a, b)
		end)
	end

	local function v(buf, m, a)
		buf:change(function(buf)
			local h <close> = io.popen(paste_cmd, "r")
			local tmp = {}
			for l in h:lines() do table.insert(tmp, {text = l}) end
			buf:append(tmp, a)
		end)
	end

	if os.getenv("WAYLAND_DISPLAY") ~= "" and lib.have_executable("wl-copy") and lib.have_executable("wl-paste") then
		copy_cmd  = "wl-copy"
		paste_cmd = "wl-paste --no-newline"

	elseif os.getenv("DISPLAY") ~= "" and lib.have_executable("xclip") then
		copy_cmd  = "xclip -i -selection clipboard"
		paste_cmd = "xclip -o -selection clipboard"

	else
		state:info("cannot use system clipboard, falling back to internal clipboard")

		c = function(buf, m, a, b)
			local tmp = {}
			buf:inspect(function(_, l) table.insert(tmp, l.text) end, a, b)
			buf.state.clipboard = tmp
		end

		x = function(buf, m, a, b)
			buf:change(function(buf)
				local tmp = {}
				buf:inspect(function(_, l) table.insert(tmp, l.text) end, a, b)
				buf:drop(a, b)
				buf.state.clipboard = tmp
			end)
		end

		v = function(buf, m, a)
			buf:change(function(buf)
				local tmp  = {}
				for _, l in ipairs(buf.state.clipboard or {}) do table.insert(tmp, {text = l}) end
				buf:append(tmp, a)
			end)
		end

	end

	table.insert(state.cmds.range_line, {"^C$", c, "copy lines"       })
	table.insert(state.cmds.range_line, {"^X$", x, "cut lines"        })
	table.insert(state.cmds.line      , {"^V$", v, "paste lines after"})
end
