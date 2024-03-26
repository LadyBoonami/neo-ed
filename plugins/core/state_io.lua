local lib = require "neo-ed.lib"

return function(state)
	local function e(file, force)
		return function(buf, m)
			curr.curr:change(function(buf) buf:load(file and m[1] or nil, force) end)
			curr.curr.modified = false
		end
	end

	table.insert(state.cmds.file, {"^e$"      , e(false, nil ),       "re-read buffer contents"          })
	table.insert(state.cmds.file, {"^e +(.*)$", e(true , nil ),       "replace buffer contents with file"})
	table.insert(state.cmds.file, {"^E$"      , e(false, true), "force re-read buffer contents"          })
	table.insert(state.cmds.file, {"^E +(.*)$", e(true , true), "force replace buffer contents with file"})


	local function r(file)
		return function(buf, m, a)
			local clear_modified = false
			buf:change(function(buf)
				local conf = file and buf.state:get_conf_for(m[1]) or buf.conf
				local tmp = {}
				for l in conf:path_read():gmatch("[^\n]*") do table.insert(tmp, {text = l}) end
				table.remove(tmp)
				buf:append(tmp, a)
				if file and not buf:get_path() then
					buf:set_path(m[1])
					clear_modified = true
				end
			end)
			if clear_modified then buf.modified = false end
		end
	end

	table.insert(state.cmds.line, {"^r$"      , r(false), "append text from current file after"})
	table.insert(state.cmds.line, {"^r +(.*)$", r(true ), "append text from file after"        })


	local function w(file, close)
		return function(buf, m, a, b)
			buf:save(file and m[1] or nil, a, b)
			if close == 1 then buf:close()      end
			if close == 2 then buf.state:quit() end
		end
	end

	table.insert(state.cmds.range_global, {"^w$"      , w(false, 0), "write to current file"                   })
	table.insert(state.cmds.range_global, {"^w +(.+)$", w(true , 0), "write to specified file"                 })
	table.insert(state.cmds.range_global, {"^wq$"     , w(false, 1), "write to current file, then close buffer"})
	table.insert(state.cmds.range_global, {"^wqq$"    , w(false, 2), "write to current file, then quit"        })


	local function q(force, full)
		return function(buf)
			if full then buf.state:quit(force) else buf:close(force) end
		end
	end

	table.insert(state.cmds.file, {"^q$" , q(false, false),       "close file"})
	table.insert(state.cmds.file, {"^Q$" , q(true , false), "force close file"})
	table.insert(state.cmds.file, {"^qq$", q(false, true ),       "quit"      })
	table.insert(state.cmds.file, {"^QQ$", q(true , true ), "force quit"      })


	table.insert(state.cmds.file, {"^f$"      , function(buf, m) print(buf:get_path())        end, "print file name"        })
	table.insert(state.cmds.file, {"^f +(.*)$", function(buf, m) buf:set_path(m[1])           end, "set file name"          })
	table.insert(state.cmds.file, {"^o +(.+)$", function(buf, m) buf.state:load(m[1]):print() end, "open file in new buffer"})
	table.insert(state.cmds.file, {"^u$"      , function(buf   ) buf:undo()                   end, "undo"                   })

	table.insert(state.cmds.file, {"^U$", function(buf)
		local choices = {}
		for i, v in ipairs(buf.history) do choices[#buf.history - i + 1] = tostring(i) .. "\t" .. v.__cmd end
		local c = buf.state:pick(choices)
		if not c then return end
		buf:undo(tonumber(c:match("^(%d+)\t")))
	end, "undo via command history"})

	table.insert(state.cmds.file, {"^#(%d+)$" , function(buf, m)
		buf.state.curr = lib.assert(buf.state.files[tonumber(m[1])], "no such file")
		buf.state.curr:print()
	end, "switch to open file"})

	table.insert(state.cmds.file, {"^:trace ([yn])", function(buf, m) lib.stacktraces = m[1] == "y" end, "enable stack traces for editor errors"})
end
