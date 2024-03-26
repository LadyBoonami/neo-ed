#!/bin/sh -e

function add_module() {
	local fname="$1"
	local mname="${fname%.lua}"
	mname="neo-ed.$(echo "$mname" | tr / .)"

	echo
	echo "package.loaded['$mname'] = (function()"
	sed 's/^\(.\)/	\1/' "$fname"
	echo "end)()"
}

head -n 1 "main.lua"

add_module "lib.lua"
add_module "conf.lua"
add_module "buffer.lua"
add_module "state.lua"

find plugins -type f | sort | while read -r m; do
	add_module "$m"
done

add_module "plugins.lua"

tail -n +2 "main.lua"
