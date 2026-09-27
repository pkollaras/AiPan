#!/usr/bin/env bash
# Σταματά το instance: η GPU δεν χρεώνεται, ο δίσκος (μοντέλα) χρεώνεται λίγο και μένει.
#   scripts/stop.sh [INSTANCE_ID]        — ξαναξεκινά με: vastai start instance ID
source "$(dirname "$0")/common.sh"
"${VAST[@]}" stop instance "$(instance_id "${1:-}")"
