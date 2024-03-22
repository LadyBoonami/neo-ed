local main = [==[
Before We Begin
===============

If the text does not fit onto your screen in its entirety, use <LineNumber>F
to jump down a bit. This will show the text around the selected line number.

1. Try to focus around line 10 now.

To view the solution for task <n>, enter `'x+<n>`, e.g. `'x+1` for task 1.



From now on, commands will always be surrounded by ` characters. They are
_not_ part of the command and should not be entered into the command prompt.

If you want to quit, the command `QQ` will unconditionally close the editor
at any time.

Finally, if you want a quick refresher, the `h` ("help") command will give
you an overview over all available commands and addresses.



Line Editing, Command Anatomy
=============================

neo-ed is a _line editor_. As such, it works by executing commands on lines
of text.  Commands entered into the prompt can be prefixed by up to two
addresses to specify the range they operate on.  How many addresses the
command takes depends on the kind of command, as do the default addresses
if not explicitly given.  The `F` command you already used takes a single
address, and defaults to the _current line_.

An _empty command_ pretty-prints the given line range. With no address given,
the _current selection_ is printed. With one address given, only that line is
printed. With two addresses given, those two lines as well as all the lines
between them are printed. Unlike most commands, the empty command does _not_
change the current line.

In general, commands that take two addresses always operate on those two
lines as well as all those between them.

Try to print the following:

2. The selection
3. Just the line containing the current heading (line 24)
4. The first paragraph in this section

To view the solution for task <n>, enter `'x+<n>`, e.g. `'x+1` for task 1.



The Current Line
================

neo-ed always has a _current line_. This line has its line number highlighted,
and is the default address for many commands.  Also, most commands change
the current line to the last line they touched.  The easiest way to change
the current line without doing anything else is to use the `p` command,
which prints the addressed lines verbatim.

The special address `.` (a single dot) stands for the current line.

5. Try to change the current line to this line.

6. Try to print the current line with the `p` command, by specifying the
   aforementioned address.

To view the solution for task <n>, enter `'x+<n>`, e.g. `'x+1` for task 1.



The Selection
=============

neo-ed always has a number of lines selected. This range always contains
the current line.  The selection is the default range for the empty command,
and some others.  The selection is changed by the following commands:

 - The `F` command selects text around the specified line. By default,
   the amount of lines is chosen based on the terminal size, but a number of
   context lines can also be specified explicitly, e.g. `F10` will select the
   specified line, and 10 lines above and below that.

 - The `S` command selects the given range of lines directly. The last line
   is also set as the current line.

Try the following:

7. Select the heading of this section, plus three lines above and below
8. Select the first paragraph of this section

To view the solution for task <n>, enter `'x+<n>`, e.g. `'x+1` for task 1.



Adding Text
===========

The command `a` starts appending text _after_ the specified line. Likewise
`i` starts inserting text _before_ the specified line.  They keep reading
more lines to be inserted, until you press `Ctrl-D` after entering the last
line. This will only work at the start of a line, pressing Ctrl-D in the
middle of a line will not work!

The original ed also accepts a period on a line by itself as the end of
input. neo-ed does not follow this convention.

After any command that changes the buffer, the differences between the old
and new buffer state are shown.  Old lines are framed in red, new lines are
framed in green.  If you made a mistake, the command `u` undoes the last
command that changed the buffer.

9. Try to append some text after this line.

10. Try to insert some text before this line.

11. Try to undo those changes.

To view the solution for task <n>, enter `'x+<n>`, e.g. `'x+1` for task 1.



Changing Text
=============

The command `c` changes the specified line, by replacing the contents of the
specified line by the text you enter.  Unlike `a` and `i`, this command only
reads a single line.

12. Try to fill out the following:

My favourite web browser is
[change here]

To view the solution for task <n>, enter `'x+<n>`, e.g. `'x+1` for task 1.



Command History and Editing History
===================================

Similar to many shells, neo-ed uses a command history, accessed by pressing
the "up" key.  This history feature is also used by the `a`, `i` and `c`
commands to help with editing:

 - `c` adds the previous contents of the line to be changed, as well as only
   its leading indentation, to the history.

 - `a` and `i` add the leading whitespace of the last line to the history.

13. Try to fill out the following, without typing the entire text again:

My favourite web browser is [change here]

To view the solution for task <n>, enter `'x+<n>`, e.g. `'x+1` for task 1.



Replacing Text
==============

One of the most important, but also complex commands is the _substitute
command_ `s`. It is formed by the following components, appended together
without text:

 - The letter `s`
 - The separator, which can be any single character
 - A Lua pattern
 - The separator character again
 - A Lua replacement string
 - The separator character again
 - Flags

Lua patterns operate like regular expressions, but have a few key
differences to common regex flavous.  A quick reference is available
under the `h patterns` command.  Further details can be found under
https://www.lua.org/manual/5.4/manual.html#6.4.1 .

Neither the pattern nor the replacement may contain the separator character.

The command operates as follows:

 - On every line specified, the Lua `string.gsub` function is called with
   the pattern and replacement as arguments.
 - By default, the first occurence of the pattern in every line is substituted.
 - If the flags section contains a number, that occurence is substituted instead.
 - If the flags section contains the letter `g`, every occurence is substituted.

 - The pattern may contain capture groups, delimited by `(` and `)`.
 - The sequence `%n` with any single digit `n` in the replacement string is
   replaced by the `n`-th capture group. The first capture group is `%1`.
 - If the pattern contains no capture groups, `%1` in the replacement string
   is replaced by the entire text matched by the pattern.

Some examples:

 - `s/test/toast/` replaces the first occurence of "test" with "toast"
 - `s.test.toast.` does the same
 - `s/test/toast/2` replaces the second occurence of "test" with "toast"
 - `s/test/toast/g` replaces every occurence of "test" with "toast"
 - `s/TODO//` deletes the word "TODO" from the line
 - `s/^/    /` indents the line by four spaces
 - `s/%.$/!/` replaces the period at the end of the sentence with an exclamation point
 - `s/a good ([^ ]+)/a very good %1 indeed/` emphasizes the point

14. Try to fill out the following sentence using the `s` command:

__________ is my favourite text editor!

To view the solution for task <n>, enter `'x+<n>`, e.g. `'x+1` for task 1.



Joining and Splitting Lines
===========================

Joining and splitting lines is done using special commands:

- `j` joins all specified lines together. If any text follows the `j`,
  the indentation of all lines except the first is replaced by that text
  before joining them together.

- `J/<RE>/<flags>` splits lines on every match of the Lua pattern
  `<RE>`. `<flags>` can either be empty, or contain the letter `s`, in which
  case every line after the first receives the first line's indentation.
  In case there is no convenient pattern to match, it can be helpful to
  first place some kind of split marker using `c`, then match it with `J`.

Try the following:

15. Split the following table so that every key-value pair is on its own
    line, and the brackets are on their own lines as well. Indentation should
    be preserved. You can indent the inner lines further using the `>` command.
    (Tip: match the Lua frontier pattern `%f[%[}]`)

	local tbl = {[1] = true, [2] = true, [3] = true,}

16. Join the following lines together. There should be exactly one space
    after each comma.

	local tbl = {
		[1] = true,
		[2] = true,
		[3] = true,
	}

To view the solution for task <n>, enter `'x+<n>`, e.g. `'x+1` for task 1.



Copying and Moving Lines
========================

**TODO**



Line Marks
==========

**TODO**



Reading and Writing Files
=========================

**TODO**



Advanced Addresses
==================

**TODO**
]==]

local solutions = [==[
10F
(the empty command)
24
27,32
64p
.p
73F3
76,78S
114a
116i
u
c
c (then press up once)
s/_+/neo-ed/
J/%f[%]}]/s
j 
]==]

local suffix = [==[
Welcome to the neo-ed tutorial!
===============================

neo-ed is operated by commands entered into the command prompt below. It
looks like this:

 >

Please enter the following text and press Enter to begin:

1F
]==]

return function(state)
	table.insert(state.cmds.file, {"^:tutorial", function()
		local b = state:load()

		for l in main:gmatch("[^\n]*") do b:insert({text = l}) end
		for i = 1, 200 do b:insert({text = ""}) end
		b:insert({text = "Solutions:", mark = "x"})
		for l in solutions:gmatch("[^\n]*") do b:insert({text = l}) end
		for i = 1, 200 do b:insert({text = ""}) end
		for l in suffix:gmatch("[^\n]*") do b:insert({text = l}) end

		b:conf_set("pygments_mode", "markdown")
		b:print()
	end, "open tutorial"})
end
