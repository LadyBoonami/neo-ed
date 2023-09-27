local m = {}

function m.base_addr_line(state)
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

function m.base_addr_pat(state)
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

function m.base_editing(state)
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
end

--function m.help(state)
--	table.insert(state.cmds.main, {"^h$", function(ctx)
--		print("Line / Range Start prefix:")
--		for i, v in ipairs(ned.cmds.line) do
--			print(("    %s%-30s %s\x1b[0m"):format(i % 2 == 0 and "\x1b[34m" or "\x1b[36m", v[1]:gsub("^%^", ""):gsub("%(%.%*%)%$$", ""), v[3]))
--		end
--
--		print("\nRange end prefix:")
--		for i, v in ipairs(ned.cmds.range) do
--			print(("    %s%-30s %s\x1b[0m"):format(i % 2 == 0 and "\x1b[34m" or "\x1b[36m", v[1]:gsub("^%^", ""):gsub("%(%.%*%)%$$", ""), v[3]))
--		end
--
--		print("\nCommands:")
--		for i, v in ipairs(ned.cmds.main) do
--			print(("    %s%-30s %s\x1b[0m"):format(i % 2 == 0 and "\x1b[34m" or "\x1b[36m", v[1]:gsub("^%^", ""):gsub("%$$", ""), v[3]))
--		end
--
--		ned.skip_print = true
--	end, "show help"})
--end
