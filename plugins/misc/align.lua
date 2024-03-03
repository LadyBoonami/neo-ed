local lib = require "neo-ed.lib"

return function(state)
	table.insert(state.cmds.range_local, {"^:align *(%p)(.-)%1(%d*)$", function(m, a, b)
		local n = tonumber(m[3]) or 1
		state.curr:change(function(buf)
			buf:seek(b)
			local max = 0
			buf:inspect(function(_, l)
				local bytes = lib.find_nth(l.text, m[2], n)
				if bytes then max = math.max(max, utf8.len(l.text:sub(1, bytes - 1))) end
			end, a, b)
			buf:map(function(_, l)
				local bytes = lib.find_nth(l.text, m[2], n)
				if bytes then
					l.text = l.text:sub(1, bytes - 1)
						.. (" "):rep(max - utf8.len(l.text:sub(1, bytes - 1)))
						.. l.text:sub(bytes)
				end
			end, a, b)
		end)
	end, "align matched pattern by padding with spaces"})
end
