#!/usr/bin/env bash
# Διαγράφει ΟΡΙΣΤΙΚΑ το instance και τον δίσκο του — μηδενική χρέωση από εδώ και πέρα.
source "$(dirname "$0")/common.sh"
ID="$(instance_id "${1:-}")"
read -r -p "Διαγραφή instance $ID και όλων των δεδομένων του; [y/N] " ok
[[ "$ok" == [yY] ]] || exit 0
"${VAST[@]}" destroy instance "$ID"
rm -f "$STATE_DIR/instance_id" "$STATE_DIR/url"
