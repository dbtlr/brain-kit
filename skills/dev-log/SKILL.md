---
name: dev-log
description: Two subcommands. 'init <workspace-slug>' bootstraps a workspace's brain-kit integration (CLAUDE.local.md, permissions, gitignore, workspace context loading). 'write' creates a comprehensive session log and updates the workspace canonical note. Triggers on milestones (task completion, session wrap-up, context limits, explicit request).
allowed-tools: [Read, Write, Edit, Bash]
---

# Dev-Log Skill

Two subcommands for brain-kit vault integration:
- **`/devlog init <workspace-slug>`** — Bootstrap and load workspace context
- **`/devlog write`** — Write a session log and update the workspace canonical note

All artifacts live in a brain-kit vault resolved via `.vault.toml`.

---

## `/devlog init <workspace-slug>`

**MANDATORY on every session start for bootstrapped workspaces.** This command is called from `CLAUDE.local.md` before any other work. It ensures the workspace is correctly wired to the vault and loads all workspace context into the session.

**Subagent exclusion:** If you were dispatched as a subagent (via the Agent tool) with a specific task, **skip this entire subcommand.** Do not run init, do not load context, do not write anything. The controller session handles all vault integration. Focus only on your assigned task.

### Step 1 — Resolve Workspace Slug

**Resolve vault config** using `${CLAUDE_PLUGIN_ROOT}/scripts/detect-vault-config.sh` (with `$PWD` as start). If no `.vault.toml` is found, fall back to `~/vaults/myvault/Workspaces/` as the workspaces directory.

From the vault config, derive:
- **vault root** — absolute path
- **workspaces_dir** — `{vault_root}/{vault.workspaces_dir}` (default `{vault_root}/Workspaces`)
- **logs_dir** — `{vault_root}/{vault.logs_dir}` (default `{vault_root}/Log`)
- **system_dir** — `{vault_root}/{vault.system_dir}` (default `{vault_root}/System`)
- **mode** — `strict` if `mode.strict = true`, otherwise `minimal`

Match the `<workspace-slug>` argument against directories under `{workspaces_dir}/`:

1. **Exact match** → use it
2. **Case-insensitive or substring match** → ask user: "Did you mean `{closest-match}`?"
3. **No match** → ask user: "Create new workspace `{slug}`, or use log-only mode (no workspace)?"
   - If create: invoke the `workspaces` skill's create operation (or replicate it inline: `mkdir -p {workspaces_dir}/{slug}/{tasks,notes,agent-artifacts}` and create `{slug}.md` from the appropriate mode template at `${CLAUDE_PLUGIN_ROOT}/templates/{mode}/workspace.md`)
   - If log-only: set `vault_workspace: none` and skip workspace-specific steps

### Step 2 — Ensure Workspace Directories

For a resolved workspace, ensure these mini-vault directories exist:

```
{workspaces_dir}/{slug}/tasks/
{workspaces_dir}/{slug}/notes/
{workspaces_dir}/{slug}/agent-artifacts/
```

Create missing directories silently via `mkdir -p`. Do not move existing files.

### Step 3 — Write/Repair CLAUDE.local.md

Check if `CLAUDE.local.md` exists in the current repo root with correct content. If missing or incomplete, write or repair it silently. This is **self-healing** — it runs every time.

Write the following content (substitute `{slug}`, `{workspaces_dir}`, `{logs_dir}`):

