---
name: boxlite
description: Master skill and complete technical reference for BoxLite (https://docs.boxlite.ai/) covering all 111 documentation pages across Open Source microVM sandboxes, BoxLite Cloud, 5 SDKs (Python, Node.js, Rust, Go, C), the boxlite CLI, agent tools, agent-in-a-box workflows, production guides, architecture, and 30 cross-SDK pitfalls.
---

# BoxLite Master Skill

Complete, offline-mirrored technical reference and routing hub for **all 111 documentation pages** under `https://docs.boxlite.ai/`.

BoxLite is an **embeddable microVM sandbox runtime for AI agents**. Unlike standard containers that share the host kernel via namespaces, each Box boots a dedicated lightweight virtual machine (KVM on Linux/WSL2, Hypervisor.framework on Apple Silicon macOS) running any standard Docker/OCI container image with:
- **Hardware-level kernel isolation** (isolated kernel, filesystem, process tree, and network stack)
- **Fast cold/warm starts** (sub-second to ~1–2s restarts using cached OCI layers and copy-on-write overlays)
- **Stateful persistence** across `stop()` and `start()` cycles
- **No daemon and no root required** (runs embedded inside your application process via native FFI/crate)
- **Drop-in Cloud execution** (**BoxLite Cloud** at `https://api.boxlite.ai` uses the exact same SDK via `Boxlite.rest(...)`)

---

## Quick Navigation: 10 Modular Domain Skills

| # | Domain Skill | Coverage | Doc Count | Entry File |
| - | - | - | - | - |
| 1 | Getting Started | Overview, introduction, quickstarts (Python/Node/Rust/Go/C), installation matrix, FAQ, changelog, resources | 6 | [boxlite-getting-started/SKILL.md](./skills/boxlite-getting-started/SKILL.md) |
| 2 | Manage Sandboxes | Box types, lifecycle, env/entrypoint/user/cwd, CPU/RAM/disk, bind & anonymous volumes, network & allowlists, snapshots/clones/export, secrets & hardening | 9 | [boxlite-manage-sandboxes/SKILL.md](./skills/boxlite-manage-sandboxes/SKILL.md) |
| 3 | Agent Tools | `CodeBox` (Python), `SimpleBox` (any language), `InteractiveBox` (PTY), `ComputerBox` (desktop), `BrowserBox` (Playwright/CDP), LLM tool loop, MCP server, GitHub ops | 9 | [boxlite-agent-tools/SKILL.md](./skills/boxlite-agent-tools/SKILL.md) |
| 4 | Agent in a Box | Running Claude Code, Codex, Pi, OpenCode, Hermes in local sandboxes & on BoxLite Cloud (`/agent-in-box/*` + `/cloud/agent-in-box/*`) | 12 | [boxlite-agent-in-box/SKILL.md](./skills/boxlite-agent-in-box/SKILL.md) |
| 5 | Human Tools | Browser-accessible noVNC desktops (`ComputerBox`) and Chrome DevTools attachment (`BrowserBox`) | 3 | [boxlite-human-tools/SKILL.md](./skills/boxlite-human-tools/SKILL.md) |
| 6 | Production Guides | Error handling, running at scale (concurrency/TTL/cleanup), Docker/K8s deployment, REST service endpoints (`boxlite serve`), private/custom image registries | 7 | [boxlite-production-guides/SKILL.md](./skills/boxlite-production-guides/SKILL.md) |
| 7 | Architecture & Dev | Core components (`boxlite-shim`, libkrun, gRPC/vsock), security isolation layers, networking, OCI storage, boot latency, CLI/Rust dev, E2E, macOS Seatbelt, CLA | 14 | [boxlite-architecture/SKILL.md](./skills/boxlite-architecture/SKILL.md) |
| 8 | SDK & CLI Reference | Full API surfaces, option types, error enums, metrics, REST prefixes & traps across Python, Node.js, Rust, Go, C, and `boxlite` CLI | 7 | [boxlite-sdk-cli-reference/SKILL.md](./skills/boxlite-sdk-cli-reference/SKILL.md) |
| 9 | BoxLite Cloud | Cloud API keys, billing/plans/pricing/cost controls, Cloud volumes, Cloud networking/tunnels/domains/policy, proxy secrets, image catalog/aliases, checkpoints, Cloud SSH | 33 (+6 agent links) | [boxlite-cloud/SKILL.md](./skills/boxlite-cloud/SKILL.md) |
| 10 | Use Cases & Recipes | Code interpreter, data analysis agent, web app preview, MCP server, sandboxed PR CI, computer use, 2-box web scraping, custom images, multi-tenant shells, locked-down analysis, repo recipe index | 11 | [boxlite-use-cases/SKILL.md](./skills/boxlite-use-cases/SKILL.md) |

---

## Offline Documentation Sync & Search Scripts

All 111 Markdown files under `./docs/` are mirrored from `llms.txt` / `llms-full.txt` and validated against `sitemap.xml`:

| Script | Platform | Command | Capabilities |
| - | - | - | - |
| [sync_docs.ps1](./scripts/sync_docs.ps1) | Windows / PowerShell 7+ | `pwsh -File ./scripts/sync_docs.ps1 [-SkipDownload] [-DocsDir <path>]` | Fetches `llms.txt` & `llms-full.txt`, extracts all pages cleanly into `docs/**/*.md` |
| [sync_docs.py](./scripts/sync_docs.py) | Cross-platform Python 3 | `python3 ./scripts/sync_docs.py [--skip-download] [--docs-dir <path>]` | Downloads & splits `llms-full.txt` using UTF-8 standard library only |
| [search_docs.ps1](./scripts/search_docs.ps1) | Windows / PowerShell 7+ | `pwsh -File ./scripts/search_docs.ps1 "<regex>" [-MaxResults 25]` | Ranks matching `.md` files by hit count, first line number, and snippet preview |
| [search_docs.py](./scripts/search_docs.py) | Cross-platform Python 3 | `python3 ./scripts/search_docs.py "<regex>" [--max-results 25]` | Case-insensitive regex search across all mirrored `.md` files |

---

## Domain 1: Getting Started, Platform Matrix & First Sandboxes

### Platform & Hardware Virtualization Support Matrix

| Platform | Architecture | Local Support | Virtualization / Requirement | Fallback When Unavailable |
| - | - | - | - | - |
| **macOS** | Apple Silicon (`arm64`) | Supported | macOS 12+, built-in `Hypervisor.framework` (no `/dev/kvm`; `boxlite-shim` runs under Seatbelt `sandbox-exec`) | — |
| **macOS** | Intel (`x86_64`) | **Not supported** | — | Use **BoxLite Cloud** (`Boxlite.rest(...)`) |
| **Linux** | `x86_64` / `arm64` | Supported | KVM enabled (`/dev/kvm` exists, user in `kvm` group, `vmx`/`svm` CPU extensions) | Use **BoxLite Cloud** |
| **Windows** | `x86_64` | **WSL2 only** | Enable KVM inside WSL2 and follow Linux `kvm` group setup (no native Windows wheel/npm/CLI) | Use **BoxLite Cloud** |
| **Containers / CI** | Any | Host-dependent | Nested KVM required (`--device /dev/kvm` in Docker); unavailable in most CI runners | Use **BoxLite Cloud** |

### SDK, Runtime & CLI Install Matrix

| Target | Minimum Version | Install Command | Key Requirements & Verify Command |
| - | - | - | - |
| **Python** | Python `3.9+` / `3.10+` | `pip install boxlite` (optional: `"boxlite[sync,orchestration]"`) | Prebuilt wheels (no `protoc`). `[sync]` adds greenlet; `[orchestration]` adds cloudpickle. Verify: `python3 -c "import boxlite; print(boxlite.__version__)"` |
| **Node.js / TS** | Node.js `18+` | `npm install @boxlite-ai/boxlite` | **Pure ESM** (`"type": "module"`). Optional peerDep `playwright-core` for `BrowserBox`. Native prebuilts for `aarch64-apple-darwin`, `x86_64-unknown-linux-gnu`, `aarch64-unknown-linux-gnu` |
| **Rust** | Rust `1.88+` | `cargo add boxlite` (plus `tokio`, `futures`; add `features = ["rest"]` for REST) | Source build requires `protoc >= 3.12` and initialized git submodules (`git submodule update --init --recursive`) |
| **Go** | Go `1.24+`, **CGO** | `go get github.com/boxlite-ai/boxlite/sdks/go` + `go run github.com/boxlite-ai/boxlite/sdks/go/cmd/setup` | `cmd/setup` downloads ~100+ MB native archive (`libboxlite.a` + `boxlite.h`). If timeout occurs, re-run — it resumes from extracted files |
| **C** | C11 (GCC/Clang) | `cargo build --release -p boxlite-c` (or `make sdk-c`) | Outputs `libboxlite.{dylib,so,a}` + `sdks/c/include/boxlite.h`. Verify with `boxlite_version()` |
| **CLI (`boxlite`)** | Any Linux/macOS/WSL2 | `curl -fsSL https://sh.boxlite.ai \| sh` (or `cargo binstall boxlite-cli` / `cargo install boxlite-cli`) | Installs to `$HOME/.local/bin/boxlite`. **Important**: put `BOXLITE_VERSION=vX.Y.Z` / `BOXLITE_INSTALL_DIR=...` / `BOXLITE_EXPECTED_SHA256=...` on the `sh` side of the pipe! |

### Five-Language Quickstart Code Patterns

**1. Python (`SimpleBox` async context manager):**
```python
import asyncio
import boxlite

async def main() -> None:
    try:
        # async with creates/starts on entry and auto_remove cleans up on exit
        async with boxlite.SimpleBox(image="python:alpine") as box:
            print(f"Sandbox started: {box.id}")
            result = await box.exec("python", "-c", "print('Hello from BoxLite!')")
            if result.exit_code != 0:
                print("stderr:", result.stderr.strip())
            print("stdout:", result.stdout.strip())
    except RuntimeError as exc:
        # Image pull failure, missing binary, or no virtualization raises RuntimeError
        print(f"Sandbox failed to run: {exc}")

asyncio.run(main())
```

**2. Node.js / TypeScript (ESM `SimpleBox`):**
```javascript
import { SimpleBox } from "@boxlite-ai/boxlite";

async function main() {
  const box = new SimpleBox({ image: "alpine:latest" });
  try {
    const result = await box.exec("echo", "Hello from BoxLite!");
    if (result.exitCode !== 0) {
      throw new Error(`Command failed (exit ${result.exitCode}): ${result.stderr}`);
    }
    console.log("stdout:", result.stdout.trim());
  } finally {
    await box.stop(); // autoRemove defaults to true
  }
}

main();
```

**3. Rust (`BoxliteRuntime` + `LiteBox` streaming exec):**
```rust
use boxlite::{BoxCommand, BoxOptions, BoxliteRuntime, RootfsSpec};
use futures::StreamExt;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let runtime = BoxliteRuntime::default_runtime(); // sync constructor!
    let options = BoxOptions {
        rootfs: RootfsSpec::Image("alpine:latest".into()),
        ..Default::default()
    };
    let litebox = runtime.create(options, None).await?;
    let mut execution = litebox
        .exec(BoxCommand::new("echo").arg("Hello from BoxLite!"))
        .await?;
    if let Some(mut stdout) = execution.stdout() {
        while let Some(line) = stdout.next().await {
            println!("{line}");
        }
    }
    let result = execution.wait().await?; // ExecResult has exit_code + error_message ONLY
    if !result.success() {
        eprintln!("non-zero exit: {}", result.exit_code);
    }
    litebox.stop().await?;
    Ok(())
}
```

**4. Go (`boxlite.NewRuntime` + `Box.Exec`):**
```go
package main

import (
	"context"
	"fmt"
	"log"
	boxlite "github.com/boxlite-ai/boxlite/sdks/go"
)

func main() {
	ctx := context.Background()
	rt, err := boxlite.NewRuntime()
	if err != nil {
		log.Fatal(err)
	}
	defer rt.Close()

	box, err := rt.Create(ctx, "alpine:latest")
	if err != nil {
		log.Fatal(err)
	}
	defer box.Close()

	res, err := box.Exec(ctx, "echo", "Hello from BoxLite!")
	if err != nil {
		log.Fatal(err) // res is nil when err != nil!
	}
	if res.ExitCode != 0 {
		fmt.Printf("failed (exit=%d): %s", res.ExitCode, res.Stderr)
		return
	}
	fmt.Print(res.Stdout)
}
```

**5. C (`boxlite_simple_*` synchronous API):**
```c
#include <stdio.h>
#include "boxlite.h"

int main(void) {
    CBoxliteSimple *box = NULL;
    CBoxliteError error = {0};
    if (boxlite_simple_new("python:slim", 0, 0, &box, &error) != Ok) {
        fprintf(stderr, "create failed (%d): %s\n", error.code, error.message ? error.message : "");
        boxlite_error_free(&error);
        return 1;
    }
    const char *args[] = {"-c", "print('Hello from BoxLite!')"};
    CBoxliteExecResult *result = NULL;
    if (boxlite_simple_run(box, "python", args, 2, &result, &error) == Ok) {
        printf("exit=%d stdout=%s", result->exit_code, result->stdout_text ? result->stdout_text : "");
        boxlite_result_free(result);
    } else {
        boxlite_error_free(&error);
    }
    boxlite_simple_free(box);
    return 0;
}
```

### Fundamental Runtime Semantics (Every SDK)
- **PID 1 Main Command**: Every box runs one main command (`ENTRYPOINT + CMD` or your override `entrypoint` + `cmd`). When PID 1 exits, **the box stops** (there is no restart policy). Use a sleeping/server PID 1 when doing multiple `exec()` calls, or make a one-shot task your PID 1 when capturing its init `exit_code`.
- **Ownership Scope**: Python `async with` and Node `await using` destroy the box on scope exit (`auto_remove=True`). Never return a handle out of the `async with` block! In Rust, Go, and C, always tear down explicitly in error/defer paths.
- **Database Schema Lock (`~/.boxlite/db/boxlite.db`)**: All local SDKs share one SQLite DB. Mixing an older SDK against a schema upgraded by a newer SDK **aborts the process (`abort()`)**, which `try/catch` CANNOT catch! Isolate older versions with `BOXLITE_HOME=/path/to/dir`.

---

## Domain 2: Managing Sandboxes (`manage-sandbox/*`)

### Six High-Level Box Types

| Class | Default Image | Key Features / Defaults | Special Caveats |
| - | - | - | - |
| `SimpleBox` | User-specified (`image` or `rootfs_path`) | Base command runner, `exec()`, `copy_in()`, `copy_out()` | Python `SimpleBox` lacks `.metrics()` — use `await box._box.metrics()`. Runtime fallback is `1 vCPU / 1024 MiB` |
| `CodeBox` | `"python:slim"` | `.run(code)`, `.install_package(pkg)`, `.install_packages(*pkgs)` | Python `run()` returns stdout only (hides stderr/tracebacks) & ignores `timeout`; Node `run()` throws `ExecError`. Pass `disk_size_gb=4` for `pandas`/`git` |
| `InteractiveBox` | User-specified | Persistent shell across `exec()`, interactive PTY forwarding via `wait()` | `tty`: `None` (auto-detect), `True`, `False`. Python constructor `env` MUST be `list[tuple[str, str]]` |
| `ComputerBox` | `lscr.io/linuxserver/webtop:ubuntu-xfce` | `1024x768` desktop + browser GUI (`localhost:3000`), `wait_until_ready()`, `screenshot()`, `mouse_move()`, `left_click()`, `double_click()`, `type()`, `key()`, `scroll()`, `cursor_position()`, `get_screen_size()` | Heavy image; use generous `wait_until_ready(timeout=180)` on first pull. Defaults: `2 vCPU / 2048 MiB`. Python kwargs `cpu`/`memory` vs Node `cpus`/`memoryMib` |
| `BrowserBox` | Playwright image | Isolated Chromium, Firefox, or WebKit | Must pin `playwright==1.58.0` / `playwright-core>=1.58.0` (`428 Precondition Required` otherwise). Default port `3000`. `endpoint()` rejects WebKit |
| `SkillBox` | Claude Code image | Preconfigured coding agent + `install_skill()` + `.call(prompt)` | Built for autonomous skill execution |

### Box Lifecycle, States & Native Runtime Methods

| State (`BoxStatus`) | Meaning | Notes |
| - | - | - |
| `Configured` | Metadata & rootfs reserved, microVM not yet running | Calling `start()` or `SimpleBox.exec()` boots it |
| `Running` | `boxlite-shim` + `libkrun` active, `boxlite-guest` responding | Counts toward Cloud concurrency and active compute billing |
| `Stopped` | VM shut down cleanly or PID 1 exited | Installed packages and files on rootfs survive! Re-starting skips image pull (~1–2s). On Cloud, stopped disks still bill `$0.00018/GiB-hr`! |
| `Paused` | Suspended VM state | Supported status variant (Note: Go SDK may expose as raw string if constant is absent) |
| `Failed` | Initialization or PID 1 fatal error | Inspect `error_reason` / `exit_code` (both `None` while healthy) |

**Key Native Runtime Methods (`runtime = Boxlite.default()` / `Boxlite.rest(...)`):**
- `await runtime.create(BoxOptions(...), name=...)` — note `name` is an argument to `create`, **NOT** a field of `BoxOptions`.
- `await runtime.get_or_create(options, name)` — idempotently find existing box by name or create it.
- `await runtime.get(id_or_name)` / `await runtime.get_info(id_or_name)` / `await runtime.list_info()` / `await runtime.exists(id_or_name)`.
- `await runtime.remove(id_or_name, force=False)` — removal is on the **runtime**, never `box.remove()`.
- `await runtime.shutdown(timeout=None)` — shuts down all boxes owned by this runtime instance.

### Environment, Compute Resources & Startup
- **Constructor `env` vs `exec` `env`**:
  - Python `BoxOptions(env=[("FOO", "bar")])`, `SimpleBox(env=[("FOO", "bar")])`, `InteractiveBox(env=[("FOO", "bar")])` take **`list[tuple[str, str]]`**. Passing a `dict` raises `TypeError: ... cannot be cast as 'Sequence'`.
  - Python `SimpleBox.exec(cmd, *args, env={"FOO": "bar"})` takes **`dict[str, str]`**.
- **`working_dir`, `user`, `entrypoint`, `cmd`**:
  - `user="1000:1000"` drops privileges inside the guest (process boundary, best paired with network/security policies).
  - Setting `entrypoint` + `cmd` overrides OCI image defaults; `rootfs_path` overrides `image` for offline OCI layouts.
- **CPU, Memory & Disk**:
  - `cpus` (`None` -> `1` vCPU fallback; CLI clamps > `255` with warning).
  - `memory_mib` (`None` -> `1024` MiB fallback; Node's exported `DEFAULT_CPUS`/`DEFAULT_MEMORY_MIB` are NOT automatically used).
  - `disk_size_gb` (sparse copy-on-write qcow2/ext4 overlay; values smaller than the base image are ignored; set `>= 4` for `pandas`/`git`).

### Volumes & File Transfers (`copy_in` / `copy_out`)
- **Bind Mounts (Local Runtime)**:
  - Python: `volumes=[("/host/dir", "/guest/dir", True)]` (`True` = read-only, `False`/2-tuple = read-write).
  - Node.js: `volumes: [{ hostPath: "/host/dir", guestPath: "/guest/dir", readOnly: true }]` (or tuple `[nameOrPath, guestPath]` in Cloud scripts).
  - Go: `boxlite.WithVolume(host, guest)` vs `boxlite.WithVolumeReadOnly(host, guest)`.
  - C: `boxlite_options_add_bind_mount(opts, host, guest, 1)` (`1` = RO, `0` = RW).
  - CLI: `-v /host:/guest:ro` or `-v /host:/guest` or anonymous `-v /abs/guest[:ro]`.
  - **Trap**: Passing `"ro"` string to Python/Node/C raises a type error!
- **Copy Without Mounts**: `await box.copy_in(host_path, guest_path)` and `await box.copy_out(guest_path, host_path)`. Always copy into persistent paths like `/data` or `/work` — **NOT `/tmp`** (mounted as `tmpfs`).

### Network Access & Outbound Allowlists (`NetworkSpec`)
- **Port Forwarding**: `ports=[(host_port, guest_port)]` (Python), `[{ hostPort, guestPort, protocol: "tcp" }]` (Node), `-p [host:]guest[/tcp|udp]` (CLI). Servers inside the box **MUST bind `0.0.0.0`**, never `127.0.0.1`.
- **NetworkSpec (since `0.10.5`)**:
  ```python
  from boxlite import BoxOptions, InboundNetworkSpec, NetworkSpec, OutboundNetworkSpec

  opts = BoxOptions(
      image="alpine:latest",
      network=NetworkSpec(
          inbound=InboundNetworkSpec(mode="disabled"),  # "enabled" required for Cloud tunnels; allow_net unsupported on inbound
          outbound=OutboundNetworkSpec(mode="enabled", allow_net=["pypi.org", "github.com"]),
      ),
  )
  ```
- **DNS Sinkhole Rule**: Setting `outbound=OutboundNetworkSpec(mode="disabled")` removes the network interface completely. Setting `allow_net=[...]` sinkholes unlisted domains to **`0.0.0.0`** — `nslookup blocked.example` still exits `0` while returning `0.0.0.0`! Always check resolved IP, not exit code.
- **0.10.5 Trap**: Legacy flat `NetworkSpec(mode="enabled")` configures **outbound only** — Cloud boxes default to `inbound=disabled` (private).

### Snapshots, Clones & Archives
- **Snapshots**: Point-in-time disk capture and restore via `box.snapshots()`.
- **Clones**: `clone_box` / `clone_boxes` create independent copy-on-write boxes from a stopped/checkpointed box.
- **Export / Import**: `box.export(path)` packs a box into a portable `.boxlite` archive; `runtime.import_box(path, name)` restores it on another host.

### Secrets Injection & OS-Level Hardening
- **Security Presets (Python)**: Passed **only** under `advanced=AdvancedBoxOptions(...)`:
  ```python
  from boxlite import AdvancedBoxOptions, BoxOptions, SecurityOptions
  opts = BoxOptions(
      image="alpine:latest",
      advanced=AdvancedBoxOptions(security=SecurityOptions.maximum()),
  )
  ```
  Available presets in Python: `development()`, `standard()`, `maximum()`. (`minimum()` does not exist!)
  In Rust: `SecurityOptions::enabled()`, `disabled()`, `from_preset()`, `builder()` (default `ResourceLimits`: 1024 open files, 1 GiB max file size, 100 procs).
- **Proxy Secret Injection (`Secret`)**:
  ```python
  from boxlite import BoxOptions, Secret
  opts = BoxOptions(
      image="python:alpine",
      secrets=[Secret(name="openai", value=real_key, hosts=["api.openai.com"], headers={"Authorization": "Bearer {value}"})],
  )
  ```
  Guest code sends `<BOXLITE_SECRET:openai>` inside an **already-present** header (`Authorization`, `X-Api-Key`, etc.). Guest sees `BOXLITE_SECRET_<UPPERCASE>` in env; the real key never enters the microVM filesystem, env, or logs.

---

## Domain 3: Agent Tools (`agent-tools/*`)

### Tool Capability Reference

| Tool / Wrapper | Primary API | Behavior & Critical Pitfalls |
| - | - | - |
| **Python Code Execution** | `CodeBox(disk_size_gb=...)` (`python:slim`) | `await cb.install_package("pkg")` / `install_packages(...)`. Python `await cb.run(code)` returns **stdout string only**, ignores `timeout`, and returns `""` on uncaught tracebacks — use `await cb.exec("python3", "-c", code)` for `stderr` + `exit_code`. Node `cb.run()` throws `ExecError`. |
| **Any Command / Language** | `SimpleBox.exec(cmd, *args, env=dict, user=..., timeout=..., cwd=...)` | Python `timeout` triggers SIGTERM -> `ExecResult(exit_code=-15, error_message=None)`. Node signature: `exec(cmd, args, env?, { cwd?, user?, timeoutSecs? })`. Native streaming via `box._box.exec(cmd, args, timeout_secs=...)`. |
| **Pseudo-Terminal (PTY)** | `InteractiveBox(image, tty=None\|True\|False, env=[(...)])` | Auto-forwards host TTY on `await box.wait()`. Fails if `tty=True` without a TTY. Rust/Go/C use low-level exec TTY flag (`cmd.tty = 1`, `.tty(true)`, `WithTty(true)`). |
| **Desktop / Computer Use** | `ComputerBox(cpu=2, memory=2048)` | Fixed `1024x768` XFCE desktop; browser view at `http://localhost:3000`. Call `await box.wait_until_ready(timeout=60..180)`. `await box.screenshot()` returns `{ "data": <base64_png>, "width": 1024, "height": 768, "format": "png" }`. Methods: `mouse_move`, `left_click`, `right_click`, `double_click`, `triple_click`, `middle_click`, `drag`, `scroll`, `type`, `key`, `cursor_position`, `get_screen_size`. |
| **Browser Automation** | `BrowserBox(BrowserBoxOptions(browser=..., port=...))` | Client Playwright **MUST match `1.58.0`** (`playwright==1.58.0` / `playwright-core>=1.58.0`) or server returns `428 Precondition Required`. `playwright_endpoint()` (WS, all browsers via `connect()`) vs `endpoint()` (CDP/BiDi via `connect_over_cdp()`, **WebKit unsupported**). Pick free port (`0`-bound socket) instead of hardcoded `3000` for concurrency! |
| **LLM Agent Tool Loop** | Single JSON Schema `{ "argv": string[] }` | Wrap `SimpleBox.exec(argv[0], *argv[1:])`, catch missing binary `RuntimeError` -> return `{exit_code: -1, stdout: "", stderr: str(e)}` so the model sees errors cleanly without crashing the loop. |
| **MCP Tool Server** | `FastMCP` (`pip install boxlite mcp`) | BoxLite does NOT bundle `boxlite.mcp`. Wrap `SimpleBox` in `@mcp.tool()`, catch both `BoxliteError` and `RuntimeError`, enforce auth/allowlists in your host MCP server. |
| **GitHub Operations** | `Secret` + `git -c "http.extraHeader=..."` | **Never** use `https://user:<BOXLITE_SECRET:...>@github.com` (fails). Use `git -c "http.extraHeader=Authorization: Bearer <BOXLITE_SECRET:github_token>" clone ...`. |

---

## Domain 4 & 5: Agent in a Box & Human Tools

### Coding Agents Inside Sandboxes (Local & Cloud)

| Agent | CLI / Package / Image | Auth Secret / Provider Config | Notes & Capabilities |
| - | - | - | - |
| **Claude Code** | `@anthropic-ai/claude-code` or native installer (`claude`) | `Secret` for `api.anthropic.com` (`x-api-key` or `Authorization: Bearer`) + `ANTHROPIC_API_KEY=<BOXLITE_SECRET:anthropic>` | Works with headless `-p` prompts locally & on Cloud; supports OAuth, MCP servers, and `SkillBox` |
| **Codex** | `@openai/codex` | `Secret` for `api.openai.com` or custom Responses-compatible `OPENAI_BASE_URL` | Isolated repo edits/tests without host blast radius |
| **Pi** | `@mariozechner/pi-coding-agent` | Provider API key via `Secret` placeholder | Lightweight tool-using coding agent |
| **OpenCode** | `opencode-ai` | Provider config passed dynamically via env/CLI | Avoids baking provider config/keys into image |
| **Hermes** | Official Hermes image / `sandbaseai-hermes` on Cloud | Model key via `Secret` | Supports one-shot CLI runs and HTTP Gateway API behind forwarded port (local) or inbound tunnel / wake-on-access preview URL (Cloud) |

### Human-in-the-Loop Access (`human-tools/*`)
- **Desktop in Browser (`desktop-access.md`)**: Run `ComputerBox`, wait for readiness, and open forwarded port `3000` (noVNC) in any browser — no VNC client needed. Works well alongside agent actions for live supervision or human takeover on captchas/2FA.
- **Chrome DevTools Inspection (`browser-access.md`)**: Connect host Chrome (`chrome://inspect` or DevTools WS) directly to `BrowserBox` forwarded debugging port to inspect DOM, console, and network requests live while an agent automates the browser.

---

## Domain 6: Production Guides (`guides/*`)

- **Layered Error Handling (`error-handling.md`)**:
  1. **Command exited non-zero**: Normal return value (`ExecResult.exit_code != 0`); inspect `stderr` & `exit_code`.
  2. **SDK wrapper errors**: `BoxliteError` -> `ExecError(command, exit_code, stderr)`, `TimeoutError` (**distinct from `builtins.TimeoutError`!**), `ParseError`.
  3. **Core / Environment failures**: Missing KVM, failed image pull, or binary spawn failure raise `RuntimeError` in Python and bare `Error` in Node (Go `*boxlite.Error` code `ErrInternal=1`; C `BoxliteErrorCode` `Ok=0..SessionReaped=21`; Rust 21 variants in `BoxliteError`).
  4. **Uncatchable Abort**: `Schema version mismatch` on shared `~/.boxlite/db/boxlite.db` aborts the process.
- **At-Scale Patterns (`at-scale.md`)**:
  - Limit concurrent boots with `asyncio.Semaphore`.
  - Use deterministic names + `get_or_create` for multi-worker affinity; always set explicit `cpus`, `memory_mib`, `disk_size_gb`, `auto_stop`, `auto_delete`.
  - Clean up leaked sandboxes via background reaper loops inspecting `await runtime.list_info()`.
- **Docker & Kubernetes Deployment (`deployment.md`)**:
  - Containerized BoxLite services still need KVM access (`--device /dev/kvm` in Docker; KVM device plugin or privileged node config in K8s). If hardware virtualization is unavailable in your cluster, run your app container KVM-free and point SDKs at `Boxlite.rest(...)` (BoxLite Cloud or remote `boxlite serve`).
- **Remote REST Endpoint (`agent-service-endpoint.md`)**:
  - Launch local server: `boxlite serve` (default `127.0.0.1:8100` since `0.10.6`; `--api-key` required when binding non-loopback). Every route except `GET /v1/config` requires `Authorization: Bearer <KEY>` when `--api-key` is active.
  - Client config: `BoxliteRestOptions.from_env()` reads `BOXLITE_REST_URL`, `BOXLITE_API_KEY`, and optional `BOXLITE_REST_PATH_PREFIX` (`/v1/{path_prefix}/boxes/...`). **Leave `path_prefix` unset for Cloud and `boxlite serve`!**
- **Image Registry Configuration (`image-registry-configuration.md`)**:
  - Precedence (low -> high): Default `docker.io` -> `--config registries.json` (`image_registries`: `{ host, search, transport: "http"|"https", skip_verify, auth: { type: "basic"|"bearer", ... } }`) -> CLI `--registry` / SDK `Options(image_registries=[...])`. Unqualified images try `search: true` registries in order; qualified images bypass search.

---

## Domain 7: Architecture & Contributor Development (`architecture/*`, `development/*`)

- **Runtime Execution Path**: Your process embeds `boxlite` -> spawns one **`boxlite-shim`** child process per running Box -> hosts **`libkrun`** microVM -> mounts digest-deduplicated OCI rootfs (`overlayfs`) + `virtio-fs` volumes + user-mode **`gvproxy`** network (`192.168.127.2`) -> communicates with guest **`boxlite-guest`** init/agent over **vsock gRPC**.
- **On-Disk Layout (`BOXLITE_HOME`, default `~/.boxlite`)**: `db/boxlite.db` (SQLite metadata/state), `images/` (content-addressed OCI blob/layer cache), `boxes/<box_id>/` (per-box writable rootfs overlay, sockets, logs).
- **Defense-in-Depth Isolation**:
  1. Hardware VM boundary (KVM / Hypervisor.framework — separate kernel)
  2. Host confinement (`bubblewrap` / `seccomp` / cgroups on Linux; deny-by-default Seatbelt `sandbox-exec` on macOS ARM64)
  3. User-mode networking (`gvproxy` DNS interception / `allow_net` sinkhole to `0.0.0.0`, no host root bridge)
  4. Guest privilege drop (`user=`) & outbound secret-injecting proxy
- **Contributing & Source Builds**:
  - Needs `git submodule update --init --recursive` (`src/deps/`: libkrun, libkrunfw, e2fsprogs, bubblewrap), `protoc >= 3.12`, Rust `1.88+`, `make setup:build`.
  - Follow `cargo fmt` + `cargo clippy` (`development/rust-style.md`), run `e2e-local.md` tests, and use Unified Logging to inspect `sandbox-exec` Seatbelt denials on Apple Silicon (`development/macos-sandbox-debugging.md`).

---

## Domain 8: SDKs & CLI Reference Highlights (`reference/*`)

### Cross-SDK Semantic Differences Table

| Feature | Python | Node.js | Rust | Go | C | CLI |
| - | - | - | - | - | - | - |
| **Volume Read-Only** | `bool` `(h, g, True)` | `{ readOnly: true }` | `bool` field | `WithVolumeReadOnly(h, g)` | `int` (`1`/`0`) | `-v h:g:ro` string |
| **Constructor `env`** | `list[tuple[str, str]]` | `Array<[string, string]>` | `Vec<(String, String)>` | `WithEnv(k, v)` per pair | Options / JSON | `-e KEY=VAL` |
| **Non-zero `exec` exit** | Returns `ExecResult` (`CodeBox.run()` swallows stderr) | Returns `ExecResult` (`CodeBox.run()` throws `ExecError`) | Returns `ExecResult` (no stdout/stderr on struct) | Returns `res` + `err == nil` (`Cmd.Run` returns `nil`!) | Returns `Ok` + callback `exit_code` | Exits `1..127` / `128+N` |
| **Spawn fail / missing bin** | `RuntimeError` | Bare `Error` | `BoxliteError::Execution` / `Internal` | `(nil, *boxlite.Error)` (`ErrInternal=1`) | Non-`Ok` code | Exits `1` |
| **Box state field** | `info.state.status` | `info.state.status` | `info.status` (`BoxStatus`) | `info.State` (string) | `CBoxInfo` | `inspect` / `list` |
| **`metrics()`** | Native `Box.metrics()` (NOT `SimpleBox`) | `simpleBox.metrics()` (`memoryBytes`) | `litebox.metrics()` (methods) | `box.Metrics(ctx)` (`RunningBoxes`) | `boxlite_*_metrics` (drain) | `boxlite stats` |

### C Native Callback & Post-and-Drain Rule
- `boxlite_simple_*` (`boxlite_simple_new`, `boxlite_simple_run`, `boxlite_simple_free`) is synchronous and cannot configure volumes/network/security.
- Native C async API (`boxlite_create_box`, `boxlite_start_box`, `boxlite_stop_box`, `boxlite_execution_wait`, etc.) **NEVER** invokes callbacks unless the caller runs `boxlite_runtime_drain(runtime, timeout_ms, &err)` in a loop until completion!
- `boxlite_box_exec(handle, &cmd, &out_exec, &err)` returns `CExecutionHandle*` synchronously (there is NO `boxlite_execute`); attach stdout/stderr callbacks before calling `boxlite_execution_wait`. Free all C strings/structs/handles with their `NULL`-safe `boxlite_*_free` functions. `CBoxliteRuntime` is thread-safe; box/exec handles are not.

### CLI Command Surface (`boxlite`)
- **Global flags**: `--home`, `--config`, `--registry`, `-u/--url`, `--profile`, `--context`, `--path-prefix`, `--debug`.
- **Lifecycle/Exec**: `run`, `create`, `start`, `stop`, `restart`, `rm`, `exec`, `cp`, `list`/`ls` (table), `inspect` (json), `info` (yaml), `stats` (table), `pull`, `images` (table — local only!), `rmi`, `volume`, `network`, `domain`, `ssh`, `serve`, `auth`, `context`, `completion <bash|zsh|fish>`.
- **Exit codes**: `0` success; `1` anyhow/runtime error (multi-target ops aggregate failures and exit `1`); `2` clap usage error; `1..127` guest exit; `128+N` killed by signal `N` (`137` SIGKILL, `143` SIGTERM).

---

## Domain 9: BoxLite Cloud (`cloud/*`)

### Cloud Endpoints, Keys & Pricing
- **API URL**: `https://api.boxlite.ai` (`BOXLITE_REST_URL`). Console is `https://app.boxlite.ai` (HTML dashboard — pointing SDK there yields `200 OK` HTML!).
- **API Keys**: `blk_live_...` (`BOXLITE_API_KEY`). Sent as `Authorization: Bearer <KEY>`. New keys carry `Full` permissions (legacy `Boxes` keys receive `403` on image endpoints). **Leave `path_prefix` / `BOXLITE_REST_PATH_PREFIX` unset on Cloud!**
- **Rates & Formula (No minimum billable duration; billed by exact transition timestamps)**:
  ```text
  hourly = vCPU * $0.0504 + memory_GiB * $0.0144 + disk_GiB * $0.00018
  ```
  - **Small** (`1 vCPU / 1 GiB / 10 GiB`): `$0.0666/hr` (`$47.95`/30d running, `$1.30`/30d stopped disk).
  - **Medium** (`2 vCPU / 4 GiB / 20 GiB`): `$0.1620/hr` (`$116.64`/30d running, `$2.59`/30d stopped disk).
  - **Large** (`4 vCPU / 8 GiB / 50 GiB`): `$0.3258/hr` (`$234.58`/30d running, `$6.48`/30d stopped disk).
  - **Organization Ceiling**: **`4 vCPU / 32 GiB / 120 GiB`** (`$0.6840/hr`).
  - **Unmetered (Free)**: Network traffic, API calls, managed volumes, preview URLs, boot time, unstarted boxes, built-in images (`base`, `python`, `node`, `sandbaseai-hermes`).
- **Plans vs Prepaid Wallet**:
  - **Starter**: `$19/mo` (`$30` quota, `20` concurrent boxes) — cheaper past `$20/mo`.
  - **Pro**: `$149/mo` (`$250` quota, `100` concurrent boxes) — cheaper past `$161/mo`.
  - **Max**: `$499/mo` (`$900` quota, `1000` concurrent boxes) — cheaper past `$601/mo`.
  - **Wallet Auto-Reload**: Attach card (earns `$100` credits) -> set threshold & target (defaults `$20` -> `$100`).
- **Cost Controls (`auto_stop` / `auto_delete`)**:
  - `auto_stop` defaults to `900` seconds (15m idle -> compute clock stops immediately when stop requested). Idle means **no SDK, terminal, or preview traffic** — running guest background jobs do NOT reset the timer!
  - `auto_delete` defaults to `0` (disabled -> stopped root disk bills `$0.00018/GiB-hr` forever!). When both are non-zero, **`auto_delete` MUST be strictly greater than `auto_stop`**. CLI `boxlite create --auto-delete` is rejected on detached boxes; set `auto_delete` via SDK.

### Cloud Storage, Images, Networking, Secrets & SSH
- **Managed Volumes**: Unmetered, outlive boxes. Create via `await rt.volumes.create("name")` / `boxlite volume create --name ...`, mount via `volumes=[("name", "/data")]` or REST `{"managed_volume": "name", "guest_path": "/data"}`. Only files inside the mount survive box removal. REST `POST /v1/boxes/{id}/exec` is async — poll `GET /v1/boxes/{id}/executions/{exec_id}` until `state == "completed"` before deleting the box!
- **Custom Image Catalog & Aliases**: `20`-image org limit (built-ins excluded). Recorded ~12s after first box **boot** (`rt.images.list()`, `usage()`, `get()`). Aliases (`rt.images.create_alias(name, alias, digest)`) pin movable aliases like `stable` to immutable `sha256:...` builds; running boxes keep their booted digest until recreated.
- **Tunnels (Strictly One-Shot)**:
  - Box MUST have `inbound=InboundNetworkSpec(mode="enabled")` (default since `0.10.5` is private `disabled`; flat `NetworkSpec(mode="enabled")` sets outbound only!).
  - Guest server MUST bind `0.0.0.0`.
  - `tunnel = await box.network.tunnel(port)`: `tunnel.uri()` returns URL without spending the tunnel; `connect()` and `forward(SocketAddress)` **consume** the tunnel (2nd call raises `tunnel connection has already been consumed`). `SocketAddress.tcp` requires numeric IP (no `"localhost"`); `SocketAddress.unix` requires absolute path. Frame raw TCP protocols explicitly (half-close `shutdown_write()` is not guaranteed end-to-end).
- **Platform HTTP Routes (`/api/box/{boxIdOrName}/...`)**:
  - Toggle public: `POST /api/box/{boxIdOrName}/public/{true|false}`.
  - Preview URL (requires active tunnel or `404 tunnel not found`): `GET /api/box/{boxIdOrName}/ports/{port}/preview-url` (authenticate private boxes via `Authorization: Bearer <tok>`, `X-BoxLite-Preview-Token: <tok>`, or `?BOXLITE_BOX_AUTH_KEY=<tok>`).
  - Signed Expiring URL (default `60s`, HTTP-only): `GET /api/box/{boxIdOrName}/ports/{port}/signed-preview-url?expiresInSeconds=900` and `POST .../expire`.
  - Wake on Access: First preview hit on a stopped box starts it and returns `503` (`Retry-After: 3`); ONLY PID 1 main command auto-restarts (`502` if service ran via `exec`).
- **Fixed Public Domains (`*.boxliteapp.com`)**: Reserve in console -> `boxlite network inbound "$BOX" enabled` -> `boxlite network tunnel "$BOX" "$PORT"` -> `boxlite domain bind "$DOMAIN" --type box --box "$BOX" --port "$PORT"`. Pass header `X-BoxLite-Skip-Preview-Warning: true` for scripted curl/clients.
- **Cloud Secrets Proxy**: Same `Secret` header replacement via BoxLite's outbound HTTPS proxy using `<BOXLITE_SECRET:name>` placeholders + system CA `/etc/ssl/certs/ca-certificates.crt`.
- **Cloud SSH**: `boxlite --context app start "$BOX"` -> `network inbound "$BOX" enabled` -> `ssh "$BOX"` (generates keys & prints exact `ProxyCommand` ssh command); revoke via `network tunnel --revoke "$BOX" 22` + `ssh --disable "$BOX"`.

---

## Domain 10: Complete 111-Page Documentation Sitemap

Every page in [llms.txt](./docs/llms.txt) and `sitemap.xml`, linked to both its offline mirror and live `.md` source:

| # | Category | Local Mirror | Live Markdown URL | Domain Skill |
| - | - | - | - | - |
| 1 | Getting Started | [index.md](./docs/index.md) | [docs.boxlite.ai/index.md](https://docs.boxlite.ai/index.md) | [getting-started](./skills/boxlite-getting-started/SKILL.md) |
| 2 | Getting Started | [getting-started/index.md](./docs/getting-started/index.md) | [docs.boxlite.ai/getting-started/index.md](https://docs.boxlite.ai/getting-started/index.md) | [getting-started](./skills/boxlite-getting-started/SKILL.md) |
| 3 | Getting Started | [getting-started/quickstart.md](./docs/getting-started/quickstart.md) | [docs.boxlite.ai/getting-started/quickstart.md](https://docs.boxlite.ai/getting-started/quickstart.md) | [getting-started](./skills/boxlite-getting-started/SKILL.md) |
| 4 | Getting Started | [getting-started/installation.md](./docs/getting-started/installation.md) | [docs.boxlite.ai/getting-started/installation.md](https://docs.boxlite.ai/getting-started/installation.md) | [getting-started](./skills/boxlite-getting-started/SKILL.md) |
| 5 | Manage Sandboxes | [manage-sandbox/index.md](./docs/manage-sandbox/index.md) | [docs.boxlite.ai/manage-sandbox/index.md](https://docs.boxlite.ai/manage-sandbox/index.md) | [manage-sandboxes](./skills/boxlite-manage-sandboxes/SKILL.md) |
| 6 | Manage Sandboxes | [manage-sandbox/sandbox-types.md](./docs/manage-sandbox/sandbox-types.md) | [docs.boxlite.ai/manage-sandbox/sandbox-types.md](https://docs.boxlite.ai/manage-sandbox/sandbox-types.md) | [manage-sandboxes](./skills/boxlite-manage-sandboxes/SKILL.md) |
| 7 | Manage Sandboxes | [manage-sandbox/lifecycle.md](./docs/manage-sandbox/lifecycle.md) | [docs.boxlite.ai/manage-sandbox/lifecycle.md](https://docs.boxlite.ai/manage-sandbox/lifecycle.md) | [manage-sandboxes](./skills/boxlite-manage-sandboxes/SKILL.md) |
| 8 | Manage Sandboxes | [manage-sandbox/environment.md](./docs/manage-sandbox/environment.md) | [docs.boxlite.ai/manage-sandbox/environment.md](https://docs.boxlite.ai/manage-sandbox/environment.md) | [manage-sandboxes](./skills/boxlite-manage-sandboxes/SKILL.md) |
| 9 | Manage Sandboxes | [manage-sandbox/compute-resources.md](./docs/manage-sandbox/compute-resources.md) | [docs.boxlite.ai/manage-sandbox/compute-resources.md](https://docs.boxlite.ai/manage-sandbox/compute-resources.md) | [manage-sandboxes](./skills/boxlite-manage-sandboxes/SKILL.md) |
| 10 | Manage Sandboxes | [manage-sandbox/volumes.md](./docs/manage-sandbox/volumes.md) | [docs.boxlite.ai/manage-sandbox/volumes.md](https://docs.boxlite.ai/manage-sandbox/volumes.md) | [manage-sandboxes](./skills/boxlite-manage-sandboxes/SKILL.md) |
| 11 | Manage Sandboxes | [manage-sandbox/network-access.md](./docs/manage-sandbox/network-access.md) | [docs.boxlite.ai/manage-sandbox/network-access.md](https://docs.boxlite.ai/manage-sandbox/network-access.md) | [manage-sandboxes](./skills/boxlite-manage-sandboxes/SKILL.md) |
| 12 | Manage Sandboxes | [manage-sandbox/snapshots.md](./docs/manage-sandbox/snapshots.md) | [docs.boxlite.ai/manage-sandbox/snapshots.md](https://docs.boxlite.ai/manage-sandbox/snapshots.md) | [manage-sandboxes](./skills/boxlite-manage-sandboxes/SKILL.md) |
| 13 | Manage Sandboxes | [manage-sandbox/secrets-and-security.md](./docs/manage-sandbox/secrets-and-security.md) | [docs.boxlite.ai/manage-sandbox/secrets-and-security.md](https://docs.boxlite.ai/manage-sandbox/secrets-and-security.md) | [manage-sandboxes](./skills/boxlite-manage-sandboxes/SKILL.md) |
| 14 | Agent Tools | [agent-tools/index.md](./docs/agent-tools/index.md) | [docs.boxlite.ai/agent-tools/index.md](https://docs.boxlite.ai/agent-tools/index.md) | [agent-tools](./skills/boxlite-agent-tools/SKILL.md) |
| 15 | Agent Tools | [agent-tools/code-execution-python.md](./docs/agent-tools/code-execution-python.md) | [docs.boxlite.ai/agent-tools/code-execution-python.md](https://docs.boxlite.ai/agent-tools/code-execution-python.md) | [agent-tools](./skills/boxlite-agent-tools/SKILL.md) |
| 16 | Agent Tools | [agent-tools/code-execution-any-language.md](./docs/agent-tools/code-execution-any-language.md) | [docs.boxlite.ai/agent-tools/code-execution-any-language.md](https://docs.boxlite.ai/agent-tools/code-execution-any-language.md) | [agent-tools](./skills/boxlite-agent-tools/SKILL.md) |
| 17 | Agent Tools | [agent-tools/pseudo-terminal.md](./docs/agent-tools/pseudo-terminal.md) | [docs.boxlite.ai/agent-tools/pseudo-terminal.md](https://docs.boxlite.ai/agent-tools/pseudo-terminal.md) | [agent-tools](./skills/boxlite-agent-tools/SKILL.md) |
| 18 | Agent Tools | [agent-tools/computer-use.md](./docs/agent-tools/computer-use.md) | [docs.boxlite.ai/agent-tools/computer-use.md](https://docs.boxlite.ai/agent-tools/computer-use.md) | [agent-tools](./skills/boxlite-agent-tools/SKILL.md) |
| 19 | Agent Tools | [agent-tools/browser-automation.md](./docs/agent-tools/browser-automation.md) | [docs.boxlite.ai/agent-tools/browser-automation.md](https://docs.boxlite.ai/agent-tools/browser-automation.md) | [agent-tools](./skills/boxlite-agent-tools/SKILL.md) |
| 20 | Agent Tools | [agent-tools/drive-from-agent-loop.md](./docs/agent-tools/drive-from-agent-loop.md) | [docs.boxlite.ai/agent-tools/drive-from-agent-loop.md](https://docs.boxlite.ai/agent-tools/drive-from-agent-loop.md) | [agent-tools](./skills/boxlite-agent-tools/SKILL.md) |
| 21 | Agent Tools | [agent-tools/mcp-server.md](./docs/agent-tools/mcp-server.md) | [docs.boxlite.ai/agent-tools/mcp-server.md](https://docs.boxlite.ai/agent-tools/mcp-server.md) | [agent-tools](./skills/boxlite-agent-tools/SKILL.md) |
| 22 | Agent Tools | [agent-tools/github-operations.md](./docs/agent-tools/github-operations.md) | [docs.boxlite.ai/agent-tools/github-operations.md](https://docs.boxlite.ai/agent-tools/github-operations.md) | [agent-tools](./skills/boxlite-agent-tools/SKILL.md) |
| 23 | Agent in a Box | [agent-in-box/index.md](./docs/agent-in-box/index.md) | [docs.boxlite.ai/agent-in-box/index.md](https://docs.boxlite.ai/agent-in-box/index.md) | [agent-in-box](./skills/boxlite-agent-in-box/SKILL.md) |
| 24 | Agent in a Box | [agent-in-box/run-claude-code.md](./docs/agent-in-box/run-claude-code.md) | [docs.boxlite.ai/agent-in-box/run-claude-code.md](https://docs.boxlite.ai/agent-in-box/run-claude-code.md) | [agent-in-box](./skills/boxlite-agent-in-box/SKILL.md) |
| 25 | Agent in a Box | [agent-in-box/run-codex.md](./docs/agent-in-box/run-codex.md) | [docs.boxlite.ai/agent-in-box/run-codex.md](https://docs.boxlite.ai/agent-in-box/run-codex.md) | [agent-in-box](./skills/boxlite-agent-in-box/SKILL.md) |
| 26 | Agent in a Box | [agent-in-box/run-pi.md](./docs/agent-in-box/run-pi.md) | [docs.boxlite.ai/agent-in-box/run-pi.md](https://docs.boxlite.ai/agent-in-box/run-pi.md) | [agent-in-box](./skills/boxlite-agent-in-box/SKILL.md) |
| 27 | Agent in a Box | [agent-in-box/run-opencode.md](./docs/agent-in-box/run-opencode.md) | [docs.boxlite.ai/agent-in-box/run-opencode.md](https://docs.boxlite.ai/agent-in-box/run-opencode.md) | [agent-in-box](./skills/boxlite-agent-in-box/SKILL.md) |
| 28 | Agent in a Box | [agent-in-box/run-hermes.md](./docs/agent-in-box/run-hermes.md) | [docs.boxlite.ai/agent-in-box/run-hermes.md](https://docs.boxlite.ai/agent-in-box/run-hermes.md) | [agent-in-box](./skills/boxlite-agent-in-box/SKILL.md) |
| 29 | Human Tools | [human-tools/index.md](./docs/human-tools/index.md) | [docs.boxlite.ai/human-tools/index.md](https://docs.boxlite.ai/human-tools/index.md) | [human-tools](./skills/boxlite-human-tools/SKILL.md) |
| 30 | Human Tools | [human-tools/desktop-access.md](./docs/human-tools/desktop-access.md) | [docs.boxlite.ai/human-tools/desktop-access.md](https://docs.boxlite.ai/human-tools/desktop-access.md) | [human-tools](./skills/boxlite-human-tools/SKILL.md) |
| 31 | Human Tools | [human-tools/browser-access.md](./docs/human-tools/browser-access.md) | [docs.boxlite.ai/human-tools/browser-access.md](https://docs.boxlite.ai/human-tools/browser-access.md) | [human-tools](./skills/boxlite-human-tools/SKILL.md) |
| 32 | Production Guides | [guides/index.md](./docs/guides/index.md) | [docs.boxlite.ai/guides/index.md](https://docs.boxlite.ai/guides/index.md) | [production-guides](./skills/boxlite-production-guides/SKILL.md) |
| 33 | Production Guides | [guides/error-handling.md](./docs/guides/error-handling.md) | [docs.boxlite.ai/guides/error-handling.md](https://docs.boxlite.ai/guides/error-handling.md) | [production-guides](./skills/boxlite-production-guides/SKILL.md) |
| 34 | Production Guides | [guides/at-scale.md](./docs/guides/at-scale.md) | [docs.boxlite.ai/guides/at-scale.md](https://docs.boxlite.ai/guides/at-scale.md) | [production-guides](./skills/boxlite-production-guides/SKILL.md) |
| 35 | Production Guides | [guides/deployment.md](./docs/guides/deployment.md) | [docs.boxlite.ai/guides/deployment.md](https://docs.boxlite.ai/guides/deployment.md) | [production-guides](./skills/boxlite-production-guides/SKILL.md) |
| 36 | Production Guides | [guides/agent-service-endpoint.md](./docs/guides/agent-service-endpoint.md) | [docs.boxlite.ai/guides/agent-service-endpoint.md](https://docs.boxlite.ai/guides/agent-service-endpoint.md) | [production-guides](./skills/boxlite-production-guides/SKILL.md) |
| 37 | Production Guides | [guides/image-registry-configuration.md](./docs/guides/image-registry-configuration.md) | [docs.boxlite.ai/guides/image-registry-configuration.md](https://docs.boxlite.ai/guides/image-registry-configuration.md) | [production-guides](./skills/boxlite-production-guides/SKILL.md) |
| 38 | Architecture | [architecture/index.md](./docs/architecture/index.md) | [docs.boxlite.ai/architecture/index.md](https://docs.boxlite.ai/architecture/index.md) | [architecture](./skills/boxlite-architecture/SKILL.md) |
| 39 | Architecture | [architecture/core-components.md](./docs/architecture/core-components.md) | [docs.boxlite.ai/architecture/core-components.md](https://docs.boxlite.ai/architecture/core-components.md) | [architecture](./skills/boxlite-architecture/SKILL.md) |
| 40 | Architecture | [architecture/security-and-isolation.md](./docs/architecture/security-and-isolation.md) | [docs.boxlite.ai/architecture/security-and-isolation.md](https://docs.boxlite.ai/architecture/security-and-isolation.md) | [architecture](./skills/boxlite-architecture/SKILL.md) |
| 41 | Architecture | [architecture/networking.md](./docs/architecture/networking.md) | [docs.boxlite.ai/architecture/networking.md](https://docs.boxlite.ai/architecture/networking.md) | [architecture](./skills/boxlite-architecture/SKILL.md) |
| 42 | Architecture | [architecture/storage.md](./docs/architecture/storage.md) | [docs.boxlite.ai/architecture/storage.md](https://docs.boxlite.ai/architecture/storage.md) | [architecture](./skills/boxlite-architecture/SKILL.md) |
| 43 | Architecture | [architecture/boot-latency.md](./docs/architecture/boot-latency.md) | [docs.boxlite.ai/architecture/boot-latency.md](https://docs.boxlite.ai/architecture/boot-latency.md) | [architecture](./skills/boxlite-architecture/SKILL.md) |
| 44 | SDK & CLI Ref | [reference/index.md](./docs/reference/index.md) | [docs.boxlite.ai/reference/index.md](https://docs.boxlite.ai/reference/index.md) | [sdk-cli-reference](./skills/boxlite-sdk-cli-reference/SKILL.md) |
| 45 | SDK & CLI Ref | [reference/python.md](./docs/reference/python.md) | [docs.boxlite.ai/reference/python.md](https://docs.boxlite.ai/reference/python.md) | [sdk-cli-reference](./skills/boxlite-sdk-cli-reference/SKILL.md) |
| 46 | SDK & CLI Ref | [reference/nodejs.md](./docs/reference/nodejs.md) | [docs.boxlite.ai/reference/nodejs.md](https://docs.boxlite.ai/reference/nodejs.md) | [sdk-cli-reference](./skills/boxlite-sdk-cli-reference/SKILL.md) |
| 47 | SDK & CLI Ref | [reference/rust.md](./docs/reference/rust.md) | [docs.boxlite.ai/reference/rust.md](https://docs.boxlite.ai/reference/rust.md) | [sdk-cli-reference](./skills/boxlite-sdk-cli-reference/SKILL.md) |
| 48 | SDK & CLI Ref | [reference/go.md](./docs/reference/go.md) | [docs.boxlite.ai/reference/go.md](https://docs.boxlite.ai/reference/go.md) | [sdk-cli-reference](./skills/boxlite-sdk-cli-reference/SKILL.md) |
| 49 | SDK & CLI Ref | [reference/c.md](./docs/reference/c.md) | [docs.boxlite.ai/reference/c.md](https://docs.boxlite.ai/reference/c.md) | [sdk-cli-reference](./skills/boxlite-sdk-cli-reference/SKILL.md) |
| 50 | SDK & CLI Ref | [reference/cli.md](./docs/reference/cli.md) | [docs.boxlite.ai/reference/cli.md](https://docs.boxlite.ai/reference/cli.md) | [sdk-cli-reference](./skills/boxlite-sdk-cli-reference/SKILL.md) |
| 51 | FAQ & Releases | [resources/index.md](./docs/resources/index.md) | [docs.boxlite.ai/resources/index.md](https://docs.boxlite.ai/resources/index.md) | [getting-started](./skills/boxlite-getting-started/SKILL.md) |
| 52 | FAQ & Releases | [faq.md](./docs/faq.md) | [docs.boxlite.ai/faq.md](https://docs.boxlite.ai/faq.md) | [getting-started](./skills/boxlite-getting-started/SKILL.md) |
| 53 | FAQ & Releases | [guides/changelog.md](./docs/guides/changelog.md) | [docs.boxlite.ai/guides/changelog.md](https://docs.boxlite.ai/guides/changelog.md) | [production-guides](./skills/boxlite-production-guides/SKILL.md) |
| 54 | Contributing | [development/index.md](./docs/development/index.md) | [docs.boxlite.ai/development/index.md](https://docs.boxlite.ai/development/index.md) | [architecture](./skills/boxlite-architecture/SKILL.md) |
| 55 | Contributing | [development/cli-development.md](./docs/development/cli-development.md) | [docs.boxlite.ai/development/cli-development.md](https://docs.boxlite.ai/development/cli-development.md) | [architecture](./skills/boxlite-architecture/SKILL.md) |
| 56 | Contributing | [development/e2e-local.md](./docs/development/e2e-local.md) | [docs.boxlite.ai/development/e2e-local.md](https://docs.boxlite.ai/development/e2e-local.md) | [architecture](./skills/boxlite-architecture/SKILL.md) |
| 57 | Contributing | [development/rust-style.md](./docs/development/rust-style.md) | [docs.boxlite.ai/development/rust-style.md](https://docs.boxlite.ai/development/rust-style.md) | [architecture](./skills/boxlite-architecture/SKILL.md) |
| 58 | Contributing | [development/building-from-source.md](./docs/development/building-from-source.md) | [docs.boxlite.ai/development/building-from-source.md](https://docs.boxlite.ai/development/building-from-source.md) | [architecture](./skills/boxlite-architecture/SKILL.md) |
| 59 | Contributing | [development/macos-sandbox-debugging.md](./docs/development/macos-sandbox-debugging.md) | [docs.boxlite.ai/development/macos-sandbox-debugging.md](https://docs.boxlite.ai/development/macos-sandbox-debugging.md) | [architecture](./skills/boxlite-architecture/SKILL.md) |
| 60 | Contributing | [development/concurrent-exec-deadlock.md](./docs/development/concurrent-exec-deadlock.md) | [docs.boxlite.ai/development/concurrent-exec-deadlock.md](https://docs.boxlite.ai/development/concurrent-exec-deadlock.md) | [architecture](./skills/boxlite-architecture/SKILL.md) |
| 61 | Contributing | [legal/CLA.md](./docs/legal/CLA.md) | [docs.boxlite.ai/legal/CLA.md](https://docs.boxlite.ai/legal/CLA.md) | [architecture](./skills/boxlite-architecture/SKILL.md) |
| 62 | BoxLite Cloud | [cloud/index.md](./docs/cloud/index.md) | [docs.boxlite.ai/cloud/index.md](https://docs.boxlite.ai/cloud/index.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 63 | BoxLite Cloud | [cloud/vs-opensource.md](./docs/cloud/vs-opensource.md) | [docs.boxlite.ai/cloud/vs-opensource.md](https://docs.boxlite.ai/cloud/vs-opensource.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 64 | BoxLite Cloud | [cloud/quickstart.md](./docs/cloud/quickstart.md) | [docs.boxlite.ai/cloud/quickstart.md](https://docs.boxlite.ai/cloud/quickstart.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 65 | BoxLite Cloud | [cloud/api-keys.md](./docs/cloud/api-keys.md) | [docs.boxlite.ai/cloud/api-keys.md](https://docs.boxlite.ai/cloud/api-keys.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 66 | BoxLite Cloud | [cloud/boxes.md](./docs/cloud/boxes.md) | [docs.boxlite.ai/cloud/boxes.md](https://docs.boxlite.ai/cloud/boxes.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 67 | BoxLite Cloud | [cloud/box-sizes.md](./docs/cloud/box-sizes.md) | [docs.boxlite.ai/cloud/box-sizes.md](https://docs.boxlite.ai/cloud/box-sizes.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 68 | BoxLite Cloud | [cloud/box-lifecycle.md](./docs/cloud/box-lifecycle.md) | [docs.boxlite.ai/cloud/box-lifecycle.md](https://docs.boxlite.ai/cloud/box-lifecycle.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 69 | BoxLite Cloud | [cloud/box-from-code.md](./docs/cloud/box-from-code.md) | [docs.boxlite.ai/cloud/box-from-code.md](https://docs.boxlite.ai/cloud/box-from-code.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 70 | BoxLite Cloud | [cloud/ssh.md](./docs/cloud/ssh.md) | [docs.boxlite.ai/cloud/ssh.md](https://docs.boxlite.ai/cloud/ssh.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 71 | Cloud Agents | [cloud/agent-in-box/index.md](./docs/cloud/agent-in-box/index.md) | [docs.boxlite.ai/cloud/agent-in-box/index.md](https://docs.boxlite.ai/cloud/agent-in-box/index.md) | [agent-in-box](./skills/boxlite-agent-in-box/SKILL.md) |
| 72 | Cloud Agents | [cloud/agent-in-box/claude-code.md](./docs/cloud/agent-in-box/claude-code.md) | [docs.boxlite.ai/cloud/agent-in-box/claude-code.md](https://docs.boxlite.ai/cloud/agent-in-box/claude-code.md) | [agent-in-box](./skills/boxlite-agent-in-box/SKILL.md) |
| 73 | Cloud Agents | [cloud/agent-in-box/codex.md](./docs/cloud/agent-in-box/codex.md) | [docs.boxlite.ai/cloud/agent-in-box/codex.md](https://docs.boxlite.ai/cloud/agent-in-box/codex.md) | [agent-in-box](./skills/boxlite-agent-in-box/SKILL.md) |
| 74 | Cloud Agents | [cloud/agent-in-box/pi.md](./docs/cloud/agent-in-box/pi.md) | [docs.boxlite.ai/cloud/agent-in-box/pi.md](https://docs.boxlite.ai/cloud/agent-in-box/pi.md) | [agent-in-box](./skills/boxlite-agent-in-box/SKILL.md) |
| 75 | Cloud Agents | [cloud/agent-in-box/opencode.md](./docs/cloud/agent-in-box/opencode.md) | [docs.boxlite.ai/cloud/agent-in-box/opencode.md](https://docs.boxlite.ai/cloud/agent-in-box/opencode.md) | [agent-in-box](./skills/boxlite-agent-in-box/SKILL.md) |
| 76 | Cloud Agents | [cloud/agent-in-box/hermes.md](./docs/cloud/agent-in-box/hermes.md) | [docs.boxlite.ai/cloud/agent-in-box/hermes.md](https://docs.boxlite.ai/cloud/agent-in-box/hermes.md) | [agent-in-box](./skills/boxlite-agent-in-box/SKILL.md) |
| 77 | BoxLite Cloud | [cloud/images.md](./docs/cloud/images.md) | [docs.boxlite.ai/cloud/images.md](https://docs.boxlite.ai/cloud/images.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 78 | BoxLite Cloud | [cloud/use-your-image.md](./docs/cloud/use-your-image.md) | [docs.boxlite.ai/cloud/use-your-image.md](https://docs.boxlite.ai/cloud/use-your-image.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 79 | BoxLite Cloud | [cloud/image-aliases.md](./docs/cloud/image-aliases.md) | [docs.boxlite.ai/cloud/image-aliases.md](https://docs.boxlite.ai/cloud/image-aliases.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 80 | BoxLite Cloud | [cloud/private-images.md](./docs/cloud/private-images.md) | [docs.boxlite.ai/cloud/private-images.md](https://docs.boxlite.ai/cloud/private-images.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 81 | BoxLite Cloud | [cloud/image-catalog.md](./docs/cloud/image-catalog.md) | [docs.boxlite.ai/cloud/image-catalog.md](https://docs.boxlite.ai/cloud/image-catalog.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 82 | BoxLite Cloud | [cloud/checkpoints.md](./docs/cloud/checkpoints.md) | [docs.boxlite.ai/cloud/checkpoints.md](https://docs.boxlite.ai/cloud/checkpoints.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 83 | BoxLite Cloud | [cloud/volumes.md](./docs/cloud/volumes.md) | [docs.boxlite.ai/cloud/volumes.md](https://docs.boxlite.ai/cloud/volumes.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 84 | BoxLite Cloud | [cloud/mount-a-volume.md](./docs/cloud/mount-a-volume.md) | [docs.boxlite.ai/cloud/mount-a-volume.md](https://docs.boxlite.ai/cloud/mount-a-volume.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 85 | BoxLite Cloud | [cloud/volume-operations.md](./docs/cloud/volume-operations.md) | [docs.boxlite.ai/cloud/volume-operations.md](https://docs.boxlite.ai/cloud/volume-operations.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 86 | BoxLite Cloud | [cloud/data-across-boxes.md](./docs/cloud/data-across-boxes.md) | [docs.boxlite.ai/cloud/data-across-boxes.md](https://docs.boxlite.ai/cloud/data-across-boxes.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 87 | BoxLite Cloud | [cloud/volume-reference.md](./docs/cloud/volume-reference.md) | [docs.boxlite.ai/cloud/volume-reference.md](https://docs.boxlite.ai/cloud/volume-reference.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 88 | BoxLite Cloud | [cloud/network.md](./docs/cloud/network.md) | [docs.boxlite.ai/cloud/network.md](https://docs.boxlite.ai/cloud/network.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 89 | BoxLite Cloud | [cloud/tunnels.md](./docs/cloud/tunnels.md) | [docs.boxlite.ai/cloud/tunnels.md](https://docs.boxlite.ai/cloud/tunnels.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 90 | BoxLite Cloud | [cloud/serve-http.md](./docs/cloud/serve-http.md) | [docs.boxlite.ai/cloud/serve-http.md](https://docs.boxlite.ai/cloud/serve-http.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 91 | BoxLite Cloud | [cloud/port-forwarding.md](./docs/cloud/port-forwarding.md) | [docs.boxlite.ai/cloud/port-forwarding.md](https://docs.boxlite.ai/cloud/port-forwarding.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 92 | BoxLite Cloud | [cloud/raw-streams.md](./docs/cloud/raw-streams.md) | [docs.boxlite.ai/cloud/raw-streams.md](https://docs.boxlite.ai/cloud/raw-streams.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 93 | BoxLite Cloud | [cloud/network-policy.md](./docs/cloud/network-policy.md) | [docs.boxlite.ai/cloud/network-policy.md](https://docs.boxlite.ai/cloud/network-policy.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 94 | BoxLite Cloud | [cloud/secrets.md](./docs/cloud/secrets.md) | [docs.boxlite.ai/cloud/secrets.md](https://docs.boxlite.ai/cloud/secrets.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 95 | BoxLite Cloud | [cloud/domains.md](./docs/cloud/domains.md) | [docs.boxlite.ai/cloud/domains.md](https://docs.boxlite.ai/cloud/domains.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 96 | BoxLite Cloud | [cloud/pricing.md](./docs/cloud/pricing.md) | [docs.boxlite.ai/cloud/pricing.md](https://docs.boxlite.ai/cloud/pricing.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 97 | BoxLite Cloud | [cloud/box-costs.md](./docs/cloud/box-costs.md) | [docs.boxlite.ai/cloud/box-costs.md](https://docs.boxlite.ai/cloud/box-costs.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 98 | BoxLite Cloud | [cloud/cost-controls.md](./docs/cloud/cost-controls.md) | [docs.boxlite.ai/cloud/cost-controls.md](https://docs.boxlite.ai/cloud/cost-controls.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 99 | BoxLite Cloud | [cloud/plans.md](./docs/cloud/plans.md) | [docs.boxlite.ai/cloud/plans.md](https://docs.boxlite.ai/cloud/plans.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 100 | BoxLite Cloud | [cloud/billing.md](./docs/cloud/billing.md) | [docs.boxlite.ai/cloud/billing.md](https://docs.boxlite.ai/cloud/billing.md) | [cloud](./skills/boxlite-cloud/SKILL.md) |
| 101 | Use Cases | [use-cases/index.md](./docs/use-cases/index.md) | [docs.boxlite.ai/use-cases/index.md](https://docs.boxlite.ai/use-cases/index.md) | [use-cases](./skills/boxlite-use-cases/SKILL.md) |
| 102 | Use Cases | [use-cases/code-interpreter.md](./docs/use-cases/code-interpreter.md) | [docs.boxlite.ai/use-cases/code-interpreter.md](https://docs.boxlite.ai/use-cases/code-interpreter.md) | [use-cases](./skills/boxlite-use-cases/SKILL.md) |
| 103 | Use Cases | [use-cases/data-analysis-agent.md](./docs/use-cases/data-analysis-agent.md) | [docs.boxlite.ai/use-cases/data-analysis-agent.md](https://docs.boxlite.ai/use-cases/data-analysis-agent.md) | [use-cases](./skills/boxlite-use-cases/SKILL.md) |
| 104 | Use Cases | [use-cases/sandboxed-web-app.md](./docs/use-cases/sandboxed-web-app.md) | [docs.boxlite.ai/use-cases/sandboxed-web-app.md](https://docs.boxlite.ai/use-cases/sandboxed-web-app.md) | [use-cases](./skills/boxlite-use-cases/SKILL.md) |
| 105 | Use Cases | [use-cases/mcp-tool-server.md](./docs/use-cases/mcp-tool-server.md) | [docs.boxlite.ai/use-cases/mcp-tool-server.md](https://docs.boxlite.ai/use-cases/mcp-tool-server.md) | [use-cases](./skills/boxlite-use-cases/SKILL.md) |
| 106 | Use Cases | [use-cases/sandboxed-ci.md](./docs/use-cases/sandboxed-ci.md) | [docs.boxlite.ai/use-cases/sandboxed-ci.md](https://docs.boxlite.ai/use-cases/sandboxed-ci.md) | [use-cases](./skills/boxlite-use-cases/SKILL.md) |
| 107 | Use Cases | [use-cases/computer-use-agent.md](./docs/use-cases/computer-use-agent.md) | [docs.boxlite.ai/use-cases/computer-use-agent.md](https://docs.boxlite.ai/use-cases/computer-use-agent.md) | [use-cases](./skills/boxlite-use-cases/SKILL.md) |
| 108 | Use Cases | [use-cases/web-scraping-agent.md](./docs/use-cases/web-scraping-agent.md) | [docs.boxlite.ai/use-cases/web-scraping-agent.md](https://docs.boxlite.ai/use-cases/web-scraping-agent.md) | [use-cases](./skills/boxlite-use-cases/SKILL.md) |
| 109 | Use Cases | [use-cases/custom-agent-image.md](./docs/use-cases/custom-agent-image.md) | [docs.boxlite.ai/use-cases/custom-agent-image.md](https://docs.boxlite.ai/use-cases/custom-agent-image.md) | [use-cases](./skills/boxlite-use-cases/SKILL.md) |
| 110 | Use Cases | [use-cases/interactive-dev-environment.md](./docs/use-cases/interactive-dev-environment.md) | [docs.boxlite.ai/use-cases/interactive-dev-environment.md](https://docs.boxlite.ai/use-cases/interactive-dev-environment.md) | [use-cases](./skills/boxlite-use-cases/SKILL.md) |
| 111 | Use Cases | [use-cases/untrusted-tool-execution.md](./docs/use-cases/untrusted-tool-execution.md) | [docs.boxlite.ai/use-cases/untrusted-tool-execution.md](https://docs.boxlite.ai/use-cases/untrusted-tool-execution.md) | [use-cases](./skills/boxlite-use-cases/SKILL.md) |

---

## Use Cases & Repository Examples Quick Index (`use-cases/*`)

| Goal / Scenario | Recommended Pattern | Critical Constraints |
| - | - | - |
| LLM Python code interpreter | `async with CodeBox() as box: await box.run(code)` | `run()` swallows `stderr`; debug via `exec("python3", "-c", code)`; open egress by default |
| CSV Pandas analysis + Matplotlib chart | `CodeBox(disk_size_gb=4)`, `copy_in(csv, "/data/...")`, `install_packages("pandas", "matplotlib")` | Must pass `disk_size_gb=4`; never store in `/tmp` (`tmpfs`); call `matplotlib.use("Agg")` before `pyplot` |
| Live web app preview | `SimpleBox(ports=[(host, guest)], reuse_existing=True)` | Guest server MUST bind `0.0.0.0`; write app via base64 + `nohup ... > /tmp/app.log 2>&1 &` |
| Standard MCP stdio server | `FastMCP` (`pip install boxlite mcp`) + `SimpleBox.exec` | Catch `BoxliteError` AND `RuntimeError`; auth & command allowlist in host tool handler |
| Untrusted PR CI review | `CodeBox(disk_size_gb=4)` + `DEBIAN_FRONTEND=noninteractive` + `Secret` for git headers | Default `python:slim` (`~224 MB`) runs out of space on `apt-get install git` without `disk_size_gb=4` |
| Autonomous GUI desktop agent | `ComputerBox(cpu=2, memory=2048)` + VLM JSON actions | `1024x768`; generous `wait_until_ready(timeout=180)`; re-verify cursor/screenshot after acting |
| 2-Box web scraper + parser | `BrowserBox(port=free_port())` -> copy raw HTML -> `CodeBox` parser -> LLM | Pin `playwright==1.58.0`; `endpoint()` = CDP; `playwright_endpoint()` = WebKit/Playwright |
| Custom / air-gapped agent image | `SimpleBox(image=...)` or `SimpleBox(rootfs_path=...)` | `rootfs_path` beats `image` if both given; neither raises `ValueError`; size `disk_size_gb` |
| Multi-tenant persistent shell | `InteractiveBox(tty=False, name=..., auto_remove=False)` | Split `exec("ls", "-la")`; constructor `env` is tuple list; clean up detached boxes explicitly |
| Maximum-lockdown untrusted binary | `OutboundNetworkSpec(mode="disabled")` + `user="1000:1000"` + `AdvancedBoxOptions(security=SecurityOptions.maximum())` | `security=` is NEVER top-level on `BoxOptions`; no `SecurityOptions.minimum()` |

---

## Error Codes & Troubleshooting Matrix

### Unified Error Codes (Go `*boxlite.Error`, Rust `BoxliteError`, C `BoxliteErrorCode`)

| C `BoxliteErrorCode` | Value | Rust `BoxliteError` | Go `boxlite.Err*` | Common Trigger / Recovery |
| - | - | - | - | - |
| `Ok` | `0` | — | `nil` | Success (non-zero guest exit codes STILL return `Ok` / `nil`!) |
| `Internal` | `1` | `Internal(String)` | `ErrInternal` | Internal engine/spawn failure (missing guest binary in Go/Node/Python) |
| `NotFound` | `2` | `NotFound(String)` | `ErrNotFound` | Box/volume/snapshot/image ID or name not found (`boxlite exec` on missing box) |
| `AlreadyExists` | `3` | `AlreadyExists(String)` | `ErrAlreadyExists` | Duplicate box/volume name on `create` (use `get_or_create` instead) |
| `InvalidState` | `4` | `InvalidState(String)` | `ErrInvalidState` | Calling `exec` on stopped box or `tunnel()` on private Cloud box without inbound enabled |
| `InvalidArgument` | `5` | `InvalidArgument(String)` | `ErrInvalidArgument` | Passing `inbound.allow_net`, `--auto-delete` on detached CLI box, or `--network disabled` + `--allow-net` |
| `Config` | `6` | `Config(String)` | `ErrConfig` | Invalid `BoxOptions`, `remove-on-stop` + `detach=true`, or `auto_delete <= auto_stop` |
| `Storage` | `7` | `Storage(String)` | `ErrStorage` | Overlay/disk/mount errors (`No space left on device` -> increase `disk_size_gb`) |
| `Image` | `8` | `Image(String)` | `ErrImage` | Image pull failure, missing private registry auth, or Cloud 20-image catalog cap |
| `Network` | `9` | `Network(String)` | `ErrNetwork` | gvproxy / tunnel failure, `tunnel connection has already been consumed` |
| `Execution` | `10` | `Execution(String)` | `ErrExecution` | Process execution error (**Rust has NO `BoxliteError::Run`!**) |
| `Stopped` | `11` | `Stopped(String)` | `ErrStopped` | Box stopped mid-operation or PID 1 exited |
| `Engine` | `12` | `Engine(String)` | `ErrEngine` | Hypervisor / VM backend initialization failure |
| `UnsupportedEngine` | `19` | `UnsupportedEngine` | `ErrUnsupportedEngine` | Missing `/dev/kvm` or unsupported host OS (Intel Mac, native Windows) |
| `Unsupported` | `—` | `Unsupported(String)` | — | Calling local-only features (e.g. Rust `litebox.ssh()`) over REST |
| `ResourceExhausted` | `—` | `ResourceExhausted` | — | Exceeded concurrency limit, org ceiling (`4 vCPU / 32 GiB / 120 GiB`), or host limits |
| `SessionReaped` | `21` | `SessionReaped` | `ErrSessionReaped` | Underlying runtime/guest session already reaped |

---

## 30 Critical Cross-SDK, CLI & Cloud Pitfalls

1. **Passing `"ro"`/`"rw"` strings to SDK volume options**: Python expects `bool` `(host, guest, True)`, Node expects `readOnly: true`, C expects `int read_only` (`1`/`0`), Go expects `WithVolumeReadOnly`. Only CLI `-v host:guest:ro` uses strings.
2. **Non-zero guest exit codes do NOT raise on `exec`**: In Python, Node (`SimpleBox`), Rust, Go (`Exec`/`Cmd.Run`), and C, non-zero exit codes return normally in `ExecResult.exit_code` (`nil` error in Go, `Ok` in C). Always check `exit_code`.
3. **Python `CodeBox.run()` vs Node `CodeBox.run()`**: Python `run()` returns `stdout` only, ignores `timeout` param, and hides tracebacks in `stderr` (returns empty string); Node `run()` throws `ExecError` on failure.
4. **Python `SimpleBox.exec(timeout=...)` vs `boxlite.TimeoutError`**: `SimpleBox.exec(timeout=...)` sends SIGTERM (`exit_code=-15`), and `boxlite.TimeoutError` is distinct from Python's built-in `TimeoutError`.
5. **Python `env` tuple vs dict mismatch**: `SimpleBox(env=...)`, `BoxOptions(env=...)`, and `InteractiveBox(env=...)` require `list[tuple[str, str]]`, whereas `SimpleBox.exec(env=...)` requires `dict[str, str]`.
6. **Passing `security=` directly on `BoxOptions`**: Top-level `security=` fails (`TypeError`/`AttributeError`); wrap it in `BoxOptions(advanced=AdvancedBoxOptions(security=SecurityOptions.maximum()))`. Also, `SecurityOptions.minimum()` does NOT exist (`development`, `standard`, `maximum` only).
7. **Node.js `SimpleBox` lazy getters before start**: Accessing `.id`, `.name`, `.created` synchronously before the first `exec()`/`start()` throws synchronously; use `await box.getId()` or `await box.getInfo()`.
8. **Node.js exported `DEFAULT_CPUS`/`DEFAULT_MEMORY_MIB`**: Exporting them is informational only; omitted VM creation parameters fall back to **`1 vCPU / 1024 MiB`** at the runtime layer across all SDKs.
9. **Node.js is ESM-only & scoped**: Always import from `@boxlite-ai/boxlite` (never `boxlite` or `@boxlite/sdk`) inside `.mjs` / `"type": "module"` projects.
10. **Native `Box.exec` vs `SimpleBox.exec` result shape**: In Python/Rust native `Box.exec().wait()`, `ExecResult` contains ONLY `exit_code` and `error_message` — `stdout`/`stderr` must be read from one-shot async streams BEFORE waiting completes.
11. **Missing binaries & KVM failures bypass `BoxliteError` in Python/Node**: Spawn failures, failed pulls, and missing virtualization raise built-in `RuntimeError` (Python) or bare `Error` (Node), so catching only `ExecError`/`BoxliteError` misses them!
12. **`boxlite[sync]` import vs attribute error**: When extras are absent, `from boxlite import SyncSimpleBox` raises `ImportError`, while `boxlite.SyncSimpleBox` raises `AttributeError`. Sync classes also fail inside an active asyncio loop.
13. **Go `Exec` nil-pointer panic**: Failed `box.Exec(ctx, ...)` returns `(nil, err)` (`Code=ErrInternal`). Always check `if err != nil` before reading `res.ExitCode`!
14. **Go `WithEnv` arity**: `WithEnv(k, v)` sets one pair per call (unlike `ExecutionOptions.Env` `map[string]string`).
15. **Rust `LiteBox` has NO `.run()` & NO `BoxliteError::Run`**: Always call `litebox.exec(BoxCommand::new(...)).await?` and match `BoxliteError::Execution(msg)`.
16. **Rust `litebox.ssh()` is local-only**: Calling `.ssh()` on a REST/Cloud `BoxliteRuntime` returns `BoxliteError::Unsupported`.
17. **C Native API requires a drain loop**: Async C calls (`create_box`, `execution_wait`, etc.) NEVER invoke callbacks until the caller polls `boxlite_runtime_drain(rt, timeout_ms, &err)` in a loop! And every handle/struct/error must be freed explicitly.
18. **`boxlite_execute` does not exist in C**: Use synchronous `boxlite_box_exec(handle, &cmd, &out_exec, &err)` -> attach stream callbacks -> `boxlite_execution_wait(...)` -> `boxlite_runtime_drain`.
19. **SQLite `Schema version mismatch` process abort**: All local SDKs share `~/.boxlite/db/boxlite.db`. Running an older SDK after a newer SDK upgrades the schema **aborts the process** (uncatchable). Isolate versions using `BOXLITE_HOME`.
20. **`BrowserBox` `playwright==1.58.0` pin & port 3000**: Any Playwright version mismatch returns `428 Precondition Required`. Also, `endpoint()` (CDP) does NOT support WebKit (`ValueError`); use `playwright_endpoint()`. Override `port` for parallel browser boxes.
21. **Copying files into `/tmp`**: `/tmp` inside the microVM is `tmpfs` (not persistent layer); copy inputs/outputs under `/data` or `/work`, and pass `disk_size_gb=4` for `pandas`/`git` in `CodeBox`.
22. **Guest servers bound to `127.0.0.1`**: Port forwards and Cloud tunnels enter via the guest network interface (`0.0.0.0`), not loopback; servers bound to `127.0.0.1` refuse or drop connections.
23. **Cloud `BOXLITE_REST_URL` & `path_prefix` traps**: Always point Cloud at `https://api.boxlite.ai` (NOT `https://app.boxlite.ai`, which returns dashboard HTML with HTTP `200`), and leave `path_prefix` / `BOXLITE_REST_PATH_PREFIX` unset!
24. **Cloud inbound default changed in `0.10.5`**: `NetworkSpec(mode="enabled")` sets **outbound only**! Tunnels/public preview URLs require `NetworkSpec(inbound=InboundNetworkSpec(mode="enabled"))` (or `POST /api/box/{id}/public/true`).
25. **Cloud `BoxTunnel` is strictly one-shot**: `tunnel.connect()` and `tunnel.forward()` spend the `BoxTunnel`; requesting a second connection raises `tunnel connection has already been consumed`. Only `tunnel.uri()` leaves it unspent.
26. **Cloud stopped-box disk billing & `auto_delete` defaults**: `auto_stop=900` stops vCPU/RAM after 15m idle (background guest jobs don't count as activity!), while `auto_delete=0` keeps billing `$0.00018/GiB-hr` for the root disk indefinitely. Set `auto_delete > auto_stop` (and remember `boxlite create --auto-delete` is blocked on detached CLI boxes).
27. **Cloud `boxlite images` CLI trap**: `boxlite images` lists LOCAL cached images even when `BOXLITE_REST_URL` points to Cloud. Use `await rt.images.list()` / `usage()` / `get()` (after ~12s boot registration delay) or the Web Console.
28. **Outbound egress allowlist sinkhole**: Blocked hosts resolve to `0.0.0.0` (so `nslookup` exits `0`!), causing connection errors rather than DNS errors.
29. **GitHub HTTPS Basic Auth + Secret failure**: `https://user:<BOXLITE_SECRET:...>@github.com` fails; pass `git -c "http.extraHeader=Authorization: Bearer <BOXLITE_SECRET:github_token>"` instead, and ensure headers exist on the request so the proxy swaps `{value}`.
30. **One-line CLI installer env placement**: `BOXLITE_VERSION=vX.Y.Z curl ... | sh` fails silently because the env var scopes to `curl`; put variables on the `sh` side: `curl -fsSL https://sh.boxlite.ai | BOXLITE_VERSION=vX.Y.Z sh`.

---

## Complete REST HTTP API & Platform API Endpoints Reference

### Core BoxLite REST API (`/v1/...`, optional `/{path_prefix}/...` on self-hosted `boxlite serve`)

On **BoxLite Cloud** (`https://api.boxlite.ai`), leave `path_prefix` unset (`/v1/...`).

| Endpoint | Method | Purpose | Request / Notes |
| - | - | - | - |
| `/v1/config` | `GET` | Fetch server capabilities / config | Unauthenticated even when `boxlite serve --api-key` is active |
| `/v1/me` | `GET` | Verify authenticated principal & discover `path_prefix` | Used by `boxlite auth whoami` & `login` |
| `/v1/boxes` | `POST` | Create a box | JSON: `{ "image", "volumes": [{"managed_volume", "guest_path"}], "secrets": [...], "env": {...}, "auto_stop", "auto_delete" }` (returns `box_id` / `id`) |
| `/v1/boxes` | `GET` | List boxes | Equivalent to `runtime.list_info()` |
| `/v1/boxes/{id}` | `GET` | Get box info | Inspect state, config, timestamps |
| `/v1/boxes/{id}?force=true` | `DELETE` | Remove box (and stop if forced) | Stops disk billing on Cloud |
| `/v1/boxes/{id}/exec` | `POST` | Start an asynchronous command execution | JSON: `{ "command", "args": [...] }` -> returns execution `id`. Poll status before removing box! |
| `/v1/boxes/{id}/executions/{exec_id}` | `GET` | Poll execution state | Look for `.state == "completed"` |
| `/v1/boxes/{id}/network/tunnel` | `POST` | Prepare a one-shot tunnel to a guest port | Driven automatically by `await box.network.tunnel(port)` |
| `/v1/volumes` | `POST` | Create a managed volume | JSON: `{ "name": "..." }` (empty creates unnamed volume whose `name == id`) |
| `/v1/volumes/{id}` | `DELETE` | Delete a managed volume | Deletion is asynchronous |

### BoxLite Cloud Platform API (`/api/box/...` — Note singular `box` and NO `/v1/`)

| Endpoint | Method | Purpose | Query / Response |
| - | - | - | - |
| `/api/box/{boxIdOrName}/public/{isPublic}` | `POST` | Toggle public inbound (`true` / `false`) | `200` returns updated box; audited in org log |
| `/api/box/{boxIdOrName}/ports/{port}/preview-url` | `GET` | Get preview URL + auth token for a port | Returns `{ boxId, url, token }`. Requires an active tunnel on `port` or returns `404 tunnel not found` |
| `/api/box/{boxIdOrName}/ports/{port}/signed-preview-url` | `GET` | Mint an expiring signed preview URL (HTTP-only) | Optional `?expiresInSeconds=N` (default `60`). Returns `{ boxId, port, token, url }` |
| `/api/box/{boxIdOrName}/ports/{port}/signed-preview-url/{token}/expire` | `POST` | Immediately revoke a signed preview URL | Path `token` comes from `.token` in signed-URL response |

---

## Complete Parameter & Return Shapes Reference

### `BoxOptions` Cross-Language Field Mapping

| Concept | Python `BoxOptions(...)` | Node.js `JsBoxOptions` | Rust `BoxOptions` | Go `BoxOption` |
| - | - | - | - | - |
| **Rootfs image** | `image="alpine:latest"` | `image: "alpine:latest"` | `rootfs: RootfsSpec::Image(...)` | First arg of `rt.Create(ctx, image, opts...)` / `WithImage` |
| **Offline OCI layout** | `rootfs_path="/path"` | `rootfsPath: "/path"` | `rootfs: RootfsSpec::RootfsPath(...)` | `WithRootfs("/path")` |
| **vCPUs** | `cpus=2` | `cpus: 2` | `cpus: Some(2)` | `WithCPUs(2)` |
| **Memory (MiB)** | `memory_mib=2048` | `memoryMib: 2048` | `memory_mib: Some(2048)` | `WithMemoryMiB(2048)` |
| **Disk (GB)** | `disk_size_gb=8` | `diskSizeGb: 8` | `disk_size_gb: Some(8)` | `WithDiskSizeGB(8)` |
| **Environment vars** | `env=[("K", "V")]` (tuple list!) | `env: [{ key, value }]` or tuples | `env: vec![("K".into(), "V".into())]` | `WithEnv("K", "V")` (1 pair/call) |
| **Working dir** | `working_dir="/work"` | `workingDir: "/work"` | `working_dir: Some("/work".into())` | `WithWorkingDir("/work")` |
| **Run user** | `user="1000:1000"` | `user: "1000:1000"` | `user: Some("1000:1000".into())` | `WithUser("1000:1000")` |
| **Entrypoint & Cmd** | `entrypoint=[...]`, `cmd=[...]` | `entrypoint`, `cmd` | `entrypoint`, `cmd` | `WithEntrypoint(...)`, `WithCmd(...)` |
| **Volumes (local)** | `volumes=[(host, guest, bool_ro)]` | `volumes: [{ hostPath, guestPath, readOnly }]` | `volumes: vec![VolumeSpec { ... }]` | `WithVolume(h, g)` / `WithVolumeReadOnly(h, g)` |
| **Volumes (Cloud)** | `volumes=[(vol_name, guest)]` | `volumes: [[vol_name, guest]]` | REST `VolumeSpec` | REST `VolumeSpec` |
| **Ports** | `ports=[(host, guest)]` | `ports: [{ hostPort, guestPort, protocol }]` | `ports: vec![PortSpec { ... }]` | `WithPort(host, guest, proto)` |
| **Network policy** | `network=NetworkSpec(inbound=..., outbound=...)` | `network: { inbound: ..., outbound: ... }` | `network: NetworkSpec { ... }` | `WithNetwork(...)` / `WithAllowNet(...)` |
| **Secrets proxy** | `secrets=[Secret(name, value, hosts, headers)]` | `secrets: [{ name, value, hosts, headers }]` | `secrets: vec![Secret { ... }]` (no `Default`) | `WithSecret(...)` |
| **Auto stop / delete** | `auto_stop=900, auto_delete=3600` | `autoStop: 900, autoDelete: 3600` | `auto_stop: Some(...), auto_delete: Some(...)` | `WithAutoStopInterval`, `WithAutoDeleteInterval` |
| **Security sandbox** | `advanced=AdvancedBoxOptions(security=SecurityOptions.maximum())` | `advanced: { security: ... }` | `advanced: AdvancedBoxOptions { security: SecurityOptions::enabled() }` | Security options |

### Cloud Tunnels Parameter & Return Reference (Python)

| Symbol | Async | Parameters / Return | Critical Rules |
| - | - | - | - |
| `await box.network.tunnel(port)` | Yes | `port: int` (`> 0`) -> `BoxTunnel` | `port == 0` raises `ValueError: tunnel port must be non-zero`. Shorthand on `SimpleBox`: `await box.tunnel(port)`. Refused with `InvalidStateError` if `inbound` is `disabled` |
| `tunnel.uri()` | **No** | `-> str \| None` | Returns public URL on Cloud (`None` on local runtime). Does **NOT** consume the tunnel |
| `await tunnel.connect()` | Yes | `-> BoxConnection` | **Consumes** the tunnel! Calling twice raises `tunnel connection has already been consumed` |
| `await tunnel.forward(listen)` | Yes | `listen: SocketAddress` -> `TunnelForwarder` | **Consumes** the tunnel! Binds local socket and forwards connections |
| `SocketAddress.tcp(host, port)` | No | Defaults `host="127.0.0.1", port=0` -> `SocketAddress` | `host` MUST be numeric IP (`ValueError: tunnel listener host must be a numeric IP` on `"localhost"`) |
| `SocketAddress.unix(path)` | No | `path: str` -> `SocketAddress` | `path` MUST be absolute (`ValueError: tunnel Unix socket path must be absolute`) |
| `TunnelForwarder.local_addr()` | **No** | `-> SocketAddress` | Check `.port` when passing `port=0` |
| `await TunnelForwarder.wait()` / `.close()` | Yes | Wait for stop / close forwarder | `—` |
| `await BoxConnection.read(max_bytes)` | Yes | `max_bytes > 0` -> `bytes` | `0` raises `ValueError`; empty `bytes` means remote closed; reading closed raises `connection is closed` |
| `await BoxConnection.write(data)` | Yes | `data: bytes` -> `int` | Returns bytes written |
| `await BoxConnection.shutdown_write()` / `.close()` | Yes | Half-close write / close both | TCP half-close not propagated reliably end-to-end — frame messages cleanly! |

### Complete `boxlite` CLI Subcommands Reference

| Command | Usage / Flags | Default Output / Notes |
| - | - | - |
| `boxlite run` | `[OPTIONS] <IMAGE> [CMD...]` (`-d/--detach`, `--rm`, `-it`, `-v h:g[:ro\|rw]`, `-p [h:]g[/tcp\|udp]`, `-e K=V`, `-w`, `-u`, `--cpus`, `--memory`, `--disk-size`, `--network`, `--allow-net`, `--security`, `--name`) | `--rm` incompatible with `-d`; `-t` fails without real TTY |
| `boxlite create` | Same creation flags + `--auto-stop 15m` (`30s`, `15m`, `2h`, `7d`) | Refuses `--auto-delete` on detached boxes (`auto_delete=0` enforced on CLI) |
| `boxlite start <BOX...>` | Starts one or more stopped/created boxes | Aggregates per-target failures and exits `1` if any fail |
| `boxlite exec` | `[-it] [-e K=V] [-w dir] [-u user] <BOX> -- <CMD...>` | Fails with `No such box: <BOX>` unless existing & running |
| `boxlite stop <BOX...>` / `restart <BOX...>` / `rm [-f] <BOX...>` | Lifecycle batch operations | Aggregate errors; exit `1` if any failed |
| `boxlite cp <SRC> <DST>` | Copy files between host and `box:path` | Both directions supported |
| `boxlite list` / `ls [-a]` | List boxes | Default output: `table` |
| `boxlite inspect <BOX>` | Detailed JSON box inspection | Default output: `json` |
| `boxlite info` | Runtime & host system info | Default output: `yaml` |
| `boxlite stats` | Live CPU / memory / network counters | Default output: `table` |
| `boxlite pull` / `images` / `rmi` | Local OCI cache operations | **`boxlite images` reads LOCAL cache only, even with `BOXLITE_REST_URL`!** |
| `boxlite volume` | `create --name ...`, `ls`, `rm` | Talks to REST server (`auth login` first) |
| `boxlite network` | `inbound <BOX> enabled\|disabled`, `tunnel [--revoke] <BOX> <PORT>` | Prepares/revokes Cloud tunnels & inbound mode |
| `boxlite domain` | `ls`, `bind <DOMAIN> --type box --box <BOX> --port <PORT>`, `unbind <DOMAIN>` | Manages `*.boxliteapp.com` fixed domains |
| `boxlite ssh <BOX>` | Initial setup, `--status`, `--enable`, `--disable` | Prints OpenSSH `ProxyCommand` connection string |
| `boxlite serve` | Starts REST server (`--host 127.0.0.1 --port 8100 --api-key <KEY>`) | Defaults `127.0.0.1:8100` (`0.10.6+`); `--api-key` required for non-loopback bind |
| `boxlite auth` | `login --url ... [--api-key-stdin\|--method api-key]`, `logout`, `status`, `whoami` | Persists profiles (`--profile` / `BOXLITE_PROFILE`) + cached `path_prefix` in `~/.boxlite/credentials.toml` |
| `boxlite context` | `use <NAME>` | Switches default named CLI context |
| `boxlite completion` | `<bash \| zsh \| fish>` | Prints shell completion script |

---

## Domain-Specific Production Checklists & Cloud Examples

### Cloud Image Aliases, Catalog Timing & Private Registries (Python SDK)

```python
import asyncio, os
from boxlite import ApiKeyCredential, Boxlite, BoxliteRestOptions, BoxOptions

async def manage_cloud_images() -> None:
    rt = Boxlite.rest(BoxliteRestOptions(
        url=os.environ.get("BOXLITE_REST_URL", "https://api.boxlite.ai"),
        credential=ApiKeyCredential(os.environ["BOXLITE_API_KEY"]),
    ))
    try:
        # 1. Images enter catalog ~12s after first box BOOTS (not immediately after create())
        for _ in range(10):
            if await rt.images.list():
                break
            await asyncio.sleep(4)

        usage = await rt.images.usage()   # ImageUsage(count=..., limit=20, known_bytes=...)
        detail = await rt.images.get("ghcr.io/acme/api")
        digest = detail.versions[0].digest  # sha256:...

        # 2. Pin & promote/rollback an alias (no registry traffic, running boxes untouched)
        await rt.images.create_alias(name="ghcr.io/acme/api", alias="stable", digest=digest)

        # 3. Inspect move history & remove stale image
        detail = await rt.images.get("ghcr.io/acme/api")
        for ev in detail.history:
            print(ev.alias, ev.from_digest, "->", ev.to_digest, ev.recorded_at)
    finally:
        rt.close()
```

### Cloud One-Shot HTTP Tunnel & Signed Preview URL Flow

```python
import asyncio, os, urllib.request, json
from boxlite import (
    ApiKeyCredential, Boxlite, BoxliteRestOptions, BoxOptions,
    InboundNetworkSpec, NetworkSpec,
)

async def tunnel_and_share() -> None:
    api_key = os.environ["BOXLITE_API_KEY"]
    base = os.environ.get("BOXLITE_REST_URL", "https://api.boxlite.ai")
    rt = Boxlite.rest(BoxliteRestOptions(url=base, credential=ApiKeyCredential(api_key)))
    box = None
    try:
        box = await rt.create(
            BoxOptions(
                image="python:alpine",
                auto_stop=900,
                auto_delete=3600,  # MUST be > auto_stop!
                # Required since 0.10.5 for tunnels & public preview URLs:
                network=NetworkSpec(inbound=InboundNetworkSpec(mode="enabled")),
            ),
            name="web-preview-demo",
        )
        await box.start()
        # Server inside box MUST bind 0.0.0.0
        await (await box.exec("sh", args=["-c", "nohup python3 -m http.server 8080 --bind 0.0.0.0 >/tmp/http.log 2>&1 &"])).wait()

        # Prepare fresh tunnel (reading uri() does NOT consume it)
        tunnel = await box.network.tunnel(8080)
        print("Tunnel URI:", tunnel.uri())

        # Mint signed expiring preview URL via Platform API (see network-policy.md)
        req = urllib.request.Request(
            f"{base}/box/{box.id}/ports/8080/signed-preview-url?expiresInSeconds=900",
            headers={"Authorization": f"Bearer {api_key}"},
        )
        with urllib.request.urlopen(req, timeout=15) as resp:
            signed = json.loads(resp.read().decode())
            print("Signed URL:", signed["url"], "Token to revoke:", signed["token"])
    finally:
        if box is not None:
            await rt.remove(box.id, force=True)
        rt.close()
```

### Cross-Language Secret Configuration Comparison (OpenAI / Anthropic Proxy Injection)

| Language / Surface | Real Key Placement | Secret Object Syntax | Guest Env Placeholder |
| - | - | - | - |
| **Python** | `Secret.value=real_key` | `boxlite.Secret(name="model", value=tok, hosts=["api.openai.com"], headers={"Authorization": "Bearer {value}"})` | `env=[("OPENAI_API_KEY", "<BOXLITE_SECRET:model>")]` |
| **Node.js / TS** | `secret.value = realKey` | `{ name: "model", value: tok, hosts: ["api.openai.com"], headers: { Authorization: "Bearer {value}" } }` | `env: [{ key: "OPENAI_API_KEY", value: "<BOXLITE_SECRET:model>" }]` |
| **Rust** | `Secret.value: real_key` | `Secret { name, hosts, placeholder, value }` (no `Default`; all 4 fields required) | `env: vec![("OPENAI_API_KEY".into(), "<BOXLITE_SECRET:model>".into())]` |
| **REST (`POST /v1/boxes`)** | `"value": "<KEY>"` | `"secrets": [{"name": "model", "value": "<KEY>", "hosts": ["api.openai.com"], "headers": {"Authorization": "Bearer {value}"}}]` | `"env": {"OPENAI_API_KEY": "<BOXLITE_SECRET:model>"}` |

### Metrics Field Mapping Across SDKs

| Metric Concept | Python (`boxlite`) | Node.js (`@boxlite-ai/boxlite`) | Rust (`boxlite`) | Go (`sdks/go`) |
| - | - | - | - | - |
| Runtime running boxes | `rt_metrics.num_running_boxes` | `rtMetrics.numRunningBoxes` | `rt_metrics.num_running_boxes()` | `rtMetrics.RunningBoxes` (NO `Num`!) |
| Runtime created total | `rt_metrics.boxes_created_total` | `rtMetrics.boxesCreatedTotal` | `rt_metrics.boxes_created_total()` | `rtMetrics.BoxesCreatedTotal` |
| Runtime failed total | `rt_metrics.boxes_failed_total` | `rtMetrics.boxesFailedTotal` | `rt_metrics.boxes_failed_total()` | `rtMetrics.BoxesFailedTotal` |
| Runtime execs / errors | `total_commands_executed`, `total_exec_errors` | `totalCommandsExecuted`, `totalExecErrors` | `total_commands_executed()`, `total_exec_errors()` | `TotalCommandsExecuted`, `TotalExecErrors` |
| Box memory usage | `box_metrics.memory_bytes` (NOT `memory_usage_bytes`) | `boxMetrics.memoryBytes` | `box_metrics.memory_bytes()` | `boxMetrics.MemoryBytes` |
| Box CPU usage | `box_metrics.cpu_percent` (NOT `cpu_time_ms`) | `boxMetrics.cpuPercent` | `box_metrics.cpu_percent()` | `boxMetrics.CpuPercent` |
| Where `.metrics()` lives | Native `Box` only (`await box._box.metrics()` for `SimpleBox`) | Both `SimpleBox.metrics()` and `JsBox.metrics()` | `litebox.metrics().await?` | `box.Metrics(ctx)` |

### Cost Optimization & Security Hardening Checklist
1. **Local Untrusted Execution**: Stack `OutboundNetworkSpec(mode="disabled")` (or narrow `allow_net`) + `user="1000:1000"` + `AdvancedBoxOptions(security=SecurityOptions.maximum())` + `exec(..., timeout=...)`. Never copy untrusted inputs into `/tmp` (`tmpfs`); clean up in `finally` / `async with`.
2. **HTML / Browser Untrusted Pipeline**: Run untrusted pages inside `BrowserBox` (`playwright==1.58.0`, free random host port), extract raw HTML, parse it inside a separate disposable `CodeBox`, and pass ONLY clean structured JSON to your LLM.
3. **Cloud Cost Hygiene**: Always pass both `auto_stop` AND `auto_delete` (`auto_delete > auto_stop`, because stopped boxes bill root disks forever at `$0.00018/GiB-hr`!), store persistent data on **unmetered** managed volumes (`rt.volumes.create`), cut vCPU before RAM/disk (`1 vCPU-hr == 3.5 GiB-hr RAM == 280 GiB-hr disk`), attach a card for `$100` credits + auto-reload, and size your subscription plan against **concurrency fan-out** (`20` Starter / `100` Pro / `1000` Max) as well as monthly spend (`$20` / `$161` / `$601` crossovers).
4. **Cloud Credential Hygiene**: Keep `BOXLITE_API_KEY` (`blk_live_...`, fleet-level) strictly on your host/backend, use `Boxlite.rest(BoxliteRestOptions.from_env())`, keep third-party model/GitHub tokens in `Secret`, verify TLS against `/etc/ssl/certs/ca-certificates.crt`, keep `inbound` disabled by default, and use short-lived revocable signed URLs instead of flipping boxes `public=true`.

---

## C Native SDK Post-and-Drain Lifecycle & Memory Freeing Table

Every async native C SDK function posts work to the runtime and **never invokes its callback** until `boxlite_runtime_drain` is pumped:

```c
/* Synchronous step: obtains CExecutionHandle* immediately (there is NO boxlite_execute) */
CExecutionHandle *exec = NULL;
BoxliteErrorCode rc = boxlite_box_exec(box_handle, &cmd, &exec, &error);
/* Attach on_stdout / on_stderr callbacks BEFORE calling boxlite_execution_wait */
rc = boxlite_execution_wait(exec, on_execution_wait, &wait_state, &error);

/* Mandatory pump loop until callback sets wait_state.done = 1 */
CBoxliteError drain_err = {0};
while (!wait_state.done) {
    if (boxlite_runtime_drain(runtime, -1, &drain_err) < 0) {
        fprintf(stderr, "drain failed: %s\n", drain_err.message ? drain_err.message : "unknown");
        boxlite_error_free(&drain_err);
        break;
    }
}
```

### C SDK Ownership & Freeing Rules (All `*_free` Functions Are `NULL`-Safe)

| Allocated Source | Free Function | Thread Safety / Lifetime Notes |
| - | - | - |
| `boxlite_box_id()` string | `boxlite_free_string` | Heap-allocated C string |
| `CBoxliteError` (on failure) | `boxlite_error_free` | Always zero-init `CBoxliteError err = {0};` |
| `CBoxliteExecResult *` | `boxlite_result_free` | Frees struct + `stdout_text` + `stderr_text` |
| `CBoxInfo *` / `CBoxInfoList *` | `boxlite_free_box_info` / `boxlite_free_box_info_list` | Returned from `info` / `list` |
| `CImagePullResult *` / `CImageInfoList *` | `boxlite_free_image_pull_result` / `boxlite_free_image_info_list` | Returned from image pull / list |
| `CBoxliteImageHandle *` | `boxlite_image_free` | Image handle |
| `CBoxHandle *` | `boxlite_box_free` | Ownership transferred via create/get callback; `boxlite_stop_box` keeps handle valid |
| `CExecutionHandle *` | `boxlite_execution_free` | Process execution handle (NOT thread-safe) |
| `CBoxliteRuntime *` | `boxlite_runtime_free` | `CBoxliteRuntime` itself IS thread-safe across worker threads |
| `CBoxliteSimple *` | `boxlite_simple_free` | Stops, removes, and frees runtime + box synchronously |
| `CBoxliteOptions *` / `CAdvancedBoxOptions *` | `boxlite_options_free` / `boxlite_advanced_options_free` | Options builders |

---

## Complete SDK Method Matrix (Python, Node.js, Rust, Go)

### Runtime Operations

| Operation | Python (`Boxlite`) | Node.js (`JsBoxlite`) | Rust (`BoxliteRuntime`) | Go (`*boxlite.Runtime`) |
| - | - | - | - | - |
| **Default local init** | `Boxlite.default()` | `JsBoxlite.withDefaultConfig()` | `BoxliteRuntime::with_defaults()?` / `default_runtime()` | `boxlite.NewRuntime(opts...)` |
| **Remote REST init** | `Boxlite.rest(BoxliteRestOptions(url, cred, path_prefix))` | `JsBoxlite.rest(new BoxliteRestOptions({ url, credential, pathPrefix }))` | `BoxliteRuntime::rest(BoxliteRestOptions)?` | `boxlite.NewRest(BoxliteRestOptions{...})` |
| **Create box** | `await rt.create(BoxOptions(...), name=...)` | `await rt.create(opts, name?)` | `rt.create(BoxOptions, name).await?` | `rt.Create(ctx, image, opts...)` |
| **Get or create** | `await rt.get_or_create(opts, name)` | `await rt.getOrCreate(opts, name)` | `rt.get_or_create(opts, name).await?` | `rt.GetOrCreate(ctx, name, opts...)` |
| **Lookup / list** | `await rt.get(id)`, `get_info(id)`, `list_info()` | `await rt.get(id)`, `getInfo(id)`, `listInfo()` | `get`, `get_info`, `list_info`, `exists` | `Get`, `GetInfo`, `ListInfo` |
| **Remove box** | `await rt.remove(id, force=False)` | `await rt.remove(id, force?)` | `rt.remove(id, force).await?` | `rt.Remove(ctx, id)`, `rt.ForceRemove(ctx, id)` |
| **Import archive** | `await rt.import_box(path, name)` | `await rt.importBox(path, name?)` | `rt.import_box(BoxArchive::new(path), name).await?` | — |
| **Shutdown runtime** | `await rt.shutdown(timeout=None)` | `await rt.shutdown(timeout?)` / `rt.close()` | `rt.shutdown(timeout).await?` | `rt.Shutdown(ctx, timeout)` / `rt.Close()` |

### Box Operations

| Operation | Python (`Box` / `SimpleBox`) | Node.js (`JsBox` / `SimpleBox`) | Rust (`LiteBox`) | Go (`*boxlite.Box`) |
| - | - | - | - | - |
| **Execute command** | `await box.exec(cmd, args=...)` | `await box.exec(cmd, args?, ...)` | `box.exec(BoxCommand::new(cmd)).await?` | `box.Exec(ctx, cmd, args...)`, `Command()`, `StartExecution()` |
| **Start / Stop** | `await box.start()`, `await box.stop()` | `await box.start()`, `await box.stop()` | `box.start().await?`, `box.stop().await?` | `box.Start(ctx)`, `box.Stop(ctx)`, `box.Close()` |
| **Info / Status** | `(await box.info()).state.status` | `(await box.info()).state.status` | `box.info().await?.status` | `box.Info(ctx)` (`State` field) |
| **Copy files** | `await box.copy_in(h, g)`, `copy_out(g, h)` | `await box.copyIn(h, g)`, `copyOut(g, h)` | `box.copy_into(...)`, `copy_out(...)` | `box.CopyInto(ctx, ...)`, `box.CopyOut(ctx, ...)` |
| **Clone / Export** | `clone_box`, `clone_boxes`, `export` | `cloneBox`, `export` | `clone_box`, `clone_boxes`, `export`, `snapshots()` | — |

---

## Complete Agent-in-a-Box & Cloud Troubleshooting Quick Reference

| Symptom | Root Cause | Exact Fix |
| - | - | - |
| `InvalidStateError: Box <ID> is not public; set public: true before opening a tunnel` | Box created without `inbound=InboundNetworkSpec(mode="enabled")` (`0.10.5+` defaults private; flat `NetworkSpec(mode="enabled")` is outbound only) | Set `NetworkSpec(inbound=InboundNetworkSpec(mode="enabled"))` on create or `POST /api/box/{id}/public/true` |
| `404 {"message":"not found: tunnel not found"}` on preview URL | Preview URL fetched for a port without an active tunnel | Call `await box.network.tunnel(port)` or `boxlite network tunnel <box> <port>` first |
| `503 {"message":"box is starting; retry shortly"}` (`Retry-After: 3`) | Wake-on-access triggered startup on a stopped Cloud box | Wait `Retry-After` seconds and retry HTTP request |
| `502 {"message":"box unreachable"}` right after Cloud box wakes | Service had been started via `exec` instead of box PID 1 main command | Configure service as the box's saved `entrypoint`/`cmd` so wake-on-access restarts it automatically |
| HTML dashboard page (`200 OK`) returned instead of JSON | `BOXLITE_REST_URL` points at console `https://app.boxlite.ai` | Set `BOXLITE_REST_URL=https://api.boxlite.ai` |
| `RuntimeError('box not found: {"detail":"Not Found"}')` with valid Cloud key | `path_prefix` or `BOXLITE_REST_PATH_PREFIX` is set on Cloud | Remove `path_prefix` / unset `BOXLITE_REST_PATH_PREFIX` (Cloud serves `/v1/boxes` directly) |
| `tunnel connection has already been consumed` | Called `connect()` or `forward()` twice on one `BoxTunnel` | `BoxTunnel` is strictly one-shot; call `await box.network.tunnel(port)` per connection |
| `ValueError: tunnel listener host must be a numeric IP` | Passed `"localhost"` to `SocketAddress.tcp` | Pass `"127.0.0.1"` or another numeric IP (`SocketAddress.unix` needs absolute path) |
| `nslookup blocked.com` exits `0` despite allowlist | DNS sinkhole returns `0.0.0.0` (successful lookup) for blocked hosts | Inspect resolved IP for `0.0.0.0`, not exit code |
| `auto_delete must be greater than auto_stop` | Both non-zero and `auto_delete <= auto_stop` | Increase `auto_delete` above `auto_stop`, or set `auto_delete=0` |
| `Error: invalid argument: remove-on-stop is incompatible with detach=true` | Passed `--auto-delete` to `boxlite create` (detached) | Set `auto_delete` via SDK or omit `--auto-delete` on `boxlite create` |
| `boxlite images` missing images used in Cloud boxes | `boxlite images` always reads LOCAL OCI cache only | Use `await rt.images.list()` / `usage()` / Console **Images** page (poll ~12s after first boot) |
| `428 Precondition Required` from `BrowserBox` | Client Playwright version mismatches image server (`1.58.0`) | Pin `pip install "playwright==1.58.0"` or `playwright-core@1.58.0` |
| `ValueError` from `BrowserBox.endpoint()` | Requested CDP `endpoint()` on WebKit (unsupported) | Use `BrowserBox.playwright_endpoint()` with `playwright.webkit.connect(ws)` |
| `OSError: [Errno 28] No space left on device` (`CodeBox`) | Default rootfs too small for `pandas`/`numpy`/`git` | Pass `disk_size_gb=4` or larger |
| `Schema version mismatch` aborts process | Older local SDK opening `~/.boxlite/db/boxlite.db` upgraded by newer SDK | Upgrade matching SDK or isolate via `BOXLITE_HOME=/path/to/dir` |
| `TypeError: 'str' object cannot be cast as 'bool'` | Passed `"ro"` string as 3rd tuple element in SDK `volumes` | Pass boolean `True`/`False` in Python (`readOnly: true` in Node, `1`/`0` in C) |
| `AttributeError` / `TypeError` on `BoxOptions(security=...)` or `.minimum()` | `security=` is not top-level on `BoxOptions`; `.minimum()` does not exist | Use `advanced=AdvancedBoxOptions(security=SecurityOptions.maximum())` (`development`/`standard`/`maximum`) |
| `panic: nil pointer dereference` after `box.Exec` in Go | Ignored non-nil `err` when binary failed to spawn (`res == nil`) | Always check `if err != nil` before accessing `res.ExitCode` |
| C async callback never fires / program hangs | Forgot `boxlite_runtime_drain` loop | Poll `boxlite_runtime_drain(rt, -1, &err)` in a `while (!done)` loop |

---

## Architecture Internals, Boot Latency & Core Utility Types

### Execution Stack & Data Directories (`architecture/*`)

| Component / Path | Responsibility |
| - | - |
| `src/boxlite` (embedded library) | Coordinates box lifecycle, SQLite metadata (`db/boxlite.db`), OCI image cache (`images/`), and spawns per-box shims |
| `boxlite-shim` | Per-box host supervisor hosting `libkrun` microVM, confined by `bubblewrap`/`seccomp` (Linux) or Seatbelt `sandbox-exec` (macOS) |
| `libkrun` + `libkrunfw` | Hypervisor integration (KVM / Hypervisor.framework), virtio-fs host/guest mounts, and guest kernel boot |
| `gvproxy` / `pasta` | User-mode virtual network stack (`192.168.127.2`), host-port forwarding, and DNS sinkhole (`0.0.0.0` for blocked domains) |
| `boxlite-guest` | PID 0/1 guest init & gRPC over vsock agent inside the microVM |
| `$BOXLITE_HOME/boxes/<id>/` | Per-box writable copy-on-write rootfs overlay, unix sockets, and logs |

### Boot Latency Breakdown (`architecture/boot-latency.md`)
1. **First run (cold image)**: Pulls OCI manifest/layers over network -> deduplicates blobs by `sha256` digest -> extracts base layer + creates sparse overlay -> boots microVM (several seconds to minutes for browser/desktop images).
2. **Subsequent cold boxes (cached image)**: Skips network pull entirely; clones local overlay + boots kernel (~1–2s).
3. **Stopped -> Started warm restart**: Preserves existing box overlay disk + packages; skips both pull and image unpack.

### Core Rust / SDK Value Types (`reference/rust.md`)

| Type | Helpers / Validation | Purpose |
| - | - | - |
| `Bytes` | `from_bytes`, `from_kib`, `from_mib`, `from_gib`, `as_bytes`, `as_kib`, `as_mib` | Type-safe memory/disk units |
| `Seconds` | `from_seconds`, `from_minutes`, `from_hours`, `as_seconds`, `as_minutes` | Type-safe duration units |
| `BoxID` | `BoxIDMint::mint()`, `BoxID::parse(s)` (`MAX_LENGTH = 128`) | Local 12-char Base62 (~71 bits entropy); accepts prefixed/remote IDs over REST |
| `ContainerID` | `ContainerID::new()`, `is_valid(s)` (`short()` -> 12 hex chars) | Strict 64-character lowercase hex OCI ID |

---

## BoxLite Cloud Plans, Billing & Volume Reference (`cloud/*`)

### Subscription Plans, Quota Crossovers & Concurrency Caps

| Plan | Monthly Price | Included Quota | Max Concurrent Running Boxes | Savings Past Quota | Switch Threshold |
| - | - | - | - | - | - |
| **Wallet-only** | `$0` | `$0` (pay-as-you-go) | Account default | `—` | Default below `$20/mo` |
| **Starter** | `$19/mo` | `$30` | `20` concurrent boxes | `$11/mo` | Cheaper past **`$20/mo`** spend |
| **Pro** | `$149/mo` | `$250` | `100` concurrent boxes | `$101/mo` | Cheaper past **`$161/mo`** spend |
| **Max** | `$499/mo` | `$900` | `1000` concurrent boxes | `$401/mo` | Cheaper past **`$601/mo`** spend |
| **Enterprise** | Negotiated | Custom / unlimited | Custom / unlimited | Custom | Contact `sales@boxlite.ai` |

- **Upgrade** applies immediately (prorated); **Downgrade** and **Cancel** take effect at next billing cycle roll (keeping existing quota/concurrency until cycle end).
- **Concurrency vs Quota**: Concurrency caps simultaneously running boxes regardless of remaining quota — an agent fan-out of 40 parallel boxes stalls on Starter (`20`) even if `$30` quota remains.

### Cloud Metered Breakdown by Box State

| State | vCPU (`$0.0504/hr`) | Memory (`$0.0144/GiB-hr`) | Disk (`$0.00018/GiB-hr`) | Cost Triggers / Clocks |
| - | - | - | - | - |
| `Configured` (never started) | Free | Free | Free | Zero charge until first start |
| `Creating` / `Starting` | Free | Free | Free | Boot time is unmetered |
| `Running` | **Charged** | **Charged** | **Charged** | Exact clock starts at Running; stops when stop requested |
| `Stopped` | Free | Free | **Still Charged** | Disk clock continues until `rt.remove()` or `auto_delete`! |
| `Deleted` | Free | Free | Free | Disk clock stops immediately when delete requested |

### Cloud Volumes vs Checkpoints Comparison

| Capability | Cloud Managed Volumes (`rt.volumes`) | Cloud Checkpoints (`cloud/checkpoints`) |
| - | - | - |
| **Metering** | **Unmetered (Free)** | Forks create boxes backed by checkpointed disk + config |
| **Persistence boundary** | Only files inside guest mount path (e.g. `/data`) survive box deletion | Captures box rootfs + configuration at checkpoint time |
| **Best use case** | Handoff artifacts across sequential boxes (`box-a` -> `box-b`), shared datasets, logs without keeping stopped disks | Prepare packages/repos once, boot N independent parallel worker boxes cleanly |
| **SDK / CLI surface** | `rt.volumes.create/list/get/remove`, `boxlite volume create/ls/rm`, REST `/v1/volumes` | Console, Python, TypeScript, and CLI checkpoint flows |
