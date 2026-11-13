# Manually deploy an agent in a box
Source: https://docs.boxlite.ai/cloud/agent-in-box/index

Create a Cloud box, install your coding agent, and run a real task.

Your agent runs inside a Cloud box, with its own filesystem, shell, and network access. Install it, configure its model connection, and give it a task.

Each guide creates a box with the native SDK, then uses the CLI and the agent's own configuration. Real model-provider keys stay outside the box. **An HTTP service and automatic stop/wake are optional additions.**

## Choose your agent

> [card] [Claude Code](/cloud/agent-in-box/claude-code)
>
> Install the CLI and run a coding task inside the box.

> [card] [Codex](/cloud/agent-in-box/codex)
>
> Run Codex with a Responses-compatible model connection.

> [card] [Pi](/cloud/agent-in-box/pi)
>
> Configure a model provider and use Pi's file and shell tools.

> [card] [OpenCode](/cloud/agent-in-box/opencode)
>
> Bring your provider configuration and run OpenCode in the box.

> [card] [Hermes](/cloud/agent-in-box/hermes)
>
> Use the official image and Hermes Gateway's native HTTP API.

## Before you start

Install the [Cloud CLI and Python SDK](/cloud/quickstart), and configure the native Cloud variables `BOXLITE_REST_URL` and `BOXLITE_API_KEY` on your workstation. Both SDK and CLI use that connection. Keep the Cloud API key outside the box.

Use a model provider supported by your agent. Each guide uses the agent's own authentication and model settings; BoxLite supplies its isolated runtime and credential boundary.

Each `create.py` reads the real provider key on your workstation without echoing it. Pass that value to a host-scoped `Secret`. The agent receives only the matching `<BOXLITE_SECRET:…>` placeholder in its native key setting.

```text theme={"theme":{"light":"github-light","dark":"github-dark"}}
Agent inside the box          BoxLite egress proxy          Model provider
Credential placeholder  →  substitute for allowed host  →  authenticated request
```

Match `Secret.hosts` to the model endpoint's hostname. This limits where substitution occurs; use an [egress policy](/cloud/network-policy) to restrict network access separately.

The create scripts configure clients to trust the system CA bundle, including BoxLite's proxy certificate. See [Secret behavior and parameters](/manage-sandbox/secrets-and-security).

`auto_stop=0` keeps the box running, and `auto_delete=0` retains its disk after stopping. Stop it when finished, or choose another [lifecycle policy](/cloud/box-lifecycle). HTTP serving and automatic stop/wake remain optional.

Each agent guide includes its own **Optional: wake on a request** section, with the interface and startup requirements for that agent.

## Add only what you need

| You want to | Continue with |
| - | - |
| Choose when a box stops and wakes | [Cloud lifecycle](/cloud/box-lifecycle) |
| Keep files when replacing the box | [Data across boxes](/cloud/data-across-boxes) |
| Run an agent on your own hardware | [Open-source Agent in a box](/agent-in-box/index) |
