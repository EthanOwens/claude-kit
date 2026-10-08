#!/usr/bin/env bash
# Commit gate for /dev-loop. Tracks which spec task is in flight and refuses
# to move on until the user has committed it. State lives in
# .claude/state/dev-loop, which the kit's .gitignore keeps out of git.
#
#   status                 print branch, HEAD, working tree and loop state
#   begin <spec> <task-id> start a task (requires a clean working tree)
#   stage                  stage every change and wait for the user's commit
#   check-commit           succeed only once the staged task has been committed
#   abort                  forget the in-flight task (working tree untouched)
set -euo pipefail

root=$(git rev-parse --show-toplevel)
state_dir="$root/.claude/state"
state="$state_dir/dev-loop"

get() {
  if [ -f "$state" ]; then sed -n "s/^$1=//p" "$state" | head -n 1; fi
}

case "${1:-status}" in
  status)
    echo "branch: $(git branch --show-current)"
    echo "head: $(git log -1 --format='%h %s' 2>/dev/null || echo '(no commits)')"
    changes=$(git status --porcelain)
    if [ -n "$changes" ]; then
      echo "working tree: DIRTY"
      echo "$changes"
    else
      echo "working tree: clean"
    fi
    if [ -f "$state" ]; then
      echo "loop state:"
      sed 's/^/  /' "$state"
    else
      echo "loop state: none"
    fi
    ;;

  begin)
    spec=${2:?usage: begin <spec> <task-id>}
    task=${3:?usage: begin <spec> <task-id>}
    if [ "$(get phase)" = "awaiting-commit" ]; then
      echo "BLOCKED: task $(get task) is still waiting for a commit." >&2
      exit 1
    fi
    if [ -n "$(git status --porcelain)" ]; then
      echo "BLOCKED: the working tree has uncommitted changes. Commit or stash them first so this task's staged changes are only its own." >&2
      git status --short >&2
      exit 1
    fi
    mkdir -p "$state_dir"
    printf 'spec=%s\ntask=%s\nbase=%s\nphase=implementing\n' \
      "$spec" "$task" "$(git rev-parse HEAD)" > "$state"
    echo "OK: task $task started at $(git rev-parse --short HEAD)"
    ;;

  stage)
    if [ "$(get phase)" != "implementing" ]; then
      echo "BLOCKED: no task is in progress." >&2
      exit 1
    fi
    git add -A
    sed 's/^phase=.*/phase=awaiting-commit/' "$state" > "$state.tmp" && mv "$state.tmp" "$state"
    echo "Staged for task $(get task):"
    git diff --cached --stat
    ;;

  check-commit)
    if [ ! -f "$state" ]; then
      echo "OK: no task is waiting for a commit."
      exit 0
    fi
    task=$(get task)
    if [ "$(get phase)" != "awaiting-commit" ]; then
      echo "BLOCKED: task $task is in phase '$(get phase)', not waiting for a commit." >&2
      exit 1
    fi
    if [ "$(git rev-parse HEAD)" = "$(get base)" ]; then
      echo "BLOCKED: task $task has not been committed yet (HEAD is still $(git rev-parse --short HEAD))." >&2
      exit 1
    fi
    if [ -n "$(git status --porcelain)" ]; then
      echo "BLOCKED: a commit was made, but uncommitted changes remain:" >&2
      git status --short >&2
      exit 1
    fi
    echo "OK: task $task committed as $(git log -1 --format='%h %s')"
    rm -f "$state"
    ;;

  abort)
    rm -f "$state"
    echo "OK: loop state cleared. The working tree was left as it is."
    ;;

  *)
    echo "usage: loop-state.sh status | begin <spec> <task-id> | stage | check-commit | abort" >&2
    exit 2
    ;;
esac
