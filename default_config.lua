return [=[
local state = ...
local plugins = require "neo-ed.plugins"

-- enable default plugins
plugins.def(state)

-- enable extra plugins that depend on external programs

if os.execute("which pygmentize >/dev/null 2>&1") then
	plugins.pygmentize_mode_detect(state)
	plugins.pygmentize_filter(state)
end

if os.execute("which editorconfig >/dev/null 2>&1") then
	plugins.editorconfig(state)
end
]=]
