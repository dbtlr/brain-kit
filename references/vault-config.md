# vault-config reference

`.vault.toml` is the single config file that ties a brain-kit vault together. Every skill reads it on startup to locate directories, resolve partner model paths, and determine which mode the vault runs in.

## Location and discovery

`.vault.toml` lives in the **vault root** — the top-level directory of your vault. Skills discover it by walking up from the current working directory (`$PWD`) toward the filesystem root, stopping at the first `.vault.toml` they find. This means you can `cd` into any subdirectory of your vault and skills will still locate the config.

Discovery is handled by `scripts/detect-vault-config.sh`. If no `.vault.toml` is found anywhere in the walk, skills fall back to a default path (`~/.claude/partner-model/`) or become inactive.

```
~/my-vault/
├── .vault.toml         ← discovered from anywhere inside my-vault/
├── Workspaces/
│   └── brain-kit/
│       └── brain-kit.md    ← cd here → still finds .vault.toml
└── Notes/
```

## Format

TOML. All sections are optional except `[vault]`, which requires `root`.

---

## `[vault]` section

The only required section.

| Key | Type | Default | Description |
|---|---|---|---|
| `root` | string | — | **Required.** Path to vault root, relative to `.vault.toml`'s location. Typically `"."` (same directory as the config file). May be absolute. |
| `workspaces_dir` | string | `"Workspaces"` | Directory holding workspace folders, relative to vault root. |
| `notes_dir` | string | `"Notes"` | Directory for standalone canonical notes. |
| `logs_dir` | string | `"Log"` | Directory where dev-log writes session logs. |
| `journal_dir` | string | `"Journal"` | Directory for daily journal entries. Used in strict mode. |
| `system_dir` | string | `"System"` | Directory for vault infrastructure (templates, partner model, etc.). |

**`vault.root` semantics:** If `root` starts with `/`, it's used as-is. Otherwise it's resolved relative to the directory containing `.vault.toml`. The convention `root = "."` means the vault root equals the directory that holds the config file.

```toml
[vault]
root = "."
workspaces_dir = "Workspaces"
logs_dir = "Log"
```

---

## `[partner_model]` section

Controls where the partner model skill reads and writes its files.

| Key | Type | Default | Description |
|---|---|---|---|
| `path` | string | `"System/partner_model.md"` | Path to the consolidated model markdown file, relative to vault root. Adjusted by `profile` — see below. |
| `log_path` | string | `"System/logs/partner_model_log.jsonl"` | Path to the JSONL observation log, relative to vault root. Shared across all profiles in v0.1. |
| `profile` | string | `"default"` | Context name for this vault's model. See profile semantics below. |

### Profile semantics

`profile` lets one user maintain separate partner models per context — for example, separate models for work and personal use. When a profile other than `"default"` is set, the model filename is adjusted:

```
partner_model.md  →  partner_model.{profile}.md
```

So `profile = "work"` means the consolidated model lives at `System/partner_model.work.md`. The JSONL log path is **not** split by profile in v0.1 — all profiles share the same log file.

```toml
[partner_model]
profile = "work"
# model path becomes: System/partner_model.work.md
# log path stays:    System/logs/partner_model_log.jsonl
```

---

## `[mode]` section

| Key | Type | Default | Description |
|---|---|---|---|
| `strict` | boolean | `false` | When `true`, enforce the typed-note ontology. Skills apply typed frontmatter requirements and install structured typed-note templates. |

### What `strict` changes

**Strict mode (`strict = true`):**
- Workspace canonical notes require `type`, `kind`, `title`, `aliases`, `description`, `created`, `modified` frontmatter
- Task files require `type: task`, `workspace`, and `status` frontmatter
- Notes files require `type: note` and a valid `kind`
- Agent artifact files require `type: agent-artifact` and `artifact_kind`
- `/brain-init` installs typed templates into `${system_dir}/Templates/`

**Minimal mode (`strict = false` or absent):**
- Only structural requirements apply: directory layout and the above/below-the-rule split in canonical workspace notes
- No frontmatter enforced on any file

See [strict-mode-ontology.md](strict-mode-ontology.md) for the full type/kind taxonomy.

---

## `[persona]` section

| Key | Type | Default | Description |
|---|---|---|---|
| `path` | string | — | Path to a self-persona note, relative to vault root. If set, the partner-model skill reads this as declared facts about the user (role, context, stakeholders). |

The persona file is hand-maintained — the partner-model skill reads it but never writes to it. See [partner-model-schema.md](partner-model-schema.md) for how the persona interacts with the observation log.

```toml
[persona]
path = "Notes/me.md"
```

---

## Complete examples

### Minimal vault

```toml
[vault]
root = "."

[partner_model]
profile = "default"
```

Everything else uses defaults: `Workspaces/`, `Notes/`, `Log/`, no typed-note enforcement.

### Strict vault with custom paths

```toml
[vault]
root = "."
workspaces_dir = "Projects"
logs_dir = "SessionLogs"
system_dir = "System"
journal_dir = "Journal"

[partner_model]
profile = "work"
path = "System/partner_model.work.md"
log_path = "System/logs/partner_model_log.jsonl"

[mode]
strict = true

[persona]
path = "Notes/me.md"
```

---

## Troubleshooting

**"no .vault.toml found"**

Skills couldn't find a config by walking up from `$PWD`. Options:
1. Run `/brain-init` in your vault directory — this creates the config file.
2. Verify you're inside the vault directory: `ls .vault.toml` from your vault root should succeed.
3. Check that the walk from CWD upward includes your vault root (no symlink detours that skip it).

**Schema validation failing**

If using `scripts/validate-vault-config.sh` (requires `dasel` + `ajv-cli`):

- Check that all required fields are present — `vault.root` is the only required key.
- Ensure `mode.strict` is a boolean (`true`/`false`), not a string (`"true"`).
- Ensure `partner_model.profile` is a string.

Run the validator directly for detailed output:

```bash
scripts/validate-vault-config.sh /path/to/.vault.toml
```

**Environment variable override**

If `$PARTNER_MODEL_PATH` is set in your shell, the partner-model skill uses it instead of `.vault.toml`. This takes priority over all config-based path resolution. Unset it if you want vault config to control the model path.
