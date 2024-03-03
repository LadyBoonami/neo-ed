local lib = require "neo-ed.lib"

return function(state)
	table.insert(state.cmds.file, {"^e +(.+)$", function(m) state     :load (m[1]):print() end, "open file"       })
	table.insert(state.cmds.file, {"^q$"      , function( ) state.curr:close(    )         end,       "close file"})
	table.insert(state.cmds.file, {"^Q$"      , function( ) state.curr:close(true)         end, "force close file"})
	table.insert(state.cmds.file, {"^qq$"     , function( ) state     :quit (    )         end,       "quit"      })
	table.insert(state.cmds.file, {"^QQ$"     , function( ) state     :quit (true)         end, "force quit"      })

	table.insert(state.cmds.file, {"^u$", function() state.curr:undo() end, "undo"})

	table.insert(state.cmds.file, {"^U$", function()
		local choices = {}
		for i, v in ipairs(state.curr.history) do choices[#state.curr.history - i + 1] = tostring(i) .. "\t" .. v.__cmd end
		local c = state:pick(choices)
		if not c then return end
		state.curr:undo(tonumber(c:match("^(%d+)\t")))
	end, "undo via command history"})

	table.insert(state.cmds.file, {"^w$"      , function( ) state.curr:save(    )                     end, "write changes to the current file"            })
	table.insert(state.cmds.file, {"^w +(.+)$", function(m) state.curr:save(m[1])                     end, "write changes to the specified file"          })
	table.insert(state.cmds.file, {"^wq$"     , function( ) state.curr:save(    ); state.curr:close() end, "write changes to the current file, then close"})
	table.insert(state.cmds.file, {"^wqq$"    , function( ) state.curr:save(    ); state:quit      () end, "write changes to the current file, then quit" })

	table.insert(state.cmds.file, {"^#(%d+)$" , function(m)
		state.curr = lib.assert(state.files[tonumber(m[1])], "no such file")
		state.curr:print()
	end, "switch to open file"})

	table.insert(state.cmds.file, {"^:trace ([yn])", function(m) lib.stacktraces = m[1] == "y" end, "enable stack traces for editor errors"})
end
