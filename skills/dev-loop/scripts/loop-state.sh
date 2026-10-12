#!/usr/bin/env bash
# Commit gate for /kit:dev-loop. In a git repository it tracks which spec task
# is in flight and refuses to move on until the user has committed it. State
# lives inside .git/, so it's never tracked or shown as a change. Outside git,
# `status` reports checkpoint mode and the skill tracks progress in the spec.
#
#   status                 print the mode, branch, HEAD, working tree and loop state
#   begin <spec> <task-id> start a task (requires a clean working tree)
#   stage                  stage every change and wait for the user's commit
#   check-commit           succeed only once the staged task has been committed
#   abort                  forget the in-flight task (working tree untouched)
set -uo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # Must exit 0: the skill runs `status` before loading, and a failure aborts it.
  if [ "${1:-status}" = "status" ]; then
    echo "mode: checkpoint (not a git repository)"
    exit 0
  fi
  echo "BLOCKED: not a git repository, so there's no commit gate. Use checkpoint mode." >&2
  exit 1
fi

set -e
state="$(git rev-parse --absolute-git-dir)/kit-dev-loop"

get() {
  if [ -f "$state" ]; then sed -n "s/^$1=//p" "$state" | head -n 1; fi
}

case "${1:-status}" in
  status)
    echo "mode: git"
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
    if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
      echo "BLOCKED: the repository has no commits yet. Make an initial commit first." >&2
      exit 1
    fi
    if [ -n "$(git status --porcelain)" ]; then
      echo "BLOCKED: the working tree has uncommitted changes. Commit or stash them first so this task's staged changes are only its own." >&2
      git status --short >&2
      exit 1
    fi
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
