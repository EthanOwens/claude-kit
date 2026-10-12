---
name: task
description: One-shot change for small jobs. Describe what you want and approve (or adjust) a short brief; then a fresh implementer builds it, a fresh reviewer checks it and, if the project has a "## Testing" section in CLAUDE.md, a tester tries it. No planning file or spec, and it works with or without git.
disable-model-invocation: true
argument-hint: "<what to change>"
---

# /kit:task

Request: `$ARGUMENTS`

If the request is empty, ask the user what they want done and stop.

You are the coordinator. Subagents (`kit:implementer`, `kit:reviewer`, `kit:tester`) do the editing, reviewing and testing. **Never commit or discard changes**: no `git commit`, `git push`, `git reset`, `git stash`, `git checkout -- <path>` or `git restore`.

## 1. Understand

- Read `CLAUDE.md` if there is one, especially `## Verification`, `## Testing` and `## Preferences and notes`.
- Look at enough of the code to brief an implementer. For anything beyond a file or two, use an Explore subagent so file contents stay out of your context.
- Check for git with `git rev-parse --is-inside-work-tree`. If this is a git repository with uncommitted changes, note which files were already modified, so the reviewer can ignore them.
- If the request is ambiguous in a way that changes the result, ask with AskUserQuestion (up to 4 questions, recommendation first). Otherwise pick sensible defaults and list them in the brief.
- If it's really several reviewable changes, say so and suggest `/kit:spec` with a planning list instead. Carry on only if the user wants to.

## 1b. Project setup (CLAUDE.md)

If `CLAUDE.md` is missing, or lacks any of `## Verification`, `## Testing`, `## Gotchas` or `## Preferences and notes`, ask with AskUserQuestion:
- **Set it up now** (recommended for a project you'll keep working in): follow `${CLAUDE_PLUGIN_ROOT}/reference/project-setup.md`, then continue with step 2. It drafts only what's missing and writes nothing until the user approves.
- **Skip for this task**: carry on without it. The agents then check their work another way, and test steps go to the user.

If setup writes a `CLAUDE.md` in a git repository, it's a change of its own: add it to the list of files already modified before the task, so the reviewer ignores it.

## 2. Write the brief and wait for approval

Write a short brief and show it to the user in one block:

```
Goal: one or two sentences
Context: files, functions and existing patterns to follow
Defaults chosen: anything you decided for them
Acceptance: checkable statements about the finished change
Test steps: actions and what each should show (skip if nothing runs)
Out of scope: what not to touch
```

End with: "Tell me anything to change, or say **go** to start." Then end your turn. Don't start step 3 until the user approves.

When the user replies:
- **They ask for changes**: update the brief, show the whole updated brief again (not just the changed lines), say in one line what changed, and end with the same prompt. Repeat as many times as they like. If a change needs more of the code, look first; if it raises a real question, ask it.
- **They approve** ("go", "start", "looks good", "do it"): go to step 3 with the latest brief, exactly as shown.
- **They cancel**: stop without changing anything.
- **It's unclear** whether they're approving or asking for a change: ask.

## 3. Implement, review and test

Use the same agents and rules as /kit:dev-loop, but pass the brief verbatim in each prompt in place of a spec path and task ID.

1. **Implement**: spawn `kit:implementer` with the brief and wait for it. If it reports `STATUS: blocked`, ask the user its question, then send the answer back to it.
2. **Review**: spawn `kit:reviewer` with the brief and the implementer's CHANGED list only: no reasoning, no claims that checks passed. Tell it whether this is a git repository, and list any files that were already modified before the task.
3. **Test**: only if CLAUDE.md has a `## Testing` section, spawn `kit:tester` with the brief and the CHANGED list.

**Fix rounds**: send only the reviewer's BLOCKING findings or the tester's FAILURES back to the implementer, then review again (and test again) with new agents. Allow at most 2 fix rounds. If problems remain, stop and show the user the findings.

## 4. Report

```
## Done: <three to eight plain words on what's different now>

<two or three sentences: what changed, what you'll notice, anything to watch for>
```

Then briefly:
- **Changed**: the files and what changed in each
- **Checks**: each verification command and its result, from the reviewer's own run, or how the change was checked without one
- **Tested**: the tester's verdict per step, or "not tested" with why
- **Try it**: test steps nobody could run for you
- **Notes**: anything from the agents the user should know
- **In a git repository**: the changes are left uncommitted; give a one-line suggested commit message in the style of `git log --oneline -10`
- **Without git**: remind the user there's no undo history beyond the editor's own
