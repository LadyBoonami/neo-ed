local m = {}

local lib = require "neo-ed.lib"

function m.core_addr_line(state)
	table.insert(state.cmds.fst, {"^(%d+)(.*)$", function(ctx, a, s)
		ctx.a = tonumber(a)
		return state:cmd(s, ctx)
	end, "start at line number"})

	table.insert(state.cmds.snd_post, {"^,(%d*)(.*)$", function(ctx, b, s)
		ctx.b = tonumber(b) or #state.curr:all()
		return state:cmd(s, ctx)
	end, "end at line number"})

	table.insert(state.cmds.snd, {"^%+(%d+)(.*)$", function(ctx, b, s)
		ctx.b = tonumber(b) + (ctx.a or 1)
		return state:cmd(s, ctx)
	end, "end after number of lines"})
end

function m.core_addr_pat(state)
	table.insert(state.cmds.fst, {"^(%p)(.-)%1(.*)$", function(ctx, sep, a, s)
		local tmp = state.curr:all()
		for i, l in ipairs(tmp) do
			local t = {l:match(a)}
			if t[1] then
				ctx.a  = i
				ctx.ta = t
				return state:cmd(s, ctx)
			end
		end
		error("pattern not found: " .. sep .. a .. sep)
	end, "start at first match of pattern"})

	table.insert(state.cmds.snd, {"^%+(%p)(.-)%1(.*)$", function(ctx, sep, b, s)
		local tmp = state.curr:all()
		b = b:gsub("^%%(%d)", function(i) return (ctx.ta or {})[tonumber(i)] end)
		b = b:gsub("([^%%])%%(%d)", function(c, i) return c .. (ctx.ta or {})[tonumber(i)] end)
		for i = (ctx.a or 1) + 1, #tmp do
			if not tmp[i]:find(b) then
				ctx.b = i - 1
				return state:cmd(s, ctx)
			end
		end
		ctx.b = #tmp
		return state:cmd(s, ctx)
	end, "end before first mismatch of pattern afterwards"})

	table.insert(state.cmds.snd, {"^,(%p)(.-)%1(.*)$", function(ctx, sep, b, s)
		local tmp = state.curr:all()
		b = b:gsub("^%%(%d)", function(i) return (ctx.ta or {})[tonumber(i)] end)
		b = b:gsub("([^%%])%%(%d)", function(c, i) return c .. (ctx.ta or {})[tonumber(i)] end)
		for i = (ctx.a or 1) + 1, #tmp do
			if tmp[i]:find(b) then
				ctx.b = i
				return state:cmd(s, ctx)
			end
		end
		error("pattern not found: " .. sep .. b .. sep)
	end, "end after first match of pattern afterwards"})
end

