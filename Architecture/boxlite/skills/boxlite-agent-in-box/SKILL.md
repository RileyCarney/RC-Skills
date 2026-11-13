---
name: boxlite-agent-in-box
description: Run coding agents (Claude Code via SkillBox or manual CLI install, OpenAI Codex CLI, Pi, OpenCode, and Nous Hermes) inside local or BoxLite Cloud microVMs with host-side Secret credential injection, non-root execution, wake-on-request HTTP endpoints, and multi-turn streaming protocols.
---

# Agent in a Box (Local & Cloud)

Put an entire autonomous coding agent *inside* a BoxLite microVM so it has its own shell, filesystem, and network while your host and real model API keys remain completely outside.

## Documentation Map (12 Pages)

| Agent / Pattern | Local Docs | Cloud Docs |
| - | - | - |
| Section Overview | [index.md](../../docs/agent-in-box/index.md) ([live](https://docs.boxlite.ai/agent-in-box/index.md)) | [cloud/agent-in-box](../../docs/cloud/agent-in-box/index.md) ([live](https://docs.boxlite.ai/cloud/agent-in-box/index.md)) |
| Claude Code | [run-claude-code.md](../../docs/agent-in-box/run-claude-code.md) ([live](https://docs.boxlite.ai/agent-in-box/run-claude-code.md)) | [claude-code.md](../../docs/cloud/agent-in-box/claude-code.md) ([live](https://docs.boxlite.ai/cloud/agent-in-box/claude-code.md)) |
| OpenAI Codex | [run-codex.md](../../docs/agent-in-box/run-codex.md) ([live](https://docs.boxlite.ai/agent-in-box/run-codex.md)) | [codex.md](../../docs/cloud/agent-in-box/codex.md) ([live](https://docs.boxlite.ai/cloud/agent-in-box/codex.md)) |
| Pi Coding Agent | [run-pi.md](../../docs/agent-in-box/run-pi.md) ([live](https://docs.boxlite.ai/agent-in-box/run-pi.md)) | [pi.md](../../docs/cloud/agent-in-box/pi.md) ([live](https://docs.boxlite.ai/cloud/agent-in-box/pi.md)) |
| OpenCode | [run-opencode.md](../../docs/agent-in-box/run-opencode.md) ([live](https://docs.boxlite.ai/agent-in-box/run-opencode.md)) | [opencode.md](../../docs/cloud/agent-in-box/opencode.md) ([live](https://docs.boxlite.ai/cloud/agent-in-box/opencode.md)) |
| Hermes Agent | [run-hermes.md](../../docs/agent-in-box/run-hermes.md) ([live](https://docs.boxlite.ai/agent-in-box/run-hermes.md)) | [hermes.md](../../docs/cloud/agent-in-box/hermes.md) ([live](https://docs.boxlite.ai/cloud/agent-in-box/hermes.md)) |

---

## Agent Matrix & Key Constraints

| Agent | Image / Runtime | Install Command (in Box) | Critical Constraints |
| - | - | - | - |
| **Claude Code (`SkillBox`)** | `ghcr.io/boxlite-ai/boxlite-skillbox:0.1.0` (`memory=4096`, `disk=10`) | Automatic on 1st `call()` | Needs `CLAUDE_CODE_OAUTH_TOKEN` or `oauth_token=...` (raises `ValueError` otherwise). Ships noVNC desktop. |
| **Claude Code (Manual)** | `node:20-slim` (`disk_size_gb=20`) or Cloud `node` | `npm i -g @anthropic-ai/claude-code` | Refuses `--dangerously-skip-permissions` as root (create non-root `agent` user on local; Cloud `node` already uses `boxlite`). Append `< /dev/null` to `claude -p`. Needs `disk_size_gb=20` for global npm. |
| **OpenAI Codex** | **glibc** image (`node:20-slim` + `ca-certificates`, NOT Alpine/musl) | `npm i -g @openai/codex` | Rust binary requires system CA store `/etc/ssl/certs/ca-certificates.crt` (`slim` omits it, causing opaque TLS failures!). Authenticate via `printenv OPENAI_API_KEY \| codex login --with-api-key`. Add `--skip-git-repo-check`. |
| **Pi Coding Agent** | `node:20-slim` (`disk_size_gb=8`) or Cloud `node` | `npm i -g --ignore-scripts @earendil-works/pi-coding-agent` | Relocate config with `PI_CODING_AGENT_DIR`. **`pi -p` exits `0` even on model errors** — parse `--mode json` events and check `message.stopReason == "error"`. |
| **OpenCode** | `node:20-slim` (`disk_size_gb=8`) or Cloud `node` | `npm i -g opencode-ai` | Reads JSON config from `OPENCODE_CONFIG_CONTENT` or `OPENCODE_CONFIG`. Endpoint `baseURL` must end in `/v1`. `opencode serve` runs headless HTTP server (auth via `OPENCODE_SERVER_PASSWORD`). |
| **Hermes** | `docker.io/nousresearch/hermes-agent:latest` (~900 MB, `memory=4096`, `disk=12`) | Preinstalled (`/opt/hermes/bin/hermes`) | One-shot: `hermes -z "<prompt>" --yolo`. Gateway mode (`hermes gateway run`, port `8642` Cloud / `8080` example) requires `chown 10000:10000` on `/opt/data/config.yaml` and `.env`. |

---

## 1. Fastest Path: `SkillBox` for Claude Code (Python & Node)

```python
import asyncio, os, boxlite

async def main():
    async with boxlite.SkillBox(skills=["anthropics/skills"]) as box:
        await box.wait_until_ready(timeout=60)
        print(f"Live noVNC desktop: https://localhost:{box.gui_https_port}")
        reply = await box.call("My favorite color is blue.")
        reply2 = await box.call("What is my favorite color?")
        print(reply2)

asyncio.run(main())
```

* **Methods**:
  * `await box.call(prompt: str) -> str`: First call installs Claude CLI + tools; subsequent calls on the **same instance** keep multi-turn session context. (Different `async with` blocks do NOT share conversation history, though `auto_remove=False` + fixed `name=` reuses the installed CLI.)
  * `await box.install_skill("owner/repo") -> bool`
  * `await box.wait_until_ready(timeout=60) -> None`
  * Node: `new SkillBox({ oauthToken, skills, name, guiHttpPort, guiHttpsPort, autoRemove })`, explicit `await box.start()`, `await box.stop()`.

---

## 2. Keeping Model API Keys Out of the Box (`Secret` Pattern)

Instead of passing real keys into `env`, inject a placeholder inside the agent's native config/env and register a host-scoped `Secret` on `BoxOptions` / `SimpleBox`:

```python
box = await runtime.create(boxlite.BoxOptions(
    image="node",
    env=[
        ("NODE_EXTRA_CA_CERTS", "/etc/ssl/certs/ca-certificates.crt"),
        ("SSL_CERT_FILE", "/etc/ssl/certs/ca-certificates.crt"),
        ("ANTHROPIC_API_KEY", "<BOXLITE_SECRET:anthropic>"),
    ],
    secrets=[boxlite.Secret(
        name="anthropic",
        value=real_api_key,
        hosts=["api.anthropic.com"],
    )],
))
```

* BoxLite's outbound HTTPS proxy replaces `<BOXLITE_SECRET:anthropic>` in headers/body when talking to `hosts`.
* Remember to pass `NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt` (for Node.js CLIs) or `SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt` (for native/Rust/Python CLIs like Codex and Hermes).
* For OpenCode (`opencode.json`) and Pi (`models.json`), set `"apiKey": "<BOXLITE_SECRET:anthropic>"` directly in the config JSON uploaded via `boxlite cp`.

---

## 3. Claude Code Manual Multi-Turn Protocol (`stream-json`)

`SkillBox.call()` wraps `claude --input-format stream-json --output-format stream-json --verbose`:
* Launch with low-level `Box.exec` and pipe JSON lines to `execution.stdin().send_input((json.dumps(msg) + "\n").encode())`.
* Read raw chunks from `execution.stdout()`, buffer on `\n`, parse each JSON line, capture `session_id`, and stop reading when `parsed.get("type") == "result"`.

---

## 4. BoxLite Cloud Deployment & Wake-on-Request HTTP Pattern

All 5 agents on Cloud follow a reusable production pattern:

1. **Create Box** with `Boxlite.rest(BoxliteRestOptions.from_env())`, `detach=True`, `auto_delete=0`, `image="node"`, `NetworkSpec(inbound=InboundNetworkSpec(mode="enabled"))`, and either:
   * `auto_stop=0` for always-on workers, OR
   * `auto_stop=120, auto_resume=True` for wake-on-request HTTP servers.
2. **Prefix-install CLI** into `/workspace/tools`:
   `boxlite exec <name> -- npm install -g --prefix /workspace/tools <pkg>` (persists cleanly in Cloud `/workspace`).
3. **Upload bearer-authenticated wrapper (`server.mjs`)** + SHA-256 caller token hash (`/workspace/http-token.sha256` with `chmod 600`), keeping the caller token only on your workstation.
4. **Startup wait loop** in `entrypoint=["/bin/sh", "-c"]` waits for the agent binary + config + `server.mjs` + token hash before `exec node /workspace/server.mjs >> /workspace/http.log 2>&1` (on `0.0.0.0:8080`).
5. **Expose via Cloud Tunnel**: `boxlite network tunnel <name> 8080` returns an HTTPS URL that wakes an `auto_stop` box automatically on incoming HTTP traffic.
6. **Hermes / OpenCode Native Gateways**:
   * **Hermes**: `cmd=["gateway", "run"]`, upload `/opt/data/config.yaml` and `.env`, `chown 10000:10000`, `boxlite restart hermes-agent`, `boxlite network tunnel hermes-agent 8642`, call `/v1/chat/completions`.
   * **OpenCode**: `opencode serve --hostname 0.0.0.0 --port 4096` with `OPENCODE_SERVER_PASSWORD`, create session via `POST /session`, send message via `POST /session/$ID/message`.

---

## Troubleshooting

| Symptom | Cause | Fix |
| - | - | - |
| Claude refuses `--dangerously-skip-permissions` | Running as `root` inside container | `useradd -m agent` and pass `user="agent"` to `exec` |
| `npm install -g` fails with `ENOSPC` | Default disk too small for large CLIs | Set `disk_size_gb=20` for Claude Code (`8`+ for Codex/Pi/OpenCode, `12` for Hermes) |
| `claude -p` / `pi -p` / `codex exec` hangs | CLI blocked waiting for EOF on stdin | Append `< /dev/null` to the shell command |
| Codex fails with `stream disconnected before completion` | Alpine lacks glibc OR `-slim` lacks `/etc/ssl/certs/ca-certificates.crt` | Use glibc image (`node:20-slim`) and `apt-get install -y ca-certificates` |
| Pi exits `0` despite API failure | Pi encodes model failures in JSON `stopReason: "error"` | Parse `--mode json` event stream and inspect `message.stopReason` |
| Hermes Gateway fails to read `/opt/data/.env` | Wrong file owner inside official container | Run `chown 10000:10000 /opt/data/config.yaml /opt/data/.env` and restart box |
| `boxlite restart` reports `State change in progress` | Box still stopping/starting | Poll `boxlite inspect` until `running` or `stopped`, then `start` or retry `restart` |
