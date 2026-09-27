#!/usr/bin/env bash
# Κοινές ρυθμίσεις για όλα τα scripts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="$ROOT/.state"
mkdir -p "$STATE_DIR"

if [[ ! -f "$ROOT/config.env" ]]; then
  echo "Λείπει το config.env. Τρέξε: cp config.env.example config.env" >&2
  exit 1
fi
# shellcheck disable=SC1091
set -a; source "$ROOT/config.env"; set +a

command -v vastai >/dev/null || { echo "Λείπει το vastai CLI. Τρέξε: pip install vastai" >&2; exit 1; }
command -v python3 >/dev/null || { echo "Χρειάζεται python3." >&2; exit 1; }

if [[ -z "${VAST_API_KEY:-}" ]]; then
  echo "Συμπλήρωσε το VAST_API_KEY στο config.env." >&2
  exit 1
fi
VAST=(vastai --api-key "$VAST_API_KEY")

# Instance id: 1ο όρισμα ή το τελευταίο που δημιουργήθηκε από το launch.sh
instance_id() {
  local id="${1:-}"
  if [[ -z "$id" && -f "$STATE_DIR/instance_id" ]]; then
    id="$(cat "$STATE_DIR/instance_id")"
  fi
  [[ -n "$id" ]] || { echo "Δώσε instance id (δες: vastai show instances)." >&2; exit 1; }
  echo "$id"
}
