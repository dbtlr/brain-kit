#!/usr/bin/env bash
# Walk up from $1 (default $PWD) until .vault.toml is found. Print absolute path or exit 1.
set -euo pipefail

start="${1:-$PWD}"
dir="$(cd "$start" && pwd)"

while [[ "$dir" != "/" ]]; do
  if [[ -f "$dir/.vault.toml" ]]; then
    echo "$dir/.vault.toml"
    exit 0
  fi
  dir="$(dirname "$dir")"
done

echo "no .vault.toml found above $start" >&2
exit 1
