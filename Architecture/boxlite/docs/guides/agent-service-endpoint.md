# Manage remote sandboxes over REST
Source: https://docs.boxlite.ai/guides/agent-service-endpoint

Manage a fleet of sandboxes through one REST endpoint — your code needs only a URL and an API key, not local virtualization.

The SDK ships a REST **client**. Point it at a host running `boxlite serve` and your `create` / `exec` / `list_info` / `remove` calls become HTTP and WebSocket requests served by real microVMs elsewhere. Swapping `Boxlite.default()` for `Boxlite.rest(...)` leaves your call sites almost unchanged.

## Prerequisites

* A working BoxLite install (Python `boxlite` or Node `@boxlite-ai/boxlite`) and a machine with hardware virtualization — see [Installation](/getting-started/installation#platform-and-virtualization-requirements-common-to-all-sdks).

| Prerequisite | Notes |
| - | - |
| A reachable REST endpoint | A remote host running `boxlite serve`, or a hosted endpoint URL. |
| API key | Required whenever the server binds a non-loopback address, and whenever it was started with `--api-key`. A loopback-only server started without a key runs in permissive mode and accepts any bearer, including none. |

Start a local server for integration testing (on a host with virtualization):

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
# Loopback only (127.0.0.1:8100), permissive mode — accepts any/no bearer
boxlite serve

# Reachable from other machines. Both flags are required: a non-loopback bind
# without a key is refused, and clients must then send a matching bearer.
boxlite serve --host 0.0.0.0 --port 8100 --api-key "<YOUR_API_KEY>"
```

By default the client reaches the server on the same host at `http://localhost:8100`.

> [!WARNING]
>
> **Upgrading from 0.10.5 or earlier?** `--host` used to default to `0.0.0.0`, so a
> server that other machines connected to will stop being reachable after the upgrade,
> and starting it with `--host 0.0.0.0` alone now exits with:
>
> ```
> Error: refusing to bind `boxlite serve` to non-loopback address 0.0.0.0 without an API key; set --api-key (or BOXLITE_SERVE_API_KEY), or bind to 127.0.0.1
> ```
>
> Restore remote access by passing **both** `--host 0.0.0.0` and `--api-key` (or
> `BOXLITE_SERVE_API_KEY`), then give the same key to every client as its
> `ApiKeyCredential`. `GET /v1/config` stays reachable without a bearer; every other
> route returns `401` without one.

## Quick Example

Minimal happy path: connect to a remote endpoint and list existing boxes. Runs as-is (start `boxlite serve` in another terminal first).

```python Python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio

from boxlite import ApiKeyCredential, Boxlite, BoxliteRestOptions

# TODO: replace with your real endpoint and API key
SERVER_URL = "http://localhost:8100"  # <YOUR_URL>
API_KEY = "local-dev-key"             # <YOUR_API_KEY>  a permissive server accepts any value (and no credential)

async def main() -> None:
    # Construct the REST client runtime handle (synchronous construction; do not await)
    # When connecting to the reference server (openapi/reference-server), pass path_prefix="default",
    # because it mounts routes at /v1/{prefix}/boxes; without it the client request to /v1/boxes returns 404.
    runtime = Boxlite.rest(
        BoxliteRestOptions(
            url=SERVER_URL,
            credential=ApiKeyCredential(API_KEY),
            path_prefix="default",  # The parameter is path_prefix (not prefix); the reference server uses "default"
        )
    )

    try:
        # List remote boxes over REST (under the REST path these runtime methods are awaitable)
        boxes = await runtime.list_info()
        print(f"Remote box count: {len(boxes)}")
        for info in boxes:
            # Note: status is at info.state.status (BoxStateInfo.status is a string)
            print(f"  - id={info.id} name={info.name} status={info.state.status}")
    except Exception as exc:  # Network unreachable / 401 authentication failure, etc.
        print(f"Connection or listing failed: {exc!r}")

if __name__ == "__main__":
    asyncio.run(main())
```

```typescript Node.js theme={"theme":{"light":"github-light","dark":"github-dark"}}
import { JsBoxlite, BoxliteRestOptions, ApiKeyCredential } from "@boxlite-ai/boxlite";

const SERVER_URL = "http://localhost:8100"; // <YOUR_URL>
const API_KEY = "local-dev-key";            // <YOUR_API_KEY>

async function main(): Promise<void> {
  // The runtime class is JsBoxlite (there is no bare Boxlite)
  const runtime = JsBoxlite.rest(
    new BoxliteRestOptions({
      url: SERVER_URL,
      credential: new ApiKeyCredential(API_KEY),
      pathPrefix: "default", // Required when connecting to the reference server; otherwise requests to /v1/boxes hit 404
    }),
  );

  try {
    const boxes = await runtime.listInfo();
    console.log(`Remote box count: ${boxes.length}`);
    for (const info of boxes) {
      console.log(`  - ${info.id} name=${info.name} status=${info.state.status}`);
    }
  } catch (err) {
    console.error("Connection or listing failed:", err);
  }
}

main();
```

> Key point: `Boxlite.rest(...)` / `JsBoxlite.rest(...)` is a **synchronous** constructor, but the runtime operations under the REST client (`create` / `get` / `get_info`/`getInfo` / `list_info`/`listInfo` / `metrics` / `remove`) must be `await`ed. The local runtime handle behaves the same way: synchronous construction, async methods.

### Create, Execute, Reclaim (End to End)

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio

from boxlite import ApiKeyCredential, Boxlite, BoxOptions, BoxliteRestOptions

SERVER_URL = "http://localhost:8100"  # <YOUR_URL>
API_KEY = "local-dev-key"             # <YOUR_API_KEY>

async def main() -> None:
    runtime = Boxlite.rest(
        BoxliteRestOptions(url=SERVER_URL, credential=ApiKeyCredential(API_KEY), path_prefix="default")
    )

    box = None
    try:
        # Create a named box on the remote (auto_remove=False to allow manual cleanup after the demo)
        box = await runtime.create(
            BoxOptions(image="alpine:latest", auto_remove=False),
            name="rest-quickstart",
        )
        await box.start()
        print(f"Created and started on remote: {box.id}")

        # Execute a command over REST; native Box.exec uses args= list and env= as list[tuple]
        execution = await box.exec("echo", args=["hello from remote box"])

        # Current limitation: streaming stdout/stderr goes over WebSocket and requires the server to implement a WS exec endpoint;
        # the reference server (openapi/reference-server) only implements POST /exec + GET /executions/{id},
        # so execution.stdout() returns no lines here. create/start/list/get_info/remove all work normally.
        stdout = execution.stdout()
        async for line in stdout:
            print(f"  stdout: {line}")

        result = await execution.wait()
        print(f"  exit_code: {result.exit_code}  error_message: {result.error_message}")
    except Exception as exc:
        print(f"Execution failed: {exc!r}")
    finally:
        # Cleanup calls remove(id, force=...) on the runtime, not box.remove()
        if box is not None:
            await runtime.remove(box.id, force=True)
            print(f"Removed {box.id}")

if __name__ == "__main__":
    asyncio.run(main())
```

## Parameters and Returns

### `BoxliteRestOptions(...)` Constructor Parameters

| Parameter | Required | Type | Description |
| - | - | - | - |
| `url` | Required | `str` | Server base URL, e.g. `http://localhost:8100`. |
| `credential` | Optional | `Credential` | Authentication credential, usually `ApiKeyCredential(key)`. Can be omitted for a permissive server. |
| `path_prefix` | Optional | `str` | Routing-slot prefix (for multi-tenant control planes). **The Python parameter is `path_prefix`** (not `prefix`; passing `prefix=` raises `TypeError: ... got an unexpected keyword argument 'prefix'`). The attribute is likewise `opts.path_prefix`. When connecting to the **reference server**, set it to `"default"` (it mounts routes at `/v1/default/boxes`); leave it empty for a single-tenant `boxlite serve` that uses `/v1/boxes`. |

> Node equivalent: `new BoxliteRestOptions({ url, credential, pathPrefix })` (the Node field is `pathPrefix`).

### Loading from Environment Variables (Recommended for CI/Production)

`BoxliteRestOptions.from_env()` reads the following environment variables and automatically wraps `BOXLITE_API_KEY` into an `ApiKeyCredential`:

| Environment variable | Required | Description |
| - | - | - |
| `BOXLITE_REST_URL` | Required | Server URL; `from_env()` raises if missing. |
| `BOXLITE_API_KEY` | Optional | API key; when set it is wrapped into a credential automatically, otherwise no credential is sent. |
| `BOXLITE_REST_PATH_PREFIX` | Optional | Routing-slot prefix, corresponding to the Python constructor parameter `path_prefix` (Node: `pathPrefix`). `from_env()` reads only `BOXLITE_REST_PATH_PREFIX`, not `BOXLITE_REST_PREFIX`. |

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio

from boxlite import Boxlite, BoxliteRestOptions

async def main() -> None:
    # Reads BOXLITE_REST_URL / BOXLITE_API_KEY / BOXLITE_REST_PATH_PREFIX
    try:
        opts = BoxliteRestOptions.from_env()
    except Exception as exc:
        # Reached here when BOXLITE_REST_URL is unset
        print(f"Missing environment variable: {exc!r}")
        print("Please set BOXLITE_REST_URL (required) and BOXLITE_API_KEY (optional)")
        return

    runtime = Boxlite.rest(opts)
    try:
        boxes = await runtime.list_info()
        print(f"Remote box count: {len(boxes)}")
    except Exception as exc:
        print(f"Listing failed: {exc!r}")

if __name__ == "__main__":
    asyncio.run(main())
```

Run:

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
export BOXLITE_REST_URL=http://localhost:8100   # <YOUR_URL>
export BOXLITE_API_KEY=your-api-key             # <YOUR_API_KEY>
python use_env_config.py
```

### REST Client Runtime Methods (All Require `await`)

| Method | Returns | Description |
| - | - | - |
| `create(options, name=None)` | `Box` | Create a box on the remote. |
| `get_or_create(options, name=None)` | `(Box, bool)` | Idempotent create; the bool indicates whether it was newly created. |
| `get(id_or_name)` | `Box` | Get a handle by id or name. |
| `get_info(id_or_name)` | `BoxInfo` | Get info (does not return a handle). |
| `list_info(_state=None)` | `list[BoxInfo]` | List all boxes (newest first). |
| `metrics()` | `RuntimeMetrics` | Runtime-level aggregate metrics. |
| `remove(id_or_name, force=False)` | — | Delete a box (called on the runtime, not `box.remove()`). |

> Metrics fields are authoritative in the source: `RuntimeMetrics` uses `num_running_boxes / boxes_created_total / boxes_failed_total / total_commands_executed / total_exec_errors`; `BoxMetrics` uses `memory_bytes / cpu_percent` (not `memory_usage_bytes / cpu_time_ms`).

### Accessing State (Common Pitfall)

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
info = await runtime.get_info(box_id)
print(info.id)              # box id
print(info.name)            # name or None
print(info.state.status)    # status string: outer BoxInfo.state -> BoxStateInfo.status
print(info.cpus, info.memory_mib, info.image)
```

The outer object is `BoxInfo.state` (a `BoxStateInfo`), and the inner field is `status` (a string). Both `.state` and `.status` must be chained correctly — the Node equivalent, `info.state.status`, is already shown in the Quick Example above.

## Troubleshooting

| Symptom / real error | Cause | Fix |
| - | - | - |
| `ConnectionRefusedError` / `Connection refused` | The server is not running, or the `url` port is wrong. | Run `boxlite serve --port 8100` on the server host and confirm the client `url` matches. |
| A client on another machine gets `Connection refused` after an upgrade, while the server looks healthy locally | Since 0.10.6 `serve` binds `127.0.0.1` by default, so it is only reachable from the server itself. | Restart it with `--host 0.0.0.0 --api-key "<YOUR_API_KEY>"` and give the client the same key. |
| The server exits immediately with `refusing to bind ... without an API key` | A non-loopback `--host` was given with no key. | Add `--api-key` or set `BOXLITE_SERVE_API_KEY`. |
| HTTP `401 Unauthorized` | The server was started with `--api-key <KEY>`, but the client sent no key or the wrong one. | Use `ApiKeyCredential(<correct key>)` on the client, or drop `--api-key` on the server to run permissive mode. |
| `RuntimeError: configuration error: BOXLITE_REST_URL not set` (raised by `from_env()`) | A required environment variable is unset. | `export BOXLITE_REST_URL=...`, and `export BOXLITE_API_KEY=...` if needed. The exception is a standard `RuntimeError` and can be caught with try/except. |
| `RuntimeError('box not found: {"detail":"Not Found"}')` (from `list_info()`/`create()`, etc.) | The client did not set `path_prefix`, so requests land on `/v1/boxes`, while the reference server mounts only `/v1/{prefix}/boxes`. | Pass `BoxliteRestOptions(..., path_prefix="default")` (reference server), or ensure the prefix matches the server's routing. |
| `execution.stdout()` yields no lines | The REST client's stdout/stderr streams over WebSocket, and the reference server does not implement the WS streaming endpoint (only `POST /exec` + `GET /executions/{id}`). | The server must implement WS exec to stream stdout. `create/start/list_info/get_info/remove` are unaffected. |
| `TypeError: BoxliteRestOptions.__new__() got an unexpected keyword argument 'prefix'` | `prefix=` was used by mistake. | The correct parameter is `path_prefix=` (Node: `pathPrefix`). |
| `box.remove()` does not exist / `AttributeError` | Treating removal as a box method. | Call it on the runtime: `await runtime.remove(box_id, force=True)`. List with `runtime.list_info()` (not `list()`). |
| `RuntimeWarning: coroutine ... was never awaited` | A REST client runtime method was not awaited. | Under the REST path, `create/get/get_info/list_info/metrics/remove` all require `await`. |
| A remote `exec` exits non-zero but does not raise | By design, `exec` does not raise on a non-zero exit. | Check `result.exit_code` yourself; inspect `result.error_message` when the process died abnormally. |
| `boxlite pull` / `boxlite images` report "not supported" in REST mode | The REST runtime does not currently support image operations. | Prepare images on the server side; the client only handles box lifecycle and execution. |
| The server fails to start a box on macOS / a machine without virtualization | The virtualization requirement falls on the **server host**. | Deploy `boxlite serve` on a Linux+KVM host (or macOS with Apple Hypervisor.framework, no `/dev/kvm` required); the client can be on any platform. |

### Real Error Example (Passing a String for a Volume)

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
from boxlite import BoxOptions

# Wrong: passing the string "ro" as the third element
BoxOptions(image="alpine:latest", volumes=[("/data", "/data", "ro")])

# Correct: bool read_only (True=read-only / False=read-write)
BoxOptions(image="alpine:latest", volumes=[("/data", "/data", True)])
```
