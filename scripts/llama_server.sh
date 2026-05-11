#!/usr/bin/env bash
set -euo pipefail

llama_cpp_repo="${LLAMA_CPP_REPO:-$HOME/Workspace/llms/llama.cpp}"
llama_server="${LLAMA_SERVER_BIN:-$llama_cpp_repo/build-hip/bin/llama-server}"
model_root="${LLAMA_MODEL_ROOT:-$HOME/Models}"
host="${LLAMA_HOST:-127.0.0.1}"
port="${LLAMA_PORT:-8080}"
state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/llama-server"
state_file="$state_dir/last.conf"

context_presets=(
    "Fast coding session (32k tokens)|32768"
    "Large repo work (64k tokens)|65536"
    "Deep analysis (128k tokens)|131072"
    "Full Qwen3.6 context (256k tokens)|262144"
)
reasoning_presets=(
    "Reasoning on - best answer quality|on"
    "Reasoning off - faster opencode/tool use|off"
    "Auto - use model/runtime default|auto"
)
model=""
ctx=""
alias_name=""
reasoning=""
force_prompt="false"
explicit_model="false"
state_found="false"
cache_k="f16"
cache_v="f16"
batch_size="4096"
ubatch_size="512"
default_model="${LLAMA_DEFAULT_MODEL:-}"
default_ctx="262144"
default_reasoning="on"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]
       $(basename "$0") reset

Start a tuned llama.cpp ROCm server for opencode.

Commands:
  reset                 Delete saved choices and prompt again.

Options:
  -m, --model PATH       GGUF model path. Prompts if omitted.
  -c, --ctx TOKENS       Context size. Prompts if omitted.
  -a, --alias NAME       API model alias. Defaults to model filename.
  -p, --port PORT        Server port. Default: $port
      --host HOST        Server host. Default: $host
      --reasoning MODE   Reasoning mode: on, off, or auto. Prompts if omitted.
      --thinking         Shorthand for --reasoning on.
      --cache-k TYPE     KV cache K type. Default: $cache_k
      --cache-v TYPE     KV cache V type. Default: $cache_v
      --batch-size N     Batch size. Default: $batch_size
      --ubatch-size N    UBatch size. Default: $ubatch_size
  -h, --help             Show this help.

Environment:
  LLAMA_MODEL_ROOT       Directory to scan for GGUF models.
  LLAMA_NO_FZF=1         Use numbered prompts instead of fzf.
EOF
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

