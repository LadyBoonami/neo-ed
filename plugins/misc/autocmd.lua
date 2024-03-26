local lib = require "neo-ed.lib"

return function(state)
	local use = {}
	local function validate(s)
		if s == "" then return nil end
		if use[s] == nil then
			local answer
			repeat
				print("Enable hook? " .. s)
				answer = lib.readline("(y/n) ")
			until answer:lower() == "y" or answer:lower() == "n"
			use[s] = answer:lower() == "y"
		end
		return use[s] and s or nil
	end

	local function add_autocmd(hook)
		state:add_conf("autocmd_" .. hook, {type = "string", def = "", descr = "command to run in the " .. hook .. " hook"})
		table.insert(state.hooks[hook], function(b)
			local cmd = validate(b.conf:get("autocmd_" .. hook))
			if cmd then b.state:cmd(cmd) end
		end)
	end

	add_autocmd "close"
	add_autocmd "print_pre"
	add_autocmd "print_post"
	add_autocmd "save_pre"
	add_autocmd "save_post"
end
