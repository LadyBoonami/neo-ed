local lib = require "neo-ed.lib"

return function(state)
	table.insert(state.cmds.line, {"^a$", function(m, a)
		state.curr:change(function(buf)
			buf:seek(a)
			while true do
				local pre = buf:scan_r(function(_, l) return l.text ~= "" and l.text:match("^(%s*)") or nil end, buf:pos()) or ""
				local s = buf:get_input({pre})
				if s then buf:insert({text = s}) else break end
			end
		end)
	end, "append lines after"})

	table.insert(state.cmds.line, {"^c$", function(m, a)
		state.curr:change(function(buf)
			buf:seek(a)
			local pre = buf:scan_r(function(_, l) return l.text ~= "" and l.text:match("^(%s*)") or nil end, buf:pos()) or ""
			buf:modify(function(n, l) l.text = buf:get_input({pre, l.text}) end)
		end)
	end, "change line"})

	table.insert(state.cmds.range_line, {"^d$", function(m, a, b)
		state.curr:change(function(buf)
			buf:drop(a, b)
		end)
	end, "delete lines (entire selection)"})

	table.insert(state.cmds.range_global, {"^([gv])(.)(.-)%2(.*)$", function(m, a, b)
		state.curr:change(function(buf)
			buf:map(function(_, l)
				if m[1] == "g" and     l.text:find(m[3])
				or m[1] == "v" and not l.text:find(m[3]) then
					l.g_mark = true
				end
			end, a, b)
			buf:seek(a)
			while true do
				local pos = buf:scan(function(n, l) return l.g_mark and n or nil end, buf:pos(), b)
				if not pos then break end
				buf:seek(pos)
				buf:modify(function(n, l) l.g_mark = nil end)
				state:cmd(m[4])
			end
		end)
	end, "perform command on every (non-)matching line"})

	table.insert(state.cmds.line, {"^i$", function(m, a)
		state.curr:change(function(buf)
			local first = true
			buf:seek(a)
			while true do
				local pre = buf:scan_r(function(_, l) return l.text ~= "" and l.text:match("^(%s*)") or nil end, buf:pos() + 1) or ""
				local s = buf:get_input({pre})
				if s then
					if first then buf:seek(a - 1) end
					first = false
					buf:insert({text = s})
				else
					break
				end
			end
		end)
	end, "insert lines before"})

	table.insert(state.cmds.range_local, {"^j(.*)$", function(m, a, b)
		state.curr:change(function(buf)
			local tmp = {}
			buf:inspect(function(_, l)
				local strip = #tmp > 0 and m[1] ~= ""
				table.insert(tmp, strip and l.text:match("^%s*(.*)$") or l.text)
			end, a, b)
			buf:drop(a, b)
			buf:seek(a - 1)
			buf:insert({text = table.concat(tmp, m[1])})
		end)
	end, "join lines"})

	table.insert(state.cmds.range_line, {"^J(.)(.*)%1(s?)$", function(m, a, b)
		state.curr:change(function(buf)
			local new = {}
			buf:inspect(function(_, l)
				local prefix = ""
				for l_ in l.text:gsub(m[2], "\n"):gmatch("[^\n]*") do
					table.insert(new, {text = prefix .. l_})
					prefix = m[3] == "s" and l.text:match("^%s*") or ""
				end
			end, a, b)
			buf:drop(a, b)
			buf:append(new, a - 1)
		end)
	end, "split lines on pattern"})

	table.insert(state.cmds.range_line, {"^m(.*)$", function(m, a, b)
		state.curr:change(function(buf)
			local dst = buf:addr(m[1])
			if dst > b then dst = dst - (b - a + 1)
			elseif dst > a then lib.error("destination inside source range")
			end

			local tmp = buf:extract(a, b)
			buf:drop(a, b)
			buf:append(tmp, dst)
		end)
	end, "move lines"})

	table.insert(state.cmds.range_line, {"^s(.)(.-)%1(.-)%1(.-)$", function(m, a, b)
		state.curr:change(function(buf)
			local ctr = 0
			buf:seek(b)
			buf:map(function(_, l)
				local ctr_ = 0
				if m[4]:find("g") then
					l.text, ctr_ = l.text:gsub(m[2], m[3])
				elseif tonumber(m[4]) then
					local pos = lib.find_nth(l.text, m[2], tonumber(m[4]))
					if pos then
						local tmp
						tmp, ctr_ = l.text:sub(pos):gsub(m[2], m[3], 1)
						l.text = l.text:sub(1, pos - 1) .. tmp
					end
				elseif m[4] == "" then
					l.text, ctr_ = l.text:gsub(m[2], m[3], 1)
				else
					lib.error("could not parse flags: " .. m[4])
				end
				ctr = ctr + ctr_
			end, a, b)
			if ctr == 0 then lib.error("substitution failed") end
		end)
	end, "substitute text using Lua gsub"})

	table.insert(state.cmds.range_line, {"^t(.*)$", function(m, a, b)
		state.curr:change(function(buf)
			local dst = buf:addr(m[1])
			buf:append(buf:extract(a, b), dst)
		end)
	end, "copy (transfer) lines"})

	table.insert(state.cmds.range_line, {"^>(%d*)$", function(m, a, b)
		local indent = "\t"
		if state.curr.conf.tab2spc then indent = (" "):rep(state.curr.conf.indent) end
		state:cmd(a .. "," .. b .. "s/^/" .. indent:rep(tonumber(m[1]) or 1) .. "/")
	end, "indent lines (by amount of steps)"})

	table.insert(state.cmds.range_line, {"^<(%d*)$", function(m, a, b)
		state.curr:change(function(buf)
			local indent = "\t"
			if state.curr.conf.tab2spc then indent = (" "):rep(state.curr.conf.indent) end
			for i = 1, tonumber(m[1]) or 1 do state:cmd(a .. "," .. b .. "s/^" .. indent .. "//") end
		end)
	end, "indent lines (by amount of steps)"})

	table.insert(state.cmds.line, {"^=$", function(m, a)
		print(a)
	end, "print line number of addressed line"})

	table.insert(state.hooks.input_post, function(l, buf)
		if not buf.conf.tab2spc then return l end
		local spc = (" "):rep(buf.conf.indent)
		return l:gsub("\t", spc)
	end)
end