```markdown
# Workspace: {slug}

## MANDATORY: brain-kit Integration

vault_workspace: {slug}

**Subagent exclusion:** If you were dispatched as a subagent (via the Agent tool) with a specific task, **skip all mandatory sections in this file.** Do not run `/devlog init`, do not load context, do not write devlogs, do not update the vault. Focus only on your assigned task. The controller session handles all vault integration.

**Before doing ANYTHING else in this session**, run: `/devlog init {slug}`

This loads workspace context, ensures permissions, and prepares the session for logging.

## MANDATORY: Load Workspace Context

After init completes, immediately read:
```
{workspaces_dir}/{slug}/{slug}.md
```

This is the canonical workspace note. Content above the horizontal rule is the durable manifest (tech stack, key paths, conventions); content below is session-tracked state (current state, what's next, open questions, learnings, recent sessions). **Do not skip this.** Working without context wastes time rediscovering things previous sessions already learned.

## Workspace Artifact Paths

Write all workspace content to the vault under the mini-vault contract — **not** to this repo:
- Tasks: `{workspaces_dir}/{slug}/tasks/`
- Notes (canonical workspace knowledge: plans, specs, decisions, research, learnings, brainstorms — differentiated by `kind:` frontmatter): `{workspaces_dir}/{slug}/notes/`
- Agent artifacts (generated execution reference from coding agents): `{workspaces_dir}/{slug}/agent-artifacts/`

Generated coding-agent plans/specs/reviews/run artifacts are **not** canonical notes. Route them to `agent-artifacts/` with `type: agent-artifact`. Only write to `notes/` when durable knowledge has been explicitly summarized as a normal `type: note`.

## Agent Artifact Frontmatter

When writing generated plans/specs/reviews into `agent-artifacts/`, use minimal frontmatter:
```yaml
---
type: agent-artifact
artifact_kind: plan # plan | spec | review | log | summary
source: claude-code
created: YYYY-MM-DDTHH:mm
modified: YYYY-MM-DDTHH:mm
workspace: "[[{slug}]]"
related_task: "[[task-note-name]]" # optional; omit if not obvious
---
```

Do not add `kind:` to agent artifacts; `kind:` is reserved for `type: note`.

## Dev Log Frontmatter

When writing dev logs for this workspace, use this frontmatter:
```yaml
---
type: log
workspace: "[[{slug}]]"
date: YYYY-MM-DD
---
```

## MANDATORY: Dev-Log is Always Active

**Subagent exclusion:** These devlog and context-loading instructions apply ONLY to the primary interactive session. If you were dispatched as a subagent with a specific task (via the Agent tool), **skip all of this** — do not run `/devlog init`, do not run `/devlog write`, do not read or update `{slug}.md`. Your job is implementation only. The controller session handles all logging.

Dev-log is always on for the primary session. You do not need to be asked. Write a dev log (`/devlog write`) when **any** of these milestones occur:

- **Task completion** — a feature, bugfix, refactor, or investigation is finished
- **Session wrap-up** — user signals they're done ("that's all", "good session", "wrap up", "done for now")
- **Context approaching limits** — write before you lose context of what was done
- **Repo switch** — switching to a different git repo mid-session; log the previous work first
- **Explicit request** — user says "dev log", "write a log", "document this"

**Do not ask permission.** Do not wait for a prompt. When a milestone hits, run `/devlog write`.
```

If `vault_workspace: none`, omit the workspace context loading, artifact paths, and frontmatter sections — keep only the dev-log trigger conditions with log-only instructions.

### Step 4 — Write/Repair .claude/settings.local.json

Check if `.claude/settings.local.json` exists with the required permissions. If missing or incomplete, write or merge.

**Required permissions** (substitute resolved absolute paths):
```json
{
  "permissions": {
    "allow": [
      "Read({logs_dir}/**)",
      "Write({logs_dir}/**)",
      "Edit({logs_dir}/**)",
      "Read({workspaces_dir}/{slug}/**)",
      "Write({workspaces_dir}/{slug}/**)",
      "Edit({workspaces_dir}/{slug}/**)",
      "Read({system_dir}/**)",
      "Write({system_dir}/logs/**)",
      "Edit({system_dir}/logs/**)"
    ]
  }
}
```

If `vault_workspace: none`, only include the `{logs_dir}/` permissions.

If the file already exists with other permissions, **merge** — add the required entries without removing existing ones. Read the file first, parse the existing `allow` array, append any missing entries, write back.

### Step 5 — Ensure Gitignore

Check `.gitignore` for `CLAUDE.local.md` and `.claude/settings.local.json`. Add any missing entries. Do not duplicate existing entries.

```bash
grep -qxF 'CLAUDE.local.md' .gitignore || echo 'CLAUDE.local.md' >> .gitignore
grep -qxF '.claude/settings.local.json' .gitignore || echo '.claude/settings.local.json' >> .gitignore
```

### Step 6 — Load Context

