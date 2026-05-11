# Workspace contract

A **workspace** is a self-contained unit of work inside your vault — a project, a product area, a long-running initiative. Every workspace has a canonical note that serves as its navigation hub, plus a small set of subdirectories for tasks, notes, and AI-generated artifacts.

The contract defines a consistent structure so that any skill — or any session — can navigate any workspace without rediscovery.

## Why the contract exists

The workspace structure serves two audiences simultaneously: you and the AI agent working with you.

For humans, it's a predictable project layout. You always know where tasks live, where plans end up, and where generated artifacts go.

For agents, it's a memory layer. The canonical note's below-the-rule sections capture session state so the next agent session picks up where the last one left off. The above/below split protects your hand-authored context from being overwritten.

Without this contract, agents accumulate redundant files, overwrite human work, and rediscover the same context every session.

---

## Directory structure

```
{workspaces_dir}/
└── my-project/              ← workspace root (kebab-case name)
    ├── my-project.md        ← canonical workspace note
    ├── tasks/               ← durable task notes
    ├── notes/               ← canonical content notes
    └── agent-artifacts/     ← AI-generated execution material
```

`{workspaces_dir}` defaults to `Workspaces` in the vault root. Change it via `vault.workspaces_dir` in `.vault.toml` (see [vault-config.md](vault-config.md)).

**Naming:** workspace directory names and filenames use **kebab-case** — lowercase letters, digits, and hyphens only. No spaces, underscores, or uppercase letters. `my-project` is correct; `MyProject` and `my_project` are not.

---

## The canonical workspace note

`my-project.md` is the root of navigation for the workspace. Every other file in the workspace links back to it (directly or indirectly). The `/devlog write` skill reads and updates this file at session end.

### Above/below-the-rule split

Every canonical note is divided by a horizontal rule (`---` on its own line, distinct from the YAML frontmatter delimiter). The rule separates two zones with different ownership:

```markdown
<!-- Above: human-authored, durable -->

# My Project

One-paragraph description — what this is, why it exists,
key tech, important paths, navigation links to notes and tasks.

---

<!-- Below: agent-maintained, may be rewritten by /devlog write -->

## Current State
(where things stand right now)

## What's Next
(immediate next actions)

## Open Questions
(unresolved decisions or blockers)

## Learnings
(things discovered that are worth remembering)

## Recent Sessions
(brief entry per session: date + what happened)
```

**Above the rule** is yours. Write whatever helps you and the agent orient quickly — the project's purpose, tech stack, key file paths, links to the most important notes. Agents never overwrite this zone.

**Below the rule** is agent-maintained. The `/devlog write` skill overwrites these sections at session end with fresh state. You can edit below the rule, but expect the agent to overwrite your changes next session. Required sections: `## Current State`, `## What's Next`, `## Open Questions`, `## Learnings`, `## Recent Sessions`.

---

## Subdirectory purposes

### `tasks/`

Durable task notes — not transient to-dos. Each file represents one actionable unit of work with a defined lifecycle:

```
backlog → in_progress → completed | wont_do
```

One task per file. Tasks are not deleted when complete — they stay in place with a terminal status. This gives you a record of what was done and why things were decided.

### `notes/`

Canonical content notes: plans, specs, decisions, research, learnings, user stories, brainstorms. Human-authored or promoted from agent artifacts when they reach durable knowledge status.

Flat structure only — no nested subfolders (`notes/specs/` or `notes/research/` are not permitted). If you find yourself wanting to group notes, use the `kind:` frontmatter field instead.

### `agent-artifacts/`

AI-generated working material: implementation plans, specs, code reviews, session logs, summaries produced by agents during execution. These are reference documents for agent use, not canonical knowledge.

Agent artifacts are not linked from the workspace navigation unless explicitly promoted. To promote an artifact to durable knowledge, extract and rewrite its key content as a `notes/` entry.

---

## Strict mode additions

When `mode.strict = true` in `.vault.toml`, typed frontmatter is required on every file in the workspace. See [strict-mode-ontology.md](strict-mode-ontology.md) for the full ontology.

### Canonical workspace note frontmatter

```yaml
---
type: note
kind: workspace
title: My Project
aliases:
  - my-project
description: One-line description of the project.
created: 2026-01-15T09:00
modified: 2026-05-10T14:30
---
```

### Task files

```yaml
---
type: task
workspace: "[[my-project]]"
status: backlog
title: Implement the thing
---
```

`status` must be one of: `backlog`, `in_progress`, `completed`, `wont_do`.

### Notes files

```yaml
---
type: note
kind: decision
title: Use TOML for config
---
```

`kind` must be a content kind — see [strict-mode-ontology.md](strict-mode-ontology.md) for the full list. Entity kinds (`workspace`, `domain`, `persona`) are not valid for files inside `notes/`.

### Agent artifact files

```yaml
---
type: agent-artifact
artifact_kind: plan
---
```

`artifact_kind` must be one of: `plan`, `spec`, `review`, `log`, `summary`.

---

## Contract compliance summary

| Requirement | Minimal | Strict |
|---|---|---|
| `tasks/`, `notes/`, `agent-artifacts/` dirs exist | required | required |
| `{name}.md` canonical note exists | required | required |
| Horizontal rule split in canonical note | required | required |
| Below-the-rule sections present | required | required |
| Canonical note frontmatter (type, kind, title, aliases, etc.) | — | required |
| Task files: type + workspace + status | — | required |
| Notes files: type + valid content kind | — | required |
| Agent artifact files: type + artifact_kind | — | required |

---

## How the workspaces skill enforces this

The `/workspaces create` skill scaffolds the directory structure and canonical note on creation. It applies the mode-appropriate template (from `.vault.toml`) and validates that the required above/below-the-rule split is present.

The `/devlog write` skill validates the canonical note before writing — it aborts if the horizontal rule is missing, rather than silently overwriting the entire note.

Neither skill creates workspaces silently. Creation always requires confirmation.
