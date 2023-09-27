local m = {}

function m.core_addr_line(state)
	table.insert(state.cmds.fst, {"^(%d+)(.*)$", function(ctx, a, s)
		ctx.a = tonumber(a)
		return state:cmd(s, ctx)
	end, "start at line number"})

	table.insert(state.cmds.snd_post, {"^,(%d*)(.*)$", function(ctx, b, s)
		ctx.b = tonumber(b) or #ned.all()
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
		for i, l in ipairs(ned.curr.curr) do
			if a <= i and i <= b then
				local pre = l:match("^(%s*)")
				ned.curr.curr[i] = ned.readline("", {l, pre})
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
		local b = ctx.b or ctx.a or (#ned.curr.prev + #ned.curr.curr + #ned.curr.next)
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

	table.insert(state.cmds.main, {"^#(%d+)$" , function(ctx, s) state.curr = assert(state.files[tonumber(s)], "no such file") end, "switch to open file"})
end

function m.core(state)
	m.core_addr_line(state)
	m.core_addr_pat (state)
	m.core_editing  (state)
	m.core_help     (state)
	m.core_state    (state)
end

return m
