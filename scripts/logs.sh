#!/usr/bin/env bash
# Logs του container.   scripts/logs.sh [INSTANCE_ID]
source "$(dirname "$0")/common.sh"
"${VAST[@]}" logs "$(instance_id "${1:-}")" --tail 100
