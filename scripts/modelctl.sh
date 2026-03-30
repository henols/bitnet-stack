#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SERVICE="${1:-}"
ACTION="${2:-}"
VALUE="${3:-}"

if [[ "$SERVICE" != "bitnet" && "$SERVICE" != "falcon" ]]; then
  echo "Usage: $0 <bitnet|falcon> <set|current|restart> [hf_repo]"
  exit 1
fi

MODEL_FILE="models/${SERVICE}/.current_model"
CONTAINER="${SERVICE}-api"

case "$ACTION" in
  set)
    if [ -z "$VALUE" ]; then
      echo "Provide a Hugging Face repo."
      exit 1
    fi
    printf '%s\n' "$VALUE" > "$MODEL_FILE"
    docker compose restart "$CONTAINER"
    ;;
  current)
    cat "$MODEL_FILE"
    ;;
  restart)
    docker compose restart "$CONTAINER"
    ;;
  *)
    echo "Usage: $0 <bitnet|falcon> <set|current|restart> [hf_repo]"
    exit 1
    ;;
esac
