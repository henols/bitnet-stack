# BitNet multi-model stack

This project deploys:

- `chat.<BASE_DOMAIN>` -> Open WebUI, proxied through Nginx Proxy Manager
- `bitnet.<BASE_DOMAIN>/bitnet/v1` -> BitNet-backed API behind Nginx Proxy Manager
- `bitnet.<BASE_DOMAIN>/falcon/v1` -> second backend behind the same API hostname
- automatic HTTPS and proxy management via Nginx Proxy Manager
- dynamic DNS updates via `ddclient`

All environment-specific values and secrets live in `.env`.

## What is included

- Docker Compose stack
- BitNet build image with the fixes needed for current upstream builds
- runtime model downloader / preparer
- reverse proxy with ACME certificates and web UI
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

   - `http://<server-ip>:81` for Nginx Proxy Manager admin
   - `https://${CHAT_SUBDOMAIN}.${BASE_DOMAIN}` for Open WebUI
   - `https://bitnet.${BASE_DOMAIN}/bitnet/v1/models`
   - `https://bitnet.${BASE_DOMAIN}/falcon/v1/models`

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
- `ddclient` updates the public DNS record for the hostnames you list in `DDCLIENT_HOSTS`.

## DNS notes

This stack renders `config/ddclient/ddclient.conf` from env vars. The template is provider-neutral and supports both a minimal config and provider-specific extra lines.

## Nginx Proxy Manager

After the stack is running, log in to Nginx Proxy Manager on port `81`. The official default credentials are `admin@example.com` / `changeme`, and NPM will ask you to change them on first login.

You can either create proxy hosts in the UI or bootstrap them from the host with [bootstrap-npm.sh](/home/henrik/dev/henrik/git/bitnet-stack/scripts/bootstrap-npm.sh).

Bootstrap example:

```bash
MODEL_API_KEY='your-shared-api-key' \
NPM_EMAIL=you@example.com \
NPM_PASSWORD='your-npm-password' \
./scripts/bootstrap-npm.sh
```

Optional overrides:

- `NPM_URL` defaults to `http://127.0.0.1:81`
- `NPM_CHAT_DOMAIN` defaults to `${CHAT_SUBDOMAIN}.${BASE_DOMAIN}`
- `NPM_API_DOMAIN` defaults to `bitnet.${BASE_DOMAIN}`

If you prefer the UI, create proxy hosts like this:

- `${CHAT_SUBDOMAIN}.${BASE_DOMAIN}` -> forward to `open-webui`, port `8080`
- `bitnet.${BASE_DOMAIN}` -> forward to `bitnet-api`, port `8080`
  custom locations:
  `/bitnet/` -> `bitnet-api:8080`
  `/falcon/` -> `falcon-api:8080`
  advanced config:
  require `Authorization: Bearer ${MODEL_API_KEY}`

You can then add Let's Encrypt certificates through the UI instead of managing ACME through compose env vars.

### Recommended NPM UI Setup

Use the script for host bootstrap if you want, but configure SSL in the NPM UI.

1. Log in to NPM at `http://<server-ip>:81`
2. Create or verify a Proxy Host for `chat.${BASE_DOMAIN}`
3. Configure it to forward to `open-webui` on port `8080`
4. Create or verify a Proxy Host for `bitnet.${BASE_DOMAIN}`
5. Configure the default forward target to `bitnet-api` on port `8080`
6. Add a Custom Location `/bitnet/` -> `bitnet-api:8080`
7. Add a Custom Location `/falcon/` -> `falcon-api:8080`
8. In the `bitnet.${BASE_DOMAIN}` host, set Advanced config to:

```nginx
if ($http_authorization != "Bearer ${MODEL_API_KEY}") {
    return 401;
}
```

9. In the SSL tab for `chat.${BASE_DOMAIN}`, request a new Let's Encrypt certificate
10. Enable `Force SSL`
11. Enable `HTTP/2 Support`
12. Save
13. In the SSL tab for `bitnet.${BASE_DOMAIN}`, request a new Let's Encrypt certificate
14. Enable `Force SSL`
15. Enable `HTTP/2 Support`
16. Save

Before certificate issuance will work:

- DNS for `chat.${BASE_DOMAIN}` must point to the server
- DNS for `bitnet.${BASE_DOMAIN}` must point to the server
- ports `80` and `443` must be reachable from the internet
- NPM must be the service listening on public `80` and `443`

After that, verify:

```bash
curl -i https://chat.${BASE_DOMAIN}
curl -i https://bitnet.${BASE_DOMAIN}/bitnet/v1/models
curl -i -H "Authorization: Bearer ${MODEL_API_KEY}" https://bitnet.${BASE_DOMAIN}/bitnet/v1/models
curl -i -H "Authorization: Bearer ${MODEL_API_KEY}" https://bitnet.${BASE_DOMAIN}/falcon/v1/models
```

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
