# AGENT.md

This file provides practical guidance for coding agents working in this repository.

## Project Summary

- Main script: `live-grep.sh`
- Goal: provide a Telescope-like live grep UX using `fzf`, `rg`, and `bat`
- Docs: `README.md`

## Expected Behavior

- Launch `fzf` in full-screen mode
- Search both file names and file contents under current directory (or `-d` target)
- Show right-side preview with `bat`
- Open selected result with:
  - `-o` command if provided
  - otherwise `LIVE_GREP_OPEN_CMD` if set
  - otherwise default `code -g`

## Local Validation

Before finishing changes:

1. Run shell syntax check:
   - `bash -n live-grep.sh`
2. Confirm help output:
   - `./live-grep.sh -h`
3. If you changed docs, verify examples match actual flags and behavior.

## Editing Guidelines

- Keep the script POSIX-friendly where practical, but current implementation targets `bash`.
- Preserve existing CLI flags and precedence rules unless explicitly requested.
- Do not introduce editor-specific hardcoded behavior in script logic.
  - Document editor-specific invocation patterns in `README.md` instead.
- Keep dependencies minimal (`fzf`, `rg`, `find`, `bat`).

## Notes

- `fzf` is interactive, so full runtime behavior cannot be completely validated in non-interactive environments.
- If changing `fzf` options, ensure prompt location and preview behavior remain consistent with README.
