---
name: config
description: Show and change the kit's settings - the model and effort for the implementer, reviewer and tester, the implementer's retry model, when the tester runs, and which agents Ponytail applies to. Saved for this machine, or as an override for the current project.
disable-model-invocation: true
argument-hint: "[show | <setting> <value> | reset]"
allowed-tools: Bash(bash "${CLAUDE_SKILL_DIR}/../../scripts/kit-config.sh" *) Bash(bash ${CLAUDE_SKILL_DIR}/../../scripts/kit-config.sh *)
---

# /kit:config

Arguments: `$ARGUMENTS`

## Current settings

!`bash "${CLAUDE_SKILL_DIR}/../../scripts/kit-config.sh" show`

Values come from the kit's defaults, then the user file (this machine), then the project file (`.claude/kit.config` in this project); later ones win. The script is `bash "${CLAUDE_SKILL_DIR}/../../scripts/kit-config.sh"`: `set [--project] <key> <value>`, `unset [--project] <key>`, `files`.

| Setting | Values | What it does |
|---|---|---|
| `implementer.model` | `sonnet`, `opus`, `haiku`, `fable`, `inherit`, or a model ID like `claude-sonnet-5-5` | Model that builds each task |
| `implementer.effort` | `low`, `medium`, `high`, `xhigh`, `max` | How hard it thinks |
| `implementer.retry_model` | a model as above, or `off` | Model for one final attempt after two failed fix rounds |
| `reviewer.model` / `reviewer.effort` | as above | The reviewer's model and effort |
| `tester.model` / `tester.effort` | as above | The tester's model and effort |
| `tester.mode` | `auto`, `always`, `off` | `auto`: test tasks marked `Tester: yes` (the default). `always`: test every task that can be tested. `off`: never; all test steps go to the user |
| Ponytail scope | which agents Ponytail applies to | Set through `PONYTAIL_SUBAGENT_MATCHER` in `~/.claude/settings.json` (see below) |

`inherit` means the agent uses whatever model your session runs on.

## What to do

- **`show`**, or no arguments: show the settings above as a short table, then ask with AskUserQuestion what they'd like to change (or nothing). Keep asking until they're done.
- **`<setting> <value>`**: set it directly.
- **`reset`**: ask whether to reset the user file, the project file, or both, then `unset` each saved key there.

For every change, ask whether it applies to **this machine** (user file) or **just this project** (`--project`), unless they've already said. Then run `set` and show the new value. A project override in a git repository is a file the project should commit; say so.

**Ponytail scope** isn't a kit setting: it's the `PONYTAIL_SUBAGENT_MATCHER` value under `env` in `~/.claude/settings.json`, a case-insensitive pattern matched against agent names. `implementer|reviewer` limits Ponytail to the kit's implementer and reviewer. Removing the value applies it to every subagent. To change it, edit that file (keep everything else in it unchanged), and tell the user it takes effect in new sessions. If Ponytail isn't installed, say so and point to the README's Ponytail section instead of setting it.

Changes to kit settings take effect the next time a kit command runs; nothing needs reloading.
