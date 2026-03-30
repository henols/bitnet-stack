#!/usr/bin/env bash
set -euo pipefail

cd /opt/BitNet

MODELS_DIR="${MODELS_DIR:-/models}"
CURRENT_MODEL_FILE="${CURRENT_MODEL_FILE:-/models/.current_model}"
QUANT_TYPE="${QUANT_TYPE:-i2_s}"
HOST="${HOST:-0.0.0.0}"
PORT="${PORT:-8080}"
THREADS="${THREADS:-4}"
CTX_SIZE="${CTX_SIZE:-2048}"
N_PREDICT="${N_PREDICT:-4096}"
TEMPERATURE="${TEMPERATURE:-0.8}"

if [ -n "${HF_TOKEN:-}" ]; then
  hf auth login --token "$HF_TOKEN" >/dev/null 2>&1 || true
fi

if [ ! -f "$CURRENT_MODEL_FILE" ]; then
  echo "Missing $CURRENT_MODEL_FILE"
  exit 1
fi

HF_REPO="$(tr -d '\r' < "$CURRENT_MODEL_FILE" | xargs)"
if [ -z "$HF_REPO" ]; then
  echo "No model repo set in $CURRENT_MODEL_FILE"
  exit 1
fi

MODEL_NAME="${HF_REPO##*/}"
if [ "$MODEL_NAME" = "BitNet-b1.58-2B-4T-gguf" ]; then
  LOCAL_MODEL_DIR="${MODELS_DIR}/BitNet-b1.58-2B-4T"
else
  LOCAL_MODEL_DIR="${MODELS_DIR}/${MODEL_NAME}"
fi
GGUF_PATH="${LOCAL_MODEL_DIR}/ggml-model-${QUANT_TYPE}.gguf"

mkdir -p "$LOCAL_MODEL_DIR"

echo "Selected model repo: $HF_REPO"
echo "Local model dir: $LOCAL_MODEL_DIR"

if [ ! -f "$GGUF_PATH" ]; then
  if [[ "$HF_REPO" == *-gguf ]]; then
    echo "Downloading GGUF model repo from Hugging Face..."
    hf download "$HF_REPO" --local-dir "$LOCAL_MODEL_DIR"
    echo "Preparing BitNet environment..."
    python setup_env.py -md "$LOCAL_MODEL_DIR" -q "$QUANT_TYPE"
  else
    echo "Downloading and preparing model via setup_env.py..."
    python setup_env.py --hf-repo "$HF_REPO" --model-dir "$MODELS_DIR" --quant-type "$QUANT_TYPE"
  fi
else
  echo "Prepared model already exists: $GGUF_PATH"
fi

exec python run_inference_server.py \
  --model "$GGUF_PATH" \
  --host "$HOST" \
  --port "$PORT" \
  --threads "$THREADS" \
  --ctx-size "$CTX_SIZE" \
  --n-predict "$N_PREDICT" \
  --temperature "$TEMPERATURE"
