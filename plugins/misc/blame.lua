local lib = require "neo-ed.lib"

return function(state)
	if not state:check_executable("git", "disabling blame command") then return end

	table.insert(state.cmds.range_local, {"^:blame$", function(m, a, b)
		local contents = {}
		state.curr:inspect(function(_, l) table.insert(contents, l.text) end)
		table.insert(contents, "")
		local s = lib.pipe(
			("git --no-pager blame -L %d,%d --contents - --line-porcelain -w -M -C -- %s"):format(
				tostring(a),
				tostring(b),
				lib.shellesc(state.curr.path)
			),
			table.concat(contents, "\n")
		)

		local pos = 1
		local lines = state.curr:print_lines()

		local lw = #tostring(state.curr:length())
		local aw = 0
		local hw = tonumber(lib.pipe("git config core.abbrev || echo 7", ""))

		local r = {}
		for i = a, b do
			local row = {}
			row.n      = i
			row.hash   = s:match("(%x+)", pos)
			row.author = s:match("\nauthor ([^\n]*)\n", pos)
			row.date   = s:match("\nauthor%-time (%d+)\n", pos)
			row.text   = lines[i].text

			if row.hash:find("^0+$") then
				row.hash = row.hash:gsub("%d", " ")
				row.author = "[uncommitted]"
			end

			aw = math.max(aw, #row.author)

			local _, next = s:find("\n\t[^\n]*\n", pos)
			pos = next + 1

			table.insert(r, row)
		end

		aw = math.min(aw, 40)

		for i, row in ipairs(r) do
			local dup = not not (r[i-1] and r[i-1].hash == row.hash)
			print(("%s%s%s %s%-" .. tostring(aw) .. "." .. tostring(aw) .. "s%s %s%s%s %s%" .. tostring(lw) .. "d│%s%s"):format(
				"\x1b[36m",
				dup and "          " or os.date("%Y-%m-%d", tonumber(row.date)),
				"\x1b[0m",
				"\x1b[35m",
				dup and "" or row.author,
				"\x1b[0m",
				"\x1b[34m",
				dup and (" "):rep(hw) or row.hash:sub(1, hw),
				"\x1b[0m",
				"\x1b[33m",
				row.n,
				"\x1b[0m",
				row.text
			))
		end
	end, "run git blame"})
end
