local lib = require "neo-ed.lib"

return function(state)
	state:add_conf("trim", {type = "boolean", def = false, descr = "trim trailing whitespace before saving"})

	table.insert(state.hooks.save_pre, function(buf)
		if buf.conf.trim then
			buf:map(function(_, l) l.text = l.text:match("^(.-)%s*$") end)
		end
	end)


	local encodings = {
		["latin1"  ] = "ISO8859_1",
		["utf-8"   ] = "UTF-8",
		["utf-16be"] = "UTF-16BE",
		["utf-16le"] = "UTF-16LE",
	}

	state:add_conf("charset", {type = "string", def = "utf-8", descr = "encoding for reading and writing", on_set = function(buf, v) lib.assert(encodings[v], "unknown charset: " .. v); return v end})

	table.insert(state.filters.read, function(s, b)
		return lib.pipe("iconv -f " .. lib.assert(encodings[b.conf.charset], "unknown charset: " .. b.conf.charset), s)
	end)

	table.insert(state.filters.write, function(s, b)
		return lib.pipe("iconv -t " .. lib.assert(encodings[b.conf.charset], "unknown charset: " .. b.conf.charset), s)
	end)


	state:add_conf("crlf", {type = "boolean", def = false, descr = "CRLF line break mode"})

	table.insert(state.filters.read, function(s) return s:gsub("\r", "") end)

	table.insert(state.filters.write, function(s, b)
		if not b.conf.crlf then return s end
		return s:gsub("\n", "\r\n")
	end)
end
