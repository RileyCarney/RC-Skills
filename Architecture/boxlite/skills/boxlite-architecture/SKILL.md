---
name: boxlite-architecture
description: BoxLite internal architecture, defense-in-depth isolation model (MicroVM + Linux/macOS Jailer), gvproxy user-mode networking, OCI image cache & CoW/virtiofs/QCOW2 storage, cold vs. warm boot latency analysis, and contributor guide (building from source, CLI development, Rust style, e2e-local CI, macOS Seatbelt debugging, musl zygote deadlock background, and CLA).
---

# BoxLite Architecture & Contributor Guide

Deep architectural model and contributor workflows across BoxLite's Rust crates (`boxlite`, `boxlite-shared`, `boxlite-shim`, `boxlite-guest`, `boxlite-cli`).

## Documentation Map (14 Pages)

| Area | Topic | Local Doc | Live Docs |
| - | - | - | - |
| Architecture | Overview | [index.md](../../docs/architecture/index.md) | [architecture](https://docs.boxlite.ai/architecture/index.md) |
| Architecture | Core Components & Metrics | [core-components.md](../../docs/architecture/core-components.md) | [core-components](https://docs.boxlite.ai/architecture/core-components.md) |
| Architecture | Security & Isolation | [security-and-isolation.md](../../docs/architecture/security-and-isolation.md) | [security-and-isolation](https://docs.boxlite.ai/architecture/security-and-isolation.md) |
| Architecture | Networking (`gvproxy`) | [networking.md](../../docs/architecture/networking.md) | [networking](https://docs.boxlite.ai/architecture/networking.md) |
| Architecture | Storage (Cache / CoW / QCOW2) | [storage.md](../../docs/architecture/storage.md) | [storage](https://docs.boxlite.ai/architecture/storage.md) |
| Architecture | Boot Latency Analysis | [boot-latency.md](../../docs/architecture/boot-latency.md) | [boot-latency](https://docs.boxlite.ai/architecture/boot-latency.md) |
| Development | Contributing Overview | [index.md](../../docs/development/index.md) | [development](https://docs.boxlite.ai/development/index.md) |
| Development | Building from Source | [building-from-source.md](../../docs/development/building-from-source.md) | [building-from-source](https://docs.boxlite.ai/development/building-from-source.md) |
| Development | CLI Development | [cli-development.md](../../docs/development/cli-development.md) | [cli-development](https://docs.boxlite.ai/development/cli-development.md) |
| Development | Rust Style Guide | [rust-style.md](../../docs/development/rust-style.md) | [rust-style](https://docs.boxlite.ai/development/rust-style.md) |
| Development | Local & CI VM E2E Tests | [e2e-local.md](../../docs/development/e2e-local.md) | [e2e-local](https://docs.boxlite.ai/development/e2e-local.md) |
| Development | macOS Seatbelt Debugging | [macos-sandbox-debugging.md](../../docs/development/macos-sandbox-debugging.md) | [macos-sandbox-debugging](https://docs.boxlite.ai/development/macos-sandbox-debugging.md) |
| Development | Concurrent Exec Deadlock Note | [concurrent-exec-deadlock.md](../../docs/development/concurrent-exec-deadlock.md) | [concurrent-exec-deadlock](https://docs.boxlite.ai/development/concurrent-exec-deadlock.md) |
| Legal | Contributor License Agreement | [CLA.md](../../docs/legal/CLA.md) | [CLA](https://docs.boxlite.ai/legal/CLA.md) |

---

## 1. Execution Chain & Core Components

End-to-end call flow:
```text
Your Code -> SDK -> BoxliteRuntime (src/boxlite/src/runtime/) -> LiteBox (src/boxlite/src/litebox/)
  -> ShimController (src/boxlite/src/vmm/) -> Jailer (src/boxlite/src/jailer/)
  -> boxlite-shim + libkrun MicroVM (src/shim/src/)
  -> Portal gRPC over vsock (src/boxlite/src/portal/) -> boxlite-guest (src/guest/src/)
```

* **Why a Shim Subprocess?**: `libkrun`'s `krun_start_enter` takes over the calling process and never returns; `ShimController` isolates the VMM in `boxlite-shim` so the host process survives and the Jailer has a sandboxable OS child process. (VMM trait supports `Libkrun` default and `Firecracker`.)
* **Guest Agent (`boxlite-guest`)**: Runs inside the VM as gRPC server over vsock with three services: `Guest` (mounts/rootfs/net), `Container` (`youki`/`libcontainer` OCI runtime + single-threaded zygote fork worker), and `Execution` (streaming process I/O).

---

## 2. Two-Layer Security & Isolation Model

1. **Line 1 — Hardware MicroVM**: KVM (Linux) or Apple `Hypervisor.framework` (Apple Silicon). Separate guest kernel, isolated memory, paravirtualized devices only.
2. **Line 2 — Process-Level Jailer (wraps `boxlite-shim`)**:
   * **Linux**: mount/PID/network namespaces, `chroot`/`pivot_root`, `seccomp` BPF allowlist, `bwrap`/`landlock`, privilege drop (`65534` `nobody`/`nogroup`), cgroups v2, `rlimits`, FD/env scrubbing.
   * **macOS**: `sandbox-exec` (Seatbelt SBPL default-deny), `rlimits`, FD/env scrubbing (**no** privilege drop, cgroups, or network namespace — prefer Linux in multi-tenant production).
3. **Default pitfall**: Rust applies jailer defaults when `SecurityOptions` is omitted, whereas Python `SecurityOptions()` with no args turns every switch **off** — always pass `SecurityOptions.standard()` or `SecurityOptions.maximum()` via `AdvancedBoxOptions(security=...)`.

---

## 3. Networking & Storage Internals

### User-Mode Networking (`gvproxy` default, `libslirp` alternative)
 guest `eth0` <-> `vsock` <-> host `gvproxy` (no root, no TUN/TAP):
* **Subnet**: `192.168.127.0/24`
* **Gateway & DNS**: `192.168.127.1` (handles DHCP, NAT, egress DNS allowlist sinkhole to `0.0.0.0`, port forwarding)
* **Guest `eth0` IP**: `192.168.127.2`
* **Host loopback alias**: `192.168.127.254` or DNS `host.boxlite.internal` -> host `127.0.0.1`

### Storage Layers
1. **OCI Image Cache**: Content-addressed blobs in `~/.boxlite/images/` deduplicated across images/boxes.
2. **Rootfs Assembly**: Overlay + Copy-on-Write (CoW) snapshot + injected DNS config.
3. **Volumes**: `virtiofs` host directory shares (`(host, guest, bool_ro)`) and thin-allocated `QCOW2` persistent/cloneable/exportable disks.

---

## 4. Cold vs. Warm Boot Latency (macOS Apple Silicon)

* **Finding**: On a cold box copy on macOS, `handle.start()` measures ~2.1s with Jailer ON vs ~0.7s with Jailer OFF. Only **~5–10ms** comes from Seatbelt policy compilation; **~70% (~1,450ms)** is macOS kernel per-page code-signature validation (`mmap` page faults by `dyld` across ~20.7 MB of freshly copied shim/dylibs).
* `cat` or `codesign --verify` do **NOT** warm the kernel's inode signature cache — **only executing a box warms it** (subsequent warm boxes drop to tens of ms). Pre-warm one box before batch workloads.

---

## 5. Contributor Quick Reference

### Building from Source (`make`, NOT bare `cargo`)

```bash
git clone https://github.com/boxlite-ai/boxlite.git && cd boxlite
git submodule update --init --recursive   # required: libkrun, libkrunfw, e2fsprogs, bubblewrap
make setup                                # installs Rust >=1.88, protoc, Go >=1.24, cmake, musl/llvm
make dev:python                           # or make dev:node / make dev:go / make dev:c / make cli
```

* Supported build hosts: Ubuntu/Debian (`apt`), manylinux (`yum`), musllinux (`apk`), macOS Apple Silicon (macOS Intel **unsupported**). Windows requires WSL2 + KVM.
* CLI binary builds to `./target/debug/boxlite` (`make cli`) or `./target/release/boxlite` (`make cli:release`).

### Testing & CI (`e2e-local.yml` & `src/cli/tests/`)

* `make test` (`test:changed`): runs suites matching working-tree changes only.
* `make test:all`: full unit + integration matrix.
* `make test:integration` / `make test:integration:core` / `make test:integration:cli FILTER=<name>`: runs real microVM tests (`cargo nextest --profile vm --no-fail-fast`).
* CLI tests use `common::boxlite()` (`PerTestBoxHome` with symlinked shared image cache and strict drop guard that fails tests if any shim process leaks).
* CI runs on a persistent AWS EC2 KVM runner (`boxlite-e2e` label, OIDC auth, triggered on PRs labeled `e2e-local` or push to `main`).

### Rust Style & Historical Concurrency Fix

* Follow [Microsoft Rust Guidelines](https://microsoft.github.io/rust-guidelines): avoid panics for recoverable errors, use `#[expect]` over `#[allow]`, implement `Debug`/`Display` on public types, and make public structs `Send + Sync` (`Arc` instead of `Rc`).
* **Async I/O only**: Use `tokio::fs`, never `std::fs` inside async tasks.
* **Errors**: Use `boxlite_shared::BoxliteError` variants (`Storage`, `Config`, `Image`, `Network`, `Execution`, `NotFound`, `AlreadyExists`, `InvalidState`, `InvalidArgument`, `Stopped`, `Internal` — **there is no `BoxliteError::Run`**).
* **macOS Seatbelt Debugging**: Stream denials in a separate terminal *before* running repros:
  `log stream --predicate 'eventMessage CONTAINS "Sandbox:" AND eventMessage CONTAINS "boxlite" AND eventMessage CONTAINS "deny"'`. Rebuild after `.sbpl` edits (`cargo clean -p boxlite && make dev:python`) because `.sbpl` files are embedded via `include_str!`. (Account for `/var` -> `/private/var`, `/tmp` -> `/private/tmp` symlinks.)
* **Zygote Fix (Historical)**: `boxlite-guest` uses static musl (`aarch64-unknown-linux-musl`), where `clone3()` from a multi-threaded Tokio worker previously risked deadlocking on musl's `__malloc_lock` inside `libcontainer`. Resolved permanently via a single-threaded pre-Tokio zygote in `src/guest/src/container/zygote.rs`.
* **CLA**: Submissions are licensed under Apache License 2.0 per [CLA.md](../../docs/legal/CLA.md).
