# Run Codex
Source: https://docs.boxlite.ai/agent-in-box/run-codex

Install and drive the OpenAI Codex CLI inside a microVM, so the agent can execute freely while the blast radius stays inside a disposable VM.

Codex ships its own sandbox for model-generated commands, and its most permissive switch is documented as "intended solely for running in environments that are externally sandboxed". A box is exactly that environment.

## Prerequisites

* The `boxlite` Python package and a machine with hardware virtualization — see [Installation](/getting-started/installation#platform-and-virtualization-requirements-common-to-all-sdks).
* An OpenAI API key, or a ChatGPT plan you can log into.
* **A glibc-based image.** Codex publishes prebuilt binaries as optional dependencies for `linux-x64` and `linux-arm64` only. `node:20-slim` is verified working: installed inside a box in about **22 s**, after which `codex --version` reports `codex-cli 0.147.0`. Musl images such as `node:alpine` have no matching binary.
* **System CA certificates in the image.** Slim images ship without them, and Codex needs them to reach any API over TLS. Install `ca-certificates` before the first prompt — the Quick Example does this in step 1. See [Why a slim image needs `ca-certificates`](#why-a-slim-image-needs-ca-certificates) for why this failure is easy to misdiagnose.

## Quick Example

Install the CLI, authenticate from stdin, and run one non-interactive prompt.

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio

from boxlite import SimpleBox

API_KEY = "<YOUR_OPENAI_API_KEY>"          # TODO: read from your own secret store


async def run(box, *cmd, env=None, user=None, timeout=None):
    result = await box.exec(*cmd, env=env, user=user, timeout=timeout)
    # exec does not raise on a non-zero exit — check it yourself
    if result.exit_code != 0:
        raise RuntimeError(f"`{' '.join(cmd)}` failed (exit={result.exit_code}): {result.stderr}")
    return result


async def main() -> None:
    try:
        # glibc image; disk_size_gb leaves room for the global install and its binary
        async with SimpleBox(image="node:20-slim", memory_mib=2048, disk_size_gb=8) as box:
            # 1) Install system CA certificates. Slim images have none, and Codex is a
            #    Rust binary that reads the system trust store — without this, every
            #    model call fails at the TLS handshake.
            await run(box, "sh", "-c",
                      "apt-get update -qq && apt-get install -y -qq ca-certificates",
                      timeout=300.0)

            # 2) Install the CLI
            await run(box, "npm", "install", "-g", "@openai/codex", timeout=600.0)
            version = await run(box, "codex", "--version")
            print(version.stdout.strip())

            # 3) Authenticate. `codex login --with-api-key` reads the key from stdin,
            #    so the key never appears in the command line or the process list.
            await run(box, "sh", "-c",
                      'printenv OPENAI_API_KEY | codex login --with-api-key',
                      env={"OPENAI_API_KEY": API_KEY}, timeout=120.0)

            # 4) One-shot prompt. --skip-git-repo-check is needed because the working
            #    directory in a fresh box is not a git repository.
            answer = await run(
                box, "sh", "-c",
                'codex exec "Write a one-line Python snippet that reverses a string." '
                '--skip-git-repo-check < /dev/null',
                timeout=300.0,
            )
            print(answer.stdout)
    except RuntimeError as exc:
        print(f"runtime error: {exc}")


if __name__ == "__main__":
    asyncio.run(main())
```

Verified inside a box on macOS (Apple Silicon) against an OpenAI-compatible endpoint. `codex exec` echoes the exchange, then repeats the final answer:

```text theme={"theme":{"light":"github-light","dark":"github-dark"}}
codex-cli 0.147.0
--------
user
Reply with exactly: BOXLITE_IN_BOX_OK
codex
BOXLITE_IN_BOX_OK
tokens used
16,470
```

## Why a slim image needs `ca-certificates`

This one is worth knowing in advance, because the symptom points away from the cause.

`node:20-slim` has no `/etc/ssl/certs/ca-certificates.crt`. Codex is a Rust binary that verifies TLS against the **system** trust store, so with no root certificates every model call dies at the handshake — surfacing as a transport error such as `stream disconnected before completion`, which reads like a network or endpoint problem rather than a missing file.

Two things make it easy to misdiagnose:

* **`npm install` still works.** Node ships its own bundled CA store, so installing the CLI and running `codex --version` both succeed. The failure appears only at the first prompt, long after the step that would have revealed it.
* **Installing `curl` to test connectivity hides the problem.** `ca-certificates` is a dependency of `curl`, so the moment you install a tool to check the network, you have silently fixed the thing you were trying to diagnose — and the network test passes.

Confirm it directly instead of inferring it from a failed request:

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
# Empty output and a non-zero exit mean the root certificates are missing
check = await box.exec("ls", "-l", "/etc/ssl/certs/ca-certificates.crt")
print(check.exit_code, check.stdout, check.stderr)
```

Images that already include the certificates — `node:20` (not `-slim`), `debian`, `ubuntu` — need no extra step. This applies to any agent CLI compiled as a native binary, not only Codex.

## Parameters and Returns

From `codex --help` and `codex exec --help`:

| Entry point | Meaning |
| - | - |
| `codex exec [PROMPT]` | Run non-interactively (alias `codex e`). With no prompt argument, the instructions are read from stdin |
| `codex login --with-api-key` | Read the API key from **stdin** |
| `codex login status` | Report the current credential, already masked |
| `-m`, `--model <MODEL>` | Model to use |
| `-s`, `--sandbox <MODE>` | Codex's own sandbox policy: `read-only`, `workspace-write`, or `danger-full-access` |
| `-C`, `--cd <DIR>` | Working directory |
| `--skip-git-repo-check` | Do not require the working directory to be a git repository |
| `--json` | Machine-readable output |

## Two sandboxes, one decision

Codex sandboxes the commands its model generates, and BoxLite sandboxes the whole Codex process. Inside a box the inner sandbox is redundant for containment — the VM boundary already holds — so you can relax it and let the agent work without per-action prompts:

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
# The permissive switch is documented as "EXTREMELY DANGEROUS. Intended solely for
# running in environments that are externally sandboxed" — which a box is.
await run(
    box, "sh", "-c",
    'codex exec "Refactor utils.py and run the tests." '
    '--skip-git-repo-check --dangerously-bypass-approvals-and-sandbox < /dev/null',
    timeout=900.0,
)
```

Relaxing it means the agent can do anything the box can do. That is the point of running it in a box, and it is also why the box's own boundary matters: keep the network narrow and the credential outside if the task is not fully trusted — see [Secrets and hardening](/manage-sandbox/secrets-and-security).

If you would rather keep Codex's own sandbox on, pass `-s workspace-write` instead and leave the bypass flag off.

## Keeping the API key out of the box

Piping the key through `codex login --with-api-key` keeps it off the command line, but it still enters the sandbox. To keep the real value on the host, inject it at the proxy: the box sees a placeholder, and BoxLite substitutes the real value on outbound requests to the hosts you allow.

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
from boxlite import NetworkSpec, OutboundNetworkSpec, Secret, SimpleBox

box = SimpleBox(
    image="node:20-slim",
    disk_size_gb=8,
    secrets=[Secret(name="openai", value="<YOUR_OPENAI_API_KEY>", hosts=["api.openai.com"])],
    network=NetworkSpec(outbound=OutboundNetworkSpec(mode="enabled", allow_net=["registry.npmjs.org", "api.openai.com"])),
)
```

Substitution covers request headers, the URL query string, and the request body — not the URL path.

## Troubleshooting

| Symptom | Cause | Fix |
| - | - | - |
| `stream disconnected before completion`, or any TLS/transport error on the first prompt — while `npm install` and `codex --version` worked | The slim image has no system CA certificates; Codex verifies TLS against the system trust store | `apt-get install -y ca-certificates`, or use a non-slim image. See [Why a slim image needs `ca-certificates`](#why-a-slim-image-needs-ca-certificates) |
| `Missing optional dependency @openai/codex-linux-*` after install | The image is musl-based (Alpine); Codex publishes glibc binaries only | Use `node:20-slim` or another glibc image |
| `npm install -g` fails with `ENOSPC: no space left on device` | The default box disk is too small | `SimpleBox(..., disk_size_gb=8)` or larger |
| `codex exec` complains the directory is not a git repository | Codex checks for one by default | Add `--skip-git-repo-check`, or `git init` the working directory |
| The command hangs and never returns | Codex reads instructions from stdin when given no prompt argument, and waits for a login when it has no credential | Pass the prompt as an argument, append `< /dev/null`, and authenticate before the first `exec` |
| The agent stops to ask for approval | Codex's own sandbox is active | Pass `-s workspace-write`, or `--dangerously-bypass-approvals-and-sandbox` when the box is your containment |
| Authentication fails after install | `--with-api-key` reads stdin; a key passed as an argument is ignored | `printenv OPENAI_API_KEY \| codex login --with-api-key` |

## Related

* [Run Pi](/agent-in-box/run-pi) — a CLI whose custom endpoints go through a config file rather than environment variables.
* [Run Claude Code](/agent-in-box/run-claude-code) — the same pattern, plus `SkillBox` and a noVNC desktop.
* [Run untrusted tools safely](/use-cases/untrusted-tool-execution) — narrowing network and privileges around an agent you do not trust.
