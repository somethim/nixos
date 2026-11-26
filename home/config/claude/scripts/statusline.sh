#!/bin/bash
input=$(cat)

model=$(echo "$input" | jq -r '.model.display_name // "unknown"')
effort=$(echo "$input" | jq -r '.effort.level // empty')
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // ""')

advisor=$(jq -r '.advisorModel // empty' ~/.claude/settings.json 2>/dev/null)
[ -z "$advisor" ] && advisor="default"

home="$HOME"
display_cwd="$cwd"
case "$cwd" in
  "$home") display_cwd="~" ;;
  "$home"/*) display_cwd="~${cwd#"$home"}" ;;
esac

branch=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short -q HEAD 2>/dev/null \
    || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
fi

C_RESET=$'\033[0m'
C_MODEL=$'\033[1;36m'
C_ADVISOR=$'\033[1;35m'
C_EFFORT=$'\033[1;33m'
C_DIM=$'\033[2m'
C_DIR=$'\033[1;32m'
C_BRANCH=$'\033[1;34m'

parts=()
parts+=("${C_MODEL}${model}${C_RESET}")
parts+=("${C_DIM}advisor:${C_RESET}${C_ADVISOR}${advisor}${C_RESET}")
if [ -n "$effort" ]; then
  parts+=("${C_DIM}effort:${C_RESET}${C_EFFORT}${effort}${C_RESET}")
fi
if [ -n "$branch" ]; then
  parts+=("${C_DIR}${display_cwd}${C_RESET} ${C_BRANCH}(${branch})${C_RESET}")
else
  parts+=("${C_DIR}${display_cwd}${C_RESET}")
fi

IFS=' | '
out=""
for i in "${!parts[@]}"; do
  if [ "$i" -eq 0 ]; then
    out="${parts[$i]}"
  else
    out="${out} ${C_DIM}|${C_RESET} ${parts[$i]}"
  fi
done

echo "$out"