function m.core_editing(state)
	table.insert(state.cmds.main, {"^a$", function(ctx)
		state.curr:undo_point()
		local a = state.curr:addr(ctx.a, "last")
		local i = 1
		while true do
			local pre = state.curr.curr[a + i - 1] and state.curr.curr[a + i - 1]:match("^(%s*)") or ""
			local s = lib.readline("", {pre})
			if s then table.insert(state.curr.curr, a + i, s); i = i + 1 else break end
		end
	end, "append lines after (end of selection)"})

	table.insert(state.cmds.main, {"^c$", function(ctx)
		state.curr:undo_point()
		local a = state.curr:addr(ctx.a, "first")
		local b = state.curr:addr(ctx.b or ctx.a, "last")
		for i, l in ipairs(state.curr.curr) do
			if a <= i and i <= b then
				local pre = l:match("^(%s*)")
				state.curr.curr[i] = lib.readline("", {l, pre})
			end
		end
	end, "change each line (in selection)"})

	table.insert(state.cmds.main, {"^d$", function(ctx)
		state.curr:undo_point()
		local a = state.curr:addr(ctx.a, "first")
		local b = state.curr:addr(ctx.b or ctx.a, "last")
		state.curr:extract(a, b)
	end, "delete lines (entire selection)"})

	table.insert(state.cmds.main, {"^f$", function(ctx)
		local a = ctx.a or 1
		local b = ctx.b or ctx.a or (#state.curr.prev + #state.curr.curr + #state.curr.next)
		state.curr:focus(a, b)
	end, "focus lines (entire file)"})

	table.insert(state.cmds.main, {"^j$", function(ctx)
		state.curr:undo_point()
		local a = state.curr:addr(ctx.a, "first")
		local b = state.curr:addr(ctx.b or ctx.a, "last")
		local tmp = table.concat(state.curr.curr, "", a, b)
		state.curr:replace(a, b, {tmp})
	end, "join lines (selection)"})

	table.insert(state.cmds.main, {"^J(.)(.)%1$", function(ctx, _, s)
		state.curr:undo_point()
		local a = state.curr:addr(ctx.a, "first")
		local b = state.curr:addr(ctx.b or ctx.a, "last")
		local new = {}
		for _, l in ipairs(state.curr:extract(a, b)) do
			for l_ in l:gmatch("[^" .. lib.patesc(s) .. "]*") do table.insert(new, l_) end
		end
		state.curr:insert(a - 1, new)
	end, "split lines (selection) on character"})

	table.insert(state.cmds.main, {"^s(.)(.-)%1(.-)%1(.-)$", function(ctx, _, pa, pb, flags)
		state.curr:undo_point()
		local a = state.curr:addr(ctx.a, "first")
		local b = state.curr:addr(ctx.b or ctx.a, "last")
		for i, l in ipairs(state.curr.curr) do
			if a <= i and i <= b then
				if flags:find("g") then
					state.curr.curr[i] = l:gsub(pa, pb)
				else
					state.curr.curr[i] = l:gsub(pa, pb, 1)
				end
			end
		end
	end, "substitute text in the current selection using Lua gsub (entire selection)"})
end

function m.core_help(state)
	table.insert(state.cmds.main, {"^h$", function(ctx)
		local function f(t)
			for i, v in ipairs(t) do print(("    %s%-30s %s\x1b[0m"):format(i % 2 == 0 and "\x1b[34m" or "\x1b[36m", v[1]:gsub("^%^", ""):gsub("%(%.%*%)%$$", ""), v[3])) end
		end

		print("Line / Range start prefix:")
		f(state.cmds.fst)
		f(state.cmds.fst_post)

		print("\nRange end prefix:")
		f(state.cmds.snd)
		f(state.cmds.snd_post)

		print("\nCommands:")
		f(state.cmds.main)
		f(state.cmds.main_post)

		state.skip_print = true
	end, "show help"})
end

function m.core_state(state)
	table.insert(state.cmds.main, {"^e +(.+)$", function(ctx, s) state     :load (s)    end, "open file"       })
	table.insert(state.cmds.main, {"^q$"      , function(ctx   ) state.curr:close(    ) end,       "close file"})
	table.insert(state.cmds.main, {"^Q$"      , function(ctx   ) state.curr:close(true) end, "force close file"})
	table.insert(state.cmds.main, {"^qq$"     , function(ctx   ) state     :quit (    ) end,       "quit"      })
	table.insert(state.cmds.main, {"^qq$"     , function(ctx   ) state     :quit (true) end, "force quit"      })

	table.insert(state.cmds.main, {"^u$"      , function(ctx   ) state.curr:undo( )                     end, "undo"                                         })
	table.insert(state.cmds.main, {"^w$"      , function(ctx   ) state.curr:save( )                     end, "write changes to the current file"            })
	table.insert(state.cmds.main, {"^w +(.+)$", function(ctx, s) state.curr:save(s)                     end, "write changes to the specified file"          })
	table.insert(state.cmds.main, {"^wq$"     , function(ctx   ) state.curr:save( ); state.curr:close() end, "write changes to the current file, then close"})
	table.insert(state.cmds.main, {"^wqq$"    , function(ctx   ) state.curr:save( ); state:quit      () end, "write changes to the current file, then quit" })

	table.insert(state.cmds.main, {"^#(%d+)$" , function(ctx, s) state.curr = assert(state.files[tonumber(s)], "no such file") end, "switch to open file"})
end

function m.core(state)
	m.core_addr_line(state)
	m.core_addr_pat (state)
	m.core_editing  (state)
	m.core_help     (state)
	m.core_state    (state)
end

function m.align(state)
	table.insert(state.cmds.main, {"^:align *(%p)(.-)%1$", function(ctx, _, pat)
		state.curr:undo_point()
		local a = state.curr:addr(ctx.a, "first")
		local b = state.curr:addr(ctx.b or ctx.a, "last")
		local max = 0
		for i, l in ipairs(state.curr.curr) do
			if a <= i and i <= b then
				local pre = l:match("^(.-)" .. pat)
				if pre then max = math.max(max, utf8.len(pre)) end
			end
		end
		for i, l in ipairs(state.curr.curr) do
			if a <= i and i <= b then
				local pre = l:match("^(.-)" .. pat)
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

	table.insert(state.cmds.main, {"^C$", function(ctx)
		local a = state.curr:addr(ctx.a, "first")
		local b = state.curr:addr(ctx.b or ctx.a, "last")
		local h <close> = io.popen(copy_cmd, "w")
		for i, l in ipairs(state.curr.curr) do
			if a <= i and i <= b then h:write(l, "\n") end
		end
	end, "copy lines (selection)"})

	table.insert(state.cmds.main, {"^X$", function(ctx)
		state.curr:undo_point()
		local a = state.curr:addr(ctx.a, "first")
		local b = state.curr:addr(ctx.b or ctx.a, "last")
		local h <close> = io.popen(copy_cmd, "w")
		for i, l in ipairs(state.curr:extract(a, b)) do h:write(l, "\n") end
	end, "cut lines (selection)"})

	table.insert(state.cmds.main, {"^V$", function(ctx)
		state.curr:undo_point()
		local a = state.curr:addr(ctx.a, "last")
		local h <close> = io.popen(paste_cmd, "r")
		local tmp = {}
		for l in h:lines() do table.insert(tmp, l) end
		paste_filter(tmp)
		state.curr:insert(a, tmp)
	end, "paste lines after (selection)"})
end

function m.config_file(state)
	table.insert(state.cmds.main, {"^:config$", function(ctx, s) state:load(state.config_file) end, "open config file"})
end

function m.editorconfig(state)
	table.insert(state.hooks.load, function(b)
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
	end)
end

function m.eol_filter(state)
	table.insert(state.print.post, function(lines)
		for i, l in ipairs(lines) do lines[i] = l .. "\x1b[34m·\x1b[0m" end
		return lines
	end)
end

function m.find(state)
	table.insert(state.cmds.main, {"^:find *(%p)(.-)%1$", function(ctx, _, pat)
		local tmp = state.curr:all()
		local lines = {}
		for i, v in ipairs(tmp) do
			if v:find(pat) then lines[i] = true end
		end
		state.curr:print(lines)
		state.skip_print = true
	end, "search for pattern in entire file"})
end

function m.lua_cmd(state)
	table.insert(state.cmds.main, {"^:lua *(.*)$", function(ctx, s)
		assert(load(s, "interactive", "t"))()
		state.skip_print = true
	end, "execute lua command"})
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

	table.insert(state.cmds.main, {"^:mode +(.+)$", function(ctx, s) state.curr.mode = s end, "set file type"})
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

	table.insert(state.cmds.main, {"^:guess$", function(ctx) guess(state.curr) end, "guess file type from content"})
end

function m.reload(state)
	table.insert(state.cmds.main, {"^:reload$", function(ctx)
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
	table.insert(state.cmds.main, {"^!(.+)$", function(ctx, s)
		local ok, how, no = os.execute(s)
		if not ok then print(how, no) end
		state.skip_print = true
	end, "execute shell command"})

	table.insert(state.cmds.main, {"^|(.+)$", function(ctx, s)
		state.curr:undo_point()
		local a = state.curr:addr(ctx.a, "first")
		local b = state.curr:addr(ctx.b or ctx.a, "last")
		local tmp = {}
		for i, l in ipairs(state.curr.curr) do
			if a <= i and i <= b then table.insert(tmp, l) end
		end
		table.insert(tmp, "")
		tmp = table.concat(tmp, "\n")
		local ret = {}
		for l in lib.pipe(s, tmp):gmatch("[^\n]*") do table.insert(ret, l) end
		table.remove(ret)
		state.curr:replace(a, b, ret)
	end, "pipe lines (selection) through shell command"})
end

function m.tabs_filter(state)
	table.insert(state.cmds.main, {"^:tabs +(%d+)$", function(ctx, s)
		state.curr.conf.tabs = tonumber(s)
	end, "set tab width"})

	table.insert(state.cmds.main, {"^:indent +(%d+)$", function(ctx, s)
		state.curr.conf.indent = tonumber(s)
	end, "set indentation"})

	table.insert(state.print.post, function(lines, b)
		for i, l in ipairs(lines) do
			local spc = (" "):rep(b.conf.tabs - 1)
			lines[i] = l
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
	m.core                  (state)
	m.align                 (state)
	m.clipboard             (state)
	m.config_file           (state)
	m.editorconfig          (state)
	m.eol_filter            (state)
	m.find                  (state)
	m.lua_cmd               (state)
	m.pygmentize_filter     (state)
	m.pygmentize_mode_detect(state)
	m.reload                (state)
	m.shell                 (state)
	m.tabs_filter           (state)
end

--[[
	TODO:
	- language-specific
	- trim
	- autosave
]]

return m