select_from_list() {
    local prompt="$1"
    local default="${2:-}"
    shift 2
    local items=("$@")
    local selected_index=0
    local i

    ((${#items[@]} > 0)) || die "nothing to select for: $prompt"

    for i in "${!items[@]}"; do
        if [[ "${items[$i]}" == "$default" ]]; then
            selected_index="$i"
            break
        fi
    done

    if [[ "${LLAMA_NO_FZF:-0}" != "1" ]] && command -v fzf >/dev/null 2>&1; then
        local selection
        if ! selection="$({
            printf '%s\n' "${items[$selected_index]}"
            for i in "${!items[@]}"; do
                ((i == selected_index)) && continue
                printf '%s\n' "${items[$i]}"
            done
        } | fzf --prompt="$prompt > " --height=40% --layout=reverse)"; then
            die "selection cancelled for: $prompt"
        fi
        [[ -n "$selection" ]] || die "selection cancelled for: $prompt"
        printf '%s\n' "$selection"
        return
    fi

    printf '%s\n' "$prompt" >&2
    for i in "${!items[@]}"; do
        if ((i == selected_index)); then
            printf '%2d) %s [default]\n' "$((i + 1))" "${items[$i]}" >&2
        else
            printf '%2d) %s\n' "$((i + 1))" "${items[$i]}" >&2
        fi
    done

    local choice
    while true; do
        read -r -p "Select 1-${#items[@]} [default: $((selected_index + 1))]: " choice
        if [[ -z "$choice" ]]; then
            printf '%s\n' "${items[$selected_index]}"
            return
        fi
        [[ "$choice" =~ ^[0-9]+$ ]] || continue
        ((choice >= 1 && choice <= ${#items[@]})) || continue
        printf '%s\n' "${items[$((choice - 1))]}"
        return
    done
}

select_value_from_options() {
    local prompt="$1"
    local default_value="${2:-}"
    shift
    shift
    local options=("$@")
    local labels=()
    local option
    local label
    local selection
    local default_label=""

    ((${#options[@]} > 0)) || die "nothing to select for: $prompt"

    for option in "${options[@]}"; do
        labels+=("${option%%|*}")
        if [[ "${option#*|}" == "$default_value" ]]; then
            default_label="${option%%|*}"
        fi
    done

    selection="$(select_from_list "$prompt" "${default_label:-}" "${labels[@]}")"

    for option in "${options[@]}"; do
        label="${option%%|*}"
        if [[ "$label" == "$selection" ]]; then
            printf '%s\n' "${option#*|}"
            return
        fi
    done

    die "invalid selection: $selection"
}

load_state() {
    [[ -f "$state_file" ]] || return 1
    # shellcheck source=/dev/null
    source "$state_file"
    model="${last_model:-}"
    ctx="${last_ctx:-}"
    reasoning="${last_reasoning:-}"
    state_found="true"
}

save_state() {
    mkdir -p "$state_dir" 2>/dev/null || return 0
    {
        printf 'last_model=%q\n' "$model"
        printf 'last_ctx=%q\n' "$ctx"
        printf 'last_reasoning=%q\n' "$reasoning"
    } >"$state_file" 2>/dev/null || return 0
}

model_label_from_path() {
    local path="$1"
    local model_dir
    local file
    local label

    model_dir="$(basename "$(dirname "$path")")"
    file="$(basename "$path" .gguf)"
    label="${file//-/ }"
    label="${label//_/ }"

    case "$file" in
    *Qwen3.6-27B-Q8_0*)
        label="Qwen3.6 27B Q8_0 - highest quality, slowest"
        ;;
    *Qwen3.6-27B-Q6_K*)
        label="Qwen3.6 27B Q6_K - higher quality, slower"
        ;;
    *Qwen3.6-27B-Q4_K_M*)
        label="Qwen3.6 27B Q4_K_M - balanced quality and speed"
        ;;
    *gemma-4-31B-it-Q4_K_M*)
        label="Gemma 4 31B IT Q4_K_M"
        ;;
    *gemma-4-31B-it-Q8_0*)
        label="Gemma 4 31B IT Q8_0"
        ;;
    *gemma-4-E4B-it-Q4_K_M*)
        label="Gemma 4 E4B IT Q4_K_M"
        ;;
    esac

    printf '%s [%s]|%s\n' "$label" "$model_dir" "$path"
}

model_alias_from_path() {
    local path="$1"
    local base
    base="$(basename "$path" .gguf)"
    printf '%s\n' "$base" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

prompt_for_model() {
    [[ -d "$model_root" ]] || die "model root does not exist: $model_root"
    mapfile -t models < <(find "$model_root" -type f -name '*.gguf' ! -iname '*mmproj*' ! -iname '*embed*' | sort)
    ((${#models[@]} > 0)) || die "no GGUF models found under: $model_root"
    model_options=()
    for model_path in "${models[@]}"; do
        model_options+=("$(model_label_from_path "$model_path")")
    done
    model="$(select_value_from_options "Model" "${model:-}" "${model_options[@]}")"
}

prompt_for_context() {
    ctx="$(select_value_from_options "Context" "${ctx:-}" "${context_presets[@]}")"
}

prompt_for_reasoning() {
    reasoning="$(select_value_from_options "Reasoning" "${reasoning:-on}" "${reasoning_presets[@]}")"
}

load_state || true

while (($#)); do
    case "$1" in
    reset)
        force_prompt="true"
        rm -f "$state_file" 2>/dev/null || true
        shift
        ;;
    -m | --model)
        model="${2:-}"
        explicit_model="true"
        shift 2
        ;;
    -c | --ctx | --context)
        ctx="${2:-}"
        shift 2
        ;;
    -a | --alias)
        alias_name="${2:-}"
        shift 2
        ;;
    -p | --port)
        port="${2:-}"
        shift 2
        ;;
    --host)
        host="${2:-}"
        shift 2
        ;;
    --thinking)
        reasoning="on"
        shift
        ;;
    --reasoning)
        reasoning="${2:-}"
        shift 2
        ;;
    --cache-k)
        cache_k="${2:-}"
        shift 2
        ;;
    --cache-v)
        cache_v="${2:-}"
        shift 2
        ;;
    --batch-size)
        batch_size="${2:-}"
        shift 2
        ;;
    --ubatch-size)
        ubatch_size="${2:-}"
        shift 2
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        die "unknown option: $1"
        ;;
    esac
