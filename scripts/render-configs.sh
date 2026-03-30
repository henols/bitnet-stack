#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ ! -f .env ]; then
  echo "Missing .env. Copy .env.example to .env and fill it in first."
  exit 1
fi

set -a
# shellcheck disable=SC1091
source .env
set +a

mkdir -p nginx/vhost.d config/ddclient models/bitnet models/falcon

: "${BASE_DOMAIN:?BASE_DOMAIN is required}"
: "${API_SUBDOMAIN:?API_SUBDOMAIN is required}"
: "${CHAT_SUBDOMAIN:?CHAT_SUBDOMAIN is required}"
: "${MODEL_API_KEY:?MODEL_API_KEY is required}"
: "${BITNET_MODEL_REPO:?BITNET_MODEL_REPO is required}"
: "${FALCON_MODEL_REPO:?FALCON_MODEL_REPO is required}"
: "${DDCLIENT_PROTOCOL:?DDCLIENT_PROTOCOL is required}"
: "${DDCLIENT_LOGIN:?DDCLIENT_LOGIN is required}"
: "${DDCLIENT_PASSWORD:?DDCLIENT_PASSWORD is required}"
: "${DDCLIENT_HOSTS:?DDCLIENT_HOSTS is required}"

API_HOST="${API_SUBDOMAIN}.${BASE_DOMAIN}"
CHAT_HOST="${CHAT_SUBDOMAIN}.${BASE_DOMAIN}"
export API_HOST CHAT_HOST MODEL_API_KEY DDCLIENT_DAEMON_SECONDS DDCLIENT_SSL DDCLIENT_USE DDCLIENT_WEB DDCLIENT_WEB_SKIP DDCLIENT_PROTOCOL DDCLIENT_LOGIN DDCLIENT_PASSWORD DDCLIENT_HOSTS

DDCLIENT_CUSTOM_LINE="${DDCLIENT_CUSTOM:+custom=${DDCLIENT_CUSTOM}}"
DDCLIENT_SERVER_LINE="${DDCLIENT_SERVER:+server=${DDCLIENT_SERVER}}"
DDCLIENT_SCRIPT_LINE="${DDCLIENT_SCRIPT:+script=${DDCLIENT_SCRIPT}}"
DDCLIENT_PROVIDER_LINE="${DDCLIENT_PROVIDER:+provider=${DDCLIENT_PROVIDER}}"
DDCLIENT_ZONE_LINE="${DDCLIENT_ZONE:+zone=${DDCLIENT_ZONE}}"
DDCLIENT_TTL_LINE="${DDCLIENT_TTL:+ttl=${DDCLIENT_TTL}}"
export DDCLIENT_CUSTOM_LINE DDCLIENT_SERVER_LINE DDCLIENT_SCRIPT_LINE DDCLIENT_PROVIDER_LINE DDCLIENT_ZONE_LINE DDCLIENT_TTL_LINE

if command -v envsubst >/dev/null 2>&1; then
  :
else
  echo "envsubst is required. Install gettext-base on the host."
  exit 1
fi

envsubst < templates/api-vhost.conf.tmpl > "nginx/vhost.d/${API_HOST}"
envsubst < templates/ddclient.conf.tmpl > config/ddclient/ddclient.conf
printf '%s\n' "$BITNET_MODEL_REPO" > models/bitnet/.current_model
printf '%s\n' "$FALCON_MODEL_REPO" > models/falcon/.current_model

echo "Rendered nginx/vhost.d/${API_HOST}"
echo "Rendered config/ddclient/ddclient.conf"
echo "Wrote models/bitnet/.current_model"
echo "Wrote models/falcon/.current_model"
