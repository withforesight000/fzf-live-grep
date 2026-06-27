# fzf-live-grep

This script combines `fzf` and `rg` to search both file names and file contents under the current directory.

## Features

- Launches `fzf` in full-screen mode in the terminal
- Searches under the current directory (`-d` to change target)
  - `F\t<path>`: file name entries
  - `L\t<path>:<line>:<text>`: file content entries (`rg --line-number`)
- Query syntax follows `fzf`
- Line numbers in content matches are highlighted via `rg --colors`
- Opens selected results with a configurable command
  - Priority: `-o` > env: `LIVE_GREP_OPEN_CMD` > auto-detect editor terminal > `code -g`
  - When possible, the default opener detects VS Code, Zed, Neovim, or Vim integrated terminals and opens the selection in that editor.
  - For example:
    - zed: `-o "zed"` or `LIVE_GREP_OPEN_CMD='zed'`
    - neovim: `-o 'f="$1"; nvim "+${f##*:}" "${f%:*}"'` or `LIVE_GREP_OPEN_CMD='f="$1"; nvim "+${f##*:}" "${f%:*}"'`
    - vim: `-o 'f="$1"; vim "+${f##*:}" "${f%:*}"'` or `LIVE_GREP_OPEN_CMD='f="$1"; vim "+${f##*:}" "${f%:*}"'`
- Right-side preview powered by `bat`
- `> ` prompt is shown at the bottom

## Requirements

- `fzf`
- `rg` (ripgrep)
- `bat` (used for preview)

## Usage

```bash
$ ./live-grep.sh -h
Usage:
  ./live-grep.sh [-d DIR] [-o "OPEN_CMD"] [-u]

Options:
  -d DIR        Search target directory (default: current directory)
  -o OPEN_CMD   Open selected result with command
                Priority: -o > env: LIVE_GREP_OPEN_CMD > auto-detect editor > "code -g"
  -u            Do not respect VCS ignore rules (e.g. .gitignore) for rg search
  -h            Show this help
```

1. Default behavior (search current directory and open in the detected editor, falling back to `code -g`)

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

6. Ignore `.gitignore` rules for file-name/content search (`rg`)

```bash
./live-grep.sh -u
```

## Editor Examples

If you run `live-grep.sh` inside a supported integrated terminal and do not pass `-o` or `LIVE_GREP_OPEN_CMD`, the script tries to pick the matching opener automatically:

- VS Code terminals: `code -g` or `code-insiders -g` when detectable and installed
- Zed terminals: `zed`
- Neovim terminals: `nvim --server "$NVIM" --remote-send ...` when `$NVIM` is available
- Vim terminals: `vim --servername "$VIM_SERVERNAME" --remote-silent ...` when `$VIM_SERVERNAME` is available

The auto-detection is best-effort. Use `-o` or `LIVE_GREP_OPEN_CMD` when your editor setup needs a specific command.

Open commands receive the selected location as `path:line`. Simple commands such as `code -g` or `zed` get it appended automatically; shell snippets can read it from `$1`.

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
- `Alt-w`: toggle result list wrap
- `Alt-j` / `Alt-k`: scroll preview down/up
- `Ctrl-d` / `Ctrl-u`: preview half-page down/up
