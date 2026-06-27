#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./live-grep.sh [-d DIR] [-o "OPEN_CMD"] [-u]

Options:
  -d DIR        Search target directory (default: current directory)
  -o OPEN_CMD   Open selected result with command
                Priority: -o > env: LIVE_GREP_OPEN_CMD > auto-detect editor > "code -g"
  -u            Do not respect VCS ignore rules (e.g. .gitignore) for rg search
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

if ! command -v bat >/dev/null 2>&1; then
  echo "error: bat is required for preview" >&2
  exit 1
fi

target_dir="."
open_cmd=""
open_cmd_source="auto"
rg_no_ignore_vcs=false

if [[ -n "${LIVE_GREP_OPEN_CMD:-}" ]]; then
  open_cmd="$LIVE_GREP_OPEN_CMD"
  open_cmd_source="env"
fi

detect_parent_editor_open_cmd() {
  local pid="${PPID:-}"
  local depth=0
  local cmd=""
  local base=""
  local ppid=""

  while [[ -n "$pid" && "$pid" != "0" && "$depth" -lt 30 ]]; do
    cmd="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    base="${cmd%% *}"
    base="${base##*/}"

    case "$cmd" in
      *"Visual Studio Code - Insiders.app"*|*"Code - Insiders"*|*"code-insiders"*)
        if command -v code-insiders >/dev/null 2>&1; then
          printf '%s\n' "code-insiders -g"
          return 0
        fi
        ;;
      *"Visual Studio Code.app"*|*"Code Helper"*)
        if command -v code >/dev/null 2>&1; then
          printf '%s\n' "code -g"
          return 0
        fi
        ;;
      *"Zed.app"*|*"zed"*)
        if command -v zed >/dev/null 2>&1; then
          printf '%s\n' "zed"
          return 0
        fi
        ;;
    esac

    case "$base" in
      code-insiders)
        if command -v code-insiders >/dev/null 2>&1; then
          printf '%s\n' "code-insiders -g"
          return 0
        fi
        ;;
      code|Code)
        if command -v code >/dev/null 2>&1; then
          printf '%s\n' "code -g"
          return 0
        fi
        ;;
      zed|Zed)
        if command -v zed >/dev/null 2>&1; then
          printf '%s\n' "zed"
          return 0
        fi
        ;;
    esac

    ppid="$(ps -p "$pid" -o ppid= 2>/dev/null || true)"
    ppid="${ppid//[[:space:]]/}"
    if [[ -z "$ppid" || "$ppid" == "$pid" ]]; then
      break
    fi
    pid="$ppid"
    depth=$((depth + 1))
  done

  return 1
}

detect_default_open_cmd() {
  if [[ -n "${TERM_PROGRAM:-}" ]]; then
    case "$TERM_PROGRAM" in
      vscode)
        if detect_parent_editor_open_cmd; then
          return 0
        fi
        if command -v code >/dev/null 2>&1; then
          printf '%s\n' "code -g"
          return 0
        fi
        ;;
      zed)
        if command -v zed >/dev/null 2>&1; then
          printf '%s\n' "zed"
          return 0
        fi
        ;;
    esac
  fi

  if [[ -n "${NVIM:-}" ]] && command -v nvim >/dev/null 2>&1; then
    printf '%s\n' 'f="$1"; file="${f%:*}"; line="${f##*:}"; printf -v q "%q" "$file"; nvim --server "$NVIM" --remote-send "<C-\><C-N>:edit +${line} ${q}<CR>"; :'
    return 0
  fi

  if [[ -n "${VIM_SERVERNAME:-}" ]] && command -v vim >/dev/null 2>&1; then
    printf '%s\n' 'f="$1"; vim --servername "$VIM_SERVERNAME" --remote-silent "+${f##*:}" "${f%:*}"; :'
    return 0
  fi

  if detect_parent_editor_open_cmd; then
    return 0
  fi

  printf '%s\n' "code -g"
}

while getopts ":d:o:uh" opt; do
  case "$opt" in
    d) target_dir="$OPTARG" ;;
    o)
      open_cmd="$OPTARG"
      open_cmd_source="cli"
      ;;
    u) rg_no_ignore_vcs=true ;;
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

if [[ "$open_cmd_source" == "auto" ]]; then
  open_cmd="$(detect_default_open_cmd)"
fi

# Build one searchable stream:
# - F\t<path> for file entries
# - L\t<colored rg path:line:text output> for content entries
build_index() {
  local -a rg_common_opts=(
    --hidden
    --glob '!.git'
  )
  local -a rg_content_opts=(
    --line-number
    --color=always
    --colors 'line:fg:cyan'
  )

  if [[ "$rg_no_ignore_vcs" == true ]]; then
    rg_common_opts+=(--no-ignore-vcs)
  fi

  rg --files "${rg_common_opts[@]}" "$target_dir" 2>/dev/null \
    | sed 's#^\./##' \
    | awk '{print "F\t" $0}'

  # rg returns exit code 1 when there is no match; treat it as non-fatal.
  rg "${rg_common_opts[@]}" "${rg_content_opts[@]}" '^' "$target_dir" 2>/dev/null \
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
  --header='Enter: select | Ctrl-/: preview toggle | Alt-w: wrap toggle | Alt-j/k or Ctrl-u/d: preview scroll' \
  --bind='ctrl-/:toggle-preview' \
  --bind='alt-w:toggle-wrap' \
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

open_selected() {
  local selected_location="$1"
  local status=0

  set +e
  case "$open_cmd" in
    *'$1'*|*'${1'*)
      bash -lc "$open_cmd" _ "$selected_location"
      status=$?
      ;;
    *)
      bash -lc "$open_cmd \"\$1\"" _ "$selected_location"
      status=$?
      ;;
  esac
  set -e

  if [[ "$status" -ne 0 ]]; then
    echo "error: failed to open selected result with: $open_cmd" >&2
    echo "hint: set LIVE_GREP_OPEN_CMD or pass -o to use a different editor command" >&2
    exit "$status"
  fi
}

# Example: ./live-grep.sh -o "code -g"
open_selected "${file}:${line}"
