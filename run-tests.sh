#!/bin/sh

rm -rf testenv >/dev/null 2>&1
mkdir testenv
cd testenv
mkdir neo-ed
cd neo-ed
ln -s ../../*.lua ./
ln -s ../../plugins ./
cd ..

IFS='
'
for d in $(find ../tests -type f -name script | sort | xargs dirname); do
	echo -e "\e[34m${d#../}\e[0m"
	cp "$d/input" "$d/expect" ./
	{ echo "f output"; echo "r input"; cat "$d/script"; echo "wq"; } >script
	./neo-ed/main.lua <./script >./log 2>&1 || exit 1
	diff -u expect output || exit 1
done

cd ..
rm -rf testenv >/dev/null 2>&1
