# Consolidation Rules

The `consolidate` subcommand reads the JSONL log and rewrites the consolidated model markdown file. These rules govern how entries are merged.

## Grouping

Group entries by theme. Common themes:
- **Design Thinking** — how the user approaches problems
- **Communication** — comms style, signals, tells
- **Working With Agents** — preferences for spec, autonomy, intervention
- **Quality** — standards, review behavior, regression tolerance
- **UX Sensibility** — taste, iteration patterns
- **Technical Profile** — stack, tools, expertise depth
- **Agent Calibration** — concrete corrections and lessons

The model is sectioned by theme. New themes get their own section if 2+ entries support them.

## Promotion / Demotion

- **Repeated observations** in the same theme over multiple sessions → promote to a canonical pattern bullet.
- **Single observations** that haven't been confirmed in subsequent sessions → keep but note as tentative.
- **Confirmations** strengthen an existing pattern (don't add a new one).
- **Corrections** override prior patterns. Rewrite the affected pattern with the corrected version. Cite the correction's session in a parenthetical: `(corrected 2026-04-11)`.

## Seed Entries

Entries marked `[seed]` (from the `bootstrap` subcommand) are downgraded once an observed entry covers the same ground. After 5+ real sessions, drop seed entries entirely unless they remain useful.

## Frontmatter Preservation

The consolidated model file may have `document_id` (assigned by an external indexer) or other frontmatter. Preserve it verbatim across rewrites.

## Append-Only Log

Never delete or modify log entries. The log is the audit trail. Consolidation rewrites the model, never the log.

## Diff Reporting

After rewriting, print a brief summary:
- Sections added
- Sections modified (which patterns changed)
- Sections deprecated (patterns that no longer hold)

This goes to stdout for the user, not into the model file.