Output a status block, then immediately read the workspace canonical note:

```
✓ brain-kit workspace: {slug}
  Workspace note: {workspaces_dir}/{slug}/{slug}.md
  Tasks:          {workspaces_dir}/{slug}/tasks/
  Notes:          {workspaces_dir}/{slug}/notes/
  Agent artifacts: {workspaces_dir}/{slug}/agent-artifacts/
  Logs:           {logs_dir}/
```

Then `Read({workspaces_dir}/{slug}/{slug}.md)` to load workspace state into agent context.

If `vault_workspace: none`, output only:
```
✓ brain-kit dev-log (log-only mode — no workspace)
  Logs: {logs_dir}/
```

---

## `/devlog write`

Write a comprehensive dev log entry for the completed work, then update shared knowledge files.

**Do not wait to be asked.** This command triggers on milestones defined in `CLAUDE.local.md`.

**Subagent exclusion:** If you were dispatched as a subagent (via the Agent tool), **do nothing.** The controller session handles logging.

### Step 1 — Gather Session Metadata

Collect the following without a helper script (use `date` and `git` directly):

```bash
# Timestamp
date -u +"%Y-%m-%dT%H:%M:%SZ"           # ISO 8601 UTC timestamp
date "+%Y-%m-%d"                          # FILE_DATE
date "+%H%M"                              # FILE_TIME

# Git context
git rev-parse --show-toplevel 2>/dev/null # GIT_REPO (basename)
git branch --show-current 2>/dev/null     # GIT_BRANCH
```

Derive:
- **TIMESTAMP** — ISO 8601 with timezone, use verbatim in log header (never invent)
- **FILE_DATE**, **FILE_TIME** — for filename construction
- **GIT_REPO** — `basename` of the repo root path
- **GIT_BRANCH** — current branch name
- **ISSUE_HINT** — extract issue IDs from branch name using regex `[A-Z]+-[0-9]+` or `[a-z]+-[0-9]+` (e.g., `feat/PROJ-123` → `PROJ-123`). Empty if no match.
- **WORKSPACE_NAME** — read from `CLAUDE.local.md`'s `vault_workspace:` line (may be `none`)

### Step 2 — Resolve Paths

Use the same vault config resolution as `init`:
- **logs_dir** — absolute path to log directory (default `{vault_root}/Log`)
- **workspaces_dir** — absolute path to workspaces directory
- **WORKSPACE_CONTEXT_PATH** — `{workspaces_dir}/{WORKSPACE_NAME}/{WORKSPACE_NAME}.md` (or `none` if workspace is none)

Find the most recent previous log:
```bash
ls -t {logs_dir}/*.md 2>/dev/null | head -1   # PREVIOUS_SESSION_PATH
```

### Step 3 — Load Previous Session

Read the previous session file for continuity:
```
Read(file_path: "{PREVIOUS_SESSION_PATH}")
```

If no previous session exists, skip silently. If continuing work on a specific issue, search for related sessions:
```bash
grep -rl '{ISSUE_HINT}' {logs_dir}/ 2>/dev/null
```

### Step 4 — Construct Filename

Build `SESSION_FILE_PATH`:
- **With issue hint:** `{logs_dir}/{FILE_DATE}_{FILE_TIME}_{ISSUE_HINT}_{description}.md`
- **Without issue hint:** `{logs_dir}/{FILE_DATE}_{FILE_TIME}_{description}.md`

Description: 3–5 words inferred from the session work, lowercase, hyphens (e.g. `add-user-auth`, `fix-prisma-pool`, `port-devlog-skill`).

### Step 5 — Write Session Log

Write to `SESSION_FILE_PATH`. The log schema varies by vault mode — see `references/log-schema.md`.

**Strict mode** — use frontmatter:
```yaml
---
type: log
workspace: "[[{WORKSPACE_NAME}]]"
date: {FILE_DATE}
---
```

**Minimal mode** — no frontmatter required.

In both modes, write these sections:

