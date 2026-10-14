---
name: test
description: Run the kit's tester on demand in bug-hunting mode, against a spec task or a described problem, in the running project. Reports what it found and offers to fix real bugs. Uses the project's CLAUDE.md "## Testing" section.
disable-model-invocation: true
argument-hint: "[task-id | what's wrong]"
allowed-tools: Bash(bash "${CLAUDE_SKILL_DIR}/../../scripts/kit-config.sh" *) Bash(bash ${CLAUDE_SKILL_DIR}/../../scripts/kit-config.sh *)
---

# /kit:test

Target: `$ARGUMENTS`

## Settings

!`bash "${CLAUDE_SKILL_DIR}/../../scripts/kit-config.sh" show`

You coordinate; `kit:tester` does the testing, with the `tester.model` and `tester.effort` settings above. **Never commit or discard changes.**

## 1. Work out what to test

- **A task ID** (such as `T3`): test that task from `spec.md` (or the spec named in the arguments).
- **A description of a problem**: test that problem, in bug-hunting mode.
- **Nothing**: if a spec task was just finished in this session, test that one. Otherwise ask the user what to test and stop.

If CLAUDE.md has no `## Testing` section, the tester has no way to reach the project. Say so, offer to set it up with `${CLAUDE_PLUGIN_ROOT}/reference/project-setup.md`, and stop if the user declines.

## 2. Test

Follow **Test** in `${CLAUDE_PLUGIN_ROOT}/reference/agent-rounds.md` (preconditions first), whatever `tester.mode` says: the user asked for this run. Spawn `kit:tester` with:
- the spec path and task ID, or the user's description of the problem
- "bug-hunting mode": reproduce the problem (if one was described), then explore around it for anything else broken
- the files changed by the task, if you know them

Handle any `LESSON:` as **Lessons** in the agents reference describes.

## 3. Report and offer a fix

Report what the tester tried and found, with the steps that reproduce each bug, plus anything it couldn't test.

If it found real bugs, ask with AskUserQuestion:
- **Fix them now**: follow `/kit:task` from its step 2, with a brief built from the findings (approval, then implement, review and test).
- **Leave them**: stop. In a /kit:dev-loop project, mention that they can go in the next `planning.md`.
