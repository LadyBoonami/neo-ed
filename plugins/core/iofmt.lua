local lib = require "neo-ed.lib"

return function(state)
	local encodings = {
		["latin1"  ] = "ISO8859_1",
		["utf-8"   ] = "UTF-8",
		["utf-16be"] = "UTF-16BE",
		["utf-16le"] = "UTF-16LE",
	}

	state:add_conf("charset", {
		type   = "string",
		def    = "utf-8",
		descr  = "encoding for reading and writing",
		on_set = function(_, v) lib.assert(encodings[v], "unknown charset: " .. v); return v end,
	})

	table.insert(state.filters.read, function(s, conf)
		local enc = lib.assert(encodings[conf:get("charset")], "unknown charset: " .. conf:get("charset"))
		return lib.pipe("iconv -f " .. enc, s)
	end)

	table.insert(state.filters.write, function(s, conf)
		local enc = lib.assert(encodings[conf:get("charset")], "unknown charset: " .. conf:get("charset"))
		return lib.pipe("iconv -t " .. enc, s)
	end)


	state:add_conf("end_nl", {type = "boolean", def = true, descr = "add terminating newline after last line"})

	table.insert(state.filters.read, function(s, conf)
		return s .. (conf:get("end_nl") and "" or "\n")
	end)

	table.insert(state.filters.write, function(s, conf)
		if conf:get("end_nl") then return s end
		return s:gsub("\n$", "")
	end)


	state:add_conf("trim", {type = "boolean", def = false, descr = "trim trailing whitespace before saving"})

	table.insert(state.hooks.save_pre, function(buf)
		if buf.conf:get("trim") then
			buf:map(function(_, l) l.text = l.text:match("^(.-)%s*$") end)
		end
	end)


	state:add_conf("crlf", {type = "boolean", def = false, descr = "CRLF line break mode"})

	table.insert(state.filters.read, function(s)
		return s:gsub("\r", "")
	end)

	table.insert(state.filters.write, function(s, conf)
		if not conf:get("crlf") then return s end
		return s:gsub("\n", "\r\n")
	end)
end
