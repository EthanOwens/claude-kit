---
name: spec
description: Turn a planning file (a plain list of wanted changes, planning.md by default) into a spec.md of small, ordered, verifiable tasks for /kit:dev-loop. Explores the code, asks the user about anything ambiguous in the plan, then writes or updates spec.md. Works with or without git.
disable-model-invocation: true
argument-hint: "[planning-file] [spec-file]"
---

# /kit:spec

Arguments: `$ARGUMENTS`. The first is the planning file (default `planning.md` in the project root) and the second is the spec file (default `spec.md` in the project root). The project root is the git repository root, or the current folder when there's no git repository. If the planning file doesn't exist, ask the user for its path and stop.

This skill only plans. Don't change any code.

## 1. Read

- The planning file, in full
- `CLAUDE.md`, if there is one, for project conventions, its `## Verification` section and the user's `## Preferences and notes`
- The existing spec file, if there is one
- In a git repository, `git log --oneline -15`, for recent work and commit style

Stop if a /kit:dev-loop task is in flight, because changing the spec under a running task breaks it. Tell the user to finish or abort it first. A task is in flight when either of these holds:
- **Git:** the file `kit-dev-loop` exists in the git directory (`git rev-parse --absolute-git-dir`).
- **Any project:** the spec has a task with `Status: in-progress`.

## 2. Create or update

- No spec yet, or every task in it is `done`: write a fresh spec. In a git repository the old one stays in history. Without git, ask before overwriting it, and offer to keep it as `spec-<date>.md`.
- The spec still has unfinished tasks: ask with AskUserQuestion whether to **append** the new work to it, **replace** it (unfinished tasks are dropped), or **cancel**.

## 3. Explore

For each planning item, or each group of related items, find the code it touches. Use Explore subagents in parallel so file contents stay out of your context. Ask each one to return file paths, how the code behaves now, existing patterns to reuse, and risks or constraints, not file dumps.

## 4. Ask the user

List every point where the plan is ambiguous in a way that changes what gets built: behaviour choices, UI details, edge cases, items that conflict with each other or with existing code. Ask about them with AskUserQuestion, up to 4 questions per call and as many rounds as needed.

- Ask only what the plan and the code can't answer. When a sensible default exists, pick it and record it under `## Decisions` instead of asking.
- Give concrete options with their tradeoffs, and put your recommendation first.
- Keep going until no open question would change the result.

## 5. Write the spec

Follow [spec-template.md](spec-template.md). Task rules:

- **One task, one checkpoint.** Split large items; merge trivial ones. The user reviews each task on its own (and commits it, in a git repository).
- **Order by dependency** and fill in `Depends on`.
- **Self-contained.** An implementer with no conversation history must be able to do the task from the spec alone. Name the files, functions and existing patterns to follow.
- **Checkable acceptance criteria.** Statements that are true or false of the finished code, not intentions.
- **Test steps.** Concrete actions in the running project and what each should show. The tester agent follows them, and you get whatever it can't reach.
- **Tester: yes or no**, with a short reason. Say no when nothing runs, or when every test step needs a human: native window behaviour, real keyboard focus, or visual judgment such as "looks right". Say yes when there's logic the tester can exercise and observe. The tester costs far more than the other agents, so don't spend it where it can't see anything.
- No code beyond short identifiers or signatures.

When appending, continue numbering from the last task ID and keep the `## Progress` section as the last section of the file.

## 6. Project setup (CLAUDE.md)

/kit:dev-loop's agents depend on `CLAUDE.md`: they run its `## Verification` checks, the tester follows its `## Testing` section, and everyone follows its `## Gotchas` and `## Preferences and notes`. If `CLAUDE.md` is missing, or lacks any of those sections, follow `${CLAUDE_PLUGIN_ROOT}/reference/project-setup.md` now. It drafts only what's missing, runs the checks once, and writes nothing until the user approves.

If all four sections already exist, still run the `## Verification` commands once on the current files. If any fail, tell the user before handing over: the loop needs a passing baseline.

## 7. Hand over

Summarise: the number of tasks, each task's ID and title, the decisions you made on the user's behalf, and anything risky. Tell them to read and edit the spec if needed, then run `/kit:dev-loop`. In a git repository, remind them that the loop needs a clean working tree, so they should commit the new spec first.
