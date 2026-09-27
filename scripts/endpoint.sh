#!/usr/bin/env bash
# Τυπώνει το δημόσιο URL του server.   scripts/endpoint.sh [INSTANCE_ID] [--wait]
source "$(dirname "$0")/common.sh"

ARG_ID=""; WAIT=0
for a in "$@"; do [[ "$a" == "--wait" ]] && WAIT=1 || ARG_ID="$a"; done
ID="$(instance_id "$ARG_ID")"
PORT="$(cat "$STATE_DIR/port" 2>/dev/null || echo 8000)"
PROFILE="$(cat "$STATE_DIR/profile" 2>/dev/null || echo vllm)"

lookup() {
  "${VAST[@]}" show instance "$ID" --raw | PORT="$PORT" python3 -c '
import json, os, sys
i = json.load(sys.stdin)
ports = (i.get("ports") or {}).get(os.environ["PORT"] + "/tcp") or []
status = i.get("actual_status") or "?"
if status == "running" and ports and i.get("public_ipaddr"):
    print("OK http://%s:%s" % (i["public_ipaddr"].strip(), ports[0]["HostPort"]))
else:
    print("WAIT " + status)
'
}

while :; do
  OUT="$(lookup)"
  if [[ "$OUT" == OK* ]]; then
    URL="${OUT#OK }"
    echo "$URL" > "$STATE_DIR/url"
    echo
    echo "Server URL: $URL"
    if [[ "$PROFILE" == vllm || "$PROFILE" == coding ]]; then
      echo "OpenAI base_url: $URL/v1"
      echo "API key:         $(cat "$STATE_DIR/api_key" 2>/dev/null)"
      echo "Model:           $(cat "$STATE_DIR/model" 2>/dev/null)"
      echo "(Το μοντέλο κατεβαίνει στην πρώτη εκκίνηση — έλεγξε με: scripts/test.sh ή scripts/logs.sh)"
      [[ "$PROFILE" == coding ]] && echo "Claude Code:     scripts/claude-code.sh"
    else
      echo "Άνοιξε το URL στον browser και κάνε ΑΜΕΣΩΣ εγγραφή (ο πρώτος χρήστης γίνεται admin)."
    fi
    exit 0
  fi
  [[ $WAIT -eq 1 ]] || { echo "Δεν είναι έτοιμο ακόμα (${OUT#WAIT })."; exit 1; }
  echo "  status: ${OUT#WAIT } ..."
  sleep 15
done
