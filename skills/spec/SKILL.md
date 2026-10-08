---
name: spec
description: Turn a planning file (a plain list of wanted changes, planning.md by default) into a spec.md of small, ordered, verifiable tasks for /dev-loop. Explores the code, asks the user about anything ambiguous in the plan, then writes or updates spec.md.
disable-model-invocation: true
argument-hint: "[planning-file] [spec-file]"
---

# /spec

Arguments: `$ARGUMENTS`. The first is the planning file (default `planning.md` at the repository root) and the second is the spec file (default `spec.md` at the repository root). If the planning file doesn't exist, ask the user for its path and stop.

This skill only plans. Don't change any code.

## 1. Read

- The planning file, in full
- `CLAUDE.md`, for project conventions and its `## Verification` section
- The existing spec file, if there is one
- `git log --oneline -15`, for recent work and commit style

If `.claude/state/dev-loop` exists, a /dev-loop task is in flight. Tell the user to finish or abort it first (changing the spec under a running task breaks it), and stop.

## 2. Create or update

- No spec yet, or every task in it is `done`: write a fresh spec. The old one stays in git history.
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

- **One task, one commit.** Split large items; merge trivial ones. The user reviews and commits each task on its own.
- **Order by dependency** and fill in `Depends on`.
- **Self-contained.** An implementer with no conversation history must be able to do the task from the spec alone. Name the files, functions and existing patterns to follow.
- **Checkable acceptance criteria.** Statements that are true or false of the finished code, not intentions.
- **Test steps.** Concrete actions in the running project and what each should show. The tester agent follows them, and you get whatever it can't reach.
- No code beyond short identifiers or signatures.

When appending, continue numbering from the last task ID and keep the `## Progress` section as the last section of the file.

## 6. Verification commands

/dev-loop's agents run the commands listed under `## Verification` in `CLAUDE.md`. If that section is missing, work out the commands from the project's manifests (package.json scripts, Cargo.toml, Makefile, pyproject.toml and so on), confirm them with the user, and add the section (create `CLAUDE.md` if needed). Run them once on the current tree. If any fail, tell the user before handing over: the loop needs a passing baseline.

/dev-loop's tester follows `## Testing` in `CLAUDE.md`. If the project has something to run and exercise (an app, CLI, API or service) and that section is missing, offer to write one. It should cover how to reach the running project, which tools to use, preconditions such as which account to use, what's off-limits, and what stays manual. The section is optional; without it, every test step goes to the user.

## 7. Hand over

Summarise: the number of tasks, each task's ID and title, the decisions you made on the user's behalf, and anything risky. Tell them to read and edit the spec if needed, then run `/dev-loop`.
