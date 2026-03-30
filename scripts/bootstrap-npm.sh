#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

: "${BASE_DOMAIN:?BASE_DOMAIN is required}"
: "${CHAT_SUBDOMAIN:?CHAT_SUBDOMAIN is required}"
: "${MODEL_API_KEY:?MODEL_API_KEY is required}"
: "${NPM_EMAIL:?Set NPM_EMAIL in the environment before running this script}"
: "${NPM_PASSWORD:?Set NPM_PASSWORD in the environment before running this script}"

NPM_URL="${NPM_URL:-http://127.0.0.1:81}"
CHAT_DOMAIN="${NPM_CHAT_DOMAIN:-${CHAT_SUBDOMAIN}.${BASE_DOMAIN}}"
API_DOMAIN="${NPM_API_DOMAIN:-bitnet.${BASE_DOMAIN}}"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

need_cmd curl
need_cmd python3

api() {
  local method="$1"
  local path="$2"
  local body="${3:-}"

  if [ -n "$body" ]; then
    curl -fsS -X "$method" \
      -H "Authorization: Bearer ${NPM_TOKEN}" \
      -H "Content-Type: application/json" \
      --data "$body" \
      "${NPM_URL}${path}"
  else
    curl -fsS -X "$method" \
      -H "Authorization: Bearer ${NPM_TOKEN}" \
      "${NPM_URL}${path}"
  fi
}

login_response="$(
  curl -fsS -X POST \
    -H "Content-Type: application/json" \
    --data "{\"identity\":\"${NPM_EMAIL}\",\"secret\":\"${NPM_PASSWORD}\"}" \
    "${NPM_URL}/api/tokens"
)"

NPM_TOKEN="$(printf '%s' "$login_response" | python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])')"

proxy_hosts_json="$(api GET /api/nginx/proxy-hosts)"

upsert_proxy_host() {
  local domain="$1"
  local payload="$2"

  local existing_id
  existing_id="$(
    printf '%s' "$proxy_hosts_json" | python3 -c '
import json, sys
domain = sys.argv[1]
hosts = json.load(sys.stdin)
for item in hosts:
    if domain in item.get("domain_names", []):
        print(item["id"])
        break
' "$domain"
  )"

  if [ -n "$existing_id" ]; then
    api PUT "/api/nginx/proxy-hosts/${existing_id}" "$payload" >/dev/null
    echo "Updated proxy host: ${domain}"
  else
    api POST /api/nginx/proxy-hosts "$payload" >/dev/null
    echo "Created proxy host: ${domain}"
  fi
}

chat_payload="$(
  python3 -c '
import json, sys
domain = sys.argv[1]
print(json.dumps({
    "domain_names": [domain],
    "forward_scheme": "http",
    "forward_host": "open-webui",
    "forward_port": 8080,
    "access_list_id": 0,
    "certificate_id": 0,
    "ssl_forced": False,
    "http2_support": False,
    "hsts_enabled": False,
    "hsts_subdomains": False,
    "block_exploits": True,
    "allow_websocket_upgrade": True,
    "caching_enabled": False,
    "advanced_config": "",
    "locations": [],
    "meta": {"letsencrypt_agree": False, "dns_challenge": False}
}))
' "$CHAT_DOMAIN"
)"

api_payload="$(
  python3 -c '
import json, sys
domain, api_key = sys.argv[1], sys.argv[2]
print(json.dumps({
    "domain_names": [domain],
    "forward_scheme": "http",
    "forward_host": "bitnet-api",
    "forward_port": 8080,
    "access_list_id": 0,
    "certificate_id": 0,
    "ssl_forced": False,
    "http2_support": False,
    "hsts_enabled": False,
    "hsts_subdomains": False,
    "block_exploits": True,
    "allow_websocket_upgrade": True,
    "caching_enabled": False,
    "advanced_config": f"""
if ($http_authorization != \"Bearer {api_key}\") {{
    return 401;
}}
""".strip(),
    "locations": [
        {
            "path": "/bitnet/",
            "forward_scheme": "http",
            "forward_host": "bitnet-api",
            "forward_port": 8080,
            "forward_path": "/"
        },
        {
            "path": "/falcon/",
            "forward_scheme": "http",
            "forward_host": "falcon-api",
            "forward_port": 8080,
            "forward_path": "/"
        }
    ],
    "meta": {"letsencrypt_agree": False, "dns_challenge": False}
}))
' "$API_DOMAIN" "$MODEL_API_KEY"
)"

upsert_proxy_host "$CHAT_DOMAIN" "$chat_payload"
upsert_proxy_host "$API_DOMAIN" "$api_payload"

cat <<EOF
Done.

Configured hosts:
- ${CHAT_DOMAIN} -> open-webui:8080
- ${API_DOMAIN} -> bitnet-api:8080
  custom locations:
  /bitnet/ -> bitnet-api:8080
  /falcon/ -> falcon-api:8080

NPM URL: ${NPM_URL}
EOF
