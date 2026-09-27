#!/usr/bin/env bash
# Τρέχει το Claude Code πάνω στο δικό σου μοντέλο (profile: coding).
#   scripts/claude-code.sh [ορίσματα του claude...]
# Το vLLM εκθέτει Anthropic Messages API (/v1/messages), οπότε το Claude Code
# μιλάει απευθείας μαζί του χωρίς proxy.
#
# Δεν χρειάζεται VAST_API_KEY: διαβάζει μόνο το .state/ που γράφει το launch.sh.
set -euo pipefail
STATE_DIR="$(cd "$(dirname "$0")/.." && pwd)/.state"

command -v claude >/dev/null || { echo "Λείπει το Claude Code: npm install -g @anthropic-ai/claude-code" >&2; exit 1; }
[[ -f "$STATE_DIR/url" ]] || { echo "Δεν υπάρχει server. Τρέξε: scripts/launch.sh coding" >&2; exit 1; }

URL="$(cat "$STATE_DIR/url")"
MODEL="$(cat "$STATE_DIR/model")"

# Χωρίς /v1 στο τέλος: το Claude Code προσθέτει μόνο του το /v1/messages.
export ANTHROPIC_BASE_URL="$URL"
ANTHROPIC_AUTH_TOKEN="$(cat "$STATE_DIR/api_key")"
export ANTHROPIC_AUTH_TOKEN
unset ANTHROPIC_API_KEY
# Όλα τα "tiers" (opus/sonnet/haiku, subagents) πάνε στο ίδιο μοντέλο.
export ANTHROPIC_MODEL="$MODEL"
export ANTHROPIC_DEFAULT_OPUS_MODEL="$MODEL"
export ANTHROPIC_DEFAULT_SONNET_MODEL="$MODEL"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$MODEL"
export CLAUDE_CODE_SUBAGENT_MODEL="$MODEL"
# Όχι telemetry/κλήσεις προς Anthropic, και σταθερό system prompt για prefix caching.
export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
export CLAUDE_CODE_ATTRIBUTION_HEADER=0

exec claude "$@"
