# Running the agents

Shared by /kit:dev-loop and /kit:task. The task is either a spec path plus task ID, or an inline brief; pass whichever you have to every agent.

## Settings

The calling skill shows the effective kit settings (from `kit-config.sh show`). Spawn each agent with the `model` and `effort` set for its role:

| Agent | Model setting | Effort setting |
|---|---|---|
| `kit:implementer` | `implementer.model` | `implementer.effort` |
| `kit:reviewer` | `reviewer.model` | `reviewer.effort` |
| `kit:tester` | `tester.model` | `tester.effort` |

Pass `inherit` by leaving `model` out. Always wait for each agent's result; don't run them in the background.

## 1. Implement

Spawn `kit:implementer` with the task. If it reports `STATUS: blocked`, put its question to the user with AskUserQuestion and send the answer back to the same implementer with SendMessage.

## 2. Review

Spawn `kit:reviewer` with the task and the implementer's CHANGED list, and nothing else: no reasoning, no claims that checks passed. Say whether this is a git repository, and list any files that were already modified before the task.

- **PASS**: go to 3.
- **FAIL**: run a fix round (below).

## 3. Test

**Decide whether to test.** Skip testing, and give every test step to the user, when any of these holds:
- CLAUDE.md has no `## Testing` section
- `tester.mode` is `off`
- `tester.mode` is `auto` and the task says `Tester: no`. A task with no `Tester:` line counts as yes.

**Check preconditions first**, so a tester isn't spent finding out the project isn't running:
- If `## Testing` has a `### Precondition` subsection, run its command. A non-zero exit means it failed.
- If `## Testing` names MCP tools the tester needs, check they're available (ToolSearch for their names).

If either fails, tell the user exactly what's missing and ask with AskUserQuestion: test once it's fixed (wait for them, then check again) or skip testing for this task.

**Spawn `kit:tester`** with the task and the CHANGED list.
- **PASS**: done.
- **FAIL**: run a fix round.
- **COULDN'T TEST** because a precondition failed after all: handle it as above.

Steps the tester left for the user go into the handover.

## Fix rounds

A fix round sends only the reviewer's BLOCKING findings or the tester's FAILURES back to the **same** implementer with SendMessage. Then **resume the same reviewer** with SendMessage ("the implementer fixed your findings; re-check them") and, if testing applies, **resume the same tester** the same way. Resumed agents keep what they've already read, so don't start new ones. (Load SendMessage with ToolSearch if it isn't available yet. If an agent can't be resumed, start a new one with the findings in its prompt.)

Allow 2 fix rounds per task, counting review and test failures together. If problems remain after the second:
1. **If `implementer.retry_model` isn't `off`**, run one final round with a **new** `kit:implementer` on that model (same effort), giving it the task, the outstanding findings, and a note that earlier changes are already in place. Then resume the reviewer (and tester) as usual.
2. **If problems still remain**, don't record the task as done. Show the user the findings and ask with AskUserQuestion: accept it as it is, run one more round, or stop so they can fix it themselves.

Mention in the handover how many fix rounds ran, what each fixed, and whether the retry model was used.

## Lessons

If the tester's report includes a `LESSON:`, check it before asking the user. Drop it, and say so in one line in the handover, when it has no `Cost:` or only a minor one, when an existing lesson already covers it, or when it only describes this task. Otherwise ask the user with AskUserQuestion whether to add it under `### Lessons` in CLAUDE.md's `## Testing` section (create the subsection if needed). When it names `Replaces:`, offer to replace that lesson rather than add one. Mark a lesson that depends on library internals with "(fragile)". Keep each lesson to one or two lines and at most 8; if the subsection is full, ask which one to replace or merge. Never add a lesson without asking. In git mode, do this before staging, so the lesson goes into the same commit.

## Testing on demand

After a handover, the user may say "test it", "check it", or "it doesn't work: <what they saw>". Run the tester (preconditions first, as above, whatever `tester.mode` says) on the task that was just finished, in bug-hunting mode, passing their description of the problem.
- **No bugs found**: report that, with what was tried.
- **Bugs found**: in /kit:dev-loop git mode, if the task hasn't been committed yet, run the gate's `reopen` first. Then run a fix round with the tester's findings: new agents, since the originals may be gone. Re-record and re-stage as usual, and hand over again.
- **The task was already committed**: report the bugs and suggest `/kit:task` to fix them.
