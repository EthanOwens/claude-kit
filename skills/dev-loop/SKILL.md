---
name: dev-loop
description: Work through the next task in a spec.md written by /kit:spec, one task per run. A fresh implementer builds it, a fresh reviewer checks it and a fresh tester tries it in the running project. In a git repository the changes are then staged and the loop waits for the user's commit; without git it pauses for the user to say continue.
disable-model-invocation: true
argument-hint: "[spec-file] | status | abort"
allowed-tools: Bash(bash "${CLAUDE_SKILL_DIR}/scripts/loop-state.sh" *) Bash(bash ${CLAUDE_SKILL_DIR}/scripts/loop-state.sh *)
---

# /kit:dev-loop

You are the coordinator. Subagents do the reading, editing, reviewing and testing; you keep the spec, the checkpoints and the user in sync. Keep your own context small: don't read source files yourself.

Arguments: `$ARGUMENTS`
- empty: use `spec.md` in the project root (the git repository root, or the current folder without git)
- a path: use that spec file
- `status`: report the mode, the task in flight, the next task and the Progress list, then stop
- `abort`: in git mode run the gate's `abort`; in checkpoint mode set the in-progress task back to `todo`. Tell the user their files were left as they are, then stop

The gate script is `bash "${CLAUDE_SKILL_DIR}/scripts/loop-state.sh" <command>`. Always go through it in git mode; never edit its state file by hand.

**Never commit or discard changes.** Never run `git commit`, `git push`, `git reset`, `git stash`, `git checkout -- <path>` or `git restore`.

## Current state

!`bash "${CLAUDE_SKILL_DIR}/scripts/loop-state.sh" status`

The first line gives the mode for this run:
- **mode: git**: the commit gate applies. Each task ends staged, and the next task can't start until the user commits it.
- **mode: checkpoint**: there's no git repository, so progress is tracked in the spec's `Status:` lines, and each task ends with a pause until the user says continue. Tell the user once, at the start, that there's no git safety net in this folder, so they can't easily undo a task.

The agents are `kit:implementer`, `kit:reviewer` and `kit:tester`.

If the user says "continue" later in this session, run the gate's `status` again and start over at step 1.

## 1. Clear the checkpoint

**Git mode**, based on the state above:
- **phase=awaiting-commit**: run `check-commit`. If it prints BLOCKED, tell the user exactly what's missing (not committed yet, or changes left over after the commit) and stop. Don't start another task. If it prints OK, report the commit in one line and go to step 2.
- **phase=implementing**: an earlier run stopped partway through a task. Show `git status --short` and ask with AskUserQuestion whether to resume that task with the changes already present (go to step 3) or abort it (run `abort`; the user cleans up the tree themselves).
- **No loop state, working tree dirty**: stop and ask the user to commit or stash first, so the next task's staged changes are only its own.
- **No loop state, working tree clean**: go to step 2.

**Checkpoint mode**: read the spec.
- **A task has `Status: in-progress`**: an earlier run stopped partway through it. Ask with AskUserQuestion whether to resume it with the changes already made (go to step 3), or reset it to `todo` and stop so the user can clean up first.
- **Otherwise**: go to step 2.

## 2. Pick the task

Read the spec. The next task is the first one with `Status: todo` whose `Depends on` tasks are all `done`.
- If every task is done, say the spec is complete and stop.
- If only blocked tasks remain, list them with their reasons and stop.

Then:
- **Git mode**: run `begin <spec-path> <task-id>`. If it prints BLOCKED, relay the message and stop.
- **Checkpoint mode**: set the task to `Status: in-progress` in the spec.

## 3. Implement (fresh context)

Spawn a `kit:implementer` subagent and wait for its result (don't run it in the background). Give it:
- the spec path and the task ID and title
- if you're resuming an interrupted task, a note that partial changes are already in place

Don't paste code or file contents. It reads the spec, CLAUDE.md and the code itself.

If it reports `STATUS: blocked`, put its question to the user with AskUserQuestion, then send the answer back to the same implementer (with SendMessage if available, otherwise a new implementer whose prompt includes the answer). If the user wants to skip the task instead, set its Status to `blocked: <reason>`, tell the user to undo any partial changes themselves, run `abort` in git mode, and stop.

## 4. Review (fresh context)

Spawn a `kit:reviewer` subagent and wait for its result. Give it the spec path, the task ID and the implementer's CHANGED list, and nothing else: no reasoning, no claims that checks passed. In checkpoint mode, tell it there's no git repository, so it reviews the files in the CHANGED list.

- **VERDICT: PASS**: go to step 5.
- **VERDICT: FAIL**: run a fix round (below), then review again with a **new** reviewer.

## 5. Test (fresh context)

If CLAUDE.md has no `## Testing` section, skip this step; every test step goes to the user in the handover.

Otherwise spawn a `kit:tester` subagent and wait for its result. Give it the spec path, the task ID and the implementer's CHANGED list.

- **VERDICT: PASS**: go to step 6.
- **VERDICT: FAIL**: run a fix round, then review again with a new reviewer and test again with a new tester.
- **VERDICT: COULDN'T TEST** because a precondition failed (for example the app isn't running): tell the user what's needed and ask with AskUserQuestion whether to test again once it's fixed or skip testing for this task.

Steps the tester left for the user go into the handover.

### Fix rounds

A fix round sends only the reviewer's BLOCKING findings or the tester's FAILURES to the implementer (the same one through SendMessage if available, otherwise a new one with the findings in its prompt). Allow at most 2 fix rounds per task, counting review and test failures together. If problems remain after that, don't record the task as done. Show the user the findings and ask with AskUserQuestion: accept it as it is, run one more fix round, or stop so they can fix it themselves.

## 6. Record

1. In the spec, set the task to `Status: done`.
2. Add one line at the end of the `## Progress` section at the bottom of the spec: `- [x] <task-id> <title>`.
3. **Git mode only**: run `stage`. It stages every change in the tree, which is exactly this task's work because the tree was clean when the task began. The spec update goes into the same commit.

## 7. Hand over and stop

Open with a heading and a short summary that someone skimming can understand without having read the spec or the code:

```
## Ready to commit: <name>        (git mode)
## Done: <name>                   (checkpoint mode)

<summary>
```

- **Name**: three to eight words in plain language describing what's different now, from the point of view of someone using the project (for example "Sticky notes remember their size"). Not the task ID, a file or function name, or the spec's title copied over.
- **Summary**: two or three sentences: what changed, what you'll notice, and anything you need to do or watch for. No jargon, paths or code identifiers.

Then report briefly:
- **Task**: ID and title from the spec
- **Changed**: one to three lines on what changed in the code
- **Checks**: each verification command and its result, from the reviewer's own run
- **Tested**: the tester's verdict and one line per step, or "no `## Testing` section" if skipped
- **Try it**: the test steps the tester couldn't cover, adjusted by the implementer's TEST STEPS notes
- **Notes**: reviewer, tester and implementer notes the user should know, if any
- **Git mode**: **Staged** (the file summary printed by `stage`) and a **Suggested commit message** (one line, in the style of `git log --oneline -10`). Finish with: "Commit when you're happy, then run `/kit:dev-loop` (or say continue) for the next task."
- **Checkpoint mode**: **Files changed** (from the implementer's CHANGED list). Finish with: "Check it over, then run `/kit:dev-loop` (or say continue) for the next task."

Then end your turn. Don't start the next task.

## Rules

- One task per run.
- If the spec itself is wrong (a task can't be done as written, or contradicts the code), stop and suggest updating it with `/kit:spec` instead of improvising.
