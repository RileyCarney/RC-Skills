---
name: boxlite-use-cases
description: Complete end-to-end patterns and recipes for BoxLite use cases, including LLM code interpreters, Pandas data analysis agents, live web app previews, MCP stdio tool servers, untrusted PR CI review, computer-use desktops, dual-box web scraping, custom OCI images, multi-tenant persistent shells, and locked-down untrusted tool execution.
---

# BoxLite Use Cases & Pattern Recipes

Production-ready patterns combining BoxLite primitives into complete workflows, grouped into three architectural shapes:
1. **The box is a tool the model calls** (host orchestrates, untrusted code executes inside)
2. **The agent lives in the box** (autonomous desktop, browser, or custom-image workbench)
3. **Multi-tenant platform** (persistent dev boxes per user/branch or maximum-lockdown analysis benches)

## Use-Cases Documentation Index (All 11 Pages)

| Category | Guide | Primary Primitives | Local Mirror | Live Docs |
| - | - | - | - | - |
| Overview & Recipes | Use Cases & Repository Recipe Index | All Box types + SDK repo examples | [use-cases/index.md](../../docs/use-cases/index.md) | [docs.boxlite.ai/use-cases/index](https://docs.boxlite.ai/use-cases/index.md) |
| Model Tool | Code Interpreter for LLM | `CodeBox`, `run()`, `exec()` | [use-cases/code-interpreter.md](../../docs/use-cases/code-interpreter.md) | [docs.boxlite.ai/use-cases/code-interpreter](https://docs.boxlite.ai/use-cases/code-interpreter.md) |
| Model Tool | Data Analysis Agent | `CodeBox(disk_size_gb=4)`, `copy_in`/`copy_out`, `install_packages` | [use-cases/data-analysis-agent.md](../../docs/use-cases/data-analysis-agent.md) | [docs.boxlite.ai/use-cases/data-analysis-agent](https://docs.boxlite.ai/use-cases/data-analysis-agent.md) |
| Model Tool | Sandboxed Web App Preview | `SimpleBox(ports=...)`, `0.0.0.0`, `reuse_existing` | [use-cases/sandboxed-web-app.md](../../docs/use-cases/sandboxed-web-app.md) | [docs.boxlite.ai/use-cases/sandboxed-web-app](https://docs.boxlite.ai/use-cases/sandboxed-web-app.md) |
| Model Tool | MCP Tool Server (`FastMCP`) | `FastMCP`, `@mcp.tool()`, `SimpleBox.exec` | [use-cases/mcp-tool-server.md](../../docs/use-cases/mcp-tool-server.md) | [docs.boxlite.ai/use-cases/mcp-tool-server](https://docs.boxlite.ai/use-cases/mcp-tool-server.md) |
| Model Tool | Sandboxed CI (Untrusted PR Review) | `CodeBox(disk_size_gb=4)`, `DEBIAN_FRONTEND=noninteractive`, `Secret` | [use-cases/sandboxed-ci.md](../../docs/use-cases/sandboxed-ci.md) | [docs.boxlite.ai/use-cases/sandboxed-ci](https://docs.boxlite.ai/use-cases/sandboxed-ci.md) |
| Agent in Box | Computer-Use Agent | `ComputerBox(cpu=2, memory=2048)`, `screenshot()`, `wait_until_ready` | [use-cases/computer-use-agent.md](../../docs/use-cases/computer-use-agent.md) | [docs.boxlite.ai/use-cases/computer-use-agent](https://docs.boxlite.ai/use-cases/computer-use-agent.md) |
| Agent in Box | Web Scraping Agent (2-Box Pipeline) | `BrowserBox(port=...)` + `CodeBox` parser | [use-cases/web-scraping-agent.md](../../docs/use-cases/web-scraping-agent.md) | [docs.boxlite.ai/use-cases/web-scraping-agent](https://docs.boxlite.ai/use-cases/web-scraping-agent.md) |
| Agent in Box | Custom Agent Image / Offline OCI | `image=...`, `rootfs_path=...`, `disk_size_gb` | [use-cases/custom-agent-image.md](../../docs/use-cases/custom-agent-image.md) | [docs.boxlite.ai/use-cases/custom-agent-image](https://docs.boxlite.ai/use-cases/custom-agent-image.md) |
| Multi-Tenant | Interactive Dev Environment | `InteractiveBox(tty=False/True)`, `exec`, `wait()` | [use-cases/interactive-dev-environment.md](../../docs/use-cases/interactive-dev-environment.md) | [docs.boxlite.ai/use-cases/interactive-dev-environment](https://docs.boxlite.ai/use-cases/interactive-dev-environment.md) |
| Multi-Tenant | Untrusted Tool Execution | `mode="disabled"`, `user="1000:1000"`, `SecurityOptions.maximum()` | [use-cases/untrusted-tool-execution.md](../../docs/use-cases/untrusted-tool-execution.md) | [docs.boxlite.ai/use-cases/untrusted-tool-execution](https://docs.boxlite.ai/use-cases/untrusted-tool-execution.md) |

---

## Key Architectural Patterns & Gotchas by Use Case

### 1. Code Interpreter (`use-cases/code-interpreter.md`)
- Run LLM-generated Python inside `async with CodeBox() as box:` so orchestration & API keys remain strictly in the host process.
- **`CodeBox.run(code)` hides errors**: returns `stdout` only, so runtime tracebacks produce an empty string. Switch to `await box.exec("python3", "-c", code)` whenever you need `stderr` and `exit_code`.
- Network egress is **open by default**; add `OutboundNetworkSpec` if preventing data exfiltration matters.

### 2. Data Analysis Agent (`use-cases/data-analysis-agent.md`)
- Send only the CSV header + sample rows to the LLM; copy the real dataset into the box explicitly via `await box.copy_in(csv_path, "/data/sales.csv")`.
- **Two mandatory rules**:
  1. Pass **`disk_size_gb=4`** to `CodeBox`: the default disk is too small for `pandas` + `numpy` (`OSError: [Errno 28] No space left on device`).
  2. Never copy into `/tmp` (mounted as `tmpfs`) or plot interactively — use persistent paths like `/data` and call `matplotlib.use("Agg")` before importing `pyplot`.

### 3. Sandboxed Web App Preview (`use-cases/sandboxed-web-app.md`)
- Declare forwarded ports upfront: `SimpleBox(image="python:alpine", name="webapp-preview", ports=[(HOST_PORT, GUEST_PORT)], reuse_existing=True)`.
- **Must bind `0.0.0.0`**: traffic enters via the guest network interface (`192.168.127.2`), NOT guest `127.0.0.1` (binding `127.0.0.1` inside the box causes `Connection reset by peer`).
- Write generated code using base64 encoding (`echo <b64> | base64 -d > /app/server.py`) to avoid shell quoting hazards, start with `nohup ... > /tmp/app.log 2>&1 &`, and poll `/api/health`.

### 4. MCP Tool Server (`use-cases/mcp-tool-server.md`)
- BoxLite does **not** bundle an MCP package (`boxlite.mcp` does not exist) — install `pip install boxlite mcp` and use `FastMCP`.
- Wrap `SimpleBox` in `@mcp.tool() async def run_in_sandbox(...)`, catching **both `BoxliteError` and `RuntimeError`** (missing KVM/image pull failure) and returning non-zero `exit_code`/`stdout`/`stderr` as structured data.
- Authentication, rate limiting, and command allowlists belong in your host `FastMCP` handler before box creation.

### 5. Sandboxed CI / Untrusted PR Review (`use-cases/sandboxed-ci.md`)
- `python:slim` default rootfs (`~224 MB`) is too small for `apt-get install git` — always set **`disk_size_gb=4`**!
- Pass `DEBIAN_FRONTEND=noninteractive` to `apt-get` so debconf doesn't hang without a TTY.
- Keep `GITHUB_TOKEN` out of the box (or inject at the proxy with `Secret` via HTTP headers, never clone URLs), and read `pytest` `result.exit_code` without appending `|| true`.

### 6. Computer-Use Agent (`use-cases/computer-use-agent.md`)
- Boot `ComputerBox(cpu=2, memory=2048)` with a generous `await desktop.wait_until_ready(timeout=180)` (large XFCE webtop image, watch live at `http://localhost:3000`).
- Screen resolution is **1024x768** (`get_screen_size()`); `await desktop.screenshot()` returns a dict `{data, width, height, format}` (`shot["data"]` is base64 PNG).
- Always re-verify state (`cursor_position()` / new `screenshot()`) after acting, and confirm before high-risk clicks.

### 7. Web Scraping Agent — Dual-Box Defense (`use-cases/web-scraping-agent.md`)
- Run Chromium/Firefox inside `BrowserBox` (`playwright==1.58.0` exact match required to avoid `428 Precondition Required`, avoid port `3000` collisions with a free ephemeral port) AND copy raw HTML into a separate `CodeBox` to parse before anything reaches your LLM!
- Use `endpoint()` (`connect_over_cdp`) for Chromium or `playwright_endpoint()` (`connect`) for Firefox/WebKit (`endpoint()` raises `ValueError` on WebKit).

### 8. Custom Agent Image & Offline OCI (`use-cases/custom-agent-image.md`)
- Pass `image="docker.io/library/node:slim"` for registry images or `rootfs_path="/path/to/oci-layout"` for offline air-gapped OCI layouts (`rootfs_path` wins if both are supplied; omitting both raises `ValueError`).
- Size `disk_size_gb` generously for large toolchains.

### 9. Interactive Dev Environment (`use-cases/interactive-dev-environment.md`)
- Use `InteractiveBox(image="alpine:latest", tty=False)` for a persistent stateful shell across multiple `exec` calls (`CodeBox.run` is stateless per call).
- Constructor `env` takes a **list of `(key, value)` tuples**, while `exec(..., env={...})` takes a `dict`. Split command and args (`exec("ls", "-la")`, not `exec("ls -la")`).
- For persistent multi-session tenant boxes, set `name=...` and `auto_remove=False`.

### 10. Untrusted Tool Execution (`use-cases/untrusted-tool-execution.md`)
Stack all **three independent controls** on top of the microVM boundary:
1. **No egress (or strict allowlist)**: `network=NetworkSpec(outbound=OutboundNetworkSpec(mode="disabled"))` (or `mode="enabled", allow_net=[...]`; blocked domains sinkhole to `0.0.0.0`).
2. **Dropped privileges**: `user="1000:1000"`.
3. **Maximum host-side OS sandbox**: `advanced=AdvancedBoxOptions(security=SecurityOptions.maximum())` (`security=` is NEVER a top-level `BoxOptions` arg, and `SecurityOptions.minimum()` does not exist).

---

## Repository Example Directory (`boxlite/examples/`) Quick Map

The `use-cases/index.md` catalog also maps directly to runnable repository files under `boxlite/`:
- `examples/python/01_getting_started/` (`run_simplebox.py`, `run_codebox.py`, `run_simplebox_sync.py`, `list_boxes.py`) & `examples/node/` (`simplebox.js`, `codebox.js`)
- `examples/python/02_features/` (`mount_host_dir.py`, `copy_files.py`, `forward_ports.py`, `network_allowlist.py`, `set_cmd_and_user.py`, `use_custom_registry.py`, `use_local_oci_bundle.py`)
- `examples/python/03_lifecycle/` (`manage_lifecycle.py`, `detach_and_reattach.py`, `share_across_processes.py`, `shutdown_runtime.py`, `clone_export_import.py`)
- `examples/python/04_interactive/` (`run_interactive_shell.py`, `install_claude_interactively.py`) & `examples/node/interactivebox.js`
- `examples/python/05_browser_desktop/` (`automate_with_playwright.py`, `automate_with_puppeteer.py`, `automate_desktop.py`)
- `examples/python/06_ai_agents/` (`chat_with_claude.py`, `use_skillbox.py`, `drive_box_with_llm.py`, `drive_box_with_minimax.py`) & `examples/node/claude_in_boxlite.js`
- `examples/python/07_advanced/` (`use_native_api.py`, `multi_agent/host.py`, `local_to_rest_migration.py`) & `examples/python/08_rest_api/` (`connect_and_list.py`)
- `examples/c/` (`simple_api_demo.c`, `execute.c`, `shutdown.c`, `01_lifecycle.c` .. `05_metrics.c`)
