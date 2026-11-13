---
name: boxlite-agent-tools
description: Build AI agent tool sandboxes with BoxLite — run untrusted Python (CodeBox), arbitrary languages/commands (SimpleBox.exec & streaming Box.exec), interactive PTY shells (InteractiveBox), GUI desktop automation (ComputerBox), remote Playwright/CDP browsers (BrowserBox), secret-safe GitHub operations, model tool-calling loops (OpenAI/Anthropic), and MCP tool servers.
---

# BoxLite Agent Tools

Capabilities an external agent calls into inside an isolated BoxLite microVM. (If the agent CLI itself runs *inside* the box, use [`boxlite-agent-in-box`](../boxlite-agent-in-box/SKILL.md).)

## Documentation Map (9 Pages)

| Tool / Pattern | Local Doc | Live Docs |
| - | - | - |
| Overview | [index.md](../../docs/agent-tools/index.md) | [agent-tools](https://docs.boxlite.ai/agent-tools/index.md) |
| Run Python (`CodeBox`) | [code-execution-python.md](../../docs/agent-tools/code-execution-python.md) | [code-execution-python](https://docs.boxlite.ai/agent-tools/code-execution-python.md) |
| Run Any Language (`SimpleBox.exec`) | [code-execution-any-language.md](../../docs/agent-tools/code-execution-any-language.md) | [code-execution-any-language](https://docs.boxlite.ai/agent-tools/code-execution-any-language.md) |
| Pseudo-Terminal (`InteractiveBox`) | [pseudo-terminal.md](../../docs/agent-tools/pseudo-terminal.md) | [pseudo-terminal](https://docs.boxlite.ai/agent-tools/pseudo-terminal.md) |
| Browser Automation (`BrowserBox`) | [browser-automation.md](../../docs/agent-tools/browser-automation.md) | [browser-automation](https://docs.boxlite.ai/agent-tools/browser-automation.md) |
| Computer Use (`ComputerBox`) | [computer-use.md](../../docs/agent-tools/computer-use.md) | [computer-use](https://docs.boxlite.ai/agent-tools/computer-use.md) |
| GitHub Operations (`git` + `Secret`) | [github-operations.md](../../docs/agent-tools/github-operations.md) | [github-operations](https://docs.boxlite.ai/agent-tools/github-operations.md) |
| Drive from an Agent Loop | [drive-from-agent-loop.md](../../docs/agent-tools/drive-from-agent-loop.md) | [drive-from-agent-loop](https://docs.boxlite.ai/agent-tools/drive-from-agent-loop.md) |
| Wrap as MCP Server | [mcp-server.md](../../docs/agent-tools/mcp-server.md) | [mcp-server](https://docs.boxlite.ai/agent-tools/mcp-server.md) |

---

## 1. Python Execution (`CodeBox`)

`CodeBox` defaults to `"python:slim"` and runs snippets via `python -c`.

```python
import asyncio
import boxlite

async def main():
    async with boxlite.CodeBox() as cb:
        await cb.install_package("requests")  # runs pip install inside the box
        out = await cb.run("import requests; print(requests.__version__)")
        print(out)

asyncio.run(main())
```

### Critical Python vs. Node Difference & Gotchas

* **Python `await cb.run(code)`**:
  * Returns **`stdout` string only** (drops `stderr`).
  * **Never raises** on non-zero exit.
  * `timeout` argument is accepted for API compatibility only and is **NOT enforced**! For enforced timeouts, `exit_code`, and `stderr`, call inherited `await cb.exec("/usr/local/bin/python", "-c", code, timeout=10.0)`.
* **Node `await cb.run(code)`**:
  * **DOES throw `ExecError`** (`err.exitCode`, `err.stderr`) on non-zero exit — the exact opposite of Python.
* Pass `memory_mib`, `cpus`, `runtime`, `volumes`, `network`, `secrets`, `advanced` to `CodeBox(...)` just like `SimpleBox`.

---

## 2. Any Language / Command (`SimpleBox.exec` & Streaming)

### High-Level `SimpleBox.exec`

* **Python**: `await box.exec(cmd, *args, env=None, user=None, timeout=None, cwd=None) -> ExecResult`
  * `env` **MUST be `dict[str, str]`** (unlike constructor `SimpleBox(..., env=[("K", "V")])` which takes `list[tuple]`). Passing a list to `exec` fails at `.items()`.
  * `timeout` (float seconds) kills the process with `SIGTERM` and returns **`ExecResult(exit_code=-15, error_message=None)`** — it does **not** raise an exception.
  * Non-zero exit codes **do not raise**; missing commands / spawn failures raise `RuntimeError` (Python) or bare `Error` (Node).
* **Node**:
  * `await box.exec(cmd, ...args)`
  * `await box.exec(cmd, args: string[], env: Record<string, string>)`
  * `await box.exec(cmd, args, env?, { cwd?, user?, timeoutSecs? })` (note **`timeoutSecs`** instead of `timeout`).
  * Returns `{ exitCode, stdout, stderr }`.

### Line-by-Line Streaming (Low-Level `Box.exec`)

Drill down via `box._box` (on `SimpleBox`) or `runtime.create(...)`:

```python
execution = await box._box.exec("sh", ["-c", "for i in 1 2 3; do echo $i; sleep 1; done"], timeout_secs=30.0)
if (stdout := execution.stdout()) is not None:
    async for chunk in stdout:
        print(chunk.rstrip() if isinstance(chunk, str) else chunk.decode("utf-8", "replace").rstrip())
result = await execution.wait()
```

Note parameter differences:
* `SimpleBox.exec`: `cmd, *args, timeout=...`
* Native `Box.exec`: `cmd, args=[...], env=..., timeout_secs=...` (returns `Execution`)
* Native `JsBox.exec`: `exec(cmd, args, env?)` (`args` is a plain array)

---

## 3. Pseudo-Terminal (`InteractiveBox`)

Provides real bidirectional PTY forwarding (`docker exec -it` equivalent).

```python
import asyncio, os
from boxlite import InteractiveBox

async def main():
    async with InteractiveBox(
        image="alpine:latest",
        shell="/bin/sh",
        env=[("TERM", os.environ.get("TERM", "xterm-256color"))],  # MUST be list[tuple]!
    ) as itbox:
        await itbox.wait()

asyncio.run(main())
```

* **`tty` modes**: `None` (auto-detect via `sys.stdin.isatty()` / `process.stdin.isTTY`), `True` (force forwarding), `False` (programmatic).
* **`env` quirk**: Python `InteractiveBox(..., env=...)` passes `env` straight to native `Box.exec`, so it **MUST be `list[tuple[str, str]]`**, not `dict`. Node uses `Record<string, string>`.
* Must run in a real terminal unless `tty=True` is forced for custom streaming.
* Lower-level PTY works from *any* SDK via `exec(..., tty=True)`.

---

## 4. Browser Automation (`BrowserBox`)

Runs real **Chromium**, **Firefox**, or **WebKit** (`mcr.microsoft.com/playwright:v1.58.0-jammy`) inside the VM while your Playwright/Puppeteer script runs on the host.

```python
from boxlite import BrowserBox, BrowserBoxOptions
from playwright.async_api import async_playwright

async with BrowserBox(BrowserBoxOptions(browser="chromium")) as bbox:
    ws = await bbox.playwright_endpoint()  # or bbox.connect()
    async with async_playwright() as p:
        browser = await p.chromium.connect(ws)
        page = await browser.new_page()
        await page.goto("https://example.com")
        await browser.close()
```

### Critical Rules

1. **Exact version pin `1.58.0` required**: Install `pip install "playwright==1.58.0"` (Python) or `npm install playwright-core@1.58.0` (Node) — do *not* run `playwright install`. Mismatched clients (e.g., `1.60.0`) fail with `428 Precondition Required`.
2. **Two mutually exclusive endpoints** (both bind host port `3000` by default):
   * `playwright_endpoint(timeout=60)` / `playwrightEndpoint()`: Playwright WebSocket protocol (`chromium`, `firefox`, `webkit`). Required for WebKit! Also wrapped by `await bbox.connect()`.
   * `endpoint(timeout=60)`: Direct CDP (`chromium`) or WebDriver BiDi (`firefox`). **WebKit raises `ValueError` / `BoxliteError`**.
3. Node defaults: `{ browser: "chromium", cpus: 2, memoryMib: 2048, port: 3000, cdpPort: 9222 }` (note Python uses `cpu`, `memory`, `port`, `cdp_port` in `BrowserBoxOptions`).

---

## 5. Computer Use / Desktop (`ComputerBox`)

Boots an XFCE Linux desktop (`lscr.io/linuxserver/webtop:ubuntu-xfce`, fixed `1024x768`, `DISPLAY=:1`), HTTP port `3000` / HTTPS `3001` (self-signed cert).

```python
import base64, boxlite

async with boxlite.ComputerBox(cpu=2, memory=2048) as desktop:
    await desktop.wait_until_ready(timeout=60)  # Poll until desktop + selkies are ready
    shot = await desktop.screenshot()          # {"data": base64_png, "width": 1024, "height": 768, "format": "png"}
    with open("desktop.png", "wb") as f:
        f.write(base64.b64decode(shot["data"]))
    await desktop.mouse_move(512, 384)
    await desktop.left_click()
    await desktop.type("hello")
    await desktop.key("Return")
```

* **Python methods**: `wait_until_ready(timeout=60)`, `screenshot()`, `mouse_move(x, y)`, `left_click()`, `right_click()`, `middle_click()`, `double_click()`, `triple_click()`, `left_click_drag(sx, sy, ex, ey)`, `cursor_position()`, `type(text)`, `key(combo)`, `scroll(x, y, direction, amount=3)` (`up`/`down`/`left`/`right`), `get_screen_size()`.
* **Node methods**: camelCase (`waitUntilReady`, `mouseMove`, `leftClick`, `leftClickDrag`, `cursorPosition`, `getScreenSize`, etc.) and constructor `{ cpus, memoryMib, guiHttpPort, guiHttpsPort }`.
* Other languages (Go/Rust/C) drive the desktop container via low-level `exec`.

---

## 6. Agent Loop Contract (`drive-from-agent-loop`)

Never let tool execution crash the agent loop:

```python
async def sandbox_exec(box, argv) -> dict:
    if not isinstance(argv, list) or not argv or not all(isinstance(a, str) for a in argv):
        return {"stdout": "", "stderr": "argv must be a non-empty list of strings", "exit_code": 2}
    try:
        result = await box.exec(*argv)
    except RuntimeError as exc:
        # Missing binary hallucinated by model raises RuntimeError/spawn_failed
        return {"stdout": "", "stderr": f"command could not be started: {exc}", "exit_code": -1}
    return {"stdout": result.stdout, "stderr": result.stderr, "exit_code": result.exit_code}
```

* One JSON Schema (`{ type: "object", properties: { argv: { type: "array", items: { type: "string" } } }, required: ["argv"] }`) works identically across OpenAI Responses API (`parameters`) and Anthropic Messages API (`input_schema`).
* Stateful across calls within a single session; one `SimpleBox` per task with `async with`.

---

## 7. Wrap as an MCP Tool Server

Register a `run_in_sandbox` handler inside `FastMCP` (from Python `mcp` package) or TypeScript MCP SDK:
* Catch **both** `BoxliteError` (SDK wrapper errors like `ExecError`) **and** `RuntimeError` / bare `Error` (image pull failures, missing KVM/virtualization).
* Return `{ "exit_code": result.exit_code, "stdout": result.stdout, "stderr": result.stderr }` as structured tool data.

---

## 8. Secret-Safe GitHub Operations

Never pass `GITHUB_TOKEN` in env vars, CLI args, or clone URLs (`https://user:token@github.com/...` fails because `git` base64-encodes it into `Authorization: Basic`, hiding the `<BOXLITE_SECRET:...>` placeholder from MITM substitution).

```python
Secret(
    name="github_token",
    value=GITHUB_TOKEN,
    hosts=["github.com", "api.github.com"],
)
# Inside guest, BOXLITE_SECRET_GITHUB_TOKEN = "<BOXLITE_SECRET:github_token>"
```

Use plaintext placeholder headers:
* **Git**: `git -c "http.extraHeader=Authorization: Bearer <BOXLITE_SECRET:github_token>" clone https://github.com/ORG/REPO.git /work/repo`
* **REST API / `curl`**: `curl -H "Authorization: Bearer <BOXLITE_SECRET:github_token>" https://api.github.com/user`
* Pair with `NetworkSpec(outbound=OutboundNetworkSpec(mode="enabled", allow_net=["github.com", "api.github.com"]))` and `disk_size_gb=8` for `git` dependencies on `ubuntu:24.04`.
