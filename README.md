# AiPan — Self-hosted AI σε Vast.ai

Σηκώνεις **το δικό σου AI μοντέλο** σε νοικιασμένη GPU στο [Vast.ai](https://vast.ai/). Τα δεδομένα σου δεν περνάνε από OpenAI/Anthropic/Google, πληρώνεις με την ώρα και το σβήνεις όποτε θέλεις.

Υπάρχουν δύο τρόποι (profiles):

| Profile | Τι σηκώνει | Για ποιον |
|---|---|---|
| `vllm` | **OpenAI-compatible API** ([vLLM](https://docs.vllm.ai/)) με API key | Εφαρμογές, n8n, scripts, agents, ό,τι μιλάει σε OpenAI API |
| `coding` | **Μοντέλο για κώδικα** (Qwen3-Coder-Next) με tool calling, που δουλεύει **με το Claude Code** και άλλους coding agents | Development με agents σε δικό σου μοντέλο |
| `webui` | **[Open WebUI](https://openwebui.com/) + Ollama**: ChatGPT-like περιβάλλον στον browser | Ομάδα/πελάτες που θέλουν απλώς να κάνουν chat |

---

## 1. Προετοιμασία (μία φορά)

1. Φτιάξε λογαριασμό στο https://cloud.vast.ai/ και βάλε credit (π.χ. $10–20 για αρχή).
2. Πάρε API key: **Account → API Keys**.
3. Στον υπολογιστή σου:
   ```bash
   pip install vastai
   cp config.env.example config.env
   # άνοιξε το config.env και βάλε το VAST_API_KEY
   ```
4. Για gated μοντέλα (π.χ. Llama) βάλε και `HF_TOKEN` από το https://huggingface.co/settings/tokens.

## 2. Δες τι GPU υπάρχουν και πόσο κοστίζουν

```bash
scripts/search.sh
```
Η λίστα είναι ταξινομημένη από τη φθηνότερη. Το φίλτρο αλλάζει με το `GPU_QUERY` στο `config.env`.

## 3. Σήκωσε τον server

**API (vLLM):**
```bash
scripts/launch.sh vllm          # παίρνει αυτόματα τη φθηνότερη προσφορά
scripts/launch.sh vllm 1234567  # ή μια συγκεκριμένη προσφορά από το search.sh
```
Στο τέλος τυπώνει το **URL** και το **API key**. Την πρώτη φορά το μοντέλο κατεβαίνει, οπότε θέλει 3–10 λεπτά:
```bash
scripts/logs.sh     # παρακολούθηση
scripts/test.sh     # περιμένει να είναι έτοιμο και στέλνει δοκιμαστικό μήνυμα
```

**Chat UI (Open WebUI):**
```bash
scripts/launch.sh webui
```
Άνοιξε το URL και **κάνε αμέσως εγγραφή**, γιατί ο πρώτος λογαριασμός γίνεται admin. Μετά, από **Admin Settings → Models**, κατέβασε μοντέλο (π.χ. `qwen3:8b`, `gemma3:12b`, `llama3.1:8b`). Από τις ρυθμίσεις μπορείς να κλείσεις και τις νέες εγγραφές.

## 4. Χρήση από κώδικα

Οποιοδήποτε OpenAI SDK δουλεύει αλλάζοντας μόνο `base_url` και `api_key`:

```python
from openai import OpenAI

client = OpenAI(base_url="http://<IP>:<PORT>/v1", api_key="<API_KEY>")
r = client.chat.completions.create(
    model="Qwen/Qwen3-8B",
    messages=[{"role": "user", "content": "Γράψε μου ένα email προσφοράς"}],
)
print(r.choices[0].message.content)
```

Το ίδιο URL/key μπαίνει και σε n8n, Flowise, LangChain, LibreChat κ.λπ. (επιλογή "OpenAI compatible").

## 5. Claude Code πάνω στο δικό σου μοντέλο (profile `coding`)

Το vLLM μιλάει και το **Anthropic Messages API** (`/v1/messages`), οπότε το Claude Code συνδέεται απευθείας, χωρίς proxy.

```bash
npm install -g @anthropic-ai/claude-code   # αν δεν το έχεις
scripts/launch.sh coding                   # νοικιάζει GPU 96GB+ και σηκώνει Qwen3-Coder-Next
scripts/test.sh                            # περιμένει να φορτώσει (~80GB download την 1η φορά)
cd ~/το-project-σου
/path/to/AiPan/scripts/claude-code.sh      # Claude Code, αλλά με το δικό σου μοντέλο
```

Το `claude-code.sh` ορίζει `ANTHROPIC_BASE_URL`, το token και τα aliases `opus`/`sonnet`/`haiku`/subagents, όλα στο ίδιο μοντέλο. Κλείνει επίσης το telemetry προς Anthropic. Ό,τι ορίσματα του δώσεις περνάνε στο `claude` (π.χ. `scripts/claude-code.sh -p "τρέξε τα tests"`).

**Μοντέλο & GPU:**

| Ρύθμιση | Μοντέλο | GPU | Σχόλιο |
|---|---|---|---|
| default | `Qwen/Qwen3-Coder-Next-FP8` (80B MoE, 3B active, 256K ctx) | 1× 96GB+ (RTX PRO 6000, H200) | Γρήγορο (~100+ tok/s), καλό για agentic coding |
| φθηνή | `Qwen/Qwen3-Coder-30B-A3B-Instruct-FP8` | 1× 48GB (A6000, L40S) | Αρκετά πιο αδύναμο, για απλές εργασίες |
| μεγάλη | GLM-5.x, Kimi K2.x, MiniMax M3, DeepSeek V4 | 8× H100/H200 | Πιο κοντά σε frontier, με πολύ ακριβότερη ώρα |

Για να αλλάξεις μοντέλο, άλλαξε `CODING_MODEL`, `CODING_GPU_QUERY` και `TOOL_CALL_PARSER` στο `config.env`. Κάθε οικογένεια μοντέλων έχει δικό της parser (δες τα [vLLM recipes](https://docs.vllm.ai/projects/recipes/)). Χωρίς σωστό parser το Claude Code δεν μπορεί να καλέσει εργαλεία (αρχεία, bash).

**Να έχεις ρεαλιστικές προσδοκίες:** τα open μοντέλα έχουν κλείσει πολύ την απόσταση, αλλά σε μεγάλες, πολύπλοκες αλλαγές το Claude (Opus/Sonnet) παραμένει ισχυρότερο. Καλή πρακτική είναι να κρατήσεις και τα δύο: το self-hosted για ευαίσθητο κώδικα πελατών και για μεγάλο όγκο ρουτίνας, το Claude για τα δύσκολα.

**Άλλοι agents** (OpenAI-compatible, `base_url = <URL>/v1`, model `coder`): [OpenCode](https://opencode.ai/), [Aider](https://aider.chat/), Cline/Roo (VS Code), Continue, Qwen Code.

> ⚠️ Ο κώδικάς σου ταξιδεύει μέσω **HTTP χωρίς κρυπτογράφηση**. Για κώδικα πελατών βάλε TLS μπροστά (δες «Ασφάλεια») πριν το χρησιμοποιήσεις σοβαρά.

## 6. Σταμάτημα / κόστος

```bash
scripts/stop.sh      # σταματά η χρέωση GPU, κρατιούνται τα αρχεία (μικρή χρέωση δίσκου)
vastai start instance <ID>   # ξαναξεκινά (το IP/port μπορεί να αλλάξει: scripts/endpoint.sh)
scripts/destroy.sh   # οριστική διαγραφή, μηδενική χρέωση
```

> ⚠️ Το Vast χρεώνει **ανά λεπτό όσο τρέχει** το instance, ακόμα κι αν δεν το χρησιμοποιείς. Κάνε `stop`/`destroy` όταν τελειώνεις.

---

## Ποια GPU για ποιο μοντέλο

Ενδεικτικά (οι τιμές στο Vast αλλάζουν συνεχώς, δες `search.sh`):

| VRAM | Κάρτες | Μοντέλα (ενδεικτικά) | `GPU_QUERY` |
|---|---|---|---|
| 24 GB | RTX 3090 / 4090 | έως ~14B σε full precision, ~32B quantized (AWQ/GGUF) | default |
| 32 GB | RTX 5090 | ~14B με μεγάλο context, ~32B quantized | `gpu_name=RTX_5090 ...` |
| 48 GB | A6000, L40S | ~32B, 70B quantized | `gpu_ram>=48 num_gpus=1 ...` |
| 80 GB | A100 / H100 | 70B quantized, 32B με μεγάλο context | `gpu_name in [A100_SXM4,H100_SXM] ...` |
| 2–8× GPU | H100 / H200 | 70B+ full, MoE μοντέλα | `num_gpus=2 ...` και `--tensor-parallel-size 2`* |

\* Για multi-GPU πρόσθεσε `--tensor-parallel-size N` στα `ARGS` του `scripts/launch.sh`.

Κανόνας: **βάρη ≈ παράμετροι × 2 bytes** (FP16), ή ×0.5–0.6 για 4-bit, συν χώρο για context (KV cache). Αν το vLLM βγάζει out-of-memory, μείωσε το `MAX_MODEL_LEN` ή διάλεξε quantized μοντέλο (π.χ. με `-AWQ` στο όνομα). Για ελληνικά δοκίμασε τα Qwen3 και Gemma 3 ή το ελληνικό [Meltemi](https://huggingface.co/ilsp).

## Ασφάλεια: διάβασέ το

- Ο server είναι **δημόσια προσβάσιμος** στο internet. Το vLLM προστατεύεται με `API_KEY`. Μην το μοιράζεσαι και μην το βάζεις σε frontend κώδικα.
- Η σύνδεση είναι **HTTP (όχι HTTPS)**. Για παραγωγή βάλε μπροστά reverse proxy με TLS (Caddy, Cloudflare Tunnel) ή σύνδεση μέσω SSH tunnel/VPN.
- Τα μηχανήματα του Vast ανήκουν σε **τρίτους hosts**. Για ευαίσθητα δεδομένα πελατών (GDPR) βάλε στο `GPU_QUERY` `datacenter=True` και `geolocation in [DE,NL,FR,SE,FI]` για EU datacenters.
- Τα δεδομένα στο instance **χάνονται με το `destroy`**.

## Επόμενα βήματα

- **Σταθερό 24/7 endpoint:** χρησιμοποίησε "reserved" instance στο Vast (φθηνότερο σε μακροχρόνια ενοικίαση) ή [Vast Serverless](https://docs.vast.ai/) για autoscaling.
- **Δικό σου hardware:** τα ίδια docker images (`vllm/vllm-openai`, `open-webui:ollama`) τρέχουν ίδια και σε δικό σου PC/server με NVIDIA GPU:
  ```bash
  docker run --gpus all -p 8000:8000 vllm/vllm-openai:latest --model Qwen/Qwen3-8B --api-key <KEY>
  docker run -d --gpus all -p 8080:8080 -v ollama:/root/.ollama -v open-webui:/app/backend/data ghcr.io/open-webui/open-webui:ollama
  ```

## Αρχεία

```
config.env.example   ρυθμίσεις (αντέγραψε σε config.env)
scripts/search.sh    διαθέσιμες GPU & τιμές
scripts/launch.sh    νοικιάζει GPU & σηκώνει vllm, coding ή webui
scripts/claude-code.sh  τρέχει το Claude Code πάνω στο δικό σου μοντέλο
scripts/endpoint.sh  URL του server
scripts/test.sh      δοκιμαστικό μήνυμα στο API
scripts/logs.sh      logs
scripts/stop.sh      παύση
scripts/destroy.sh   οριστική διαγραφή
```
