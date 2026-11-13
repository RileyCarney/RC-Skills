---
name: boxlite-production-guides
description: Production engineering patterns for BoxLite — exception hierarchy and error handling (ExecResult vs BoxliteError vs RuntimeError), scaling concurrency models, zombie-free timeouts, runtime/box metrics, orphan cleanup, Docker/Kubernetes /dev/kvm deployment, remote REST control planes (boxlite serve & BoxliteRestOptions), and private/custom OCI image registries.
---

# BoxLite Production Guides

Patterns and guardrails for operating BoxLite sandboxes reliably at scale in production services.

## Documentation Map (7 Pages)

| Guide | Local Doc | Live Docs |
| - | - | - |
| Overview | [index.md](../../docs/guides/index.md) | [guides](https://docs.boxlite.ai/guides/index.md) |
| Error Handling | [error-handling.md](../../docs/guides/error-handling.md) | [error-handling](https://docs.boxlite.ai/guides/error-handling.md) |
| Running at Scale | [at-scale.md](../../docs/guides/at-scale.md) | [at-scale](https://docs.boxlite.ai/guides/at-scale.md) |
| Docker & Kubernetes Deployment | [deployment.md](../../docs/guides/deployment.md) | [deployment](https://docs.boxlite.ai/guides/deployment.md) |
| Agent Service REST Endpoint | [agent-service-endpoint.md](../../docs/guides/agent-service-endpoint.md) | [agent-service-endpoint](https://docs.boxlite.ai/guides/agent-service-endpoint.md) |
| Image Registry Configuration | [image-registry-configuration.md](../../docs/guides/image-registry-configuration.md) | [image-registry-configuration](https://docs.boxlite.ai/guides/image-registry-configuration.md) |
| Changelog & Releases | [changelog.md](../../docs/guides/changelog.md) | [changelog](https://docs.boxlite.ai/guides/changelog.md) |

---

## 1. Error Handling & Exception Hierarchy

**Core rule:** `box.exec(...)` **never raises** on a non-zero exit code — it returns an `ExecResult(exit_code != 0)`. Wrap `exec` in a helper if you want `ExecError`:

```python
async def run_checked(box, cmd: str, *args: str, timeout: float | None = None) -> str:
    result = await box.exec(cmd, *args, timeout=timeout)
    if result.exit_code != 0:
        raise ExecError(command=" ".join([cmd, *args]), exit_code=result.exit_code, stderr=result.stderr)
    return result.stdout
```

### Python Exception Hierarchy & Catch Order

In Python, native errors inherit from both `BoxliteError` and `RuntimeError`:
```text
InvalidArgumentError / InternalError -> _NativeError -> BoxliteError -> RuntimeError -> Exception
```
Always catch from most specific to broadest:
`ExecError` / `TimeoutError` / `ParseError` / `InvalidArgumentError` -> `BoxliteError` -> `RuntimeError` -> `Exception`.

| Scenario | Python | Node (`@boxlite-ai/boxlite`) | Notes |
| - | - | - | - |
| Command exits non-zero | Returns `ExecResult(exit_code != 0)` | Returns `{ exitCode != 0 }` | Does **not** raise |
| `SimpleBox.exec(timeout=...)` expires | Returns `ExecResult(exit_code == -15)` | Signal termination | Does **not** raise `TimeoutError` (`SIGTERM`) |
| Missing `entrypoint`/`cmd` (main command) | `InvalidArgumentError` at `start()` | Error at start | Clean message since `0.10.6` |
| Missing `exec` command binary | `InternalError` (`spawn_failed`) | **Bare `Error`** (`err instanceof BoxliteError === false`, `code: "GenericFailure"`) | Catch in fallback `else` in Node |
| Image pull failure / no KVM | `RuntimeError` | Bare `Error` | Catch broadly around startup |
| `BrowserBox`/`ComputerBox` readiness timeout | `boxlite.TimeoutError` | `TimeoutError` | Different class from Python `builtins.TimeoutError` |
| Native `(await box.exec(...)).wait()` result | `ExecResult(exit_code, error_message)` | Same | **Has NO `.stdout`/`.stderr`** — use `SimpleBox.exec` or `execution.stdout()`! |

---

## 2. Running at Scale Checklist

1. **Choose concurrency mode**:
   * **Mode A (default)**: One sandbox, many concurrent `exec()`s (`asyncio.gather`) — pays VM startup once.
   * **Mode B**: One sandbox per tenant/task — stronger boundary or distinct images/resource caps.
2. **Always set explicit `cpus` and `memory_mib`**: Do not rely on runtime defaults (`1 vCPU / 1024 MiB`).
3. **Prevent zombie processes on timeouts**:
   * **Never** use bare `asyncio.wait_for(box.exec(...))` alone — canceling the Python task leaves the guest process running!
   * **High-level**: `await box.exec(..., timeout=30.0)` kills the guest process cleanly (`SIGTERM`, `exit_code=-15`).
   * **Low-level**: Wrap `await execution.wait()` in `asyncio.wait_for(...)` and call `await execution.kill()` in `except asyncio.TimeoutError:`.
4. **Harden untrusted workloads**: `advanced=AdvancedBoxOptions(security=SecurityOptions.maximum())` + `NetworkSpec` allowlist/disabled + `Secret(...)`.
5. **Reclaim sandboxes & recover orphans**:
   * Prefer `async with SimpleBox(...)` or `try/finally: await runtime.remove(box.id, force=True)`.
   * On graceful process shutdown, call `await runtime.shutdown(timeout=None)` (`None`=10s, `-1`=wait indefinitely).
   * After `SIGKILL`/OOM crash, clean orphans via CLI: `boxlite ps -a` and `boxlite rm -a -f`.
6. **Observe metrics with exact field names** (`runtime.metrics()` and `box.metrics()` are both **async**):
   * `RuntimeMetrics`: `num_running_boxes` (not `active_boxes`), `boxes_created_total`, `boxes_failed_total`, `total_commands_executed`, `total_exec_errors`.
   * `BoxMetrics`: `memory_bytes` (not `memory_usage_bytes`), `cpu_percent` (not `cpu_time_ms`), `total_create_duration_ms`, `stage_*_ms`.
7. **Pre-warm image cache & dylib signature cache**: Start one box before peak traffic (see [`boxlite-architecture`](../boxlite-architecture/SKILL.md)).

---

## 3. Docker & Kubernetes Deployment (`/dev/kvm`)

Every BoxLite microVM requires host hardware virtualization (`/dev/kvm` on Linux x86_64/ARM64):

* **Docker**: `docker run --privileged --device /dev/kvm:/dev/kvm myapp`
* **Kubernetes Pod**:
  * `nodeSelector` targeting KVM-capable nodes (`boxlite.ai/kvm: "true"`)
  * `securityContext.privileged: true`
  * `hostPath` volume `{ path: /dev/kvm, type: CharDevice }`
* **Multi-tenancy warning**: Granting `--privileged` reduces container->host isolation for the *controller* pod itself. For strict multi-tenant workloads, isolate tenant controller pods on dedicated VMs rather than relying on container boundaries.

---

## 4. Agent Service REST Endpoint (`boxlite serve` & `Boxlite.rest`)

Manage sandboxes remotely without local virtualization:

```bash
# Loopback only (default since v0.10.6): permissive mode (accepts no key)
boxlite serve --port 8100

# Remote network bind: MUST supply --api-key or BOXLITE_SERVE_API_KEY
boxlite serve --host 0.0.0.0 --port 8100 --api-key "<YOUR_API_KEY>"
```

* (`GET /v1/config` stays public; every other route requires `Authorization: Bearer <key>` when `--api-key` is configured.)

### Client Connection (Python & Node)

```python
from boxlite import ApiKeyCredential, Boxlite, BoxliteRestOptions

# Or read BOXLITE_REST_URL, BOXLITE_API_KEY, BOXLITE_REST_PATH_PREFIX:
# opts = BoxliteRestOptions.from_env()
opts = BoxliteRestOptions(
    url="http://localhost:8100",
    credential=ApiKeyCredential("<YOUR_API_KEY>"),
    # path_prefix="default"  # Required ONLY for openapi/reference-server (/v1/default/boxes); OMIT for boxlite serve & Cloud!
)
runtime = Boxlite.rest(opts)  # synchronous constructor; methods (create/list_info/remove) are async
```

* Parameter names are **`path_prefix`** (Python, not `prefix`), **`pathPrefix`** (Node `JsBoxlite.rest(new BoxliteRestOptions({...}))`), and env var **`BOXLITE_REST_PATH_PREFIX`** (not `BOXLITE_REST_PREFIX`).
* `openapi/reference-server` currently omits WebSocket streaming, so `execution.stdout()` yields no lines there even though `create`/`start`/`list_info`/`remove` succeed.

---

## 5. Private & Custom Image Registries

Configure `image_registries` at runtime construction (`Boxlite(Options(...))` / `new JsBoxlite({ imageRegistries: [...] })`):

```python
import boxlite

opts = boxlite.Options(image_registries=[
    boxlite.ImageRegistry(host="ghcr.io", search=True, bearer_token=token),
    boxlite.ImageRegistry(host="registry.local:5000", transport="http", search=True),
    boxlite.ImageRegistry(host="registry.example.com", search=True, username=u, password=p, skip_verify=False),
    boxlite.ImageRegistry(host="docker.io", search=True),
])
```

* **`host` format**: `host[:port]` only — never include `http://`, `https://`, or `/path`!
* **`search` defaults to `False`**: Must pass `search=True` for unqualified image names (`alpine:latest`) to try that registry in list order. Fully-qualified references (`quay.io/org/img:tag`) bypass the search list.
* **`transport`**: lowercase `"https"` (default) or `"http"` only (uppercase `"HTTP"` raises `RuntimeError`).
* **Auth rules**: `username` and `password` must both be set if used; `bearer_token` takes precedence if both are provided. Node nests credentials inside `auth: { username?, password?, bearerToken? }`.
* SDK ignores local Docker/Podman config files (`~/.docker/config.json`) — behavior is 100% explicit via `Options`.
