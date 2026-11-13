---
name: boxlite-manage-sandboxes
description: Manage BoxLite local sandboxes end-to-end — box types (SimpleBox, CodeBox, BrowserBox, ComputerBox, InteractiveBox, SkillBox), compute limits (CPU, memory, disk), environment/entrypoint/workdir, volume mounts & copy_in/copy_out, lifecycle states (detach/auto_remove/reuse_existing), networking (ports, egress allowlists, inbound), snapshots/clones/export/import, and local Secrets + SecurityOptions (jailer, seccomp).
---

# Manage BoxLite Sandboxes

Complete guide for configuring, running, networking, snapshotting, and hardening local BoxLite microVM sandboxes.

## Documentation Map (9 Pages)

| Topic | Local Doc | Live Docs |
| - | - | - |
| Overview | [index.md](../../docs/manage-sandbox/index.md) | [manage-sandbox](https://docs.boxlite.ai/manage-sandbox/index.md) |
| Box Types | [sandbox-types.md](../../docs/manage-sandbox/sandbox-types.md) | [sandbox-types](https://docs.boxlite.ai/manage-sandbox/sandbox-types.md) |
| Compute Resources | [compute-resources.md](../../docs/manage-sandbox/compute-resources.md) | [compute-resources](https://docs.boxlite.ai/manage-sandbox/compute-resources.md) |
| Environment & Entrypoint | [environment.md](../../docs/manage-sandbox/environment.md) | [environment](https://docs.boxlite.ai/manage-sandbox/environment.md) |
| Volumes & File Copy | [volumes.md](../../docs/manage-sandbox/volumes.md) | [volumes](https://docs.boxlite.ai/manage-sandbox/volumes.md) |
| Lifecycle States | [lifecycle.md](../../docs/manage-sandbox/lifecycle.md) | [lifecycle](https://docs.boxlite.ai/manage-sandbox/lifecycle.md) |
| Network Access | [network-access.md](../../docs/manage-sandbox/network-access.md) | [network-access](https://docs.boxlite.ai/manage-sandbox/network-access.md) |
| Snapshots, Clones, Export | [snapshots.md](../../docs/manage-sandbox/snapshots.md) | [snapshots](https://docs.boxlite.ai/manage-sandbox/snapshots.md) |
| Local Secrets & SecurityOptions | [secrets-and-security.md](../../docs/manage-sandbox/secrets-and-security.md) | [secrets-and-security](https://docs.boxlite.ai/manage-sandbox/secrets-and-security.md) |

---

## 1. Box Types (`SimpleBox` Hierarchy)

All six Python/Node high-level sandbox classes inherit from `SimpleBox` and implement async context management (`async with` in Python, `await using` or explicit `stop()` in TypeScript `@boxlite-ai/boxlite`).

| Class | Use Case | Default Resources / Notes |
| - | - | - |
| `SimpleBox` | General-purpose command execution (`exec`), base class | Unset `cpus`/`memory_mib` default at runtime to `1 vCPU / 1024 MiB`; `10 GB` sparse rootfs |
| `CodeBox` | Sandboxed Python code execution (`run(code, timeout=None)`) | Built for executing untrusted Python snippets |
| `BrowserBox` | Headless/CDP browser automation (`endpoint()`, Chrome/Chromium) | Defaults to `cpu=2`, `memory=2048` |
| `ComputerBox` | GUI desktop + mouse/keyboard/screenshot (`screenshot()`, `click()`, `mouse_move()`, `type()`, `key()`) | Defaults to `cpu=2`, `memory=2048` |
| `InteractiveBox` | Interactive TTY shell session over stdin/stdout streams | Full PTY workflow |
| `SkillBox` | Skill-equipped agent environment (`skills=[...]`) | Defaults to `memory_mib=4096`, `disk_size_gb=10` |

* Every specialized box keeps `exec(...)`, `copy_in(...)`, `copy_out(...)`, `info()`, and lifecycle kwargs from `SimpleBox`.
* Node.js/TypeScript uses `@boxlite-ai/boxlite` (ESM), camelCase options, and `await box.stop()` or `await using`.

---

## 2. Compute Resources (`cpus`, `memory_mib`, `disk_size_gb`)

| Parameter (Python) | Parameter (Node) | Type | Default Behavior | Notes |
| - | - | - | - | - |
| `cpus` | `cpus` | `int` (`u8`, 1–255) | Runtime default: `1` vCPU | `> 255` raises `OverflowError` in SDK; CLI clamps to `255` with a warning |
| `memory_mib` | `memoryMib` | `int` (MiB) | Runtime default: `1024` MiB | Unset SDK options do **not** apply `DEFAULT_*` SDK constants; runtime `vm_defaults` apply |
| `disk_size_gb` | `diskSizeGb` | `int` (GB) | `10` GB sparse qcow2 | Sparse disk capped at `disk_size_gb`; zero-allocated on host until written |

> Note: Never guess `disk_gib` — the parameter is `disk_size_gb` (Python/REST `disk_size_gb`, Node `diskSizeGb`).

---

## 3. Environment, Working Directory, and Entrypoint

### Construction vs. Per-Exec `env` and `cwd`

| Scope | Python Type | Node Type | Behavior if Invalid / Missing |
| - | - | - | - |
| `SimpleBox(..., env=...)` / `BoxOptions(env=...)` | `list[tuple[str, str]]` | `Record<string, string>` | Applied to guest PID 1 and inherited by execs |
| `box.exec(..., env=...)` | `dict[str, str]` | `Record<string, string>` | Applies only to that `exec` call |
| `SimpleBox(..., working_dir=...)` / `BoxOptions(working_dir=...)` | `str` | `workingDir?: string` | **Missing directory fails box creation** |
| `box.exec(..., cwd=...)` | `str` | `cwd?: string` | Missing directory fails only that `exec` (does not kill the box) |

### Entrypoint and CMD Interaction

* Passing `entrypoint=[...]` replaces the image `ENTRYPOINT` **and discards the image's default `CMD`**.
* Passing `entrypoint=[]` explicitly drops the image `ENTRYPOINT` while keeping the image `CMD`.
* Overriding `cmd=[...]` drops the image `WORKDIR` — set `working_dir` explicitly if your command relies on a working directory.

---

## 4. Volumes and File Transfer (`volumes`, `copy_in`, `copy_out`)

### Host Bind Mounts (`volumes`)

| SDK / CLI | Accepted Forms | Read-Only Rule |
| - | - | - |
| Python `SimpleBox` / `BoxOptions` | `(host, guest)`, `(host, guest, bool)`, or `{"host": ..., "guest": ..., "read_only": ...}` (`host_path`/`guest_path`/`ro` aliases accepted) | 3rd tuple element **MUST be a `bool`** (`True`/`False`). Passing `"ro"` or `"rw"` raises `TypeError`! |
| Node `@boxlite-ai/boxlite` | `{ hostPath, guestPath, readOnly? }` | `readOnly` is boolean |
| CLI (`boxlite run -v` / `create -v`) | `-v /host:/guest[:ro\|rw]` | Only the CLI uses `:ro` / `:rw` string suffixes |

### Host <-> Guest Copy (`copy_in` / `copy_out`)

Both `await box.copy_in(host_src, guest_dst)` and `await box.copy_out(guest_src, host_dst)` are **async**:
* Append `/.` to copy directory **contents** rather than nesting the source directory name (`SRC/.`).
* Note: `include_parent` was **removed in v0.10.6** — use `SRC/.` semantics instead.
* Avoid `/tmp` and `/dev/shm` as destinations for persistent data or `copy_in` inputs that must survive VM restarts: they are ephemeral `tmpfs` mounts.

---

## 5. Lifecycle States, `detach`, `auto_remove`, and Multi-Process Sharing

```
Created (lazy handle, no VM) --[async with / start() / 1st exec()]--> Running (VM + rootfs up)
Running --[stop() / PID 1 exits]--> Stopped (VM released, rootfs + DB metadata kept)
Stopped --[start() / exec()]--> Running (disk intact)
Stopped / Running --[runtime.remove(id, force=...) / auto_remove=True on stop]--> Removed
```

### Key Rules

1. **Creation is lazy**: `SimpleBox(...)` or `await runtime.create(...)` creates only a handle + DB record until `async with`, `await box.start()`, or the first `await box.exec(...)`.
2. **Main command = PID 1**: The box stops whenever PID 1 (`entrypoint + cmd`) exits. (`kill -TERM 1` is ignored by Linux PID 1 unless trapped; there is no auto-restart policy.)
3. **`await box.info()` is ALWAYS async**: Call `info = await box.info()`, never `box.info()`. `info.state` is a `BoxStateInfo` with `.pid`, `.running`, `.status` (no exit code — for PID 1 exit code, use native `exec = await box.attach()` and `await exec.wait()`).
4. **Stop invalidates the box handle**: After `await box.stop()` (or `snapshot.restore()`), re-acquire a handle via `box = await runtime.get(box.id)` before calling `exec()`.
5. **`detach` and `auto_remove`**:
   * `detach=True` combined with `auto_remove=True` is **invalid**. Use `detach=True, auto_remove=False` (or on Cloud, `auto_delete=0`).
   * Keep `auto_remove=False` if you plan to call `clone_box()`, `export()`, or reattach later with `runtime.get(id_or_name)`.
6. **Cross-process runtime sharing**:
   * **Never** use singleton `boxlite.Boxlite.default()` / `JsBoxlite.withDefaultConfig()` across multiple processes — a stale lock remains in `$BOXLITE_HOME/locks/`.
   * Instead create isolated runtimes: `boxlite.Boxlite(boxlite.Options(home_dir=...))` / `new JsBoxlite({ homeDir: ... })` or talk to a single daemon via `boxlite serve` + `Boxlite.rest(...)`.
7. **Cleanup methods live on `runtime`**: Call `await runtime.remove(box.id, force=True)` and `await runtime.list_info()`, NOT `box.remove()` or `runtime.list()`.

---

## 6. Networking (`ports` & `NetworkSpec`)

The sandbox runs a user-mode network stack (`gvproxy`) with guest NIC IP `192.168.127.2`.

### Port Forwarding (`ports`)

* Python tuples: `(host_port, guest_port)`, `(host_port, guest_port, protocol)`, `(host_port, guest_port, protocol, host_ip)` or dict `{"guest_port": 8080, "host_port": 18080, "protocol": "tcp", "host_ip": ...}`.
* Node: `[{ hostPort, guestPort, protocol? }]`.
* **CRITICAL**: Your in-sandbox server **MUST bind to `0.0.0.0`**, NOT `127.0.0.1`! `gvproxy` forwards host traffic to `192.168.127.2`, which cannot reach guest loopback (`127.0.0.1`).
* CLI `-p` currently supports TCP only; use the SDK for `protocol="udp"`.

### Network Policy (`NetworkSpec`)

`NetworkSpec` separates **outbound** (egress) and **inbound** (public reachability):

```python
from boxlite import NetworkSpec, OutboundNetworkSpec, InboundNetworkSpec, SimpleBox

# Egress allowlist only (DNS sinkholes non-allowed hosts to 0.0.0.0)
net_allow = NetworkSpec(
    outbound=OutboundNetworkSpec(mode="enabled", allow_net=["example.com", "*.openai.com"])
)

# Fully offline sandbox (no NIC)
net_off = NetworkSpec(outbound=OutboundNetworkSpec(mode="disabled"))

# Public inbound enabled (since v0.10.5, inbound defaults to "disabled"!)
net_public = NetworkSpec(inbound=InboundNetworkSpec(mode="enabled"))
```

* `InboundNetworkSpec.allow_net` **must stay empty (`[]`)** — passing entries raises `InvalidArgumentError`.
* **Do not mix** nested `outbound=...`/`inbound=...` with legacy flat `NetworkSpec(mode=..., allow_net=...)` (`ValueError`), and do not expect legacy `NetworkSpec(mode="enabled")` to open inbound traffic (it sets outbound only).
* **How to test egress allowlists**: Blocked domains resolve to `0.0.0.0` via DNS sinkhole, and `nslookup` may still return `exit_code == 0`. Check `"0.0.0.0" in res.stdout`.

---

## 7. Snapshots, Clones, and Export / Import

| Operation | API | Purpose & Caveats |
| - | - | - |
| Snapshot create | `await box.snapshot.create(name="v1")` | `name` is **keyword-only** (`create(*, options=None, name)`). Returns `SnapshotInfo` |
| Snapshot list / get / remove | `await box.snapshot.list()` / `get(name)` / `remove(name)` | Cannot `remove` a snapshot the current disk depends on (`RuntimeError`) |
| Snapshot restore | `await box.stop()`, `await box.snapshot.restore("v1")`, `box = await runtime.get(box.id)` | Must stop first; handle is invalidated on stop. Note: in-place `restore` is not a guaranteed clean rollback if guest already flushed disk writes — prefer `clone_box` / `export` for clean isolation |
| Clone | `cloned = await box.clone_box(name="copy")` | Independent copy; requires `auto_remove=False` on source to tear down source before clone cleanly |
| Export | `archive = await box.export(dest="/tmp/dir")` | Produces portable `.boxlite` archive; requires `auto_remove=False` on source if exited |
| Import | `imp = await runtime.import_box(archive_path, name="restored")` | Called on **`runtime`**, not on a box |

---

## 8. Local Secrets & Security Hardening

### Secret Proxy Injection (Zero In-Box Exposure)

BoxLite's outbound HTTPS MITM proxy injects host-side credentials only when the guest talks to allowed `hosts`, keeping real API keys out of guest environment variables and disk:

```python
import boxlite

secret = boxlite.Secret(
    name="model",
    value="sk-real-key",           # Stays on host only
    hosts=["api.openai.com"],      # Always scope hosts (exact or *.domain); empty = ANY host!
    headers={"Authorization": "Bearer {value}"},
    # placeholder defaults to "<BOXLITE_SECRET:model>"
)

box = await runtime.create(boxlite.BoxOptions(
    image="python:alpine",
    secrets=[secret],
))
```

* Inside the guest, send HTTP requests to `https://api.openai.com/...` with header `"Authorization": "Bearer <BOXLITE_SECRET:model>"` and trust the system CA bundle (`/etc/ssl/certs/ca-certificates.crt`).
* **Rules**:
  * Placeholders are substituted in **request headers**, **URL query string**, and **request body** — **NOT** in the URL path.
  * When using custom `headers` dicts, provide explicit `"Authorization": "Bearer {value}"` (or required header name). Proxy replaces existing matching headers for listed `hosts`.
  * Egress must be HTTPS and pass through the BoxLite proxy (`outbound` not disabled).
  * Node.js passes `secrets` directly on `SimpleBox` options: `{ name, value, hosts, headers?, placeholder? }`.

### OS Hardening (`SecurityOptions` + `AdvancedBoxOptions`)

Python separates OS isolation behind `AdvancedBoxOptions`:

```python
from boxlite import SimpleBox, SecurityOptions, AdvancedBoxOptions
# Note: in older SDKs, AdvancedBoxOptions may require: from boxlite.boxlite import AdvancedBoxOptions

advanced = AdvancedBoxOptions(security=SecurityOptions.maximum())
async with SimpleBox(image="alpine:latest", advanced=advanced) as box:
    ...
```

| Preset (Python) | Jailer | Seccomp | Resource Limits | `close_fds` |
| - | - | - | - | - |
| `SecurityOptions.development()` | Off | Off | None | Off |
| `SecurityOptions.standard()` | On (Linux/macOS) | On (Linux only) | None | On |
| `SecurityOptions.maximum()` | On | On (Linux only) | `max_open_files=1024`, `max_file_size=1 GiB`, `max_processes=100` | On |

* There is **no `SecurityOptions.minimum()`** (use `development()`) and **no top-level `security=` argument** on `BoxOptions` / `SimpleBox` in Python.
* `seccomp_enabled`, `new_pid_ns`, `new_net_ns`, and `chroot` are **Linux-only** (ignored with a warning on macOS); `network_enabled` on `SecurityOptions` is **macOS-relevant only**.
* In Node.js, `security` is a top-level field on `SimpleBoxOptions` with camelCase fields (`{ jailerEnabled, seccompEnabled, maxOpenFiles, maxProcesses, closeFds }`) and no `maximum()` preset.

---

## Troubleshooting Quick Reference

| Error / Symptom | Root Cause | Fix |
| - | - | - |
| Port forward refuses connection | Server inside guest bound to `127.0.0.1` | Bind guest server to `0.0.0.0` |
| `TypeError` on Python `volumes` | Passed `"ro"`/`"rw"` string as 3rd tuple element | Pass `bool`: `(host, guest, True)` |
| `include_parent` keyword error | Removed in BoxLite `0.10.6` | Append `/.` to source path for contents |
| `box.exec` ignores non-zero failure | `exec` returns `ExecResult(exit_code!=0)`, never raises | Always assert/check `result.exit_code == 0` |
| Missing command or pull failure not caught by `BoxliteError` | Raises standard `RuntimeError` (Python) / bare `Error` (Node) | Catch `Exception` / `Error` around startup/exec |
| `RuntimeError: invalid state` on teardown after clone | `auto_remove=True` tries to delete source while clone exists | Create clone sources with `auto_remove=False` |
| `Handle invalidated after stop()` | Used old `Box` handle after `stop()` or `restore()` | Re-fetch with `box = await runtime.get(box.id)` |
| Stale lock across Python/Node processes | Shared `Boxlite.default()` singleton across processes | Use `Boxlite(Options(home_dir=...))` per process or `boxlite serve` |
