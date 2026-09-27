#!/usr/bin/env bash
# Δείχνει τις φθηνότερες διαθέσιμες GPU που ταιριάζουν στο GPU_QUERY.
source "$(dirname "$0")/common.sh"
"${VAST[@]}" search offers "$GPU_QUERY" --storage "$DISK_GB" -o 'dph_total' --limit "${1:-15}"
