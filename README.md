# BitNet multi-model stack

This project deploys:

- `chat.<BASE_DOMAIN>` -> Open WebUI
- `api.<BASE_DOMAIN>/bitnet/v1` -> BitNet-backed OpenAI-compatible API
- `api.<BASE_DOMAIN>/falcon/v1` -> second model container behind the same API hostname
- automatic HTTPS via `nginx-proxy` + `acme-companion`
- dynamic DNS updates via `ddclient`

All environment-specific values and secrets live in `.env`.

## What is included

- Docker Compose stack
- BitNet build image with the fixes needed for current upstream builds
- runtime model downloader / preparer
- reverse proxy with ACME certificates
- generated nginx auth config for one shared API key
- generated ddclient config from env vars
- helper scripts for deploy, logs, status, and model switching

## Prerequisites on the server

- Docker Engine
- Docker Compose plugin
- ports `80`, `443`, and `22` reachable from the internet
- DNS record(s) for your chosen hostnames pointing at your server

## Quick start

1. Clone the repo on your server.
2. Create your env file:

   ```bash
   cp .env.example .env
   ```

3. Edit `.env` and fill in all placeholders.
4. Deploy:

   ```bash
   ./scripts/deploy.sh
   ```

5. Open:

   - `https://${CHAT_SUBDOMAIN}.${BASE_DOMAIN}` for Open WebUI
   - `https://${API_SUBDOMAIN}.${BASE_DOMAIN}/bitnet/v1/models`
   - `https://${API_SUBDOMAIN}.${BASE_DOMAIN}/falcon/v1/models`

## How Open WebUI should be configured

Inside Open WebUI, add OpenAI-compatible connections that use:

- `https://${API_SUBDOMAIN}.${BASE_DOMAIN}/bitnet/v1`
- `https://${API_SUBDOMAIN}.${BASE_DOMAIN}/falcon/v1`

Use the same API key value you set as `MODEL_API_KEY` in `.env`.

## Common operations

Bring up or update the stack:

```bash
./scripts/deploy.sh
```

See status:

```bash
./scripts/status.sh
```

See logs:

```bash
./scripts/logs.sh
```

Switch the BitNet path to a different Hugging Face repo:

```bash
./scripts/modelctl.sh bitnet set microsoft/BitNet-b1.58-2B-4T-gguf
```

Switch the Falcon path to a different Hugging Face repo:

```bash
./scripts/modelctl.sh falcon set tiiuae/Falcon3-1B-Instruct-1.58bit
```

After switching, restart the specific backend:

```bash
./scripts/modelctl.sh bitnet restart
./scripts/modelctl.sh falcon restart
```

## Notes

- The BitNet image downloads models at runtime into the mounted `./models` folders.
- If the selected repo ends in `-gguf`, the entrypoint downloads the repo directly and uses the existing `ggml-model-<quant>.gguf` file.
- Otherwise it falls back to BitNet's `setup_env.py --hf-repo ...` path.
- The reverse proxy protects the whole `api.<BASE_DOMAIN>` host with one shared bearer token.
- `ddclient` updates the public DNS record for `api.<BASE_DOMAIN>` and `chat.<BASE_DOMAIN>` by updating the underlying hostname / record you configure in `.env`.

## DNS notes

This stack assumes that your DDNS provider can update the record you configure through `ddclient`. If your provider needs a different `ddclient` stanza than the example template, edit `templates/ddclient.conf.tmpl` and rerun `./scripts/render-configs.sh`.
