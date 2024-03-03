return function(state)
	table.insert(state.cmds.addr.prim, {"^(%d+)(.*)$"  , function(m      ) return tonumber(m[1])                             , m[2] end, "line number"            })
	table.insert(state.cmds.addr.prim, {"^%^%^(.*)$"   , function(m      ) return 1                                          , m[1] end, "first line of file"     })
	table.insert(state.cmds.addr.prim, {"^%^(.*)$"     , function(m      ) return state.curr:sel_first()                     , m[1] end, "first line of selection"})
	table.insert(state.cmds.addr.prim, {"^%.(.*)$"     , function(m      ) return state.curr:pos()                           , m[1] end, "current line"           })
	table.insert(state.cmds.addr.prim, {"^%$%$(.*)$"   , function(m      ) return state.curr:length()                        , m[1] end, "last line of file"      })
	table.insert(state.cmds.addr.prim, {"^%$(.*)$"     , function(m      ) return state.curr:sel_last()                      , m[1] end, "last line of selection" })
	table.insert(state.cmds.addr.cont, {"^%+(%d*)(.*)$", function(m, base) return base + (m[1] == "" and 1 or tonumber(m[1])), m[2] end, "add lines"              })
	table.insert(state.cmds.addr.cont, {"^%-(%d*)(.*)$", function(m, base) return base - (m[1] == "" and 1 or tonumber(m[1])), m[2] end, "subtract lines"         })

	table.insert(state.cmds.addr.prim, {"^%+(%d*)(.*)$", function(m) return state.curr:pos() + (m[1] == "" and 1 or tonumber(m[1])), m[2] end, "current line + x"})
	table.insert(state.cmds.addr.prim, {"^%-(%d*)(.*)$", function(m) return state.curr:pos() - (m[1] == "" and 1 or tonumber(m[1])), m[2] end, "current line - x"})

	table.insert(state.cmds.addr.range, {"^%%%%(.*)$"  , function(m) return 1                     , state.curr:length()  , m[1] end, "entire file"     })
	table.insert(state.cmds.addr.range, {"^%%(.*)$"    , function(m) return state.curr:sel_first(), state.curr:sel_last(), m[1] end, "entire selection"})
end
