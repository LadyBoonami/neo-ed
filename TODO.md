# TODO

List of tasks to complete before the next release.

## POSIX compatibility

The following incompatibilities with POSIX remain to be fixed:

### Process I/O

- read process stdout using `e !foo` (simple)
- read process stdout using `r !foo` (simple)
- write process stdin using `w !foo` (simple)

### Parser modifications

- RE escaped delimiter inside (hard to impossible to express with current regex-based parser) (hard)
- Multiple commands inside global command (hard)
- `a`, `i`, `c` inside global command (need to change how commands read their input) (very hard)

### Miscellaneous

- `s` command sets the current line to the last changed line (simple)

## Quality of life

- `e`, `r`, `w`, etc. should report number of bytes (and lines?) (simple)
- `<` and `>` should allow character repetitions, e.g. `>>` as a synonym for `>2` (simple)
- Escape control characters in print pipeline (simple)
- Allow line marks with more complex labels than single characters (moderate)
- Tutorial (moderate)
- More configurability for base functionality (e.g. theming) (simple)

## API

- Documentation of publicly available functions (moderate)
- Gutter formatting hooks (simple)
- Gutter info (simple)
- Function to print buffer with additional gutter information (e.g. git blame) (simple)
- Plugin manager (moderate)

## Plugins

- Language Server Protocol (hard)

## Cleanup

- `lib.profile_hooks`

## Someday / Maybe

- ctags plugin?
- Proper tab handling?
- More powerful `readline` replacement / bindings?
- Somehow guard against `Ctrl-C Ctrl-C` readline-induced program closing?
