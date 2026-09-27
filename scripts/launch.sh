#!/usr/bin/env bash
# Νοικιάζει GPU στο Vast.ai και σηκώνει τον AI server.
#
#   scripts/launch.sh vllm  [OFFER_ID]   # OpenAI-compatible API (vLLM) στην πόρτα 8000
#   scripts/launch.sh webui [OFFER_ID]   # Open WebUI + Ollama (ChatGPT-like UI) στην πόρτα 8080
#
# Χωρίς OFFER_ID επιλέγεται αυτόματα η φθηνότερη προσφορά του GPU_QUERY.
source "$(dirname "$0")/common.sh"

PROFILE="${1:-vllm}"
OFFER_ID="${2:-}"

if [[ -z "${API_KEY:-}" ]]; then
  API_KEY="$(python3 -c 'import secrets; print("sk-" + secrets.token_urlsafe(32))')"
  echo "Δημιουργήθηκε API_KEY (φυλάχτηκε στο .state/api_key)."
fi
echo "$API_KEY" > "$STATE_DIR/api_key"
chmod 600 "$STATE_DIR/api_key"

if [[ -z "$OFFER_ID" ]]; then
  OFFER_ID="$("${VAST[@]}" search offers "$GPU_QUERY" --storage "$DISK_GB" -o 'dph_total' --limit 1 --raw \
    | python3 -c 'import json,sys; o=json.load(sys.stdin); print(o[0]["id"] if o else "")')"
  [[ -n "$OFFER_ID" ]] || { echo "Δεν βρέθηκε προσφορά. Χαλάρωσε το GPU_QUERY στο config.env." >&2; exit 1; }
  echo "Επιλέχθηκε offer $OFFER_ID (φθηνότερο)."
fi

case "$PROFILE" in
  vllm)
    PORT=8000
    ENV="-p 8000:8000 -e HF_TOKEN=${HF_TOKEN:-} -e HUGGING_FACE_HUB_TOKEN=${HF_TOKEN:-}"
    ARGS=(--model "$MODEL" --served-model-name "$MODEL" --host 0.0.0.0 --port 8000
          --api-key "$API_KEY" --max-model-len "$MAX_MODEL_LEN" --gpu-memory-utilization 0.90)
    CREATE=(--image "$VLLM_IMAGE" --env "$ENV" --args "${ARGS[@]}")
    ;;
  webui)
    PORT=8080
    # Ο πρώτος χρήστης που κάνει εγγραφή στο UI γίνεται admin — κάν' το αμέσως.
    ENV="-p 8080:8080 -e WEBUI_SECRET_KEY=$API_KEY -e ENABLE_SIGNUP=true"
    CREATE=(--image "$WEBUI_IMAGE" --env "$ENV")
    ;;
  *)
    echo "Άγνωστο profile: $PROFILE (vllm | webui)" >&2; exit 1 ;;
esac

# Το --args πρέπει να είναι τελευταίο, γι' αυτό το CREATE μπαίνει στο τέλος.
RESULT="$("${VAST[@]}" create instance "$OFFER_ID" --disk "$DISK_GB" --label "$INSTANCE_LABEL" \
  --cancel-unavail --raw "${CREATE[@]}")"
ID="$(echo "$RESULT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("new_contract",""))')"
[[ -n "$ID" ]] || { echo "Αποτυχία δημιουργίας: $RESULT" >&2; exit 1; }

echo "$ID" > "$STATE_DIR/instance_id"
echo "$PROFILE" > "$STATE_DIR/profile"
echo "$PORT" > "$STATE_DIR/port"
echo "Instance $ID δημιουργήθηκε ($PROFILE). Περιμένω να ξεκινήσει..."
exec "$(dirname "$0")/endpoint.sh" "$ID" --wait
