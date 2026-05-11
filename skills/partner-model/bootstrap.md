---
name: partner-model bootstrap
description: Subcommand of partner-model. Seeds the consolidated model from a persona file (declared facts) and optionally from past Claude Code conversation logs (observed behavior). Never asks the user about preferences — observations are derived, not surveyed. Idempotent — no-op if model already exists with content.
allowed-tools: [Read, Write, Edit, Bash]
---

# partner-model bootstrap

## Overview

This subcommand seeds the partner model on first run with **inferred observations**, never user-reported preferences. It checks for a persona file (declared facts about the user) and optionally for past Claude Code conversation logs (observed behavioral patterns), derives observation entries from each, writes them to the JSONL log with `[seed-from-*]` prefixes, then invokes consolidation to produce the initial model markdown. If no sources are available, it writes an empty model and exits — observations will accumulate from real sessions.

The bootstrap is **read-only with respect to the user**. It does not ask questions. See `references/seed-sources.md` for the full sourcing model and rationale.

## When to use

Invoke manually when the user runs `/partner-model bootstrap`, or invoke automatically by the `brain-init` skill during new vault setup. Safe to call multiple times — the idempotency check ensures a second invocation is a no-op when the model already contains content.

## Step 1: Resolve config

Use the same three-tier path resolution defined in `SKILL.md` under **File Locations** — do not duplicate the logic here. The outcome is:

- **Model path** — absolute path to the consolidated model markdown file.
- **Log path** — absolute path to the JSONL log file.
- **Persona path** — resolved from `$PERSONA_PATH` (env var) if set, or from `persona.path` in `.vault.toml` relative to vault root. If neither, persona path is unset.
- **Profile** — `partner_model.profile` from `.vault.toml`, or `"default"` if absent. Used in summary output only.
- **Crawl CC logs flag** — `mode.crawl_cc_logs` from `.vault.toml` (default `false`). Opt-in because it reads user content.

If no writable path can be determined (tier 3 directory creation also fails), abort with an informative message and exit cleanly — do not write anything.

## Step 2: Idempotency check

Read the model file at the resolved model path. If the file exists AND contains more than just a YAML frontmatter block (non-whitespace content below the closing `---`), the model is already initialized. Print:

```
partner-model already initialized at {path}.
Use `consolidate` to refresh from logs.
```

Then exit cleanly. This is not an error.

To test: `test -f "$MODEL_PATH"` first, then `grep -v '^---' "$MODEL_PATH" | grep -c '\S'`. Count > 0 means initialized.

## Step 3: Identify seed sources

Check each potential source. Sources are non-exclusive — both may apply.

- **Persona source** — true if persona path is set AND `test -s "$PERSONA_PATH"` (exists and non-empty).
- **CC logs source** — true if `mode.crawl_cc_logs` is true AND `~/.claude/projects/` exists AND contains at least one project directory with JSONL files modified within the last 30 days.

Record which sources are active. The summary in Step 7 reports them. If no sources are active, skip Step 4 and proceed to Step 6 — bootstrap still runs consolidation to produce a valid (empty-but-frontmattered) model file.

## Step 4: Derive observations from sources

For each active source, derive observation entries per the rules in `references/seed-sources.md`. The agent invoking this subcommand reads the source content and writes log entries that describe what it INFERRED about the user — not what the user told it.

### 4a: From persona

Read the persona file. For each declared fact (sections like "Current role", "What I'm optimizing for", "Stakeholders", "Growth edges"), produce one observation entry. Be conservative — encode only what the file directly supports.

All entries use:
- `type: observation`
- `session: bootstrap-seed-{timestamp}` where `{timestamp}` is the ISO 8601 UTC timestamp at the start of bootstrap (e.g., `bootstrap-seed-2026-05-10T14:00:00Z`)
- `pattern_ref: null`
- Text prefixed with `[seed-from-persona]`

Example entry:

```jsonl
{"ts": "2026-05-10T14:00:00Z", "session": "bootstrap-seed-2026-05-10T14:00:00Z", "project": "brain-kit", "type": "observation", "pattern_ref": null, "text": "[seed-from-persona] User is a senior staff engineer; assume technical depth and systems thinking."}
```

### 4b: From Claude Code logs (optional)

**v0.1 status:** Specified but **not implemented**. The flag is recognized; the crawler is deferred to v0.2 (tracked in `v0.2-and-beyond.md`). Skip this step in v0.1 even when the flag is set.

When implemented: read the most recent N conversation JSONL files under `~/.claude/projects/` (bounded by recency and total count per `references/seed-sources.md`). Look for behavioral patterns (terseness, correction signals, decision speed, tool preferences). Encode patterns observed in ≥2 sessions as observation entries with prefix `[seed-from-cc-logs]`. Never include verbatim content from conversations. See `references/seed-sources.md` for full rules.

## Step 5: Append seeds to log

Ensure the log file's parent directory exists. For tier-3 (default fallback), create it if needed:

```bash
mkdir -p "$(dirname "$LOG_PATH")"
```

For tier-2 (vault-resolved), do NOT create directories — fall back to tier 3 in Step 1 if the directory is missing.

Append each seed entry to the log file, one JSON object per line, using the `echo >>` pattern from `SKILL.md`:

```bash
echo '{"ts": "...", "session": "...", "project": "...", "type": "observation", "pattern_ref": null, "text": "..."}' >> "$LOG_PATH"
```

The `project` field is the current project. Use `basename "$PWD"` if no better context is available. Never overwrite or truncate the log.

## Step 6: Run consolidation

Invoke the `consolidate` subcommand. Consolidation reads the JSONL log and rewrites the model markdown with sectioned patterns derived from all entries, including the seeds just written.

If no observations were derived in Step 4 (no sources active or all empty), still run consolidation — it will produce a model file with frontmatter and an explicit "no observations yet" note. That's acceptable; future sessions populate it via real observation.

If consolidation is not yet available, write a minimal stub model file to satisfy the idempotency check:

```markdown
---
generated: {timestamp}
profile: {profile}
seed_sources: {comma-separated list, or "none"}
---

# Partner Model

> No observations yet. Future sessions will populate this via passive observation and periodic `consolidate`.
```

## Step 7: Print summary

This is the one point where partner-model talks to the user directly. Bootstrap is an explicit setup command; user-facing output is appropriate.

```
✓ partner-model bootstrapped
  Model: {model_path}
  Log: {log_path}
  Seed sources: {comma-separated active sources, or "none — empty model"}
  Entries seeded: {count}
  Profile: {profile}

Future sessions will refine the model via observation + periodic consolidation.
```

Where:
- `{model_path}` — resolved absolute path to the model file
- `{log_path}` — resolved absolute path to the JSONL log file
- `{count}` — number of seed entries written in Step 5 (0 if no sources)
- `{profile}` — resolved profile name
