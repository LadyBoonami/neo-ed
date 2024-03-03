local lib = require "neo-ed.lib"

return function(state)
	if not state:check_executable("ssh", "disabling ssh integration") then return end

	table.insert(state.protocols, {"^ssh://([^:/]+):?(%d*)(/.*)$", {
		read = function(m)
			local p = m[2] == "" and "22" or m[2]
			local h <close> = io.popen("ssh -p " .. p .. " " .. lib.shellesc(m[1]) .. " cat " .. lib.shellesc(m[3]), "r")
			return h:read("a")
		end,
		write = function(m, s)
			local p = m[2] == "" and "22" or m[2]
			local h <close> = io.popen("ssh -p " .. p .. " " .. lib.shellesc(m[1]) .. " tee " .. lib.shellesc(m[3]) .. " >/dev/null", "w")
			h:write(s)
		end,
	}})
end
