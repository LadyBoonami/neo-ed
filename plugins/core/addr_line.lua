return function(state)
	local p = state.cmds.addr.prim
	local c = state.cmds.addr.cont
	local r = state.cmds.addr.range

	table.insert(p, {"^(%d+)(.*)$"  , function(buf, m   ) return tonumber(m[1])                             , m[2] end, "line number"            })
	table.insert(p, {"^%^(.*)$"     , function(buf, m   ) return 1                                          , m[1] end, "first line of file"     })
	table.insert(p, {"^%[(.*)$"     , function(buf, m   ) return buf:sel_first()                            , m[1] end, "first line of selection"})
	table.insert(p, {"^%.(.*)$"     , function(buf, m   ) return buf:pos()                                  , m[1] end, "current line"           })
	table.insert(p, {"^%](.*)$"     , function(buf, m   ) return buf:sel_last()                             , m[1] end, "last line of selection" })
	table.insert(p, {"^%$(.*)$"     , function(buf, m   ) return buf:length()                               , m[1] end, "last line of file"      })
	table.insert(c, {"^%+(%d*)(.*)$", function(buf, m, a) return a + (m[1] == "" and 1 or tonumber(m[1]))   , m[2] end, "add lines"              })
	table.insert(c, {"^%-(%d*)(.*)$", function(buf, m, a) return a - (m[1] == "" and 1 or tonumber(m[1]))   , m[2] end, "subtract lines"         })

	table.insert(p, {"^%+(%d*)(.*)$", function(buf, m) return buf:pos() + (m[1] == "" and 1 or tonumber(m[1])), m[2] end, "current line + x"})
	table.insert(p, {"^%-(%d*)(.*)$", function(buf, m) return buf:pos() - (m[1] == "" and 1 or tonumber(m[1])), m[2] end, "current line - x"})

	table.insert(r, {"^@(.*)$"     , function(buf, m) return buf:sel_first(), buf:sel_last(), m[1] end, "entire selection"})
	table.insert(r, {"^%%(.*)$"    , function(buf, m) return 1              , buf:length()  , m[1] end, "entire file"     })
end
