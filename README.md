# neo-ed

neo-ed is the new standard editor.

## Installation

Dependencies:

- Lua 5.4
- Lua `readline` bindings
- `iconv` executable
- Optional: `pygments` for syntax highlighting
- Optional: `wl-clipboard` or `xclip` for clipboard support
- Optional: `editorconfig` for Editorconfig support
- Optional: `fzf` for a nice selection dialog provider

Run `build.sh`.
This will bundle everything into an executable script called `ned`, which you can put anywhere onto your `$PATH`.

## Command Types

`neo-ed`'s commands match the following categories:

- **File** commands affect the entire file, or the global state of the editor.
  They do not take any addresses.

- **Global range** commands run on a range of lines.
  They take two addresses, and operate on every line from the first to the second addess, including them.
  If only one address is given, the second defaults to the first.
  If no address is given, the command executes on the entire file.

- **Local range** commands work like global range commands, but default to the current selection if no address is given.

- **Line range** commands work like global range commands, but default to only the current line if not address is given.

- **Line** commands run on a single line in the current selection.
  If no address is given, the command executes on the last line of the selection.

## Addressing

Commands take up to two addresses.
The address(es) are written directly before the command they affect.
Each address may be specified using exactly one line address, followed by any number of offset modifiers.

Like the original `ed`, `neo-ed` always has a "current" line.
Most commands change that "current" line to the last line they modified.
Unlike `ed`, `neo-ed` also has the concept of the current selection.
This is a range of lines that always contains the current line.
An empty command styles and prints this selection, and the `f` and `F` commands can be used to place it.

### Line Addresses

- A number stands for the line with that number.
- `^` stands for the first line of the file.
- `[` stands for the first line of the current selection.
- `.` stands for the current line.
- `]` stands for the last line of the current selection.
- `$` stands for the last line in the file.
- A `+` sign stands for the line after the current one.
- A `-` sign stands for the line before the current one.
- A number preceded by a `+` sign stands for the current line plus that number of lines.
- A number preceded by a `-` sign stands for the current line minus that number of lines.
- A lua pattern, delimited by a single punctuation character (usually `/`), stands for the first line in the file that matches that pattern.
- `'` followed by a single lowercase letter stands for the first line marked with that letter.

### Address Modifiers

- A `+` sign adds a single line to the address.
- A `-` sign subtracts a single line from the address.
- A number preceded by a `+` sign adds the given number of lines to the address.
- A number preceded by a `-` sign subtracts the given number of lines from the address.
- A lua pattern delimited by `/` characters selects the next line afterwards that matches that pattern.
- A lua pattern delimited by `\` characters selects the last line before that matches that pattern.
- `'` followed by a single lowercase letter selects the next line afterwards that is marked with that letter.
- A backtick followed by a single lowerase letter selects the last line before that is marked with that letter.

### Range Shorthands

- A `@` is short for `[,]`, i.e. the entire selection.
- A `%` is short for `^,$`, i.e. the entire file.

### Ranges

A range can be specified in the following ways:

- Specifying a single address results in a range that contains only that address.
- Two addresses separated by a `,` result in a range that contains all lines from the first through the second address.
- After an address followed by a `;`, more modifiers may be specified, resulting in a range spanning from the first address to the first address modified by the specified modifies.

## Commands

This section will only explain core commands.
For a complete overview of commands, including those installed by plugins, use the `h` command.

### File

- `h`: show command help.
- `o <path>`: open specified file.
- `e <path>`: load contents from file.
- `E <path>`: load contents from file even if modified.
- `f <path>`: set current file path.
- `q`: close file.
- `Q`: close file even if modified.
- `qq`: quit editor.
- `QQ`: quit editor even if files are modified.
- `u`: undo.
- `U`: undo via command history.
- `w`: write changes.
- `w <path>`: write changes th specified file.
- `wq`: write changes, then close file.
- `wqq`: write changes, then quit editor.
- `#<n>`: switch to open file no. `<n>`.
- `!<cmd>`: execute shell command `<cmd>`.
- `:set`: list all settings for the current file.
- `:set <k>`: print setting `<k>` with its value.
- `:set <k>=<v>`: set value of setting `<k>`.

Each file path can be a directory path prefixed by a `@` symbol to open a file picker there.

### Line

- `a`: start appending lines after the selected line.
  `Ctrl+D` to exit.
  The command history (press Up) contains the indentation prefix of the previous line.
- `F<n>`: mark line as current line, and select the surrounding `<n>` lines.
  Without `<n>`, the selection is derived from the terminal size.
- `i`: start insert lines before the selected line.
  `Ctrl+D` to exit.
  The command history (press Up) contains the indentation prefix of the next line.
- `k` removes the mark on the selected line.
- `k<x>` with some lowercase letter `<x>` marks the selected line with that letter.
- `r <filename>`: insert contents of file after the selected line.
- `r !<command>`: insert output of command after the selected line.
- `V`: paste lines from the clipboard after the selected line.

### Line Range

- `c`: replace the selected lines.
  The command history (press Up) contains the previous contents of the line, and the indentation prefix of the line.
- `d`: delete the selected lines.
- `J<sep><pattern><sep><flags>`: split the line(s) on each match of lua pattern `<pattern>`.
  `<sep>` may be any punctuation character (usually `/`).
  If `<flags>` contains `s`, prefix all new lines with the leading whitespace of the line they stem from.
- `m<addr>`: move selected lines after `<addr>`.
- `s<sep><pattern><sep><replacement><sep><mode>`: in the selected lines, replace lua pattern `<pattern>` with `<replacement>`.
  `<sep>` may be any character (usually `/`).
  Only replaces the first occurence by default.
  If `<mode>` is `g`, replaces all occurences.
  If `<mode>` is a number, replace that occurence.
- `t<addr>`: copy (transfer) selected lines after `<addr>`.
- `l`: style and print lines.
- `n`: print code prefixed with line numbers.
- `p`: print code raw.
- `C`: copy line(s) to clipboard.
- `X`: cut line(s) to clipboard.
- `|<cmd>`: pipe lines through shell command `<cmd>`.
- `>`: indent lines according to indentation settings, append number to add multiple levels.
- `<`: unindent lines according to indentation settings, append number to remove multiple levels.

### Local Range

- (empty command): style and print lines.
- `j<sep>`: join the selected lines.
  If `<sep>` is given, strip the leading whitespace of each line except the first, and replace it with `<sep>`.

### Global Range

- `S`: select the specified lines.
- `g<sep><pattern><sep><command>`: execute command `<command>` on each line that matches lua pattern `<pattern>`.
  `<sep>` may be any punctuation character (usually `/`).
- `v<sep><pattern><sep><command>`: like `g`, but execute `<command>` on every line that does NOT match `<pattern>`.
