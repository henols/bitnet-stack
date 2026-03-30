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
- `ddclient` updates the public DNS record for the hostnames you list in `DDCLIENT_HOSTS`.

## DNS notes

This stack renders `config/ddclient/ddclient.conf` from env vars. The template is provider-neutral and supports both a minimal config and provider-specific extra lines.

Start by setting these required values in `.env`:

- `DDCLIENT_PROTOCOL`
- `DDCLIENT_LOGIN`
- `DDCLIENT_PASSWORD`
- `DDCLIENT_HOSTS`

Then add optional values only if your provider requires them:

- `DDCLIENT_SERVER`
- `DDCLIENT_SCRIPT`
- `DDCLIENT_PROVIDER`
- `DDCLIENT_ZONE`
- `DDCLIENT_TTL`

`DDCLIENT_HOSTS` becomes the final hostname line in `ddclient.conf`. For some providers that can be a single hostname like `api.example.com`; for others it can be a comma-separated list like `example.com,api.example.com,chat.example.com`.

Generic setup flow:

1. Find the working `ddclient` example for your DNS provider.
2. Map each directive from that example to the matching `DDCLIENT_*` variable in `.env`.
3. Leave unused optional variables unset.
4. Run `./scripts/render-configs.sh` to inspect the generated config.
5. Run `./scripts/deploy.sh` once the rendered `config/ddclient/ddclient.conf` matches your provider's expected format.

If your provider's documentation uses a directive that is not covered by the current template, add it to [templates/ddclient.conf.tmpl](/home/henrik/dev/henrik/git/bitnet-stack/templates/ddclient.conf.tmpl) and export it in [scripts/render-configs.sh](/home/henrik/dev/henrik/git/bitnet-stack/scripts/render-configs.sh).

Note: current `ddclient` v4 images no longer accept the older `custom=yes` directive for `dyndns2` setups, so do not set `DDCLIENT_CUSTOM` unless you have verified your image/provider combination still supports it.
