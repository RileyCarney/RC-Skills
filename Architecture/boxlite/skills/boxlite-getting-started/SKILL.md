---
name: boxlite-getting-started
description: >-
  Install, verify, and run your first BoxLite hardware-isolated microVM sandbox across Python,
  Node.js, Rust, Go, C, and the CLI. Use when checking platform virtualization requirements
  (Linux KVM, macOS Apple Silicon Hypervisor.framework, Windows WSL2), installing SDKs/CLI,
  verifying checksums/attestations, or resolving startup/FAQ/version issues.
---

# BoxLite Getting Started, Installation & FAQ

BoxLite is an embeddable microVM sandbox runtime for AI agents and untrusted workloads. Every Box runs its own Linux kernel (KVM on Linux, Hypervisor.framework on macOS) with an embedded library architecture (no daemon, no root required) and persistent rootfs state across `stop()` / `start()`.

**Source docs:**
- [BoxLite documentation](../../docs/index.md) ([live](https://docs.boxlite.ai/index.md))
- [Introduction to BoxLite](../../docs/getting-started/index.md) ([live](https://docs.boxlite.ai/getting-started/index.md))
- [Quickstart](../../docs/getting-started/quickstart.md) ([live](https://docs.boxlite.ai/getting-started/quickstart.md))
- [Installation](../../docs/getting-started/installation.md) ([live](https://docs.boxlite.ai/getting-started/installation.md))
- [FAQ](../../docs/faq.md) ([live](https://docs.boxlite.ai/faq.md))
- [FAQ and releases](../../docs/resources/index.md) ([live](https://docs.boxlite.ai/resources/index.md))
- [Release notes and version](../../docs/guides/changelog.md) ([live](https://docs.boxlite.ai/guides/changelog.md))

---

## 1. Box vs. Container & Track Selection

| Aspect | BoxLite | Docker / Containers |
| - | - | - |
| Isolation | Hardware microVM (separate kernel) | Shared host kernel (namespaces/cgroups) |
| Daemon | None (embedded library in your process) | Requires background daemon |
| Root / sudo | Not required (`kvm` group on Linux) | Typically required |
| Stateful lifecycle | Persistent rootfs across `stop()` / `start()` | Usually ephemeral |
| Startup (cached) | ~1–2s | ~100–500ms |

### Open Source vs. BoxLite Cloud Check

Run this check to decide whether the host can run self-hosted microVMs or should target BoxLite Cloud (`Boxlite.rest(...)`):

```bash
# Linux
ls /dev/kvm 2>/dev/null
# macOS (Apple Silicon reports arm64)
uname -m | grep -q arm64 && echo "/dev/kvm-equivalent: Hypervisor.framework"
```

- **Prints a path / Hypervisor.framework** → Self-hosted open-source BoxLite works locally.
- **Prints nothing (CI runners, nested VMs, containers, Intel Mac)** → Use [BoxLite Cloud](../boxlite-cloud/SKILL.md) (`Boxlite.rest(...)`); needs only `BOXLITE_API_KEY` and HTTPS.

---

## 2. Platform & Virtualization Matrix

| Platform | Architecture | Status | Virtualization Requirement |
| - | - | - | - |
| macOS | Apple Silicon (ARM64) | Supported | macOS 12+, built-in Hypervisor.framework (no `/dev/kvm` needed) |
| macOS | Intel (`x86_64`) | **Not supported** | — |
| Linux | `x86_64` | Supported | KVM enabled, `/dev/kvm` accessible (`sudo usermod -aG kvm $USER`) |
| Linux | ARM64 (`aarch64`) | Supported | KVM enabled, `/dev/kvm` accessible |
| Windows | `x86_64` | Supported via WSL2 | Native Windows unsupported; configure KVM inside WSL2 (`kvm` group) |

- **Network**: First run of any image pulls OCI layers from the registry; subsequent runs use `~/.boxlite/images/`.
- **Ubuntu 24.04 AppArmor note**: Ubuntu 24.04 restricts unprivileged userns (`bwrap`). Either relax with `sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0` or use `AdvancedBoxOptions(security=SecurityOptions.development())` in dev.

---

## 3. SDK & CLI Installation

### Language Runtime Requirements & Install Commands

| Surface | Minimum Version | Package / Artifact | Install Command |
| - | - | - | - |
| **Python** | 3.10+ | `boxlite` (PyPI) | `pip install boxlite` |
| **Python Sync** | 3.10+ | `boxlite[sync]` (greenlet) | `pip install "boxlite[sync]"` |
| **Python Orchestration** | 3.10+ | `boxlite[orchestration]` (cloudpickle) | `pip install "boxlite[orchestration]"` |
| **Node.js** | 18+ (pure ESM) | `@boxlite-ai/boxlite` (npm) | `npm install @boxlite-ai/boxlite` |
| **Rust** | 1.88+ | `boxlite` crate | `cargo add boxlite` (+ `tokio`, `futures`) |
| **Go** | 1.24+ (CGO) | `github.com/boxlite-ai/boxlite/sdks/go` | `go get ...` + `go run .../cmd/setup` |
| **C** | C11 (GCC/Clang) | `libboxlite` + `boxlite.h` | `make sdk-c` (from source) |
| **CLI** | — | `boxlite` binary | `curl -fsSL https://sh.boxlite.ai \| sh` |

**Critical package notes:**
- The npm package is **`@boxlite-ai/boxlite`** (not `boxlite` or `@boxlite/sdk`), and it is **pure ESM** (`"type": "module"` — `require()` fails). Prebuilt native targets cover `aarch64-apple-darwin`, `x86_64-unknown-linux-gnu`, and `aarch64-unknown-linux-gnu` (`playwright-core` is an optional peer dependency for `BrowserBox`).
- Building Rust, C, or CLI from source requires **`protoc >= 3.12`** (`brew install protobuf` / `apt-get install -y protobuf-compiler`) and **`git submodule update --init --recursive`** (for `libkrun`, `libkrunfw`, `e2fsprogs`, `bubblewrap` under `src/deps/`), or run `make setup:build`.

### CLI Pinning & Artifact Verification

Env vars must sit on the `sh` side of the pipe:

```bash
curl -fsSL https://sh.boxlite.ai \
  | BOXLITE_VERSION=vX.Y.Z \
    BOXLITE_INSTALL_DIR=/usr/local/bin \
    BOXLITE_EXPECTED_SHA256=<sha256> sh
```

Verify `install.sh` or release tarballs independently before running:

```bash
curl -fsSL -o install.sh "https://github.com/boxlite-ai/boxlite/releases/latest/download/install.sh"
curl -fsSL -o install.sh.sha256 "https://github.com/boxlite-ai/boxlite/releases/latest/download/install.sh.sha256"
sha256sum -c install.sh.sha256
gh attestation verify install.sh --repo boxlite-ai/boxlite
sh ./install.sh
```

Other CLI install methods: `cargo install boxlite-cli`, `cargo binstall boxlite-cli`, or `cargo build --release -p boxlite-cli`.

### Verify Installed Versions

```bash
python3 -c "import boxlite; print(boxlite.__version__)"
node -e "import('node:module').then(({createRequire}) => console.log(createRequire(import.meta.url)('@boxlite-ai/boxlite/package.json').version))"
boxlite --version
```

Debug runtime logs with `RUST_LOG=debug` (`trace` / `debug` / `info` / `warn` / `error`).
Note: There is no `CHANGELOG.md` in the repo; authoritative release notes and security advisories (including CVEs fixed in `>= 0.9.0`) live on [GitHub Releases](https://github.com/boxlite-ai/boxlite/releases).

---

## 4. Five-Language Quickstart

Every language follows 5 steps: create, start, exec, read output, tear down.

### Python

```python
import asyncio
import boxlite

async def main() -> None:
    try:
        async with boxlite.SimpleBox(image="python:alpine") as box:
            print(f"Sandbox started: {box.id}")
            result = await box.exec("python", "-c", "print('Hello from BoxLite!')")
            # Non-zero exit codes do NOT raise; check exit_code yourself
            if result.exit_code != 0:
                print("stderr:", result.stderr.strip())
            else:
                print("stdout:", result.stdout.strip())
    except RuntimeError as exc:
        print(f"Sandbox failed to run: {exc}")

if __name__ == "__main__":
    asyncio.run(main())
```

### Node.js / TypeScript (ESM)

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
  } catch (err) {
    console.error("Execution error:", err);
    process.exitCode = 1;
  } finally {
    await box.stop();
  }
}

main();
```

### Rust

```rust
use boxlite::{BoxCommand, BoxOptions, BoxliteRuntime, RootfsSpec};
use futures::StreamExt;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let runtime = BoxliteRuntime::default_runtime();
    let options = BoxOptions {
        rootfs: RootfsSpec::Image("alpine:latest".into()),
        ..Default::default()
    };
    let litebox = runtime.create(options, None).await?;
    let mut execution = litebox.exec(BoxCommand::new("echo").arg("Hello from BoxLite!")).await?;

    if let Some(mut stdout) = execution.stdout() {
        while let Some(line) = stdout.next().await {
            println!("{}", line);
        }
    }
    let result = execution.wait().await?;
    if !result.success() {
        eprintln!("Non-zero exit: {}", result.exit_code);
    }
    litebox.stop().await?;
    Ok(())
}
```

### Go

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
		log.Fatal(err)
	}
	if res.ExitCode != 0 {
		fmt.Printf("command failed (exit=%d): %s", res.ExitCode, res.Stderr)
		return
	}
	fmt.Print(res.Stdout)
}
```

### C

```c
#include <stdio.h>
#include "boxlite.h"

int main(void) {
    CBoxliteSimple *box = NULL;
    CBoxliteError error = {0};
    if (boxlite_simple_new("python:slim", 0, 0, &box, &error) != Ok) {
        fprintf(stderr, "create failed (%d): %s\n", error.code, error.message ? error.message : "unknown");
        boxlite_error_free(&error);
        return 1;
    }
    const char *args[] = {"-c", "print('Hello from BoxLite!')"};
    CBoxliteExecResult *result = NULL;
    if (boxlite_simple_run(box, "python", args, 2, &result, &error) == Ok) {
        printf("exit=%d stdout=%s", result->exit_code, result->stdout_text ? result->stdout_text : "");
        boxlite_result_free(result);
    } else {
        fprintf(stderr, "exec failed (%d): %s\n", error.code, error.message ? error.message : "unknown");
        boxlite_error_free(&error);
    }
    boxlite_simple_free(box);
    return 0;
}
```

---

## 5. Core Mental Model & Critical Gotchas

1. **Main command (PID 1) keeps the box alive**: Every box runs one main command (`ENTRYPOINT + CMD`, or `entrypoint` / `cmd`). When PID 1 exits or crashes, the box stops (there is no restart policy). Use a long-running main command for `exec`-based agent jobs, or pass the workload as `entrypoint` / `cmd` and read its exit code with `box.attach()` on native `Box`.
2. **Scope ownership**: In Python (`async with`) and Node (`await using`), exiting the block destroys the box (`auto_remove=True` by default). Never return a box handle out of its owning block. In Rust, Go, and C, clean up explicitly in error paths (`Drop`, `defer`, `boxlite_simple_free`).
3. **Database `Schema version mismatch` aborts**: All local SDKs share `~/.boxlite/db/boxlite.db`. Mixing SDK versions (e.g., newer Python + older Node) causes a fatal process abort that `try/catch` cannot intercept. Match SDK versions or isolate with `BOXLITE_HOME="$PWD/.boxlite-node"`.
4. **Key API gotchas**:
   - `exec()` never raises on non-zero exit code; check `result.exit_code` / `result.exitCode`.
   - Missing commands, image pull failures, and missing `/dev/kvm` raise builtin `RuntimeError` (Python) / bare `Error` (Node), not `BoxliteError`.
   - `box.info()` is **async** (`await box.info()`), and status lives at `info.state.status`.
   - `runtime.list_info()` and `runtime.remove(id, force=True)` live on the runtime (not `runtime.list()` or `box.remove()`).
   - `metrics()` lives on native `Box` (not `SimpleBox`), with fields `memory_bytes`, `cpu_percent`, and `RuntimeMetrics.num_running_boxes`.
   - SDK `volumes` third element is a **`bool read_only`** (`True`/`False`), whereas CLI `-v` uses `:ro`/`:rw`.
   - `AdvancedBoxOptions` is imported from top-level `boxlite` and passed via `BoxOptions(advanced=AdvancedBoxOptions(security=SecurityOptions.maximum()))` (no top-level `security=` kwarg, no `SecurityOptions.minimum()`).
