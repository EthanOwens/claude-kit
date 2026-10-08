# Claude Code dev-loop kit

A portable `/spec` → `/dev-loop` workflow. Nothing in this folder is specific to one project.

## Install

Pick one:

- **Copy**: drop this folder into a project as `.claude/`.
- **Git submodule**: from the project root, `git submodule add <kit-repo-url> .claude`, then commit. The project must not already have a `.claude/` folder.

Then make sure the project's `CLAUDE.md` has a `## Verification` section listing the commands that must pass after every change. `/spec` offers to add it if it's missing.

### Working with the submodule

- Clone a project that uses the kit: `git clone --recurse-submodules <project-url>`, or run `git submodule update --init` in an existing clone.
- Pull kit updates into a project: `git submodule update --remote .claude`, then commit the changed `.claude` pointer in the project.
- To edit the kit from inside a project, run `cd .claude && git switch main` first (submodules check out a detached HEAD), then commit and push from there.

## Roles

| Role | Where it runs | Job |
|---|---|---|
| Coordinator | Your session, through `/dev-loop` | Picks the task, starts the other agents, updates the spec, stages, and waits for your commit. Runs in your session because it has to ask you questions and stop for commits. |
| Implementer | `agents/dev-loop-implementer.md`, fresh context | Builds one task and runs the verification commands. |
| Reviewer | `agents/dev-loop-reviewer.md`, fresh context, read-only | Re-runs verification and checks the change against the task's acceptance criteria, without seeing the implementer's reasoning. |

## Use

1. Write the changes you want as a plain list in `planning.md` at the project root.
2. `/spec`: Claude explores the code, asks you about anything ambiguous, and writes `spec.md`, a list of small, ordered tasks. Pass paths to use other files: `/spec docs/plan.md docs/spec.md`.
3. `/dev-loop`: runs the next task. A fresh implementer subagent builds it, a fresh reviewer subagent checks it, and the changes are staged. Then it stops.
4. Review, test and commit it yourself, then run `/dev-loop` (or say "continue") for the next task. It won't continue until the staged task is committed and the tree is clean.

`/dev-loop status` shows where you are. `/dev-loop abort` forgets the task in flight and leaves your files alone.

## Files

| Path | Purpose |
|---|---|
| `skills/spec/` | `/spec` and the spec template |
| `skills/dev-loop/` | `/dev-loop` and its commit-gate script |
| `agents/dev-loop-implementer.md` | Implements one task in fresh context |
| `agents/dev-loop-reviewer.md` | Reviews one task's change in fresh context (read-only) |
| `.gitignore` | Keeps project and machine files out of the kit |

## What stays in the project

These belong to each project, not the kit:

- `CLAUDE.md`: project knowledge and the `## Verification` commands
- `planning.md` and `spec.md`: committed with the project's own history
- `.claude/settings.json`, `.claude/settings.local.json` and `.claude/state/`: ignored by the kit's `.gitignore`

## Requirements

Git and bash. On Windows, Claude Code runs commands in Git Bash.
