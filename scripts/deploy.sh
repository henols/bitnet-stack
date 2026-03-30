#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ ! -f .env ]; then
  echo "Missing .env. Copy .env.example to .env and fill it in first."
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required on the server."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose plugin is required."
  exit 1
fi

if ! command -v envsubst >/dev/null 2>&1; then
  echo "envsubst is required. Install gettext-base on the server."
  exit 1
fi

./scripts/render-configs.sh
docker compose up -d --build
