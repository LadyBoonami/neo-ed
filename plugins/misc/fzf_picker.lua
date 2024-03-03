local lib = require "neo-ed.lib"

return function(state)
	if not state:check_executable("fzf", "falling back to builtin picker") then return end

	state.pick = function(_, choices)
		return lib.pipe("fzf", table.concat(choices, "\n") .. "\n"):match("^[^\n]*")
	end
end
