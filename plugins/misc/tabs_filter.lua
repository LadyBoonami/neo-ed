local lib = require "neo-ed.lib"

local color = {
	function(s) return "\x1b[31m" .. s .. "\x1b[0m" end,
	function(s) return "\x1b[33m" .. s .. "\x1b[0m" end,
	function(s) return "\x1b[32m" .. s .. "\x1b[0m" end,
	function(s) return "\x1b[36m" .. s .. "\x1b[0m" end,
	function(s) return "\x1b[34m" .. s .. "\x1b[0m" end,
	function(s) return "\x1b[35m" .. s .. "\x1b[0m" end,
}

local function superscript(s)
	return (s
		:gsub("0", "⁰")
		:gsub("1", "¹")
		:gsub("2", "²")
		:gsub("3", "³")
		:gsub("4", "⁴")
		:gsub("5", "⁵")
		:gsub("6", "⁶")
		:gsub("7", "⁷")
		:gsub("8", "⁸")
		:gsub("9", "⁹")
	)
end

local function indentlvl(width, lvl, pre, num, suf)
	local ret = {}
	local rem = width - utf8.len(pre) - utf8.len(suf)
	local lvls = tostring(lvl)
	local lw  = #lvls
	local col = color[(lvl - 1) % 6 + 1]
	table.insert(ret, pre)
	if num and rem >= lw then
		for i = 1, rem - lw do table.insert(ret, " ") end
		table.insert(ret, superscript(lvls))
	else
		for i = 1, rem do table.insert(ret, " ") end
	end
	table.insert(ret, suf)
	return col(table.concat(ret))
end

return function(state)
	state:add_conf("elastic_tabstops", {
		type = "boolean",
		def = false,
		descr = "Enable elastic tabstops",
		drop_cache = true,
	})

	table.insert(state.print.pre, function(lines, b)
		if b.conf:get("elastic_tabstops") then
			local tbl    = {}
			local widths = {}

			for _, l in ipairs(lines) do
				local cols = {}
				local i = 1

				for c in l.text:gmatch("([^\t]*)") do
					-- table with single member as substitute for a pointer
					widths[i] = widths[i] or {0}

					table.insert(cols, {text = c, width = widths[i]})
					i = i + 1
				end

				table.insert(tbl, cols)

				for j = #widths, i, -1 do widths[j] = nil end
				if l.text == "" then widths[1] = nil end
			end

			for _, l in ipairs(tbl) do
				for i = 1, #l - 1 do
					l[i].width[1] = math.max(l[i].width[1], utf8.len(l[i].text) + b.conf:get("tabs"))
				end
			end

			for i, l in ipairs(tbl) do
				local col = {}
				for j, c in ipairs(l) do
					table.insert(col, j == #l and c.text or lib.pad(c.text, c.width[1], true))
				end
				lines[i].text = table.concat(col)
			end
		end
	end)

	table.insert(state.print.post, function(lines, b)
		if not b.conf:get("elastic_tabstops") then
			local last = 0
			local had = false

			local conf_indent = b.conf:get("indent")
			local conf_tabs   = b.conf:get("tabs")

			local function spcs(wsp, t, i)
				had = true
				t = t or {}
				i = i or 0
				if #wsp < conf_indent then
					table.insert(t, wsp)
					last = -i
					return table.concat(t)
				end
				local num = #wsp < 2*conf_indent
				if num and i+1 <= -last then num = false end
				table.insert(t, indentlvl(conf_indent, i + 1, "", num, "┆"))
				return spcs(wsp:sub(conf_indent + 1), t, i + 1)
			end

			local tab = (" "):rep(conf_tabs - 2)
			local tab_ = (conf_tabs > 1 and "·" or "") .. (" "):rep(conf_tabs - 2) .. "│"
			local function tabs(wsp, t, i)
				had = true
				t = t or {}
				i = i or 0
				if wsp == "" then
					last = i
					return table.concat(t)
				end
				if wsp:find("^ ") then
					table.insert(t, wsp)
					last = i
					return table.concat(t)
				end
				local num = #wsp < 2 or wsp:find("^\t ")
				if num and i+1 <= last then num = false end
				table.insert(t, indentlvl(conf_tabs, i + 1, "", num, "│"))
				return tabs(wsp:sub(2), t, i + 1)
			end

			local function distrib(wsp)
				if wsp:find("^\t") then return tabs(wsp) else return spcs(wsp) end
			end

			for i, l in ipairs(lines) do
				had = false
				lines[i].text = l.text
					:gsub("^(\x1b[^m]-m)([\t ]+)", function(pre, wsp) return distrib(wsp) .. pre end)
					:gsub(            "^([\t ]+)", function(     wsp) return distrib(wsp)        end)
					:gsub("\t", tab_)
				if not had then last = 0 end
			end

		end
	end)
end
