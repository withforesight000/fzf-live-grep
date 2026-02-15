# fzf-live-grep

This script combines `fzf` and `rg` to search both file names and file contents under the current directory.

## Features

- Launches `fzf` in full-screen mode in the terminal
- Searches under the current directory (`-d` to change target)
  - `F\t<path>`: file name entries
  - `L\t<path>:<line>:<column>:<text>`: file content entries (`rg --vimgrep`)
- Query syntax follows `fzf`
- Line numbers in content matches are highlighted via `rg --colors`
- Opens selected results with a configurable command
  - Priority: `-o` > env: `LIVE_GREP_OPEN_CMD` > `code -g` for VSCode
  - For example:
    - zed: `-o "zed"` or `LIVE_GREP_OPEN_CMD='zed'`
    - neovim: `-o 'f="$1"; nvim "+${f##*:}" "${f%:*}"'` or `LIVE_GREP_OPEN_CMD='f="$1"; nvim "+${f##*:}" "${f%:*}"'`
    - vim: `-o 'f="$1"; vim "+${f##*:}" "${f%:*}"'` or `LIVE_GREP_OPEN_CMD='f="$1"; vim "+${f##*:}" "${f%:*}"'`
- Right-side preview powered by `bat`
- `> ` prompt is shown at the bottom

## Requirements

- `fzf`
- `rg` (ripgrep)
- `find`
- `bat` (used for preview)

## Usage

```bash
$ ./live-grep.sh -h
Usage:
  ./live-grep.sh [-d DIR] [-o "OPEN_CMD"]

Options:
  -d DIR        Search target directory (default: current directory)
  -o OPEN_CMD   Open selected result with command
                Priority: -o > env: LIVE_GREP_OPEN_CMD > "code -g" for VSCode
  -h            Show this help
```

1. Default behavior (search current directory and open with `code -g` on selection)

```bash
./live-grep.sh
```

2. Specify a target directory

```bash
./live-grep.sh -d ./src
```

3. Specify the open command

```bash
./live-grep.sh -o "code -g"
```

4. Set the default open command via environment variable

```bash
export LIVE_GREP_OPEN_CMD='f="$1"; nvim "+${f##*:}" "${f%:*}"'
./live-grep.sh
```

5. Combine `-d` and `-o`

```bash
./live-grep.sh -d ./src -o "code -g"
```

## Editor Examples

`zed` accepts `path:line`, so it can be used directly.

```bash
./live-grep.sh -o "zed"
```

`nvim` uses `+{line} {file}`, so split `$1` (`path:line`) before passing it.

```bash
./live-grep.sh -o 'f="$1"; nvim "+${f##*:}" "${f%:*}"'
```

`vim` uses the same `+{line} {file}` format.

```bash
./live-grep.sh -o 'f="$1"; vim "+${f##*:}" "${f%:*}"'
```

Using environment variables:

```bash
export LIVE_GREP_OPEN_CMD='f="$1"; nvim "+${f##*:}" "${f%:*}"'
./live-grep.sh
```

## Key Bindings

- `Enter`: select
- `Ctrl-/`: toggle preview
- `Alt-j` / `Alt-k`: scroll preview down/up
