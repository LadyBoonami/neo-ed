local lib = require "neo-ed.lib"

return function(state)
	local function cmdline(buf, s)
		return s:gsub("%f[%%]%%", buf:get_path() or function() lib.error("cannot substitute path for unnamed file") end):gsub("%%%%", "%%")
	end

	table.insert(state.cmds.file, {"^!(.+)$", function(buf, m)
		local ok, how, no = os.execute(cmdline(buf, m[1]))
		if not ok then print(how .. " " .. no) end
	end, "execute shell command"})

	table.insert(state.cmds.range_line, {"^|(.+)$", function(buf, m, a, b)
		buf:change(function(buf)
			local tmp = {}
			buf:inspect(function(_, l) table.insert(tmp, l.text) end, a, b)
			table.insert(tmp, "")
			tmp = table.concat(tmp, "\n")
			local ret = {}
			for l in lib.pipe(cmdline(buf, m[1]), tmp):gmatch("[^\n]*") do table.insert(ret, {text = l}) end
			table.remove(ret)
			buf:drop(a, b)
			buf:append(ret, a - 1)
		end)
	end, "pipe lines through shell command"})
end
