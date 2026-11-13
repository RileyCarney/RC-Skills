---
name: boxlite-sdk-cli-reference
description: Complete API and CLI reference for BoxLite across Python, Node.js, Rust, Go, C, and the boxlite CLI, covering runtime constructors, box options, execution streams, metrics, error handling, REST remote clients, and cross-SDK differences.
---

# BoxLite SDK & CLI Reference

Comprehensive API reference across all five BoxLite SDKs (**Python**, **Node.js**, **Rust**, **Go**, **C**) and the **`boxlite` CLI**, including cross-SDK differences, remote REST configuration, error hierarchies, and common traps.

## Reference Documentation Index

| Topic | Local Mirror | Live Docs |
| - | - | - |
| Reference Overview | [reference/index.md](../../docs/reference/index.md) | [docs.boxlite.ai/reference/index](https://docs.boxlite.ai/reference/index.md) |
| Python SDK Reference | [reference/python.md](../../docs/reference/python.md) | [docs.boxlite.ai/reference/python](https://docs.boxlite.ai/reference/python.md) |
| Node.js SDK Reference | [reference/nodejs.md](../../docs/reference/nodejs.md) | [docs.boxlite.ai/reference/nodejs](https://docs.boxlite.ai/reference/nodejs.md) |
| Rust SDK Reference | [reference/rust.md](../../docs/reference/rust.md) | [docs.boxlite.ai/reference/rust](https://docs.boxlite.ai/reference/rust.md) |
| Go SDK Reference | [reference/go.md](../../docs/reference/go.md) | [docs.boxlite.ai/reference/go](https://docs.boxlite.ai/reference/go.md) |
| C SDK Reference | [reference/c.md](../../docs/reference/c.md) | [docs.boxlite.ai/reference/c](https://docs.boxlite.ai/reference/c.md) |
| CLI Reference | [reference/cli.md](../../docs/reference/cli.md) | [docs.boxlite.ai/reference/cli](https://docs.boxlite.ai/reference/cli.md) |

---

## Cross-SDK Comparison & Critical Traps

Always account for these exact behavioral differences when switching between SDKs or the CLI:

| Feature / Behavior | Python (`boxlite`) | Node.js (`@boxlite-ai/boxlite`) | Rust (`boxlite`) | Go (`sdks/go`) | C (`boxlite.h`) | CLI (`boxlite`) |
| - | - | - | - | - | - | - |
| **Volume read-only** | `bool` (`(host, guest, True)`) | `boolean` (`{ hostPath, guestPath, readOnly: true }`) | `bool` on `VolumeSpec` | Separate `WithVolumeReadOnly(h, g)` option | `int read_only` (`1`/`0`) | String `-v host:guest:ro` / `:rw` |
| **Resource fallback when omitted** | `1 vCPU / 1024 MiB` | `1 vCPU / 1024 MiB` (exported `DEFAULT_CPUS`/`DEFAULT_MEMORY_MIB` are NOT applied) | `None` -> runtime allocates `1 vCPU / 1024 MiB` | Runtime allocates `1 vCPU / 1024 MiB` | Passing `0` -> runtime allocates `1 vCPU / 1024 MiB` | Same runtime fallback |
| **Constructor `env` format** | `list[tuple[str, str]]` on `BoxOptions`, `SimpleBox`, `InteractiveBox` | `Array<[string, string]>` (`env` on `BoxOptions`/`SimpleBox`) | `Vec<(String, String)>` on `BoxOptions` | `WithEnv(k, v)` (one pair per call) | `const char *` options / JSON | `-e KEY=VAL` (repeatable) |
| **`exec` `env` format** | `SimpleBox.exec(env={"K": "V"})` (`dict[str, str]`) | `SimpleBox.exec(cmd, args, env?)` (`Record<string, string>`) | `BoxCommand::env(k, v)` | `ExecutionOptions{Env: map[string]string}` | `env` in JSON cmd / options | `--env KEY=VAL` |
| **`exec` timeout parameter** | `SimpleBox.exec(..., timeout=5.0)` (kills w/ SIGTERM -> `exit_code=-15`); native `Box.exec(..., timeout_secs=5.0)` | `SimpleBox.exec(cmd, args, env, { timeoutSecs })` | `BoxCommand::timeout(...)` | `ctx` deadline / `ExecutionOptions` | `timeout_secs` in options | `--timeout` / context |
| **Command exits non-zero** | `ExecResult(exit_code != 0)` (no raise; `CodeBox.run()` returns stdout string & never raises) | `SimpleBox.exec()` returns `ExecResult` (no raise); `CodeBox.run()` throws `ExecError` | `Execution::wait()` returns `ExecResult { exit_code, error_message }` (no raise) | `Exec` and `Cmd.Run`/`Output` return `nil` `err`; check `ExitCode` | `boxlite_simple_run` / `WaitCb` returns `Ok` with `exit_code` | Propagates exit code `1..127`, or `128+N` on signal |
| **Command not found / spawn failure** | Raises standard `RuntimeError` (not `BoxliteError`) | Throws bare `Error` (`instanceof BoxliteError === false`) | `Err(BoxliteError::Execution(...))` or `Internal` | Returns `(nil, *boxlite.Error)` (`Code = ErrInternal` / `1`) — check `err` before `res`! | Returns error / non-Ok `BoxliteErrorCode` | Exits `1` (`Error: ...`) |
| **Box state path** | `(await box.info()).state.status` | `(await box.info()).state.status` | `(litebox.info().await?).status` (`BoxStatus` enum directly) | `info.State` (string; `paused`/`failed` may have no Go constant) | `CBoxInfo` | `boxlite inspect` / `list` |
| **`metrics()`** | Native `await box.metrics()` (not on `SimpleBox`; use `box._box.metrics()`) | `await simpleBox.metrics()` or native `JsBox.metrics()`; field is `memoryBytes` | `litebox.metrics().await?`, `runtime.metrics().await?` (methods: `.num_running_boxes()`) | `box.Metrics(ctx)`, `rt.Metrics(ctx)` (`RunningBoxes`, no `Num` prefix) | `boxlite_runtime_metrics` / `boxlite_box_metrics` (drain) | `boxlite stats` |
| **REST routing prefix** | `Boxlite.rest(BoxliteRestOptions(url, credential, path_prefix))` | `JsBoxlite.rest(new BoxliteRestOptions({ url, credential, pathPrefix }))` | `BoxliteRuntime::rest(BoxliteRestOptions)` (requires `rest` crate feature) | Via REST client / CLI | Via options | `boxlite --url ...` or `boxlite auth login` |

---

## 1. Python SDK (`boxlite`)

- **Package**: `pip install boxlite` (optional extras: `pip install "boxlite[sync]"`, `pip install "boxlite[orchestration]"`).
- **High-level async classes**: `SimpleBox`, `CodeBox` (default `"python:slim"`, `run()` returns stdout string only and never raises), `BrowserBox` (requires `playwright==1.58.0`), `ComputerBox` (`1024x768`), `InteractiveBox`, `SkillBox`. All support `async with ... as box:`.
- **Sync wrappers (`boxlite[sync]`)**: `SyncBoxlite`, `SyncBox`, `SyncSimpleBox`, `SyncCodeBox`, `SyncSkillBox`. Cannot be called inside an existing asyncio event loop.
  - **Trap**: When `[sync]` extras are missing, `from boxlite import SyncSimpleBox` raises `ImportError`, whereas `boxlite.SyncSimpleBox` raises `AttributeError`.
- **Native Runtime & Box**:
  - `runtime = Boxlite.default()` or `Boxlite(Options(home_dir=..., image_registries=[...]))`
  - `runtime = Boxlite.rest(BoxliteRestOptions(url=..., credential=ApiKeyCredential(...), path_prefix=...))`
  - Methods: `await runtime.create(BoxOptions(...), name=...)`, `await runtime.get_or_create(...)`, `await runtime.get(id_or_name)`, `await runtime.list_info()`, `await runtime.get_info(id_or_name)`, `await runtime.remove(id_or_name, force=False)`, `await runtime.metrics()`, `await runtime.shutdown()`.
  - Native `Box`: `await box.exec(cmd, args=[], env=[], timeout_secs=None)` returns `Execution` (streams stdout/stderr, `await execution.wait()` returns `ExecResult(exit_code, error_message)` — **not** `stdout`/`stderr`), `await box.info()` -> `state.status`, `await box.metrics()` (`memory_bytes`, `cpu_percent`), `await box.stop()`.
- **Security & Options Trap**:
  - `AdvancedBoxOptions` is imported from `boxlite` (lives in `boxlite.boxlite`, NOT `boxlite.AdvancedBoxOptions` via `import boxlite` module attribute in older imports; use `from boxlite import AdvancedBoxOptions`).
  - `BoxOptions` has NO top-level `security=` argument — pass `advanced=AdvancedBoxOptions(security=SecurityOptions.maximum())`.
  - Presets on `SecurityOptions`: `development()`, `standard()`, `maximum()`. (`minimum()` does NOT exist.)
- **Exceptions**: `BoxliteError` -> `ExecError(command, exit_code, stderr)`, `TimeoutError`, `ParseError`. Note: `exec` does not raise `ExecError` on non-zero exit; spawn/pull/missing-KVM raise built-in `RuntimeError`.

---

## 2. Node.js / TypeScript SDK (`@boxlite-ai/boxlite`)

- **Package & Module System**: `npm install @boxlite-ai/boxlite` (**ESM-only**; use `.mjs`, `"type": "module"`, or dynamic `import()`). Wrong package names like `boxlite` or `@boxlite/sdk` do not exist.
- **High-Level Classes**: `SimpleBox`, `CodeBox`, `BrowserBox`, `ComputerBox`, `InteractiveBox`, `SkillBox`.
  - Supports `await using box = new SimpleBox(...)` via `[Symbol.asyncDispose]`.
  - **Lazy getters trap**: `SimpleBox` getters `box.id`, `box.name`, `box.created` throw synchronously if read before the box starts; use `await box.getId()`, `await box.getInfo()`, `await box.info()`, or call `exec()` first.
  - **`CodeBox.run()`**: Unlike Python, Node.js `CodeBox.run()` **throws `ExecError`** if the code fails.
  - **`BrowserBox`**: Requires `playwright-core >= 1.58.0` (`optional` peer dependency). `endpoint()` supports CDP/BiDi (Chromium/Firefox); WebKit requires `playwrightEndpoint()`.
- **Native Classes (`JsBoxlite`, `JsBox`, `JsExecution`)**:
  - `JsBoxlite.withDefaultConfig()`, `JsBoxlite.rest(new BoxliteRestOptions({ url, credential: new ApiKeyCredential(...), pathPrefix }))` (`pathPrefix` inserts `/v1/{pathPrefix}/...`).
  - `await runtime.images.pull(ref)`, `await runtime.images.list()`, `runtime.close()`.
  - `JsExecution`: `stdin()` (`write`, `writeString`, `close`), single-use `stdout()` / `stderr()` async streams with `await stream.next()` returning `string | null`.
- **Errors & Metrics**:
  - Command-not-found / image pull / missing KVM throw bare `Error` (often from napi), NOT `ExecError`. Validate volumes with `readOnly: true` (boolean), never `"ro"`.
  - `JsRuntimeMetrics` fields: `boxesCreatedTotal`, `boxesFailedTotal`, `numRunningBoxes`, `totalCommandsExecuted`, `totalExecErrors`.
  - `JsBoxMetrics` fields: `commandsExecutedTotal`, `execErrorsTotal`, `bytesSentTotal`, `bytesReceivedTotal`, `cpuPercent`, `memoryBytes`, `networkBytesSent`, `networkBytesReceived`, `guestBootDurationMs`, `totalCreateDurationMs`.

---

## 3. Rust SDK (`boxlite`)

- **Crate**: `boxlite = "0.10"` (Tokio async runtime; enable `features = ["rest"]` for `BoxliteRestOptions` / `BoxliteRuntime::rest`).
- **Runtime Constructors (Synchronous) vs Operations (Async)**:
  - Sync: `BoxliteRuntime::with_defaults()?`, `BoxliteRuntime::new(options)?`, `BoxliteRuntime::rest(rest_opts)?`, `BoxliteRuntime::default_runtime()`, `BoxliteRuntime::try_default_runtime()`, `BoxliteRuntime::init_default_runtime(options)?`.
  - Async: `.create(BoxOptions, name).await?`, `.get_or_create(options, name).await?`, `.get(id_or_name).await?`, `.get_info(id_or_name).await?`, `.list_info().await?`, `.exists(id_or_name).await?`, `.metrics().await?`, `.remove(id_or_name, force).await?`, `.import_box(BoxArchive::new(path), name).await?`, `.shutdown(timeout).await?`.
  - `BoxliteRuntime` and `LiteBox` are `Send + Sync`.
- **`LiteBox` API**:
  - No `.run()` method — use `litebox.exec(BoxCommand::new("cmd").args(["a"]).env("K", "V"))`.
  - `ExecResult` contains ONLY `exit_code` and `error_message`. Read output via one-shot `execution.stdout()` / `execution.stderr()` implementing `futures::Stream<Item = String>`.
  - Lifecycle/data: `start().await?`, `stop().await?`, `info().await?` (`info.status` is `BoxStatus` enum: `Configured`, `Running`, `Stopping`, `Stopped`, `Paused`, `Failed`), `metrics().await?`, `copy_into(...)`, `copy_out(...)`.
  - Snapshots/clones/export: `litebox.snapshots()`, `clone_box`, `clone_boxes`, `export`.
  - **Local-only SSH control**: `litebox.ssh().configure(SshConfig)`, `.status()`, `.disable()` — returns `BoxliteError::Unsupported` over REST/Cloud.
- **Options, Types & Errors**:
  - `SecurityOptions`: `enabled()`, `disabled()`, `from_preset(...)`, `builder()` (default `ResourceLimits`: 1024 open files, 1 GiB max file size, 100 processes; NO `development/standard/maximum` presets).
  - `Secret` has no `Default` — all 4 fields (`name`, `hosts`, `placeholder`, `value`) required.
  - Utilities: `Bytes` (`from_mib`, `from_gib`, `as_bytes`), `Seconds`, `BoxID` (12-char Base62 locally, up to 128 chars remotely), `ContainerID` (64 lowercase hex chars).
  - `RuntimeMetrics` uses **methods**: `num_running_boxes()`, `boxes_created_total()`, `total_commands_executed()`, `total_exec_errors()`.
  - `BoxliteError` (21 variants): `UnsupportedEngine`, `Engine`, `Config`, `Storage`, `Image`, `Portal`, `Network`, `Rpc`, `RpcTransport`, `Internal`, `Execution`, `Unsupported`, `NotFound`, `AlreadyExists`, `InvalidState`, `Database`, `MetadataError`, `InvalidArgument`, `Stopped`, `ResourceExhausted`, `SessionReaped`. (**There is NO `BoxliteError::Run`.**)

---

## 4. Go SDK (`github.com/boxlite-ai/boxlite/sdks/go`)

- **Setup**: Requires cgo and one-time native library download: `go run github.com/boxlite-ai/boxlite/sdks/go/cmd/setup` (re-run if slow network hits `context deadline exceeded`; it resumes from extracted files). On macOS, `ld: warning: ignoring duplicate libraries: '-lresolv'` is harmless.
- **Runtime & Box**:
  - `rt, err := boxlite.NewRuntime(boxlite.WithHomeDir(...), boxlite.WithImageRegistry(...), boxlite.WithImageRegistries(...))` (`defer rt.Close()`).
  - `*Runtime`: `Create(ctx, opts...)`, `GetOrCreate(ctx, opts...)`, `Get(ctx, idOrName)`, `ListInfo(ctx)`, `GetInfo(ctx, idOrName)`, `Remove(ctx, idOrName)`, `ForceRemove(ctx, idOrName)`, `Metrics(ctx)`, `Images()`, `Shutdown(ctx, timeout)`.
  - `*Box`: `ID()`, `Name()`, `Info(ctx)`, `Start(ctx)`, `Exec(ctx, cmd, args...)`, `StartExecution(ctx, opts)`, `Command(ctx, cmd, args...)` -> `*Cmd`, `Metrics(ctx)`, `Stop(ctx)`, `CopyInto(ctx, ...)`, `CopyOut(ctx, ...)`, `Close()`.
- **Functional Options (`BoxOption`)**:
  - `WithCPUs`, `WithMemoryMiB`, `WithDiskSizeGB`, `WithImage`, `WithRootfs`, `WithWorkingDir`, `WithEntrypoint`, `WithCmd`, `WithUser`
  - `WithEnv(k, v)` — one key/value pair per call (vs `ExecutionOptions{Env: map[string]string}`)
  - `WithVolume(host, guest)` vs `WithVolumeReadOnly(host, guest)`
  - `WithPort(host, guest, proto)`, `WithNetwork(...)`, `WithAllowNet(...)`, `WithSecret(...)`, `WithAutoDeleteInterval(...)` (`WithAutoRemove` is deprecated).
- **Critical Go Traps**:
  1. **Nil-pointer panic on failed `Exec`**: If spawn fails (e.g., missing binary), `res, err := box.Exec(...)` returns `(nil, err)`. Check `if err != nil` before accessing `res.ExitCode`!
  2. **`Cmd.Run`/`Output`/`CombinedOutput` non-zero exit**: Unlike `os/exec`, BoxLite returns `err == nil` on non-zero exit codes. Always check `res.ExitCode` or `cmd.ExitCode()`.
  3. **`RuntimeMetrics.RunningBoxes`**: Uses `RunningBoxes` (NO `Num` prefix).
  4. **`*boxlite.Error`**: Inspect `.Code` (`ErrInternal = 1` .. `ErrSessionReaped = 21`) and `.Message`. Note that binary spawn failures return `ErrInternal` (`1`), not necessarily `ErrExecution`.

---

## 5. C SDK (`sdks/c/include/boxlite.h`)

- **Build**: `cargo build --release -p boxlite-c` -> `libboxlite` (`LD_LIBRARY_PATH` on Linux, `DYLD_LIBRARY_PATH` or `install_name_tool -add_rpath` on macOS).
- **Two APIs**:
  1. **Simple API (Synchronous)**: `boxlite_simple_new(image, cpus, memory_mib, ...)`, `boxlite_simple_run(...)` -> `CBoxliteExecResult*`, `boxlite_result_free`, `boxlite_simple_free`. Passing `0` for `cpus`/`memory_mib` uses engine fallback `1 vCPU / 1024 MiB`. Cannot configure volumes/network/security.
  2. **Native API (Post-and-Drain Callback Model)**:
     - **MUST run drain loop**: Async calls (`boxlite_create_box`, `boxlite_start_box`, `boxlite_stop_box`, `boxlite_get`, `boxlite_remove`, `boxlite_execution_wait`, `boxlite_execution_kill`, `boxlite_execution_signal`, `boxlite_execution_tty_resize`, `copy_into`, `copy_out`, `info`, `metrics`, `image_pull`, `image_list`, `shutdown`) do **NOT** dispatch callbacks until `boxlite_runtime_drain(runtime, timeout_ms, &err)` is polled in a loop until completion!
     - **Execution handle**: `boxlite_box_exec(handle, &cmd, &out_exec, &err)` returns `CExecutionHandle*` synchronously (there is NO `boxlite_execute` function). Attach `on_stdout`/`on_stderr` callbacks **before** calling `boxlite_execution_wait(exec, cb, ud, &err)`.
     - **Interactive I/O**: `boxlite_execution_stdin_write` and `boxlite_execution_stdin_close` are synchronous (no drain needed); `signal` / `tty_resize` / `kill` are async (need drain).
     - **Volumes & Security**: `boxlite_options_add_bind_mount(opts, host, guest, int read_only)` (`1` = RO, `0` = RW — never `"ro"`). `boxlite_advanced_options_set_security_enabled(adv, 0)` disables sandbox only for debugging.
- **Memory & Thread Safety**:
  - Every allocated resource has a `NULL`-safe free function: `boxlite_free_string`, `boxlite_error_free`, `boxlite_result_free`, `boxlite_free_box_info`, `boxlite_free_box_info_list`, `boxlite_free_image_pull_result`, `boxlite_free_image_info_list`, `boxlite_image_free`, `boxlite_box_free`, `boxlite_execution_free`, `boxlite_runtime_free`, `boxlite_simple_free`, `boxlite_advanced_options_free`, `boxlite_options_free`. (`boxlite_stop_box` leaves `CBoxHandle*` valid until `boxlite_box_free`.)
  - `CBoxliteRuntime` is thread-safe; `CBoxHandle`, `CExecutionHandle`, `CBoxliteSimple` are **not** thread-safe. Callbacks execute on whichever thread calls `boxlite_runtime_drain`.
  - `BoxliteErrorCode`: `22` enum values from `Ok = 0` through `SessionReaped = 21`. Non-zero guest exit codes still return `Ok` — check `exit_code`.

---

## 6. `boxlite` CLI

- **Install env trap**: Put `BOXLITE_VERSION` on the `sh` side of the pipe:
  ```bash
  curl -fsSL https://sh.boxlite.ai | BOXLITE_VERSION=v<VERSION> sh
  ```
- **Global Flags**: `--home <DIR>`, `--config <FILE>`, `--registry <REGISTRY>` (highest priority over `--config` JSON `image_registries`, which overrides default `docker.io`), `-u / --url <URL>`, `--debug`.
- **Commands**:
  - **Lifecycle**: `run`, `create`, `start`, `stop`, `restart`, `rm`
  - **Execution & Files**: `exec` (only on existing running box — `-it` fails if stdin is not a TTY), `cp`
  - **Inspection**: `list` / `ls` (default `table`), `inspect` (default `json`), `info` (default `yaml`), `stats` (default `table`)
  - **Images**: `pull`, `images` (default `table`), `rmi`
  - **Server, Auth & Shell**:
    - `boxlite serve` (defaults to `127.0.0.1:8100` since `0.10.6`; requires `--api-key` for non-loopback binds; every endpoint except `GET /v1/config` requires `Authorization: Bearer <KEY>` when `--api-key` is set)
    - `boxlite auth login | logout | status | whoami` (caches `Principal.path_prefix` per profile)
    - `boxlite completion <bash|zsh|fish>`
- **CLI Flag Syntax**:
  - `-v hostPath:boxPath[:ro|rw]` or `-v /abs/boxPath[:ro]` (anonymous volume MUST use absolute guest path).
  - `-p [hostPort:]boxPort[/tcp|udp]`.
  - `--network <enabled|disabled>` and repeatable `--allow-net <HOST>` (cannot combine `--allow-net` with `--network disabled`).
  - `--cpus <N>` (clamped to `255` with warning), `--memory <MiB>`, `--disk-size <GB>` (sparse overlay; values smaller than base image ignored).
  - `--security <enable|disable>` (or `BOXLITE_SECURITY`; only `enable`/`disable` accepted).
  - `--rm` (auto-delete on exit, incompatible with `-d / --detach`).
- **Exit Codes**: `0` success; `1` runtime/anyhow error (`list`/`rm`/`start`/`stop`/`restart` aggregate per-target errors and exit `1` if any failed); `2` clap CLI syntax error; `1..127` guest process exit code; `128 + N` killed by signal `N` (`137` SIGKILL, `143` SIGTERM).
