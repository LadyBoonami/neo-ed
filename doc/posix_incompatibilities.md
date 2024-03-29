# POSIX Incompatibilities

This report documents incompatibilities between `neo-ed`'s
behaviour and the required behaviour of `ed`, as specified by
[POSIX.1-2017](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/ed.html).
Not all of these incompatibilities are intended to stay, refer to the "POSIX
compatibility" section in `TODO.md` for details.

## Options

`neo-ed` does not support the options specified by POSIX. Prompt and output
are handled differently in `neo-ed`, see below.

## Environment Variables

`neo-ed` currently does not have internationalization support, and therefore
ignores all related environment variables.

## Asynchronous Events

`neo-ed` currently does not implement any signal handling. If a valid use
case arises, this can be looked at again.

## Stdout and Stderr

`neo-ed` uses stdout and stderr to communicate with the user however it sees
fit. Any requirements to print a specific output, including but not limited
to the infamous `?`, are ignored.

## Regular Expressions

Instead of regular expressions, `neo-ed` uses Lua patterns, as specified by the
[Lua 5.4 Reference Manual](https://www.lua.org/manual/5.4/manual.html#6.4.1).

`neo-ed` does not implement the "null RE shall be equivalent to the last
RE encountered" convention. The authors believe that this is unnecessarily
messy to implement, and that `neo-ed`'s command history features are a
better alternative.

## Addresses

Addresses in `neo-ed` are constructed from a base address and appended
address modifiers. This results in similar behaviour to POSIX addresses,
but some differences:

- As a base address, RE forward search starts from the beginning of the file.
- Use of a number as an address modifier without prior `+` or `-` is not
  supported.
- Specifying more addresses than the command takes is currently not supported.
- After a `;`, `neo-ed` reads further address modifiers. They are applied
  to the address specified before the semicolon to obtain the second address.

Backwards RE search is delimited by backslash characters, not question
marks. This is done to allow for the unescaped use of the question mark
within the RE, as `?` is an important modifier in Lua patterns.

Not specifying an address before or after the comma or semicolon results in
that address defaulting to the beginning and end of the current selection
respectively. Note that this is not the same as leaving out the command's
address prefix altogether.

## Commands

`neo-ed` does not currently support the print suffixes `l`, `n`, and `p`.

Instead of skipping the warning on the second `e` or `q` command, `neo-ed`
requires a `E` or `Q` command if the buffer has been modified since the
last write.

In `neo-ed`, an end-of-file in command mode is equivalent to a `qq` command,
which closes all buffers and then the editor. The end result is the same as
with POSIX `ed`.

`neo-ed` does not currently support omitting the closing delimiter of a RE
as specified.

`neo-ed` currently does not support using the delimiter character inside a
regular expression.

### Change Command

Using address 0 is not supported.

### Edit Command

Reading the stdout of a command using `e !command` is currently not
supported.

### Global Command

`neo-ed` currently does not support executing multiple commands inside a
global command.

`neo-ed` currently does not support `a`, `i`, and `c` inside global commands
in a meaningful way.

`neo-ed` has a meaningful empty command, so the global command does not
default to `p` for its command list.

### Interactive Global Command

This command is currently not supported by `neo-ed`.

### Help Command

This command is currently not supported by `neo-ed`, the `h` command has a
different meaning.

### Help-Mode Command

This command is redundant with `neo-ed`'s default behaviour, and therefore
not supported.

### Insert Command

`neo-ed` does not support the use of the zero address for the insert command.

### Join Command

`neo-ed`'s join command operates on the entire selection if no address
is specified.

### Mark Command

`neo-ed` supports multiple lines having the same mark on them. The base
address `'x` selects the first line with mark `x`. As modifiers, apostrophe
and backtick followed by a letter search for the first line with that mark
after and before the base address respectively.

### List Command

The `l` command in `neo-ed` employs the print pipeline to format the lines. In
`neo-ed`'s default settings, this format is unambiguous regarding whitespace,
but different to the format described by POSIX.

### Prompt Command

This command is redundant with `neo-ed`'s default behaviour, and therefore
not supported.

### Quit Command

The `q` command in `neo-ed` only closes the current buffer. If no buffers
remain after this, the editor is closed as well. `neo-ed` has `qq` to close
all buffers and the editor in a single command.

### Quit Without Checking Command

Just like with the `q` command, `Q` only closes a single buffer. `QQ` can
be used to immediately close all buffers and the editor without checking
for changes.

### Read Command

The `r` command currently does not set the file name if no file name is
set.

### Substitute Command

After a successful substitute command, `neo-ed` sets the last line of the
specified range as the current line.

`neo-ed` uses the Lua replacement sequences, `%n` for the `n`-th match. `&`
and `\n` are not supported, as is the special meaning of `%` as the only
letter in the replacement string.

`neo-ed` does not support using the substitute command to split lines,
a separate `J` command is provided instead.

As already stated, print suffixes are currently not supported by `neo-ed`.

### Global Non-Matched Command

See Global Command.

### Interactive Global Non-Matched Command

See Interactive Global Command.

### Write Command

If the entire buffer has been written to a named file using the `w` command,
and the remembered file name is not changed to that file by this command,
`neo-ed` does not reset the "last w command that wrote the entire buffer"
flag. This avoids a situation where the buffer contents differ from the
contents of the remembered file on disk, but the modified flag is not set,
which the authors believe is a situation that should never occur.

Using `!` to write to the standard input of a process is currently not
supported.

### Shell Escape Command

`neo-ed` currently does not support the `!!` syntax.

### Null Command

`neo-ed`s null command pretty-prints the addressed range, defaulting to the current selection. It does not change the current line.

## Exit Status

`neo-ed` always exits with value 0.
