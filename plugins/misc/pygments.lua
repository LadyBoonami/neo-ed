local lib = require "neo-ed.lib"

return function(state)
	if not state:check_executable("pygmentize", "disabling syntax highlighting") then return end

	state:add_conf("pygments_mode", {type = "string", def = "", descr = "pygments highlighting mode"})

	state.print.highlight = function(lines, curr)
		if curr.conf.pygments_mode ~= "" then
			local a = 1
			local b = #lines
			while lines[a] and lines[a].text == "" do a = a + 1 end
			while lines[b] and lines[b].text == "" do b = b - 1 end
			if a <= b then
				local raw = {}

				for i = a, b do table.insert(raw, lines[i].text) end

				raw = lib.pipe("pygmentize -P style=native -l " .. lib.shellesc(curr.conf.pygments_mode), table.concat(raw, "\n"))

				local i = a
				for l in raw:gmatch("[^\n]*") do
					if i > b then break end
					lines[i].text = l
					i = i + 1
				end
			end
		end
	end

	local function guess(curr)
		local tmp = {}
		curr:map(function(_, l) table.insert(tmp, l.text) end)
		curr:conf_set("pygments_mode", lib.pipe("pygmentize -C", table.concat(tmp, "\n")):match("^[^\n]*"))
	end

	table.insert(state.hooks.load_post, function(curr)
		if curr.path and curr.conf.pygments_mode == "" then
			local h <close> = io.popen("pygmentize -N " .. lib.shellesc(curr.path), "r")
			curr:conf_set("pygments_mode", h:read("l"))
		end
		if curr:length() > 100 and (curr.conf.pygments_mode == "") then guess(curr) end
	end)

	table.insert(state.cmds.file, {"^:pygments_guess$", function() guess(state.curr) end, "guess file type from content"})
end