done

[[ -x "$llama_server" ]] || die "llama-server not found or not executable: $llama_server"
require_command find
require_command sed

if [[ "$force_prompt" == "true" || "$state_found" != "true" ]]; then
    prompt_model_default="${model:-$default_model}"
    prompt_ctx_default="${ctx:-$default_ctx}"
    prompt_reasoning_default="${reasoning:-$default_reasoning}"

    if [[ -z "$model" || "$force_prompt" == "true" ]]; then
        model="$prompt_model_default"
        prompt_for_model
    fi
    if [[ -z "$ctx" || "$force_prompt" == "true" ]]; then
        ctx="$prompt_ctx_default"
        prompt_for_context
    fi
    if [[ -z "$reasoning" || "$force_prompt" == "true" ]]; then
        reasoning="$prompt_reasoning_default"
        prompt_for_reasoning
    fi
fi

if [[ -n "$model" && ! -f "$model" && "$state_found" == "true" && "$force_prompt" != "true" && "$explicit_model" != "true" ]]; then
    printf 'Saved model no longer exists, choose another model: %s\n' "$model" >&2
    prompt_for_model
fi

[[ -n "$model" ]] || die "model is missing; run '$(basename "$0") reset' and select a GGUF model"
[[ -f "$model" ]] || die "model file does not exist: $model"
[[ -n "$ctx" ]] || die "context is missing; run '$(basename "$0") reset'"
[[ "$ctx" =~ ^[0-9]+$ ]] || die "context must be a number: $ctx"
[[ "$port" =~ ^[0-9]+$ ]] || die "port must be a number: $port"
[[ -n "$reasoning" ]] || die "reasoning is missing; run '$(basename "$0") reset'"

case "$reasoning" in
on | off | auto) ;;
*) die "reasoning must be one of: on, off, auto" ;;
esac

if [[ -z "$alias_name" ]]; then
    alias_name="$(model_alias_from_path "$model")"
fi

save_state

printf 'Starting llama-server\n'
if [[ "$state_found" == "true" && "$force_prompt" != "true" ]]; then
    printf '  using:   saved choices from %s\n' "$state_file"
fi
printf '  model:   %s\n' "$model"
printf '  alias:   %s\n' "$alias_name"
printf '  context: %s\n' "$ctx"
printf '  listen:  http://%s:%s/v1\n' "$host" "$port"
printf '  reasoning: %s\n' "$reasoning"

exec env ROCBLAS_USE_HIPBLASLT=1 "$llama_server" \
    --model "$model" \
    --alias "$alias_name" \
    --host "$host" \
    --port "$port" \
    --ctx-size "$ctx" \
    --n-gpu-layers 999 \
    --flash-attn on \
    --no-mmap \
    --cache-type-k "$cache_k" \
    --cache-type-v "$cache_v" \
    --batch-size "$batch_size" \
    --ubatch-size "$ubatch_size" \
    --reasoning "$reasoning"
