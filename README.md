# neo-ed

neo-ed is the new standard editor.

## Installation

Dependencies:

- Lua 5.4
- Lua `readline` bindings
- Optional: `pygments` for syntax highlighting
- Optional: `wl-clipboard` or `xclip` for clipboard support
- Optional: `editorconfig` for Editorconfig support
- Optional: `fzf` for a nice selection dialog provider

Put this repository into your `LUA_PATH`, and symlink `main.lua` as `ned` into your `PATH`.

## Command Types

`neo-ed`'s commands match the following categories:

- **File** commands affect the entire file, or the global state of the editor.
  They do not take any addresses.

- **Global range** commands run on a range of lines in the entire file.
  They take two addresses, and operate on every line from the first to the second addess, including them.
  If only one address is given, the second defaults to the first.
  If no address is given, the command executes on the entire file.

- **Local range** commands run on a range of lines in the current selection.
  They cannot access lines that are not currently selected.
  They take two addresses, and operate on every line from the first to the second addess, including them.
  If only one address is given, the second defaults to the first.
  If no address is given, the command executes on the entire selection.

- **Line** commands run on a single line in the current selection.
  They cannot access lines that are not currently selected.
  If no address is given, the command executes on the last line of the selection.

## Addressing

Commands take up to two addresses.
The address(es) are written directly before the command they affect.
Each address may be specified using exactly one line address, followed by any number of offset modifiers.

### Line Addresses

- A number stands for the line with that number.
- `^` stands for the first line of the current selection.
- `.` stands for the last line of the current selection.
- `$` stands for the last line in the file.
- A lua pattern, delimited by a single punctuation character (usually `/`), stands for the first line in the file that matches that pattern.
- `'` followed by a single lowercase letter stands for the first line marked with that letter.

### Address modifiers

- A `+` sign adds a single line to the address.
- A `-` sign subtracts a single line from the address.
- A number preceded by a `+` sign adds the given number of lines to the address.
- A number preceded by a `-` sign subtracts the given number of lines from the address.
- A lua pattern delimited by `/` characters selects the next line afterwards that matches that pattern.
- A lua pattern delimited by `\` characters selects the last line before that matches that pattern.
- `'` followed by a single lowercase letter selects the next line afterwards that is marked with that letter.
- A backtick followed by a single lowerase letter selects the last line before that is marked with that letter.

### Ranges

A range can be specified in the following ways:

- Specifying a single address results in a range that contains only that address.
- Two addresses separated by a `,` result in a range that contains all lines from the first through the second address.
- After an address followed by a `;`, more modifiers may be specified, resulting in a range spanning from the first address to the first address modified by the specified modifies.

## Commands

This section will only explain core commands.
For a complete overview of commands, including those installed by plugins, use the `h` command.

### File

- `h`: show command help
- `e <path>`: open specified file
- `f <path>`: set file name
- `q`: close file
- `Q`: close file even if modified
- `qq`: quit editor
- `QQ`: quit editor even if files are modified
- `u`: undo
- `w`: write changes
- `w <path>`: write changes th specified file
- `wq`: write changes, then close file
- `wqq`: write changes, then quit editor
- `#<n>`: switch to open file no. `<n>`

Each file path can be a directory path prefixed by a `@` symbol to open a file picker there.

### Line

- `a`: start appending lines after the selected line.
  `Ctrl+D` to exit.
  The command history (press Up) contains the indentation prefix of the previous line.
- `c`: replace the selected line.
  The command history (press Up) contains the previous contents of the line, and the indentation prefix of the line.
- `i`: start insert lines before the selected line.
  `Ctrl+D` to exit.
  The command history (press Up) contains the indentation prefix of the next line.
- `k` removes the mark on the selected line.
- `k<x>` with some lowercase letter `<x>` marks the selected line with that letter.
- `r <filename>`: insert contents of file after the selected line.
- `r !<command>`: insert output of command after the selected line.

### Local Range

- `d`: delete the selected lines
- `g<sep><pattern><sep><command>`: execute command `<command>` on each line that matches lua pattern `<pattern>`.
  `<sep>` may be any punctuation character (usually `/`).
- `j`: join the selected lines
- `J<sep><pattern><sep>`: split the line on each match of lua pattern `<pattern>`.
  `<sep>` may be any punctuation character (usually `/`).
- `m<addr>`: move selected lines after `<addr>`.
  `<addr>` must be outside the range of selected lines.
- `s<sep><pattern><sep><replacement><sep><mode>`: in the selected lines, replace lua pattern `<pattern>` with `<replacement>`.
  `<sep>` may be any punctuation character (usually `/`).
  Only replaces the first occurence by default.
  If `<mode>` is `g`, replaces all occurences.
  If `<mode>` is a number, replace that occurence.
- `t<addr>`: copy (transfer) selected lines after `<addr>`.
- `v<sep><pattern><sep><command>`: like `g`, but execute `<command>` on every line that does NOT match `<pattern>`.

### Global Range

- (empty command): alias for `l`
- `f`: select ("focus") the specified lines
- `l`: print code listing using formatting pipeline
- `n`: print code prefixed with line numbers
- `p`: print code raw
