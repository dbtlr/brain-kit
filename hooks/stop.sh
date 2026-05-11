#!/usr/bin/env bash
# brain-kit Stop hook
#
# Fires when the agent attempts to stop. Backstop for partner-model writes:
# if this session resolved to a brain-kit partner-model log path AND we
# haven't already prompted in this session, block the stop with a brief
# reason asking the agent to apply the partner-model filter and write
# any observations that pass — or stop cleanly if nothing meets the bar.
#
# Idempotent within a session: uses session_id from hook input to mark
# that we've already fired, so subsequent stops in the same session
# allow through without re-prompting (avoids infinite loops).
#
# Silent no-op in non-brain-kit contexts (no partner-model resolvable).

set -uo pipefail

# Read hook input (JSON on stdin)
hook_input="$(cat || true)"

# Extract session_id for dedupe. Use jq if available, else cheap grep.
session_id=""
if command -v jq >/dev/null 2>&1; then
  session_id="$(printf '%s' "$hook_input" | jq -r '.session_id // empty' 2>/dev/null || true)"
fi
if [[ -z "$session_id" ]]; then
  # Fallback parse — best effort
  session_id="$(printf '%s' "$hook_input" \
    | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | sed 's/.*"\([^"]*\)"[[:space:]]*$/\1/' \
    | head -1)"
fi

# If no session_id, can't dedupe. Allow stop silently.
if [[ -z "$session_id" ]]; then
  exit 0
fi

marker="/tmp/brain-kit-stop-${session_id}"

# Already prompted this session — allow stop
if [[ -f "$marker" ]]; then
  exit 0
fi

# Resolve partner-model log path to confirm we're in a brain-kit context
# and to include the concrete path in the prompt.
plugin_root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
detect="${plugin_root}/scripts/detect-vault-config.sh"

resolve_log_path() {
  # Tier 1: env var
  if [[ -n "${PARTNER_MODEL_PATH:-}" ]]; then
    printf '%s\n' "$(dirname "$PARTNER_MODEL_PATH")/logs/partner_model_log.jsonl"
    return 0
  fi

  # Tier 2: vault config
  local vault_config
  if vault_config="$("$detect" 2>/dev/null)"; then
    local config_dir vault_root_rel actual_root log_rel
    config_dir="$(dirname "$vault_config")"

    vault_root_rel="$(awk '
      /^\[vault\]/ { in_section = 1; next }
      /^\[/ { in_section = 0 }
      in_section && /^root[[:space:]]*=/ {
        sub(/^root[[:space:]]*=[[:space:]]*/, "")
        gsub(/^"/, ""); gsub(/"[[:space:]]*$/, "")
        print; exit
      }
    ' "$vault_config")"
    vault_root_rel="${vault_root_rel:-.}"
    if [[ "$vault_root_rel" = /* ]]; then
      actual_root="$vault_root_rel"
    else
      actual_root="${config_dir}/${vault_root_rel}"
    fi

    log_rel="$(awk '
      /^\[partner_model\]/ { in_section = 1; next }
      /^\[/ { in_section = 0 }
      in_section && /^log_path[[:space:]]*=/ {
        sub(/^log_path[[:space:]]*=[[:space:]]*/, "")
        gsub(/^"/, ""); gsub(/"[[:space:]]*$/, "")
        print; exit
      }
    ' "$vault_config")"
    log_rel="${log_rel:-System/logs/partner_model_log.jsonl}"
    printf '%s\n' "${actual_root}/${log_rel}"
    return 0
  fi

  # Tier 3: default fallback path (only meaningful if it already exists)
  local default_path="$HOME/.claude/partner-model/logs/log.jsonl"
  if [[ -f "$default_path" ]]; then
    printf '%s\n' "$default_path"
    return 0
  fi

  return 1
}

if ! log_path="$(resolve_log_path)"; then
  # Not a brain-kit context — silent allow
  exit 0
fi

# Mark this session as prompted (we'll only fire once per session)
touch "$marker"

# Emit block JSON. The reason text tells the agent what to do and what
# the filter is. The agent applies the filter and writes only if it
# clears the bar — otherwise it acknowledges "nothing this session" and
# stops on the next turn (marker file lets the second Stop pass).
cat <<EOF
{
  "decision": "block",
  "reason": "Before ending the session: apply the partner-model filter to anything you noticed about the user this session. The filter: 'Would a fresh agent, starting a new session tomorrow with no context about today, work differently if it knew this?' If yes, append one JSONL entry per observation to: ${log_path}. Use the schema from the partner-model skill (ts, session, project, type, pattern_ref, text). Most sessions have nothing that passes the filter — that is the expected case. If nothing meets the bar, briefly say 'no partner-model observations this session' and stop. Do not write for the sake of writing; noise hurts the model. Consolidation does not clean up everything."
}
EOF
exit 0
