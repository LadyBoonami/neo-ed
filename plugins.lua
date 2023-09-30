local m = {}

local lib = require "neo-ed.lib"

function m.core_addr_line(state)
	table.insert(state.cmds.addr.prim, {"^(%d+)(.*)$", function(m) return tonumber(m[1]), m[2] end, "line number"})
	table.insert(state.cmds.addr.prim, {"^%^(.*)$", function(m) return #state.curr.prev + 1, m[1] end, "first line of selection"})
	table.insert(state.cmds.addr.prim, {"^%.(.*)$", function(m) return #state.curr.prev + #state.curr.curr, m[1] end, "last line of selection"})
	table.insert(state.cmds.addr.prim, {"^%$(.*)$", function(m) return #state.curr.prev + #state.curr.curr + #state.curr.next, m[1] end, "last line"})
	table.insert(state.cmds.addr.cont, {"^%+(%d*)(.*)$", function(m, base) return base + (m[1] == "" and 1 or tonumber(m[1])), m[2] end, "add lines"})
	table.insert(state.cmds.addr.cont, {"^%-(%d*)(.*)$", function(m, base) return base - (m[1] == "" and 1 or tonumber(m[1])), m[2] end, "subtract lines"})
end

function m.core_addr_pat(state)
	table.insert(state.cmds.addr.prim, {"^(%p)(.-)%1(.*)$", function(m)
		local tmp = state.curr:all()
		for i, l in ipairs(tmp) do
			if l:find(m[2]) then return i, m[3] end
		end
		error("pattern not found: " .. m[1] .. pat .. m[1])
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
		state.curr:undo_point()
		local i = 1
		while true do
			local pre = state.curr.curr[a + i - 1] and state.curr.curr[a + i - 1]:match("^(%s*)") or ""
			local s = lib.readline("", {pre})
			if s then table.insert(state.curr.curr, a + i, s); i = i + 1 else break end
		end
	end, "append lines after"})

	table.insert(state.cmds.line, {"^c$", function(m, a)
		state.curr:undo_point()
		local pre = state.curr.curr[a]:match("^(%s*)")
		state.curr.curr[a] = lib.readline("", {pre, state.curr.curr[a]})
	end, "change line"})

	table.insert(state.cmds.range_local, {"^d$", function(m, a, b)
		state.curr:undo_point()
		state.curr:extract(a, b)
	end, "delete lines (entire selection)"})

	table.insert(state.cmds.range_global, {"^f$", function(m, a, b)
		state.curr:focus(a, b)
	end, "select (\"focus\") lines"})

	table.insert(state.cmds.range_local, {"^j$", function(m, a, b)
		state.curr:undo_point()
		local tmp = table.concat(state.curr.curr, "", a, b)
		state.curr:replace(a, b, {tmp})
	end, "join lines"})

	table.insert(state.cmds.range_local, {"^J(.)(.*)%1$", function(m, a, b)
		state.curr:undo_point()
		local new = {}
		for _, l in ipairs(state.curr:extract(a, b)) do
			local tmp = l:gsub(m[2], "\n")
			for l_ in tmp:gmatch("[^\n]*") do table.insert(new, l_) end
		end
		state.curr:insert(a - 1, new)
	end, "split lines on pattern"})

	table.insert(state.cmds.range_local, {"^s(.)(.-)%1(.-)%1(.-)$", function(m, a, b)
		state.curr:undo_point()
		for i, l in ipairs(state.curr.curr) do
			if a <= i and i <= b then
				if m[4]:find("g") then
					state.curr.curr[i] = l:gsub(m[2], m[3])
				else
					state.curr.curr[i] = l:gsub(m[2], m[3], 1)
				end
			end
		end
	end, "substitute text using Lua gsub"})
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

		state.skip_print = true
	end, "show help"})
end

function m.core_state(state)
	table.insert(state.cmds.file, {"^e +(.+)$", function(m) state     :load (m[1]) end, "open file"       })
	table.insert(state.cmds.file, {"^q$"      , function( ) state.curr:close(    ) end,       "close file"})
	table.insert(state.cmds.file, {"^Q$"      , function( ) state.curr:close(true) end, "force close file"})
	table.insert(state.cmds.file, {"^qq$"     , function( ) state     :quit (    ) end,       "quit"      })
	table.insert(state.cmds.file, {"^QQ$"     , function( ) state     :quit (true) end, "force quit"      })

	table.insert(state.cmds.file, {"^u$"      , function( ) state.curr:undo(    )                     end, "undo"                                         })
	table.insert(state.cmds.file, {"^w$"      , function( ) state.curr:save(    )                     end, "write changes to the current file"            })
	table.insert(state.cmds.file, {"^w +(.+)$", function(m) state.curr:save(m[1])                     end, "write changes to the specified file"          })
	table.insert(state.cmds.file, {"^wq$"     , function( ) state.curr:save(    ); state.curr:close() end, "write changes to the current file, then close"})
	table.insert(state.cmds.file, {"^wqq$"    , function( ) state.curr:save(    ); state:quit      () end, "write changes to the current file, then quit" })

	table.insert(state.cmds.file, {"^#(%d+)$" , function(m) state.curr = assert(state.files[tonumber(m[1])], "no such file") end, "switch to open file"})
end

function m.core(state)
	m.core_addr_line(state)
	m.core_addr_pat (state)
	m.core_editing  (state)
	m.core_help     (state)
	m.core_state    (state)
end

function m.align(state)
	table.insert(state.cmds.range_local, {"^:align *(%p)(.-)%1$", function(m, a, b)
		state.curr:undo_point()
		local max = 0
		for i, l in ipairs(state.curr.curr) do
			if a <= i and i <= b then
				local pre = l:match("^(.-)" .. m[2])
				if pre then max = math.max(max, utf8.len(pre)) end
			end
		end
		for i, l in ipairs(state.curr.curr) do
			if a <= i and i <= b then
				local pre = l:match("^(.-)" .. m[2])
				if pre then state.curr.curr[i] = pre .. (" "):rep(max - utf8.len(pre)) .. l:sub(#pre + 1) end
			end
		end
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
		state.curr:undo_point()
		local h <close> = io.popen(copy_cmd, "w")
		for i, l in ipairs(state.curr:extract(a, b)) do h:write(l, "\n") end
	end, "cut lines"})

	table.insert(state.cmds.line, {"^V$", function(m, a)
		state.curr:undo_point()
		local h <close> = io.popen(paste_cmd, "r")
		local tmp = {}
		for l in h:lines() do table.insert(tmp, l) end
		paste_filter(tmp)
		state.curr:insert(a, tmp)
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
		state.skip_print = true
	end, "search for pattern"})
end

function m.lua_cmd(state)
	table.insert(state.cmds.file, {"^:lua *(.*)$", function(m)
		assert(load(m[1], "interactive", "t"))()
		state.skip_print = true
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
	table.insert(state.cmds.file, {"^!(.+)$", function(m)
		local ok, how, no = os.execute(m[1])
		if not ok then print(how, no) end
		state.skip_print = true
	end, "execute shell command"})

	table.insert(state.cmds.range_local, {"^|(.+)$", function(m, a, b)
		state.curr:undo_point()
		local tmp = {}
		for i, l in ipairs(state.curr.curr) do
			if a <= i and i <= b then table.insert(tmp, l) end
		end
		table.insert(tmp, "")
		tmp = table.concat(tmp, "\n")
		local ret = {}
		for l in lib.pipe(m[1], tmp):gmatch("[^\n]*") do table.insert(ret, l) end
		table.remove(ret)
		state.curr:replace(a, b, ret)
	end, "pipe lines through shell command"})
end

function m.tabs_filter(state)
	table.insert(state.cmds.file, {"^:tabs +(%d+)$"  , function(m) state.curr.conf.tabs   = tonumber(m[1]) end, "set tab width"  })
	table.insert(state.cmds.file, {"^:indent +(%d+)$", function(m) state.curr.conf.indent = tonumber(m[1]) end, "set indentation"})

	table.insert(state.print.post, function(lines, b)
		for i, l in ipairs(lines) do
			local spc = (" "):rep(b.conf.tabs - 1)
			lines[i] = l
				:gsub("^(\t\t\t\t\t\t)(\t+)", function(a, b) return a .. b:gsub("\t", "\x1b[37m│\x1b[0m" .. spc) end)
				:gsub("^(\t\t\t\t\t)\t", "%1\x1b[35m│\x1b[0m" .. spc)
				:gsub("^(\t\t\t\t)\t", "%1\x1b[34m│\x1b[0m" .. spc)
				:gsub("^(\t\t\t)\t", "%1\x1b[36m│\x1b[0m" .. spc)
				:gsub("^(\t\t)\t", "%1\x1b[32m│\x1b[0m" .. spc)
				:gsub("^(\t)\t", "%1\x1b[33m│\x1b[0m" .. spc)
				:gsub("^\t", "%1\x1b[31m│\x1b[0m" .. spc)
				:gsub("^(\x1b[^m]-m\t\t\t\t\t\t)(\t+)", function(a, b) return a .. b:gsub("\t", "\x1b[37m│\x1b[0m" .. spc) end)
				:gsub("^(\x1b[^m]-m\t\t\t\t\t)\t", "%1\x1b[35m│\x1b[0m" .. spc)
				:gsub("^(\x1b[^m]-m\t\t\t\t)\t", "%1\x1b[34m│\x1b[0m" .. spc)
				:gsub("^(\x1b[^m]-m\t\t\t)\t", "%1\x1b[36m│\x1b[0m" .. spc)
				:gsub("^(\x1b[^m]-m\t\t)\t", "%1\x1b[32m│\x1b[0m" .. spc)
				:gsub("^(\x1b[^m]-m\t)\t", "%1\x1b[33m│\x1b[0m" .. spc)
				:gsub("^(\x1b[^m]-m)\t", "%1\x1b[31m│\x1b[0m" .. spc)
				:gsub("\t", "\x1b[34m│\x1b[0m" .. spc)
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
		end
	end)
end

function m.pygmentize_filter(state)
	state.print.highlight = function(lines, curr)
		if curr.mode then
			local pre, main, suf = (table.concat(lines, "\n") .. "\n"):match("^(%s*)(.-\n)(%s*)$")
			if pre then
				local tmp = table.concat{pre, lib.pipe("pygmentize -P style=native -l " .. lib.shellesc(curr.mode), main), suf}
				local ret = {}
				for l in tmp:gmatch("[^\n]*") do table.insert(ret, l) end
				table.remove(ret)
				return ret
			end
			return lines
		end
		return lines
	end

	table.insert(state.cmds.file, {"^:mode +(.+)$", function(m) state.curr.mode = m[1] end, "set file type"})
end

function m.pygmentize_mode_detect(state)
	local function guess(curr)
		curr.mode = lib.pipe("pygmentize -C", table.concat(curr:all(), "\n")):match("^[^\n]*")
	end

	table.insert(state.hooks.load, function(curr)
		if curr.path and not curr.mode then
			local h <close> = io.popen("pygmentize -N " .. lib.shellesc(curr.path), "r")
			curr.mode = h:read("l")
		end
		if #curr.curr > 100 and (not curr.mode or curr.mode == "text") then guess(curr) end
	end)

	table.insert(state.cmds.file, {"^:guess$", function() guess(state.curr) end, "guess file type from content"})
end

--[[
	TODO:
	- language-specific
	- trim
	- autosave
]]

return m
