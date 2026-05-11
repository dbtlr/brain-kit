---
name: partner-model consolidate
description: Subcommand of partner-model. Reads the JSONL log, applies consolidation rules, and rewrites the consolidated model markdown. Run periodically or after significant new observations. Append-only log is preserved.
allowed-tools: [Read, Write, Edit, Bash]
---

# partner-model consolidate

## Overview

This subcommand reads the full JSONL log, applies consolidation rules, and rewrites the consolidated model markdown file. The log is the append-only audit trail — it is never modified. The model file is the synthesized output — it gets overwritten on each run. Frontmatter is preserved verbatim across rewrites, including `document_id` fields written by external indexers (stripping them breaks indexing pipelines). The operation ends with a diff summary printed to the user so they know what changed at a high level. Silent operation for file I/O; summary output is the only user-visible side effect.

## When to Use

- **Manually invoked** by the user: `partner-model consolidate`
- **Auto-invoked** at the end of the bootstrap subcommand (Task 6) after seed entries are written
- **Scheduled** (e.g., monthly retro cron, post-significant-session hook)
- **NOT invoked mid-session.** Consolidation is a synthesis operation — run it when the session is winding down or after a batch of sessions has accumulated new observations. Running it mid-session adds no value and risks rewriting the model with partial signal.

## Step 1: Resolve Config

Use the same path resolution order as the main `SKILL.md`:

**Tier 1 — Environment variable:**
If `$PARTNER_MODEL_PATH` is set, use it as the model path. Derive:
- Log path: `${PARTNER_MODEL_DIR}/logs/partner_model_log.jsonl`

where `PARTNER_MODEL_DIR` is the parent directory of `$PARTNER_MODEL_PATH`.

**Tier 2 — Vault config discovery:**
If `$PARTNER_MODEL_PATH` is not set, invoke `${CLAUDE_PLUGIN_ROOT}/scripts/detect-vault-config.sh` with `$PWD` as the start directory. If it succeeds:
- Parse the returned `.vault.toml` path using `grep`/`awk`.
- Read `partner_model.path` (default: `System/partner_model.md`) and `partner_model.log_path` (default: `System/logs/partner_model_log.jsonl`).
- Resolve both relative to the vault root (`vault.root` in `.vault.toml`; `"."` means the directory containing `.vault.toml`).
- Apply profile suffix if `partner_model.profile` is set and not `"default"`: `partner_model.md` → `partner_model.${profile}.md`.
- If the log path's parent directory does not exist, fall through to Tier 3.

**Tier 3 — Default fallback:**
- Model: `~/.claude/partner-model/default.md`
- Log: `~/.claude/partner-model/logs/log.jsonl`
- Create the directory structure if it doesn't exist.

**Abort condition:** If the log file does not exist at the resolved path, print `no log file found; nothing to consolidate.` and stop. There is nothing to consolidate without a log.

## Step 2: Read Inputs

**Read the log file.** Process it line by line:
- Skip blank lines silently.
- Attempt to parse each non-blank line as JSON. If a line fails to parse, emit a warning to stderr (`warn: skipping malformed log line {N}: {raw}`) and continue — one bad line should not block the whole run.
- Collect all valid parsed entries into a working list.

**Read the existing model file** if it exists:
- Extract the frontmatter block — the content between the first `---` delimiter and the closing `---`. Preserve it verbatim, including any `document_id`, custom keys, or unusual formatting. If no model file exists yet, treat the frontmatter as empty (you will write a minimal `---\n---\n` block).
- Extract the body (everything after the closing `---`) for reference during diff reporting. The body will be replaced entirely in Step 6.

## Step 3: Group Entries by Theme

Assign each log entry to a theme. This is a **judgment task** — read the entry's `text` field and assign it to the theme whose description best fits the observation. Do not rely on keyword matching alone; meaning determines grouping.

Common themes (from `references/consolidation-rules.md`):
- **Design Thinking** — how the user approaches problems, frames questions, scopes work
- **Communication** — comms style, tells, signals for agreement/uncertainty/frustration
- **Working With Agents** — preferences around spec, autonomy, intervention, execution architecture
- **Quality** — standards, review behavior, regression tolerance, validation approach
- **UX Sensibility** — taste, iteration patterns, operational-UX thinking
- **Technical Profile** — stack, tools, expertise depth, learning trajectory
- **Agent Calibration** — concrete corrections, friction lessons, calibration notes

**New themes:** If 2 or more entries share a coherent theme not in the list above, create a new section for it. One entry is not enough to establish a theme — keep it tentative or fold it into the closest existing theme.

Entries of `type: seed-from-*` (written by the bootstrap subcommand) are tracked separately within each theme so promotion/demotion rules can be applied in Step 4.

## Step 4: Apply Promotion / Demotion Rules

Within each theme, evaluate the collected entries and determine what goes into the model:

