local lib = require "neo-ed.lib"

return function(state)
	table.insert(state.cmds.file, {"^h$", function()
		local function f(t, addr)
			for i, v in ipairs(t) do print(("    %s%-30s %s\x1b[0m"):format(i % 2 == 0 and "\x1b[34m" or "\x1b[36m", v[1]:gsub("^%^", ""):gsub(addr and "%(%.%*%)%$$" or "%$$", ""), v[3])) end
		end

		print("Line addressing:")
		f(state.cmds.addr.prim, true)

		print("Address modifiers:")
		f(state.cmds.addr.cont, true)

		print("Address range shorthands:")
		f(state.cmds.addr.range, true)

		print("Single line commands (prefixed by a single address, defaults to current line)")
		f(state.cmds.line)

		print("Single line range commands (prefixed by two addresses, defaults to current line only)")
		f(state.cmds.range_line)

		print("Local range commands (prefixed by up to two addresses, default to the current selection)")
		f(state.cmds.range_local)

		print("Global range commands (prefixed by up to two addresses, defaults to the entire file)")
		f(state.cmds.range_global)

		print("File level commands")
		f(state.cmds.file)
	end, "show help"})

	table.insert(state.cmds.file, {"^h patterns$", function()
		lib.print_doc [[
			**Lua pattern quick reference**

			Character classes (uppercase character for inverted set):
			  __x__ where __x__ not in `^$()%.[]*+-?`: __x__ itself
			  `%`__x__ where __x__ not alphanumeric: character __x__ (escaped)
			  `.` : all characters
			  `%a`: all letters
			  `%c`: control characters
			  `%d`: digits
			  `%g`: printable characters except space
			  `%l`: lowercase letters
			  `%p`: punctuation characters
			  `%s`: space characters
			  `%u`: uppercase letters
			  `%w`: alphanumeric characters
			  `%x`: hexadecimal digits
			  `[`__set..__`]` : all characters in that set
			  `[^`__set..__`]`: all characters not in that set

			Patterns:
			  __set__`*`: zero or more times
			  __set__`+`: one or more times
			  __set__`-`: zero or more times, shortest possible match
			  __set__`?`: zero or one time
			  `%`__n__: capture #__n__ (1-9)
			  `%b`__xy__: string that starts with __x__, ends with __y__, and contains an equal amount of __x__ and __y__
			  `%f[`__set..__`]`: empty string between a character not in the set and a character in the set, beginning and end are `\0`

			For more details, see `https://www.lua.org/manual/5.4/manual.html#6.4.1`.
		]]
	end, "show Lua pattern help"})
end
