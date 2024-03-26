local lib = require "neo-ed.lib"

return function(state)
	if not state:check_executable("editorconfig", "disabling editorconfig integration") then return end

	local function from_editorconfig(from)
		local ret = {}

		local t = {
			charset                  = function(v) return "charset", v                                   end,
			end_of_line              = function(v) return "crlf", v:lower() == "crlf" and "y" or "n"     end,
			indent_size              = function( ) return ""                                             end,
			indent_style             = function(v) return "tab2spc", v:lower() == "space" and "y" or "n" end,
			tab_width                = function(v) return "tabs", tostring(tonumber(v) or 4)             end,
			trim_trailing_whitespace = function(v) return "trim", v:lower() == "true" and "y" or "n"     end,
		}

		for k, v in pairs(from) do
			local k_, v_
			k_ = k:match("^ned_(.*)$")
			if k_ then v_ = v end
			if not k_ and t[k] then k_, v_ = t[k](v) end
			if k_ then ret[k_] = v_ end
		end

		if from.indent_size then
			ret.indent = (from.indent_size:lower() == "tab" and (from.tab_width or ret.tabs or "4")) or from.indent_size or "4"
		end

		return ret
	end

	local function load_editorconfig_for(conf, path)
		local h <close> = io.popen("editorconfig " .. lib.shellesc(lib.realpath(path)))
		local data = {}
		for l in h:lines() do
			local k, v = l:match("^([^=]+)=(.*)$")
			if k then data[k] = v end
		end

		for k, v in pairs(from_editorconfig(data)) do
			local ok, msg = xpcall(conf.set, lib.traceback, conf, k, v)
			if not ok then state:warn("ignoring editorconfig key " .. k .. ": " .. msg) end
		end
	end

	table.insert(state.hooks.conf_load, function(conf, path)
		load_editorconfig_for(conf, conf.state.config_dir .. "/global")
		local suf = path:match("[^/.]+(%.[^/]+)$")
		if suf then load_editorconfig_for(conf, conf.state.config_dir .. "/global" .. suf) end
		load_editorconfig_for(conf, path)
	end)

	table.insert(state.cmds.file, {"^h editorconfig$", function()
		lib.print_doc [[
			Patterns:
			  `*`: any string of characters, except `/`
			  `**`: any string of characters
			  `?`: any single character, except `/`
			  `[`__seq__`]`: any single character in __seq__
			  `[!`__seq__`]`: any single character not in __seq__
			  `{`__s1__`,`__s2__`,`__s3__`}`: any of the strings given
			  `{`__num1__`..`__num2__`}`: any integer numbers between __num1__ and __num2__ (can be negative)
			  `\`: escape other character

			Keys:
			  `indent_style`: set to `tab` or `space` to use hard or soft tabs (i.e. tabs are replaced by spaces when entered)
			  `indent_size`: set to a whole number defining the number of columns per indentation level and the width of soft tabs, or `tab` to default to the setting of `tab_width`
			  `tab_width`: set to a whole number defining the width of a tab character, defaults to `indent_size`
			  `end_of_line`: set to `lf` or `crlf` to control how line breaks are saved
			  `charset`: set to `latin1`, `utf-8`, `utf-16be` or `utf-16le` to control input and output character set
			  `trim_trailing_whitespace`: set to `true` to remove trailing whitespace characters
			  `insert_final_newline`: set to `true` to save the file with a final newline
		]]
	end, "show editorconfig help"})

	table.insert(state.cmds.file, {"^:econf global", function()
		state:load(state.config_dir .. "/.editorconfig"):print()
	end, "open global editorconfig file"})
end
