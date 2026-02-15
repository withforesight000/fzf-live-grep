#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./live-grep.sh [-d DIR] [-o "OPEN_CMD"]

Options:
  -d DIR        Search target directory (default: current directory)
  -o OPEN_CMD   Open selected result with command
                Priority: -o > env: LIVE_GREP_OPEN_CMD > "code -g" for VSCode
  -h            Show this help
EOF
}

if ! command -v fzf >/dev/null 2>&1; then
  echo "error: fzf is required" >&2
  exit 1
fi

if ! command -v rg >/dev/null 2>&1; then
  echo "error: rg (ripgrep) is required" >&2
  exit 1
fi

if ! command -v find >/dev/null 2>&1; then
  echo "error: find is required" >&2
  exit 1
fi

if ! command -v bat >/dev/null 2>&1; then
  echo "error: bat is required for preview" >&2
  exit 1
fi

target_dir="."
open_cmd="${LIVE_GREP_OPEN_CMD:-code -g}"

while getopts ":d:o:h" opt; do
  case "$opt" in
    d) target_dir="$OPTARG" ;;
    o) open_cmd="$OPTARG" ;;
    h)
      usage
      exit 0
      ;;
    :)
      echo "error: option -$OPTARG requires an argument" >&2
      usage >&2
      exit 1
      ;;
    \?)
      echo "error: invalid option -$OPTARG" >&2
      usage >&2
      exit 1
      ;;
  esac
done

shift $((OPTIND - 1))

if [[ "$#" -gt 0 ]]; then
  echo "error: unexpected positional arguments: $*" >&2
  usage >&2
  exit 1
fi

if [[ ! -d "$target_dir" ]]; then
  echo "error: directory not found: $target_dir" >&2
  exit 1
fi

# Build one searchable stream:
# - F\t<path> for file entries
# - L\t<colored rg path:line:text output> for content entries
build_index() {
  find "$target_dir" -type f -not -path '*/.git/*' -print \
    | sed 's#^\./##' \
    | awk '{print "F\t" $0}'

  # rg returns exit code 1 when there is no match; treat it as non-fatal.
  rg --line-number --color=always \
    --colors 'line:fg:cyan' \
    --hidden --glob '!.git' '^' "$target_dir" 2>/dev/null \
    | sed 's#^\./##' \
    | awk '{print "L\t" $0}' \
    || true
}

preview_cmd="$(cat <<'EOF'
bash -c '
line="${1-}"
if [[ -z "$line" ]]; then
  exit 0
fi
kind="${line%%$'\''\t'\''*}"
body="${line#*$'\''\t'\''}"

if [[ "$kind" == "F" ]]; then
  file="$body"
  bat --style=numbers --color=always --line-range=:300 -- "$file"
  exit 0
fi

raw="$(printf "%s\n" "$body" | sed -E "s/\x1B\\[[0-9;]*m//g")"
file="${raw%%:*}"
rest="${raw#*:}"
lineno="${rest%%:*}"
if [[ -z "$lineno" || ! "$lineno" =~ ^[0-9]+$ ]]; then
  lineno=1
fi

start=$((lineno-20))
if (( start < 1 )); then start=1; fi
end=$((lineno+40))
bat --style=numbers --color=always --highlight-line "$lineno" --line-range "${start}:${end}" -- "$file"
' _ {}
EOF
)"

set +e
selected="$({ build_index; } | fzf \
  --ansi \
  --delimiter='\t' \
  --with-nth=2.. \
  --prompt='> ' \
  --layout=default \
  --border \
  --cycle \
  --info=inline-right \
  --header='Enter: select | Ctrl-/: preview toggle | Alt-j/k or Ctrl-u/d: preview scroll' \
  --bind='ctrl-/:toggle-preview' \
  --bind='alt-j:preview-down' \
  --bind='alt-k:preview-up' \
  --bind='ctrl-d:preview-half-page-down' \
  --bind='ctrl-u:preview-half-page-up' \
  --preview-window='right,50%,border-left' \
  --preview "$preview_cmd")"
fzf_status=$?
set -e

if [[ "$fzf_status" -ne 0 ]]; then
  # 1: no match, 130: cancelled (Esc/Ctrl-C)
  if [[ "$fzf_status" -eq 1 || "$fzf_status" -eq 130 ]]; then
    exit 0
  fi
  echo "error: fzf failed (exit $fzf_status)" >&2
  echo "hint: run in an interactive terminal and check fzf version/options compatibility" >&2
  exit "$fzf_status"
fi

# no selection / cancelled
if [[ -z "${selected:-}" ]]; then
  exit 0
fi

kind="${selected%%$'\t'*}"
body="${selected#*$'\t'}"

file=""
line=""
if [[ "$kind" == "F" ]]; then
  file="$body"
  line="1"
else
  raw="$(printf "%s\n" "$body" | sed -E "s/\x1B\\[[0-9;]*m//g")"
  file="${raw%%:*}"
  rest="${raw#*:}"
  line="${rest%%:*}"
  if [[ -z "$line" || ! "$line" =~ ^[0-9]+$ ]]; then
    line="1"
  fi
fi

# Example: ./live-grep.sh -o "code -g"
bash -lc "$open_cmd \"\$1\"" _ "${file}:${line}"