```markdown
# {TIMESTAMP} ({timezone}) - {Brief Title}

## Overview
2–3 sentences. What was accomplished?

## Context
Why this work? Branch, issue IDs, user request. Link to prior session: [[{previous-log-filename}]].

## Problem Analysis OR Implementation Approach
Bug fix → root cause discovery, investigation steps taken.
Feature → architecture decision, approach chosen.

## Implementation OR Solution
Specific changes: file paths, key patterns, algorithms, build issues resolved.
Include line numbers when referencing specific code locations.

## Testing
How was the work validated? What was tested, what passed, what didn't?

## Design Decisions
**Why X not Y** — use Considered/Rejected/Chosen format for significant decisions.

## Key Learnings
Mistakes made and corrected. Surprises. Better approaches for next time.

## Files Modified
Grouped by repo if multi-repo work.

## Commits
Commit hashes and messages, or note if uncommitted with rationale.
```

Conditional sections (add when relevant):
- `## Remaining Work` — unfinished tasks, follow-ups
- `## Open Questions` — unresolved questions with context and blocking status
- `## Mysteries and Uncertainties` — unexplained behaviors, gaps in understanding
- `## References` — related sessions, external docs, issue links

**More detail is always better than less.** Write for a future session with zero memory of today. 500-line entries are fine; future context is priceless.

### Step 6 — Update Workspace Canonical Note

If `WORKSPACE_NAME` is `none`, skip this step.

Read `{WORKSPACE_CONTEXT_PATH}`, find the horizontal rule (`---` on its own line, separate from frontmatter delimiter), and update the **below-the-rule** sections only.

**CRITICAL BOUNDARY:**
- **Above the rule** — human-authored durable manifest (tech stack, key paths, conventions). `/devlog write` MUST NEVER modify this content. Never touch it.
- **Below the rule** — agent-maintained session state. Update only these sections:

  - **Current State** — what was just built, what's merged, what's in-flight
  - **What's Next** — immediate next step
  - **Open Questions** — things that need decisions (remove resolved ones)
  - **Learnings** — novel discoveries (library quirks, patterns, debugging approaches)
  - **Recent Sessions** — keep last 3 session summaries with wikilinks to full log files

If the workspace note does not yet exist, create it from `${CLAUDE_PLUGIN_ROOT}/templates/{mode}/workspace.md`. Fill above-the-rule sections from discoveries about the repo (tech stack, key paths, conventions) and seed below-the-rule sections from the current session.

### Step 7 — Update Partner Model Log

Append any partner_model observations from this session to the JSONL log file per the partner-model skill's filter and entry schema. This is where partner-model session-end writes happen.

Apply the filter first: **"Would a fresh agent, starting a new session tomorrow with no context about today, work differently if it knew this?"** Only write entries that pass.

Use the partner-model skill's path resolution to find `${PARTNER_MODEL_LOG}`. Append one JSONL entry per observation:
```bash
echo '{"ts": "...", "session": "...", "project": "...", "type": "...", "pattern_ref": null, "text": "..."}' >> "$PARTNER_MODEL_LOG"
```

If no observations pass the filter, skip silently.

### Step 8 — Do NOT commit the vault

**The vault owns its own git lifecycle.** Do not run `git add` / `git commit` / `git push` against the vault from this skill.

If the user has configured vault-level git automation (e.g., a SessionStart hook that snapshots and pushes, atlas-style), it will pick up your file changes on the next session boundary. If they haven't, they'll commit manually when they want — that's their call, not the agent's.

The skill's job ends when files are written. Git is not your concern.

---

## Important Notes

- **Never invent the timestamp** — always use the `date` command output, never fabricate it
- **More detail > less detail** — 500-line entries are fine; future context is priceless
- **Document mistakes** — failed approaches are as valuable as successful ones
- **Design Decisions section is gold** — "why X not Y" ages better than implementation details
- **Mysteries section is honest** — documenting unknowns prevents future sessions from wasting time on dead ends
- **One file per session** — never append to an existing log
- **NEVER modify above-the-rule** content in workspace notes — the horizontal rule is a hard boundary
- **Subagents skip everything** — if dispatched as a subagent, do nothing; the controller handles logging
- **Learnings go in both places** — novel discoveries should appear in the log (detailed) and below-the-rule `## Learnings` in the workspace note (summarized) so future sessions get them without reading every log
