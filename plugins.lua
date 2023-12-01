local m = {}

local lib = require "neo-ed.lib"

function m.core_addr_line(state)
	table.insert(state.cmds.addr.prim, {"^(%d+)(.*)$"  , function(m      ) return tonumber(m[1])                             , m[2] end, "line number"            })
	table.insert(state.cmds.addr.prim, {"^%^(.*)$"     , function(m      ) return state.curr:curr_first()                    , m[1] end, "first line of selection"})
	table.insert(state.cmds.addr.prim, {"^%.(.*)$"     , function(m      ) return state.curr:curr_last()                     , m[1] end, "last line of selection" })
	table.insert(state.cmds.addr.prim, {"^%$(.*)$"     , function(m      ) return state.curr:length()                        , m[1] end, "last line"              })
	table.insert(state.cmds.addr.cont, {"^%+(%d*)(.*)$", function(m, base) return base + (m[1] == "" and 1 or tonumber(m[1])), m[2] end, "add lines"              })
	table.insert(state.cmds.addr.cont, {"^%-(%d*)(.*)$", function(m, base) return base - (m[1] == "" and 1 or tonumber(m[1])), m[2] end, "subtract lines"         })
end

function m.core_addr_pat(state)
	table.insert(state.cmds.addr.prim, {"^/(.-)/(.*)$", function(m)
		return (
			state.curr:map(function(i, l) if l.text:find(m[1]) then return i end end)
			or lib.error("pattern not found: /" .. m[1] .. "/")
		), m[2]
	end, "first matching line"})

	table.insert(state.cmds.addr.cont, {"^/(.-)/(.*)$", function(m, base)
		return (
			state.curr:map(function(i, l) if i > base and l.text:find(m[1]) then return i end end)
			or lib.error("pattern not found: " .. tostring(base) .. "/" .. m[1] .. "/")
		), m[2]
	end, "first matching line after"})

	table.insert(state.cmds.addr.cont, {"^\\(.-)\\(.*)$", function(m, base)
		return (
			state.curr:rmap(function(i, l) if i < base and l.text:find(m[1]) then return i end end)
			or lib.error("pattern not found: " .. tostring(base) .. "\\" .. m[1] .. "\\")
		), m[2]
	end, "last matching line before"})
end

