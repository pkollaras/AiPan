#!/usr/bin/env bash
# Στέλνει ένα δοκιμαστικό μήνυμα στο vLLM API.   scripts/test.sh ["ερώτηση"]
source "$(dirname "$0")/common.sh"
URL="$(cat "$STATE_DIR/url")"
KEY="$(cat "$STATE_DIR/api_key")"
SERVED="$(cat "$STATE_DIR/model" 2>/dev/null || echo "$MODEL")"
PROMPT="${1:-Γεια! Πες μου σε μία πρόταση τι μπορείς να κάνεις.}"

until curl -sf -H "Authorization: Bearer $KEY" "$URL/v1/models" >/dev/null; do
  echo "Ο server φορτώνει ακόμα το μοντέλο... (ξαναδοκιμάζω σε 20s)"; sleep 20
done

BODY="$(MODEL="$SERVED" PROMPT="$PROMPT" python3 -c '
import json, os
print(json.dumps({"model": os.environ["MODEL"], "max_tokens": 300,
                  "messages": [{"role": "user", "content": os.environ["PROMPT"]}]}))')"
curl -s "$URL/v1/chat/completions" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" -d "$BODY" \
  | python3 -c 'import json,sys; r=json.load(sys.stdin); print(r["choices"][0]["message"]["content"] if "choices" in r else r)'
