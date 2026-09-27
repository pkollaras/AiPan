#!/usr/bin/env bash
# Κοινές ρυθμίσεις για όλα τα scripts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE_DIR="$ROOT/.state"
mkdir -p "$STATE_DIR"

# Defaults από το config.env.example, και από πάνω το config.env (αν υπάρχει).
# Ένα VAST_API_KEY από το περιβάλλον (π.χ. secret του CI/cloud) έχει προτεραιότητα.
ENV_VAST_API_KEY="${VAST_API_KEY:-}"
# shellcheck disable=SC1091
set -a; source "$ROOT/config.env.example"
[[ -f "$ROOT/config.env" ]] && source "$ROOT/config.env"
set +a
VAST_API_KEY="${ENV_VAST_API_KEY:-$VAST_API_KEY}"

command -v vastai >/dev/null || { echo "Λείπει το vastai CLI. Τρέξε: pip install vastai" >&2; exit 1; }
command -v python3 >/dev/null || { echo "Χρειάζεται python3." >&2; exit 1; }

if [[ -z "${VAST_API_KEY:-}" ]]; then
  echo "Συμπλήρωσε το VAST_API_KEY στο config.env ή όρισέ το ως μεταβλητή περιβάλλοντος." >&2
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