function m.core_editing(state)
	table.insert(state.cmds.line, {"^a$", function(m, a)
		state.curr:change(function(buf)
			local i = 1
			while true do
				local pre = buf.curr[a + i - 1] and buf.curr[a + i - 1].text:match("^(%s*)") or ""
				local s = buf:get_input({pre})
				if s then table.insert(buf.curr, a + i, {text = s}); i = i + 1 else break end
			end
		end)
	end, "append lines after"})

	table.insert(state.cmds.line, {"^c$", function(m, a)
		state.curr:change(function(buf)
			local pre = buf.curr[a].text:match("^(%s*)")
			buf.curr[a].text = buf:get_input({pre, buf.curr[a].text})
		end)
	end, "change line"})

	table.insert(state.cmds.range_local, {"^d$", function(m, a, b)
		state.curr:change(function(buf)
			buf:extract(a, b)
		end)
	end, "delete lines (entire selection)"})

	table.insert(state.cmds.range_global, {"^f$", function(m, a, b)
		state.curr:focus(a, b)
		state.curr:print()
	end, "select (\"focus\") lines"})

	-- TODO: do this in order
	table.insert(state.cmds.range_local, {"^([gv])(%p)(.-)%2(.*)$", function(m, a, b)
		state.curr:change(function(buf)
			for i = b, a, -1 do
				if m[1] == "g" and     buf.curr[i].text:find(m[3])
				or m[1] == "v" and not buf.curr[i].text:find(m[3]) then
					state:cmd(tostring(#buf.prev + i) .. m[4])
				end
			end
		end)
	end, "perform command on every (non-)matching line"})

	table.insert(state.cmds.line, {"^i$", function(m, a)
		state.curr:change(function(buf)
			local i = 1
			while true do
				local i_ = i == 1 and (a + i - 1) or (a + i - 2)
				local pre = buf.curr[i_] and buf.curr[i_].text:match("^(%s*)") or ""
				local s = buf:get_input({pre})
				if s then table.insert(buf.curr, a + i - 1, {text = s}); i = i + 1 else break end
			end
		end)
	end, "insert lines before"})

	table.insert(state.cmds.range_local, {"^j$", function(m, a, b)
		state.curr:change(function(buf)
			local tmp = {}
			for i = a, b do table.insert(tmp, buf.curr[i].text) end
			buf:replace(a, b, {{text = table.concat(tmp, "")}})
		end)
	end, "join lines"})

	table.insert(state.cmds.range_local, {"^J(.)(.*)%1$", function(m, a, b)
		state.curr:change(function(buf)
			local new = {}
			for _, l in ipairs(buf:extract(a, b)) do
				local tmp = l.text:gsub(m[2], "\n")
				for l_ in tmp:gmatch("[^\n]*") do table.insert(new, {text = l_}) end
			end
			buf:insert(a - 1, new)
		end)
	end, "split lines on pattern"})

	table.insert(state.cmds.range_local, {"^m(.*)$", function(m, a, b)
		state.curr:change(function(buf)
			local dst = buf:addr(m[1], true)
			if dst > b then dst = dst - (b - a + 1)
			elseif dst > a then lib.error("destination inside source range")
			end

			buf:insert(dst, buf:extract(a, b))
		end)
	end, "move lines"})

	table.insert(state.cmds.line, {"^r +(.*)$", function(m, a)
		state.curr:change(function(buf)
			local h <close> = buf.state:path_hdl(m[1])
			local tmp = {}
			for l in h:lines() do table.insert(tmp, {text = l}) end
			buf:insert(a, tmp)
		end)
	end, "append text from file / command after"})

	table.insert(state.cmds.range_local, {"^s(.)(.-)%1(.-)%1(.-)$", function(m, a, b)
		state.curr:change(function(buf)
			for i, l in ipairs(buf.curr) do
				if a <= i and i <= b then
					if m[4]:find("g") then
						buf.curr[i].text = l.text:gsub(m[2], m[3])
					elseif tonumber(m[4]) then
						local pos = lib.find_nth(l.text, m[2], tonumber(m[4]))
						if pos then buf.curr[i].text = l.text:sub(1, pos - 1) .. l.text:sub(pos):gsub(m[2], m[3], 1) end
					elseif m[4] == "" then
						buf.curr[i].text = l.text:gsub(m[2], m[3], 1)
					else
						lib.error("could not parse flags: " .. m[4])
					end
				end
			end
		end)
	end, "substitute text using Lua gsub"})

	table.insert(state.cmds.range_local, {"^t(.*)$", function(m, a, b)
		state.curr:change(function(buf)
			local dst = buf:addr(m[1], true)
			local tmp = {}
			for i = a, b do table.insert(tmp, lib.dup(buf.curr[i])) end
			buf:insert(dst, tmp)
		end)
	end, "copy (transfer) lines"})
end

function m.core_help(state)
	table.insert(state.cmds.file, {"^h$", function()
		local function f(t, addr)
			for i, v in ipairs(t) do print(("    %s%-30s %s\x1b[0m"):format(i % 2 == 0 and "\x1b[34m" or "\x1b[36m", v[1]:gsub("^%^", ""):gsub(addr and "%(%.%*%)%$$" or "%$$", ""), v[3])) end
		end

		print("Line addressing:")
		f(state.cmds.addr.prim, true)

		print("Address modifiers:")
		f(state.cmds.addr.cont, true)

		print("Single line commands (prefixed by a single address, defaults to end of selection)")
		f(state.cmds.line)

		print("Local range commands (prefixed by up to two addresses, default to the current selection)")
		local t = {}
		for _, v in ipairs(state.cmds.range_local   ) do table.insert(t, v) end
		for _, v in ipairs(state.cmds.range_local_ro) do table.insert(t, v) end
		f(t)

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

function m.core_marks(state)
	table.insert(state.cmds.line, {"^k(%l?)$", function(m, a)
		state.curr.curr[a].mark = m[1] ~= "" and m[1] or nil
	end, "mark line"})

	table.insert(state.cmds.addr.prim, {"^'(%l)(.*)$", function(m)
		return (
			state.curr:map(function(i, l) if l.mark == m[1] then return i end end)
			or lib.error("mark not found: '" .. m[1])
		), m[2]
	end, "first line with mark"})

	table.insert(state.cmds.addr.cont, {"^'(%l)(.*)$", function(m, base)
		return (
			state.curr:map(function(i, l) if i > base and l.mark == m[1] then return i end end)
			or lib.error("mark not found: " .. tostring(base) .. "'" .. m[1])
		), m[2]
	end, "first line with mark after"})

	table.insert(state.cmds.addr.cont, {"^`(%l)(.*)$", function(m, base)
		return (
			state.curr:rmap(function(i, l) if i < base and l.mark == m[1] then return i end end)
			or lib.error("mark not found: " .. tostring(base) .. "`" .. m[1])
		), m[2]
	end, "last line with mark before"})

	table.insert(state.print.post, function(lines)
		for _, l in ipairs(lines) do
			if l.mark then l.text = l.text .. " \x1b[47;30m " .. l.mark .. " \x1b[0m" end
		end
		return lines
	end)
end

function m.core_print(state)
	table.insert(state.cmds.range_local_ro, {"^$", function(m, a, b) state:cmd(tostring(a) .. "," .. tostring(b) .. "l") end, "print code listing (alias for `l` command)"})

	table.insert(state.cmds.range_local_ro, {"^l$", function(m, a, b)
		local lines = {}
		for i = a, b do lines[i] = true end
		state.curr:print(lines)
	end, "print code listing (use the print pipeline)"})

	table.insert(state.cmds.range_local_ro, {"^n$", function(m, a, b)
		state.curr:map(function(i, l) if a <= i and i <= b then print(i, l.text) end end)
	end, "print lines with line numbers"})

	table.insert(state.cmds.range_local_ro, {"^p$", function(m, a, b)
		state.curr:map(function(i, l) if a <= i and i <= b then print(l.text) end end)
	end, "print raw lines"})

end

function m.core_state(state)
	table.insert(state.cmds.file, {"^e +(.+)$", function(m) state     :load    (m[1]):print()                     end, "open file"       })
	table.insert(state.cmds.file, {"^f +(.+)$", function(m) state.curr:set_path(m[1]); state.curr.modified = true end, "set file name"   })
	table.insert(state.cmds.file, {"^q$"      , function( ) state.curr:close   (    )                             end,       "close file"})
	table.insert(state.cmds.file, {"^Q$"      , function( ) state.curr:close   (true)                             end, "force close file"})
	table.insert(state.cmds.file, {"^qq$"     , function( ) state     :quit    (    )                             end,       "quit"      })
	table.insert(state.cmds.file, {"^QQ$"     , function( ) state     :quit    (true)                             end, "force quit"      })

	table.insert(state.cmds.file, {"^u$"      , function( ) state.curr:undo(    )                     end, "undo"                                         })
	table.insert(state.cmds.file, {"^w$"      , function( ) state.curr:save(    )                     end, "write changes to the current file"            })
	table.insert(state.cmds.file, {"^w +(.+)$", function(m) state.curr:save(m[1])                     end, "write changes to the specified file"          })
	table.insert(state.cmds.file, {"^wq$"     , function( ) state.curr:save(    ); state.curr:close() end, "write changes to the current file, then close"})
	table.insert(state.cmds.file, {"^wqq$"    , function( ) state.curr:save(    ); state:quit      () end, "write changes to the current file, then quit" })

	table.insert(state.cmds.file, {"^#(%d+)$" , function(m)
		state.curr = assert(state.files[tonumber(m[1])], "no such file")
		state.curr:print()
	end, "switch to open file"})

	table.insert(state.cmds.file, {"^:trace ([yn])", function(m) lib.stacktraces = m[1] == "y" end, "enable stack traces for editor errors"})
end

function m.core(state)
	m.core_addr_line(state)
	m.core_addr_pat (state)
	m.core_editing  (state)
	m.core_help     (state)
	m.core_marks    (state)
	m.core_print    (state)
	m.core_state    (state)
end

function m.align(state)
	table.insert(state.cmds.range_local, {"^:align *(%p)(.-)%1(%d*)$", function(m, a, b)
		local n = tonumber(m[3]) or 1
		state.curr:change(function(buf)
			local max = 0
			for i, l in ipairs(buf.curr) do
				if a <= i and i <= b then
					local bytes = lib.find_nth(l.text, m[2], n)
					if bytes then max = math.max(max, utf8.len(l.text:sub(1, bytes - 1))) end
				end
			end
			for i, l in ipairs(buf.curr) do
				if a <= i and i <= b then
					local bytes = lib.find_nth(l.text, m[2], n)
					if bytes then
						buf.curr[i].text = l.text:sub(1, bytes - 1)
							.. (" "):rep(max - utf8.len(l.text:sub(1, bytes - 1)))
							.. l.text:sub(bytes)
					end
				end
			end
		end)
	end, "align matched pattern by padding with spaces"})
end

function m.autocmd(state)
	local use = {}
	local function validate(s)
		if s == nil then return nil end
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

function m.charset(state)
	local encodings = {
		["latin1"  ] = "ISO8859_1",
		["utf-8"   ] = "UTF-8",
		["utf-16be"] = "UTF-16BE",
		["utf-16le"] = "UTF-16LE",
	}

	table.insert(state.filters.read, function(s, b)
		return lib.pipe("iconv -f " .. assert(encodings[b.conf.charset], "unknown charset: " .. b.conf.charset), s)
	end)

	table.insert(state.filters.write, function(s, b)
		return lib.pipe("iconv -t " .. assert(encodings[b.conf.charset], "unknown charset: " .. b.conf.charset), s)
	end)

	table.insert(state.cmds.file, {"^:charset *(.*)$", function(m) state.curr.conf.charset = m[1] end, "Set charset"})
end

function m.clipboard(state)
	local copy_cmd, paste_cmd, paste_filter

	if os.getenv("WAYLAND_DISPLAY") ~= "" then
		copy_cmd     = "wl-copy"
		paste_cmd    = "wl-paste --no-newline"

	elseif os.getenv("DISPLAY") ~= "" then
		copy_cmd     = "xclip -i -selection clipboard"
		paste_cmd    = "xclip -o -selection clipboard"

	else
		return

	end

	table.insert(state.cmds.range_local, {"^C$", function(m, a, b)
		local h <close> = io.popen(copy_cmd, "w")
		for i, l in ipairs(state.curr.curr) do
			if a <= i and i <= b then h:write(l.text, "\n") end
		end
	end, "copy lines"})

	table.insert(state.cmds.range_local, {"^X$", function(m, a, b)
		state.curr:change(function(buf)
			local h <close> = io.popen(copy_cmd, "w")
			for i, l in ipairs(buf:extract(a, b)) do h:write(l.text, "\n") end
		end)
	end, "cut lines"})

	table.insert(state.cmds.line, {"^V$", function(m, a)
		state.curr:change(function(buf)
			local h <close> = io.popen(paste_cmd, "r")
			local tmp = {}
			for l in h:lines() do print(l); table.insert(tmp, {text = l}) end
			buf:insert(a, tmp)
		end)
	end, "paste lines after"})
end

function m.config_file(state)
	table.insert(state.cmds.file, {"^:config$", function() state:load(state.config_file):print() end, "open config file"})
end

function m.eol(state)
	table.insert(state.filters.read, function(s) return s:gsub("\r", "") end)

	table.insert(state.filters.write, function(s, b)
		if not b.conf.crlf then return s end
		return s:gsub("\n", "\r\n")
	end)

	table.insert(state.cmds.file, {"^:crlf ([yn])$", function(m) state.curr.conf.crlf = m[1] == "y" end, "Set CRLF line breaks"})
end

function m.eol_filter(state)
	table.insert(state.print.post, 1, function(lines)
		for i, l in ipairs(lines) do lines[i].text = l.text .. "\x1b[34m·\x1b[0m" end
		return lines
	end)
end

function m.find(state)
	table.insert(state.cmds.range_global, {"^:find *(%p)(.-)%1$", function(m, a, b)
		local lines = {}
		state.curr:map(function(i, l)
			if a <= i and i <= b and l.text:find(m[2]) then lines[i] = true end
		end)
		state.curr:print(lines)
	end, "search for pattern"})
end

function m.lua_cmd(state)
	table.insert(state.cmds.file, {"^:lua *(.*)$", function(m)
		assert(load(m[1], "interactive", "t"))()
	end, "execute lua command"})
end

function m.reload(state)
	table.insert(state.cmds.file, {"^:reload$", function()
		local files = {}
		for _, v in ipairs(state.files) do
			if v.modified then lib.error("buffer modified: " .. v.path) end
			table.insert(files, {path = v.path, cmd = tostring(#v.prev + 1) .. "," .. tostring(#v.prev + #v.curr) .. "f"})
		end
		for _, v in ipairs(state.files) do v:close() end
		return require("neo-ed.state")(files):main()
	end, "reload editor config"})
end

function m.shell(state)
	local function cmdline(s)
		return s:gsub("%f[%%]%%", state.curr.path):gsub("%%%%", "%%")
	end

	table.insert(state.cmds.file, {"^!(.+)$", function(m)
		local ok, how, no = os.execute(cmdline(m[1]))
		if not ok then print(how, no) end
	end, "execute shell command"})

	table.insert(state.cmds.range_local, {"^|(.+)$", function(m, a, b)
		state.curr:change(function(buf)
			local tmp = {}
			for i, l in ipairs(buf.curr) do
				if a <= i and i <= b then table.insert(tmp, l.text) end
			end
			table.insert(tmp, "")
			tmp = table.concat(tmp, "\n")
			local ret = {}
			for l in lib.pipe(cmdline(m[1]), tmp):gmatch("[^\n]*") do table.insert(ret, {text = l}) end
			table.remove(ret)
			buf:replace(a, b, ret)
		end)
	end, "pipe lines through shell command"})
end

function m.ssh_url(state)
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

function m.tabs_filter(state)
	table.insert(state.cmds.file, {"^:tabs +(%d+)$"   , function(m) state.curr.conf.tabs    = tonumber(m[1]) end, "set tab width"      })
	table.insert(state.cmds.file, {"^:indent +(%d+)$" , function(m) state.curr.conf.indent  = tonumber(m[1]) end, "set indentation"    })
	table.insert(state.cmds.file, {"^:tab2spc ([yn])$", function(m) state.curr.conf.tab2spc = m[1] == "y"    end, "set tab replacement"})

	table.insert(state.print.post, function(lines, b)
		local color = {
			function(s) return "\x1b[31m" .. s .. "\x1b[0m" end,
			function(s) return "\x1b[33m" .. s .. "\x1b[0m" end,
			function(s) return "\x1b[32m" .. s .. "\x1b[0m" end,
			function(s) return "\x1b[36m" .. s .. "\x1b[0m" end,
			function(s) return "\x1b[34m" .. s .. "\x1b[0m" end,
			function(s) return "\x1b[35m" .. s .. "\x1b[0m" end,
		}

		local function spcs(wsp, t, i)
			t = t or {}
			i = i or 0
			if #wsp < b.conf.indent then
				table.insert(t, wsp)
				return table.concat(t)
			end
			table.insert(t, wsp:sub(2, b.conf.indent))
			table.insert(t, color[i % 6 + 1]("┆"))
			return spcs(wsp:sub(b.conf.indent + 1), t, i + 1)
		end

		local tab = (" "):rep(b.conf.tabs - 2)
		local tab_ = (b.conf.tabs > 1 and "·" or "") .. (" "):rep(b.conf.tabs - 2) .. "│"
		local function tabs(wsp, t, i)
			t = t or {}
			i = i or 0
			if wsp == "" then return table.concat(t) end
			if wsp:find("^ ") then
				table.insert(t, wsp)
				return table.concat(t)
			end
			if b.conf.tabs > 1 then table.insert(t, color[i % 6 + 1]("·")) end
			table.insert(t, tab)
			table.insert(t, color[i % 6 + 1]("│"))
			return tabs(wsp:sub(2), t, i + 1)
		end

		for i, l in ipairs(lines) do
			lines[i].text = l.text
				:gsub("^(\x1b[^m]-m)([\t ]+)", function(pre, wsp) return tabs(wsp) end)
				:gsub(            "^([\t ]+)", function(     wsp) return spcs(wsp) end)
				:gsub("\t", tab_)
		end
		return lines
	end)

	table.insert(state.hooks.input_post, function(l, buf)
		if not buf.conf.tab2spc then return l end
		local spc = (" "):rep(buf.conf.indent)
		return l:gsub("\t", spc)
	end)
end

function m.def(state)
	m.core       (state)
	m.align      (state)
	m.autocmd    (state)
	m.charset    (state)
	m.clipboard  (state)
	m.config_file(state)
	m.eol        (state)
	m.eol_filter (state)
	m.find       (state)
	m.lua_cmd    (state)
	m.reload     (state)
	m.ssh_url    (state)
	m.shell      (state)
	m.tabs_filter(state)
end

function m.editorconfig(state)
	local function from_editorconfig(from, to)
		to = to or {}

		local t = {
			charset                  = function(v) return "charset", v                    end,
			end_of_line              = function(v) return "crlf", v:lower() == "crlf"     end,
			indent_size              = function( ) return ""                              end,
			indent_style             = function(v) return "tab2spc", v:lower() == "space" end,
			tab_width                = function(v) return "tabs", tonumber(v) or 4        end,
			trim_trailing_whitespace = function(v) return "trim", v:lower() == "true"     end,
		}

		for k, v in pairs(from) do
			local k_, v_
			k_ = k:match("^ned_(.*)$")
			if k_ then v_ = v end
			if not k_ and t[k] then k_, v_ = t[k](v) end
			if k_ then to[k_] = v_ end
		end

		if from.indent_size then
			to.indent = (from.indent_size:lower() == "tab" and (tonumber(from.tab_width) or to.tabs or 4)) or tonumber(from.indent_size) or 4
		end

		return to
	end

	table.insert(state.hooks.load_pre, function(b)
		if b.path then
			local h <close> = io.popen("editorconfig " .. lib.shellesc(lib.realpath(b.path)))
			local conf = {}
			for l in h:lines() do
				local k, v = l:match("^([^=]+)=(.*)$")
				if k then conf[k] = v end
			end

			from_editorconfig(conf, b.conf)
		end
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
end

function m.fzf_picker(state)
	state.pick = function(_, choices)
		return lib.pipe("fzf", table.concat(choices, "\n") .. "\n"):match("^[^\n]*")
	end
end

function m.pygmentize_filter(state)
	state.print.highlight = function(lines, curr)
		if curr.conf.mode then
			local tmp = curr:all()
			local a = 1
			local b = #tmp
			while tmp[a] and tmp[a].text == "" do a = a + 1 end
			while tmp[b] and tmp[b].text == "" do b = b - 1 end
			if a <= b then
				local pre  = {}
				local main = {}
				local suf  = {}
				local raw  = {}

				for i = 1    , a - 1 do table.insert(pre , tmp[i])                                 end
				for i = a    , b     do table.insert(main, tmp[i]); table.insert(raw, tmp[i].text) end
				for i = b + 1, #tmp  do table.insert(suf , tmp[i])                                 end

				raw = lib.pipe("pygmentize -P style=native -l " .. lib.shellesc(curr.conf.mode), table.concat(raw, "\n"))

				local ret = {}
				for _, l in ipairs(pre) do table.insert(ret, l) end
				local i = 1
				for l in raw:gmatch("[^\n]*") do
					if not main[i] then break end
					local l_ = main[i]
					l_.text = l
					table.insert(ret, l_)
					i = i + 1
				end
				for _, l in ipairs(suf) do table.insert(ret, l) end
				return ret
			end
			return lines
		end
		return lines
	end

	table.insert(state.cmds.file, {"^:mode +(.+)$", function(m) state.curr.conf.mode = m[1] end, "set file type"})
end

function m.pygmentize_mode_detect(state)
	local function guess(curr)
		local tmp = {}
		curr:map(function(_, l) table.insert(tmp, l.text) end)
		curr.conf.mode = lib.pipe("pygmentize -C", table.concat(tmp, "\n")):match("^[^\n]*")
	end

	table.insert(state.hooks.load_post, function(curr)
		if curr.path and not curr.conf.mode then
			local h <close> = io.popen("pygmentize -N " .. lib.shellesc(curr.path), "r")
			curr.conf.mode = h:read("l")
		end
		if #curr.curr > 100 and (not curr.conf.mode or curr.conf.mode == "text") then guess(curr) end
	end)

	table.insert(state.cmds.file, {"^:guess$", function() guess(state.curr) end, "guess file type from content"})
end

return m
