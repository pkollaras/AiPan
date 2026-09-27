#!/usr/bin/env bash
# Νοικιάζει GPU στο Vast.ai και σηκώνει τον AI server.
#
#   scripts/launch.sh vllm  [OFFER_ID]   # OpenAI-compatible API (vLLM) στην πόρτα 8000
#   scripts/launch.sh coding [OFFER_ID]  # Coding μοντέλο με tool calling, για Claude Code (πόρτα 8000)
#   scripts/launch.sh webui [OFFER_ID]   # Open WebUI + Ollama (ChatGPT-like UI) στην πόρτα 8080
#
# Χωρίς OFFER_ID επιλέγεται αυτόματα η φθηνότερη προσφορά του GPU_QUERY.
source "$(dirname "$0")/common.sh"

PROFILE="${1:-vllm}"
OFFER_ID="${2:-}"

# Το profile coding έχει δικό του μοντέλο, GPU φίλτρο και δίσκο.
if [[ "$PROFILE" == coding ]]; then
  MODEL="$CODING_MODEL"
  GPU_QUERY="$CODING_GPU_QUERY"
  DISK_GB="$CODING_DISK_GB"
  MAX_MODEL_LEN="$CODING_MAX_MODEL_LEN"
fi

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

SERVED_MODEL="$MODEL"
case "$PROFILE" in
  vllm|coding)
    PORT=8000
    ENV="-p 8000:8000 -e HF_TOKEN=${HF_TOKEN:-} -e HUGGING_FACE_HUB_TOKEN=${HF_TOKEN:-}"
    ARGS=(--model "$MODEL" --host 0.0.0.0 --port 8000
          --api-key "$API_KEY" --max-model-len "$MAX_MODEL_LEN" --gpu-memory-utilization 0.92)
    if [[ "$PROFILE" == coding ]]; then
      # Σύντομο όνομα που δηλώνεται στο Claude Code. Tool calling + prefix caching
      # είναι απαραίτητα για agents (ίδιο system prompt σε κάθε βήμα).
      SERVED_MODEL=coder
      ARGS+=(--enable-auto-tool-choice --tool-call-parser "$TOOL_CALL_PARSER"
             --enable-prefix-caching --kv-cache-dtype fp8 --max-num-seqs 4)
    fi
    ARGS+=(--served-model-name "$SERVED_MODEL")
    CREATE=(--image "$VLLM_IMAGE" --env "$ENV" --args "${ARGS[@]}")
    ;;
  webui)
    PORT=8080
    # Ο πρώτος χρήστης που κάνει εγγραφή στο UI γίνεται admin — κάν' το αμέσως.
    ENV="-p 8080:8080 -e WEBUI_SECRET_KEY=$API_KEY -e ENABLE_SIGNUP=true"
    CREATE=(--image "$WEBUI_IMAGE" --env "$ENV")
    ;;
  *)
    echo "Άγνωστο profile: $PROFILE (vllm | coding | webui)" >&2; exit 1 ;;
esac

# Το --args πρέπει να είναι τελευταίο, γι' αυτό το CREATE μπαίνει στο τέλος.
RESULT="$("${VAST[@]}" create instance "$OFFER_ID" --disk "$DISK_GB" --label "$INSTANCE_LABEL" \
  --cancel-unavail --raw "${CREATE[@]}")"
ID="$(echo "$RESULT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("new_contract",""))')"
[[ -n "$ID" ]] || { echo "Αποτυχία δημιουργίας: $RESULT" >&2; exit 1; }

echo "$ID" > "$STATE_DIR/instance_id"
echo "$PROFILE" > "$STATE_DIR/profile"
echo "$PORT" > "$STATE_DIR/port"
echo "$SERVED_MODEL" > "$STATE_DIR/model"
echo "Instance $ID δημιουργήθηκε ($PROFILE). Περιμένω να ξεκινήσει..."
exec "$(dirname "$0")/endpoint.sh" "$ID" --wait
