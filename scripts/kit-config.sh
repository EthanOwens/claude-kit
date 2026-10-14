#!/usr/bin/env bash
# Kit settings: built-in defaults, then the user file, then the project file;
# later files win. Files hold `key=value` lines so this needs nothing but bash.
#
#   show                          effective settings, with where each value came from
#   get <key>                     one effective value
#   set [--project] <key> <value> save to the user file (or the project file)
#   unset [--project] <key>       remove a saved value
#   files                         print the user and project file paths
set -uo pipefail

user_file="${HOME}/.claude/kit/config"
if root=$(git rev-parse --show-toplevel 2>/dev/null); then :; else root="$PWD"; fi
project_file="$root/.claude/kit.config"

defaults() {
  cat <<'EOF'
implementer.model=sonnet
implementer.effort=medium
implementer.retry_model=opus
reviewer.model=sonnet
reviewer.effort=medium
tester.model=claude-haiku-5-5
tester.effort=low
tester.mode=auto
EOF
}

valid() {
  local key=$1 value=$2
  case "$key" in
    implementer.model|reviewer.model|tester.model)
      [[ "$value" =~ ^(inherit|haiku|sonnet|opus|fable|claude-[a-z0-9.-]+)$ ]] ;;
    implementer.retry_model)
      [[ "$value" =~ ^(off|inherit|haiku|sonnet|opus|fable|claude-[a-z0-9.-]+)$ ]] ;;
    implementer.effort|reviewer.effort|tester.effort)
      [[ "$value" =~ ^(low|medium|high|xhigh|max)$ ]] ;;
    tester.mode)
      [[ "$value" =~ ^(auto|always|off)$ ]] ;;
    *) return 1 ;;
  esac
}

value_in() { [ -f "$2" ] && sed -n "s/^$1=//p" "$2" | tail -n 1; }

effective() {
  local key=$1 v source=default
  v=$(defaults | sed -n "s/^$key=//p")
  local u p
  u=$(value_in "$key" "$user_file"); [ -n "$u" ] && { v=$u; source=user; }
  p=$(value_in "$key" "$project_file"); [ -n "$p" ] && { v=$p; source=project; }
  printf '%s\t%s\n' "$v" "$source"
}

write() {
  local file=$1 key=$2 value=${3-}
  mkdir -p "$(dirname "$file")"
  touch "$file"
  grep -v "^$key=" "$file" > "$file.tmp" || true
  [ -n "$value" ] && echo "$key=$value" >> "$file.tmp"
  mv "$file.tmp" "$file"
}

case "${1:-show}" in
  show)
    echo "kit settings (default < user < project):"
    defaults | cut -d= -f1 | while read -r key; do
      IFS=$'\t' read -r v source < <(effective "$key")
      printf '  %-26s %-20s (%s)\n' "$key" "$v" "$source"
    done
    echo "  ponytail.subagents         ${PONYTAIL_SUBAGENT_MATCHER:-<all subagents, or ponytail not installed>} (env PONYTAIL_SUBAGENT_MATCHER)"
    ;;
  get)
    key=${2:?usage: get <key>}
    effective "$key" | cut -f1
    ;;
  set|unset)
    cmd=$1; shift
    file=$user_file
    if [ "${1:-}" = "--project" ]; then file=$project_file; shift; fi
    key=${1:?usage: $cmd [--project] <key> [value]}
    if ! defaults | grep -q "^$key="; then
      echo "ERROR: unknown setting '$key'. Known: $(defaults | cut -d= -f1 | tr '\n' ' ')" >&2; exit 1
    fi
    if [ "$cmd" = "set" ]; then
      value=${2:?usage: set [--project] <key> <value>}
      if ! valid "$key" "$value"; then echo "ERROR: '$value' isn't a valid value for $key." >&2; exit 1; fi
      write "$file" "$key" "$value"
      echo "OK: $key=$value saved in $file"
    else
      write "$file" "$key"
      echo "OK: $key removed from $file"
    fi
    ;;
  files)
    echo "user: $user_file"
    echo "project: $project_file"
    ;;
  *)
    echo "usage: kit-config.sh show | get <key> | set [--project] <key> <value> | unset [--project] <key> | files" >&2
    exit 2
    ;;
esac
