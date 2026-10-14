# kit: a Claude Code workflow plugin

Plan a list of changes into small tasks, then build them one at a time. Each task gets a fresh implementer, a reviewer that didn't write it, and a tester that tries it in the running app. For small jobs, a one-shot command skips the planning. Works in any folder, with or without git.

| Command | What it does |
|---|---|
| `/kit:spec [planning-file] [spec-file]` | Reads `planning.md`, explores the code, asks you about anything unclear, and writes `spec.md`: small, ordered tasks with acceptance criteria and test steps. |
| `/kit:dev-loop [spec-file \| status \| abort]` | Runs the next task: implement → review → test (when useful), with up to 2 fix rounds plus one final attempt on a stronger model. Then it stops for you. |
| `/kit:task <what to change>` | One-shot: writes a short brief and waits while you adjust it; once you say go, implement → review → test, and a report. No planning file or spec. |
| `/kit:test [task-id \| what's wrong]` | Runs the tester on demand in bug-hunting mode, and offers to fix what it finds. You can also just say "test it" or "it doesn't work: ..." after a task. |
| `/kit:config [show \| <setting> <value> \| reset]` | Shows and changes the kit's settings: models, effort, retry model, when the tester runs, and the Ponytail scope. |

## Install

On any machine, in a Claude Code session:

```
/plugin marketplace add EthanOwens/claude-kit
/plugin install kit@claude-kit
```

Pick **user scope** so it's active in every folder. Plugins load when a session starts, so start a new session, or run `/reload-plugins`, after installing.

**While developing the plugin itself**, add your local clone instead: `/plugin marketplace add ~/projects/personal/claude-kit`. A marketplace added from a local path loads the plugin's files in place, so your edits take effect at the next session start (or `/reload-plugins`) with no update step.

### Updates

`plugin.json` has no `version`, so every pushed commit counts as a new version. Get it with `/plugin marketplace update claude-kit`, or turn on auto-update for the marketplace under **Marketplaces** in `/plugin`.

## Git mode and checkpoint mode

`/kit:dev-loop` picks its mode from the folder:

- **Git repository (git mode)**: a task can only start from a clean working tree. When it's done, every change is staged and the loop won't start the next task until you've committed it. Commits are always yours; the loop never commits, resets or discards anything. Its state lives in `.git/kit-dev-loop`, so it never shows up as a change.
- **No git (checkpoint mode)**: progress is tracked in the spec's `Status:` lines. After each task the loop stops and waits for you to say "continue". The reviewer reads the changed files instead of a diff. There's no undo beyond your editor's own, so this suits small or throwaway work.

`/kit:task` works the same in both: it leaves changes uncommitted in a git repository.

## Settings and cost

Each agent runs on its own model and effort, so the expensive model is only used where it pays off. Defaults:

| Role | Model | Effort |
|---|---|---|
| Implementer | Sonnet | medium; one final attempt on **Opus** after two failed fix rounds |
| Reviewer | Sonnet | medium |
| Tester | Haiku 5.5 | low |

Your own session (the coordinator) keeps whatever model you run it on. Change any of these with `/kit:config`, for this machine (`~/.claude/kit/config`) or for one project (`.claude/kit.config`, which the project should commit). Two environment variables override everything: `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` and `CLAUDE_CODE_EFFORT_LEVEL`.

Other things that keep tasks cheap:

- **The tester only runs when it can see something.** `/kit:spec` marks each task `Tester: yes` or `no`, with a reason. Change that with `tester.mode` (`auto`, `always`, `off`).
- **A precondition check runs before any tester.** It runs the command under `### Precondition` in `## Testing` and checks that the testing tools are loaded, so a tester is never spent finding out the app isn't running.
- **Fix rounds resume the same agents.** When a review or test fails, the same implementer fixes the findings, and the same reviewer and tester re-check them. They keep what they've already read instead of starting over. There are 2 rounds, then the one Opus attempt, then it's your call.
- **`/clear` between tasks.** The loop's state is on disk, so clearing loses nothing, and each task starts from a small context instead of re-sending every earlier task. The handover reminds you.

### Ponytail (optional)

[Ponytail](https://github.com/DietrichGebert/ponytail) pushes agents to write the least code that works. It pairs well with the implementer, and with the reviewer for spotting over-built code (reported as a note, not a blocker). Install it and scope it to those two agents:

```sh
claude plugin marketplace add DietrichGebert/ponytail
claude plugin install ponytail@ponytail --scope user
```

Then set `"PONYTAIL_SUBAGENT_MATCHER": "implementer|reviewer"` under `env` in `~/.claude/settings.json` (or use `/kit:config`). It needs `node` on your PATH.

## What a project provides

Nothing is required, but these make the agents much better. All of it lives in the project, not the plugin. When `CLAUDE.md` is missing or incomplete, `/kit:spec` sets it up and `/kit:task` offers to, following [reference/project-setup.md](reference/project-setup.md): it drafts only the missing sections, runs the checks once, and writes nothing until you approve.

- **`CLAUDE.md` → `## Verification`**: commands that must exit 0 after every change, such as a type check, build and tests. `/kit:spec` offers to add it. Without it, the agents check their work another way and say how.
- **`CLAUDE.md` → `## Testing`** (optional): how the tester reaches the running project, which tools to use, preconditions (such as which test account), what's off-limits, and what stays manual. Without it, test steps come to you.
  - `### Precondition`: one command that exits 0 only when the project is ready to test.
  - `### Lessons`: one- or two-line lessons the tester suggests from experience. Each is added only after you approve it, with at most 8.
- **`CLAUDE.md` → `## Gotchas`** (optional): non-obvious things that cause mistakes, such as generated files, settings kept outside the repo, or platform quirks.
- **`CLAUDE.md` → `## Preferences and notes`**: your own rules and knowledge: how you like changes made, non-negotiables, things that live outside the repo, areas to leave alone, known issues. Every agent follows it, and the reviewer treats breaking a non-negotiable as blocking.
- **`.mcp.json`** (optional): MCP servers the tester uses, such as a browser or app-automation server.
- **`planning.md` and `spec.md`**: your plan and the generated tasks.

## Roles

| Role | Runs as | Job |
|---|---|---|
| Coordinator | Your session, via `/kit:dev-loop` or `/kit:task` | Picks the task, briefs the agents, updates the spec, checkpoints with you |
| Implementer | `kit:implementer`, fresh context | Builds one task and runs the verification commands |
| Reviewer | `kit:reviewer`, fresh context, read-only | Re-runs verification and checks the change against the acceptance criteria, without seeing the implementer's reasoning |
| Tester | `kit:tester`, fresh context, can't edit files | Follows the test steps in the running project and reports pass/fail per step with evidence. In bug-hunting mode it reproduces a reported problem and explores around it |

## Moving a project off the old `.claude` submodule

```sh
git submodule deinit -f .claude
git rm -f .claude
rm -rf .git/modules/.claude
git commit -m "Moved claude-kit from submodule to plugin"
```

The project's `.claude/` folder is then free for its own settings and project-only skills.

## Requirements

Claude Code with plugin support, and bash. On Windows, Claude Code runs commands in Git Bash. Git is optional.
