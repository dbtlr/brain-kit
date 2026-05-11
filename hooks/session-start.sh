#!/usr/bin/env bash
# brain-kit SessionStart hook
#
# Loads the partner-model file (if available) and outputs it to stdout so
# Claude sees it as initial session context.
#
# Path resolution mirrors the three-tier logic in
# skills/partner-model/SKILL.md:
#   1. $PARTNER_MODEL_PATH env var
#   2. .vault.toml discovered by walking up from CWD
#   3. ~/.claude/partner-model/default.md (only if the file exists)
#
# Silent no-op in non-brain-kit contexts: if no model file is reachable,
# exits 0 with no output. Designed to be safe to run in any repo.

set -uo pipefail

# Locate the plugin's detect script. CLAUDE_PLUGIN_ROOT is set by the
# Claude Code runtime; fall back to deriving from script path for manual testing.
plugin_root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
detect="${plugin_root}/scripts/detect-vault-config.sh"

# Helper: read a key from a TOML section. Tolerates whitespace and quoting.
# Usage: toml_get <file> <section> <key>
toml_get() {
  local file="$1" section="$2" key="$3"
  awk -v s="[$section]" -v k="$key" '
    $0 == s { in_section = 1; next }
    /^\[/ { in_section = 0 }
    in_section && $0 ~ "^" k "[[:space:]]*=" {
      sub("^" k "[[:space:]]*=[[:space:]]*", "")
      gsub(/^"/, ""); gsub(/"[[:space:]]*$/, "")
      print
      exit
    }
  ' "$file"
}

resolve_model_path() {
  # Tier 1: env var
  if [[ -n "${PARTNER_MODEL_PATH:-}" ]]; then
    printf '%s\n' "$PARTNER_MODEL_PATH"
    return 0
  fi

  # Tier 2: .vault.toml discovery
  local vault_config
  if vault_config="$("$detect" 2>/dev/null)"; then
    local config_dir vault_root_rel actual_root model_rel profile
    config_dir="$(dirname "$vault_config")"

    vault_root_rel="$(toml_get "$vault_config" vault root)"
    vault_root_rel="${vault_root_rel:-.}"
    if [[ "$vault_root_rel" = /* ]]; then
      actual_root="$vault_root_rel"
    else
      actual_root="${config_dir}/${vault_root_rel}"
    fi

    model_rel="$(toml_get "$vault_config" partner_model path)"
    model_rel="${model_rel:-System/partner_model.md}"

    profile="$(toml_get "$vault_config" partner_model profile)"
    if [[ -n "$profile" && "$profile" != "default" ]]; then
      model_rel="${model_rel%.md}.${profile}.md"
    fi

    printf '%s\n' "${actual_root}/${model_rel}"
    return 0
  fi

  # Tier 3: default fallback (only if the file already exists; we don't
  # create the directory on session start)
  local default_path="$HOME/.claude/partner-model/default.md"
  if [[ -f "$default_path" ]]; then
    printf '%s\n' "$default_path"
    return 0
  fi

  return 1
}

main() {
  local model_path
  if ! model_path="$(resolve_model_path)"; then
    exit 0  # No brain-kit context — silent skip
  fi

  if [[ ! -f "$model_path" || ! -s "$model_path" ]]; then
    exit 0  # Model not yet populated — silent skip
  fi

  # Emit the model as context. The <partner-model> tags help Claude recognize
  # the source and the path attribute identifies where the content came from.
  printf '<partner-model source="%s">\n' "$model_path"
  cat "$model_path"
  printf '\n</partner-model>\n'
}

main "$@"