**Repeated observations → canonical pattern.**
If the same pattern appears across multiple sessions (same or similar text, or `type: confirmation` entries referencing the same `pattern_ref`), promote it to a canonical bullet. Drop the session-level noise — the bullet is the abstracted signal.

**Single observations → tentative.**
If a pattern appears only once and has no subsequent confirmations, keep it but mark it as tentative in your synthesis (you may note it as "observed once" in the bullet text, or hold it at lower confidence). It should not be presented with the same authority as a confirmed pattern.

**Confirmations strengthen, don't duplicate.**
A `type: confirmation` entry says an existing pattern held in a new context. It adds weight to the existing bullet — it does not generate a new bullet. Merge it silently.

**Corrections override.**
A `type: correction` entry says the current model is wrong or incomplete. Rewrite the affected pattern to reflect the correction. Cite the correction's session in a parenthetical: `(corrected YYYY-MM-DD)`. The old version is gone — the corrected version is canonical.

**Seed entries: demotion rules.**
Entries from the `bootstrap` subcommand are tagged `[seed-from-*]` in their text or `session` field. Apply this logic:
- If a real observed entry (non-seed) covers the same ground, the seed entry is superseded. Drop it from the model — the real observation takes its place.
- If fewer than 5 real sessions have contributed entries (count distinct session values across non-seed entries), keep any uncontested seed entries in the model as lightweight placeholders.
- After 5+ real sessions, drop all remaining seed entries entirely. The model should be grounded in observation by that point.

## Step 5: Generate the Model Body

For each theme (in standard order), write a section with pattern bullets. Each bullet follows this format:

```
- **Pattern name.** One-line declarative statement of the pattern.
  - **Why:** Optional one-line rationale — when to apply this observation or what it tells you.
```

Guidelines for tone and style:
- **Terse and declarative.** No hedging, no padding, no "it seems that." State the pattern as a fact derived from observation.
- **Bold lead-in** names the pattern at a glance; the rest of the sentence gives the content. A reader skimming bold text should get the map; a reader reading the full sentence gets the signal.
- **Why lines are optional** but valuable when the pattern is non-obvious or when knowing the cause changes how you apply it.
- **Don't over-explain.** If a pattern takes three sentences to state, it's probably two patterns.

Standard section ordering:
1. Design Thinking
2. Communication
3. Working With Agents
4. Quality
5. UX Sensibility
6. Technical Profile
7. Agent Calibration
8. (Any new sections, appended after the standard seven)

If a theme has no patterns that survived promotion/demotion, omit its section from the output.

## Step 6: Compose the New Model File

Assemble the new file content in this order:

1. **Frontmatter** — the preserved block from Step 2, verbatim. If no prior model existed, use a minimal block:
   ```
   ---
   ---
   ```

2. **Preamble** — immediately below the closing `---`, add:
   ```
   **Purpose:** Living model of the user, maintained by Claude instances. Generated by consolidation. Do not edit directly — update the log instead.

   **Maintenance:** Session observations are appended to the JSONL log. This file is regenerated by the `partner-model consolidate` subcommand.

   Everything below this line is generated by consolidation and may change with each run.

   ---
   ```

3. **Theme sections** — the generated body from Step 5.

**Atomic write:** Do not write directly to the model file path. Instead:
```bash
# Write to a temp file, then rename atomically
TMPFILE="$(dirname "$MODEL_PATH")/.partner_model_tmp_$$"
# ... write content to $TMPFILE ...
mv "$TMPFILE" "$MODEL_PATH"
```

This prevents leaving the model in a half-written state if the process is interrupted mid-write. The rename is atomic on POSIX systems.

## Step 7: DO NOT Delete the Log

The JSONL log is the append-only audit trail of all observations. It is never modified or deleted by this subcommand or any other. Consolidation reads the log and rewrites the model — the log itself is sacred. If you find yourself with any impulse to truncate, rotate, or clean the log, stop. The model is the clean artifact; the log is the raw history.

This is not a cleanup step — it is a reminder. Preserve the log exactly as found.

## Step 8: Print Diff Summary

After writing the new model file, print a summary to the user. The diff doesn't need to be mechanically precise — it should give the user a clear sense of what changed at a section level.

```
✓ partner-model consolidated
  Model: {absolute path to model file}
  Log entries processed: {N}
  Sections in new model: {M}
    Added: {list of new section names not present in previous model, or "none"}
    Modified: {list of section names where patterns changed, or "none"}
    Unchanged: {list of section names that are substantively the same, or "none"}
    Removed: {list of section names present before but dropped for lack of support, or "none"}
  Seed entries remaining: {count of seed entries still in the new model, or 0}
```

To generate this summary, compare the section names you found in the old model body (Step 2) against the sections in the new model body (Step 5). Identifying which specific patterns changed within a section is a best-effort judgment — if you can't tell precisely, a section-level "Modified" is sufficient.
