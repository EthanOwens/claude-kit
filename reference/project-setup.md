# Project setup: CLAUDE.md

Shared procedure for /kit:spec and /kit:task. It creates or completes the project's `CLAUDE.md`, the file every Claude session and kit agent loads. The kit's agents rely on four sections:

| Section | Who uses it | Required |
|---|---|---|
| `## Verification` | The implementer runs these checks after every change; the reviewer re-runs them as its pass/fail gate | When the project has anything to build, type check, lint or test |
| `## Testing` | The tester: how to reach and exercise the running project | Only when there's something to run (app, server, CLI, API) |
| `## Gotchas` | Every agent: non-obvious things that cause mistakes | Only if you found some |
| `## Preferences and notes` | Every agent: the user's own rules and knowledge | Always present |

`CLAUDE.md` is in the project root: the git repository root, or the current folder without git.

## 1. Check what's there

- **No `CLAUDE.md`**: draft a whole file.
- **`CLAUDE.md` exists**: draft only the sections above that are missing. Never rewrite, reorder or remove anything already in it.
- **All four sections exist**: nothing to do. Return to the calling skill.

## 2. Draft

Use what you already learned while exploring the code; look further only where you need to.

**Verification.** Work out the checks from the project's files: package.json scripts (typecheck, lint, test, build), Cargo.toml (`cargo check`, `cargo test`), Makefile targets, pyproject.toml (pytest, ruff, mypy), go.mod (`go build ./...`, `go vet ./...`, `go test ./...`) and so on. Pick checks that are meaningful and quick enough to run after every change. Run each one once now:
- All pass: list them.
- Any fail: tell the user which and why, and ask whether to fix that first, leave the command out, or keep it anyway. The loop needs a passing baseline.
- Nothing to check (a folder of notes, a one-off script): leave the section out and say so.

**Testing.** Only when there's something to run. Ask the user (AskUserQuestion, recommendation first) whatever the code can't tell you:
- How it runs and who starts it. Should the tester attach to something the user starts, or launch it itself?
- Which tools the tester should use: an MCP server in `.mcp.json`, a browser, `curl`, the CLI itself.
- Which account or test data to use, and what must never be touched.
- What stays manual (things out of the tools' reach).

If the user doesn't want testing set up, leave the section out.

**Gotchas.** Only non-obvious things you actually found that would cause mistakes: constraints, generated files, things that must not be edited, platform quirks, things configured outside the repo. Never write an architecture tour or file-by-file descriptions; agents can read the code.

**Preferences and notes.** Always include this section. Ask the user, in one open question, whether they have any of these to add:
- how they like changes made (for example small changes over refactors, no new dependencies without asking)
- non-negotiables (platforms that must keep working, offline support, accessibility)
- things that live outside the repo (consoles, dashboards, secrets, external config)
- areas to leave alone, and known issues to work around

Write down what they give you as short bullets. If they have nothing yet, write the heading with a one-line HTML comment listing those four prompts, so they can fill it in later.

Two things belong elsewhere; suggest them instead of putting them in `CLAUDE.md`:
- **Quirks of one machine** (local paths, SDK settings): `CLAUDE.local.md` in the project root, which should be gitignored.
- **Preferences for all of the user's projects**: `~/.claude/CLAUDE.md`.

Keep the whole file short. For each line, ask whether removing it would cause a mistake; if not, cut it.

## 3. Review with the user

Show the full draft (or the sections to add) in one block, in this shape:

```markdown
# <Project name>

<One line: what the project is.>

## Verification

Run all of these after every change. Each must exit 0:

- `<command>`

## Testing

- <how to reach the running project, tools, account, off-limits, manual steps>

## Gotchas

- <non-obvious thing that causes mistakes>

## Preferences and notes

- <the user's preferences and notes>
```

End with: "Tell me anything to change, or say **write** to save it." Then wait. On changes, show the whole updated draft again with one line on what changed, and repeat until they approve. If they decline, don't write anything, and continue with the calling skill.

## 4. Write

- **New file**: create `CLAUDE.md` with the approved draft.
- **Existing file**: append the approved sections at the end, leaving everything else exactly as it was.

In a git repository, tell the user to commit `CLAUDE.md` (/kit:dev-loop needs a clean working tree). Then return to the calling skill.
