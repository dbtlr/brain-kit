#!/usr/bin/env bash
# Validate a .vault.toml file against the JSON schema.
# Usage: validate-vault-config.sh <path-to-.vault.toml>
set -euo pipefail

config="${1:-}"
if [[ -z "$config" || ! -f "$config" ]]; then
  echo "usage: $0 <path-to-.vault.toml>" >&2
  exit 1
fi

plugin_root="$(cd "$(dirname "$0")/.." && pwd)"
schema="$plugin_root/schemas/vault-config.schema.json"

if ! command -v dasel &>/dev/null; then
  echo "warning: dasel not installed; skipping validation" >&2
  exit 0
fi
if ! command -v ajv &>/dev/null; then
  echo "warning: ajv-cli not installed; skipping validation" >&2
  exit 0
fi

json="$(dasel -r toml -w json < "$config")"
echo "$json" | ajv validate -s "$schema" -d /dev/stdin
