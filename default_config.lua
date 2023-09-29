return [=[
local state = ...
local plugins = require "neo-ed.plugins"

-- enable default plugins
plugins.def(state)

-- enable extra plugins that depend on external programs

	-- depends on `pygmentize`
	--plugins.pygmentize_mode_detect(state)
	--plugins.pygmentize_filter(state)

	-- depends on `editorconfig`
	--plugins.editorconfig(state)
]=]
