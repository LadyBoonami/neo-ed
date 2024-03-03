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

	state:add_conf("autocmd_load_post", {type = "string", def = "", descr = "command to run after loading a file"})
	state:add_conf("autocmd_save_pre" , {type = "string", def = "", descr = "command to run before saving a file"})
	state:add_conf("autocmd_save_post", {type = "string", def = "", descr = "command to run after saving a file" })

	table.insert(state.hooks.load_post, function(b)
		local cmd = validate(b.conf.autocmd_load_post)
		if cmd then b.state:cmd(cmd) end
	end)

	table.insert(state.hooks.save_pre, function(b)
		local cmd = validate(b.conf.autocmd_save_pre)
		if cmd then b.state:cmd(cmd) end
	end)

	table.insert(state.hooks.save_post, function(b)
		local cmd = validate(b.conf.autocmd_save_post)
		if cmd then b.state:cmd(cmd) end
	end)
end
