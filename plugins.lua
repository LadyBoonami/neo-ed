local m = {}

local lib = require "neo-ed.lib"

function m.core_addr_line(state)
	table.insert(state.cmds.addr.prim, {"^(%d+)(.*)$"  , function(m      ) return tonumber(m[1]), m[2]                                         end, "line number"            })
	table.insert(state.cmds.addr.prim, {"^%^(.*)$"     , function(m      ) return #state.curr.prev + 1, m[1]                                   end, "first line of selection"})
	table.insert(state.cmds.addr.prim, {"^%.(.*)$"     , function(m      ) return #state.curr.prev + #state.curr.curr, m[1]                    end, "last line of selection" })
	table.insert(state.cmds.addr.prim, {"^%$(.*)$"     , function(m      ) return #state.curr.prev + #state.curr.curr + #state.curr.next, m[1] end, "last line"              })
	table.insert(state.cmds.addr.cont, {"^%+(%d*)(.*)$", function(m, base) return base + (m[1] == "" and 1 or tonumber(m[1])), m[2]            end, "add lines"              })
	table.insert(state.cmds.addr.cont, {"^%-(%d*)(.*)$", function(m, base) return base - (m[1] == "" and 1 or tonumber(m[1])), m[2]            end, "subtract lines"         })
end

function m.core_addr_pat(state)
	table.insert(state.cmds.addr.prim, {"^(%p)(.-)%1(.*)$", function(m)
		local tmp = state.curr:all()
		for i, l in ipairs(tmp) do
			if l:find(m[2]) then return i, m[3] end
		end
		error("pattern not found: " .. m[1] .. m[2] .. m[1])
	end, "first matching line"})

	table.insert(state.cmds.addr.cont, {"^/(.-)/(.*)$", function(m, base)
		local tmp = state.curr:all()
		for i = base + 1, #tmp do
			if tmp[i]:find(m[1]) then return i, m[2] end
		end
		error("pattern not found: /" .. m[1] .. "/")
	end, "first matching line after"})

	table.insert(state.cmds.addr.cont, {"^\\(.-)\\(.*)$", function(m, base)
		local tmp = state.curr:all()
		for i = base - 1, 1, -1 do
			if tmp[i]:find(m[1]) then return i, m[2] end
		end
		error("pattern not found: \\" .. m[1] .. "\\")
	end, "last matching line before"})

	-- TODO:
		-- pass pattern information
end

function m.core_editing(state)
	table.insert(state.cmds.line, {"^a$", function(m, a)
		state.curr:change(function(buf)
			local i = 1
			while true do
				local pre = buf.curr[a + i - 1] and buf.curr[a + i - 1]:match("^(%s*)") or ""
				local s = lib.readline("", {pre})
				if s then table.insert(buf.curr, a + i, s); i = i + 1 else break end
			end
		end)
	end, "append lines after"})

	table.insert(state.cmds.line, {"^c$", function(m, a)
		state.curr:change(function(buf)
			local pre = buf.curr[a]:match("^(%s*)")
			buf.curr[a] = lib.readline("", {pre, buf.curr[a]})
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

	table.insert(state.cmds.range_local, {"^([gv])(%p)(.-)%2(.*)$", function(m, a, b)
		state.curr:change(function(buf)
			for i = b, a, -1 do
				if m[1] == "g" and     buf.curr[i]:find(m[3])
				or m[1] == "v" and not buf.curr[i]:find(m[3]) then
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
				local pre = buf.curr[i_] and buf.curr[i_]:match("^(%s*)") or ""
				local s = lib.readline("", {pre})
				if s then table.insert(buf.curr, a + i - 1, s); i = i + 1 else break end
			end
		end)
	end, "insert lines before"})

	table.insert(state.cmds.range_local, {"^j$", function(m, a, b)
		state.curr:change(function(buf)
			local tmp = table.concat(buf.curr, "", a, b)
			buf:replace(a, b, {tmp})
		end)
	end, "join lines"})

	table.insert(state.cmds.range_local, {"^J(.)(.*)%1$", function(m, a, b)
		state.curr:change(function(buf)
			local new = {}
			for _, l in ipairs(buf:extract(a, b)) do
				local tmp = l:gsub(m[2], "\n")
				for l_ in tmp:gmatch("[^\n]*") do table.insert(new, l_) end
			end
			buf:insert(a - 1, new)
		end)
	end, "split lines on pattern"})

	table.insert(state.cmds.range_local, {"^m(.*)$", function(m, a, b)
		state.curr:change(function(buf)
			local dst = buf:addr(m[1], true)
			if dst > b then dst = dst - (b - a + 1)
			elseif dst > a then error("destination inside source range")
			end

			buf:insert(dst, buf:extract(a, b))
		end)
	end, "move lines"})

	table.insert(state.cmds.line, {"^r +(!?)(.*)$", function(m, a)
		state.curr:change(function(buf)
			local h <close> = #m[1] > 0 and io.popen(m[2], "r") or assert(io.open(m[2], "r"))
			local tmp = {}
			for l in h:lines() do table.insert(tmp, l) end
			buf:insert(a, tmp)
		end)
	end, "append text from file / command after"})

	table.insert(state.cmds.range_local, {"^s(.)(.-)%1(.-)%1(.-)$", function(m, a, b)
		state.curr:change(function(buf)
			for i, l in ipairs(buf.curr) do
				if a <= i and i <= b then
					if m[4]:find("g") then
						buf.curr[i] = l:gsub(m[2], m[3])
					elseif tonumber(m[4]) then
						local pos = lib.find_nth(l, m[2], tonumber(m[4]))
						if pos then buf.curr[i] = l:sub(1, pos - 1) .. l:sub(pos):gsub(m[2], m[3], 1) end
					elseif m[4] == "" then
						buf.curr[i] = l:gsub(m[2], m[3], 1)
					else
						error("could not parse flags: " .. m[4])
					end
				end
			end
		end)
	end, "substitute text using Lua gsub"})

	table.insert(state.cmds.range_local, {"^t(.*)$", function(m, a, b)
		state.curr:change(function(buf)
			local dst = buf:addr(m[1], true)
			local tmp = {}
			for i = a, b do table.insert(tmp, buf.curr[i]) end
			buf:insert(dst, tmp)
		end)
	end, "copy (transfer) lines"})
end

function m.core_help(state)
	table.insert(state.cmds.file, {"^h$", function()
		local function f(t)
			for i, v in ipairs(t) do print(("    %s%-30s %s\x1b[0m"):format(i % 2 == 0 and "\x1b[34m" or "\x1b[36m", v[1]:gsub("^%^", ""):gsub("%(%.%*%)%$$", ""), v[3])) end
		end

		print("Line addressing:")
		f(state.cmds.addr.prim)

		print("Address modifiers:")
		f(state.cmds.addr.cont)

		print("Single line commands (prefixed by a single address, defaults to end of selection)")
		f(state.cmds.line)

		print("Local range commands (prefixed by up to two addresses, default to the current selection)")
		f(state.cmds.range_local)

		print("Global range commands (prefixed by up to two addresses, defaults to the entire file)")
		f(state.cmds.range_global)

		print("File level commands")
		f(state.cmds.file)
	end, "show help"})
end

function m.core_state(state)
	table.insert(state.cmds.file, {"^$", function( ) state.curr:print() end, "print current selection"})

	table.insert(state.cmds.file, {"^e +(.+)$", function(m) state     :load    (m[1])                             end, "open file"       })
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
end

function m.core(state)
	m.core_addr_line(state)
	m.core_addr_pat (state)
	m.core_editing  (state)
	m.core_help     (state)
	m.core_state    (state)
end

function m.align(state)
	table.insert(state.cmds.range_local, {"^:align *(%p)(.-)%1(%d*)$", function(m, a, b)
		local n = tonumber(m[3]) or 1
		state.curr:change(function(buf)
			local max = 0
			for i, l in ipairs(buf.curr) do
				if a <= i and i <= b then
					local bytes = lib.find_nth(l, m[2], n)
					if bytes then max = math.max(max, utf8.len(l:sub(1, bytes - 1))) end
				end
			end
			print(max)
			for i, l in ipairs(buf.curr) do
				if a <= i and i <= b then
					local bytes = lib.find_nth(l, m[2], n)
					if bytes then buf.curr[i] = l:sub(1, bytes - 1) .. (" "):rep(max - utf8.len(l:sub(1, bytes - 1))) .. l:sub(bytes) end
				end
			end
		end)
	end, "align matched pattern by padding with spaces"})
end

function m.clipboard(state)
	local copy_cmd, paste_cmd, paste_filter

	if os.getenv("WAYLAND_DISPLAY") ~= "" then
		copy_cmd     = "wl-copy"
		paste_cmd    = "wl-paste"
		paste_filter = function(t) table.remove(t) end

	elseif os.getenv("DISPLAY") ~= "" then
		copy_cmd     = "xclip -i -selection clipboard"
		paste_cmd    = "xclip -o -selection clipboard"
		paste_filter = function() end

	else
		return

	end

	table.insert(state.cmds.range_local, {"^C$", function(m, a, b)
		local h <close> = io.popen(copy_cmd, "w")
		for i, l in ipairs(state.curr.curr) do
			if a <= i and i <= b then h:write(l, "\n") end
		end
	end, "copy lines"})

	table.insert(state.cmds.range_local, {"^X$", function(m, a, b)
		state.curr:change(function(buf)
			local h <close> = io.popen(copy_cmd, "w")
			for i, l in ipairs(buf:extract(a, b)) do h:write(l, "\n") end
		end)
	end, "cut lines"})

	table.insert(state.cmds.line, {"^V$", function(m, a)
		state.curr:change(function(buf)
			local h <close> = io.popen(paste_cmd, "r")
			local tmp = {}
			for l in h:lines() do table.insert(tmp, l) end
			paste_filter(tmp)
			buf:insert(a, tmp)
		end)
	end, "paste lines after"})
end

function m.config_file(state)
	table.insert(state.cmds.file, {"^:config$", function() state:load(state.config_file) end, "open config file"})
end

function m.eol_filter(state)
	table.insert(state.print.post, function(lines)
		for i, l in ipairs(lines) do lines[i] = l .. "\x1b[34m·\x1b[0m" end
		return lines
	end)
end

function m.find(state)
	table.insert(state.cmds.range_global, {"^:find *(%p)(.-)%1$", function(m, a, b)
		local tmp = state.curr:all()
		local lines = {}
		for i, v in ipairs(tmp) do
			if a <= i and i <= b and v:find(m[2]) then lines[i] = true end
		end
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
			if v.modified then error("buffer modified: " .. v.path) end
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
				if a <= i and i <= b then table.insert(tmp, l) end
			end
			table.insert(tmp, "")
			tmp = table.concat(tmp, "\n")
			local ret = {}
			for l in lib.pipe(cmdline(m[1]), tmp):gmatch("[^\n]*") do table.insert(ret, l) end
			table.remove(ret)
			buf:replace(a, b, ret)
		end)
	end, "pipe lines through shell command"})
end

function m.tabs_filter(state)
	table.insert(state.cmds.file, {"^:tabs +(%d+)$"  , function(m) state.curr.conf.tabs   = tonumber(m[1]) end, "set tab width"  })
	table.insert(state.cmds.file, {"^:indent +(%d+)$", function(m) state.curr.conf.indent = tonumber(m[1]) end, "set indentation"})

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
			if wsp == "" then return table.concat(t) end
			table.insert(t, color[i % 6 + 1]("┆"))
			table.insert(t, wsp:sub(2, b.conf.indent))
			return spcs(wsp:sub(b.conf.indent + 1), t, i + 1)
		end

		local tab = (" "):rep(b.conf.tabs - 1)
		local tab_ = ("┄"):rep(b.conf.tabs - 1) .. "┤"
		local function tabs(wsp, t, i)
			t = t or {}
			i = i or 0
			if wsp == "" then return table.concat(t) end
			if wsp:find("^ ") then return spcs(wsp, t, i) end
			table.insert(t, color[i % 6 + 1]("│"))
			table.insert(t, tab)
			return tabs(wsp:sub(2), t, i + 1)
		end

		for i, l in ipairs(lines) do
			lines[i] = l
				:gsub("^(\x1b[^m]-m)([\t ]+)" , function(pre, wsp) return tabs(wsp) end)
				:gsub(            "^([\t ]+)" , function(     wsp) return spcs(wsp) end)
				:gsub("\t", "\x1b[34m" .. tab_ .. "\x1b[0m")
		end
		return lines
	end)
end

function m.def(state)
	m.core       (state)
	m.align      (state)
	m.clipboard  (state)
	m.config_file(state)
	m.eol_filter (state)
	m.find       (state)
	m.lua_cmd    (state)
	m.reload     (state)
	m.shell      (state)
	m.tabs_filter(state)
end

function m.autocmd(state)
	table.insert(state.hooks.save_post, function(b)
		if b.conf.ext.autocmd then b.state:cmd(b.conf.ext.autocmd) end
	end)
end

function m.editorconfig(state)
	table.insert(state.hooks.load, function(b)
		if b.path then
			local h <close> = io.popen("editorconfig " .. lib.shellesc(lib.realpath(b.path)))
			local conf = {}
			for l in h:lines() do
				local k, v = l:match("^([^=]+)=(.*)$")
				if k then conf[k] = v end
			end

			if conf.indent_style             then b.conf.tab2spc = conf.indent_style:lower() == "space"                                                                                      end
			if conf.indent_size              then b.conf.indent  = (conf.indent_size:lower() == "tab" and (tonumber(conf.tab_width) or b.conf.tabs or 4)) or tonumber(conf.indent_size) or 4 end
			if conf.tab_width                then b.conf.tabs    = tonumber(conf.tab_width) or 4                                                                                             end
			if conf.end_of_line              then b.conf.crlf    = conf.end_of_line:lower() == "crlf"                                                                                        end
			if conf.trim_trailing_whitespace then b.conf.trim    = conf.trim_trailing_whitespace == "true"                                                                                   end

			for k, v in pairs(conf) do
				local k_ = k:match("^ned%-(.*)$")
				if k_ then b.conf.ext[k_] = v end
			end
		end
	end)
end

function m.pygmentize_filter(state)
	state.print.highlight = function(lines, curr)
		if curr.conf.ext.mode then
			local pre, main, suf = (table.concat(lines, "\n") .. "\n"):match("^(%s*)(.-\n)(%s*)$")
			if pre then
				local tmp = table.concat{pre, lib.pipe("pygmentize -P style=native -l " .. lib.shellesc(curr.conf.ext.mode), main), suf}
				local ret = {}
				for l in tmp:gmatch("[^\n]*") do table.insert(ret, l) end
				table.remove(ret)
				return ret
			end
			return lines
		end
		return lines
	end

	table.insert(state.cmds.file, {"^:mode +(.+)$", function(m) state.curr.conf.ext.mode = m[1] end, "set file type"})
end

function m.pygmentize_mode_detect(state)
	local function guess(curr)
		curr.conf.ext.mode = lib.pipe("pygmentize -C", table.concat(curr:all(), "\n")):match("^[^\n]*")
	end

	table.insert(state.hooks.load, function(curr)
		if curr.path and not curr.conf.ext.mode then
			local h <close> = io.popen("pygmentize -N " .. lib.shellesc(curr.path), "r")
			curr.conf.ext.mode = h:read("l")
		end
		if #curr.curr > 100 and (not curr.conf.ext.mode or curr.conf.ext.mode == "text") then guess(curr) end
	end)

	table.insert(state.cmds.file, {"^:guess$", function() guess(state.curr) end, "guess file type from content"})
end

return m
