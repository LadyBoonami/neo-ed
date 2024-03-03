local m = {}

local lib = require "neo-ed.lib"

function m.core(state)
	require "neo-ed.plugins.core.addr_line" (state)
	require "neo-ed.plugins.core.addr_pat"  (state)
	require "neo-ed.plugins.core.editing"   (state)
	require "neo-ed.plugins.core.help"      (state)
	require "neo-ed.plugins.core.iofmt"     (state)
	require "neo-ed.plugins.core.marks"     (state)
	require "neo-ed.plugins.core.print"     (state)
	require "neo-ed.plugins.core.settings"  (state)
	require "neo-ed.plugins.core.state"     (state)
end

function m.def(state)
	m.core(state)

	require "neo-ed.plugins.misc.align"        (state)
	require "neo-ed.plugins.misc.autocmd"      (state)
	require "neo-ed.plugins.misc.blame"        (state)
	require "neo-ed.plugins.misc.clipboard"    (state)
	require "neo-ed.plugins.misc.editorconfig" (state)
	require "neo-ed.plugins.misc.eol_filter"   (state)
	require "neo-ed.plugins.misc.fzf_picker"   (state)
	require "neo-ed.plugins.misc.pygments"     (state)
	require "neo-ed.plugins.misc.shell"        (state)
	require "neo-ed.plugins.misc.ssh_url"      (state)
	require "neo-ed.plugins.misc.tabs_filter"  (state)
end

return m
