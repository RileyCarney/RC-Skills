# Network access
Source: https://docs.boxlite.ai/manage-sandbox/network-access

Control the sandbox's network boundary: expose a service to the host with port forwarding, restrict outbound traffic with an egress allowlist, or turn networking off entirely.

The sandbox has its own network stack behind a user-mode proxy, reachable at the fixed guest IP `192.168.127.2`. That is why a forwarded service must bind `0.0.0.0` rather than `127.0.0.1`.

## Quick Example

### Port forwarding: expose an in-sandbox HTTP service to the host

The following starts an HTTP server inside the sandbox (listening on `0.0.0.0:18789`) and reaches it from the host at `127.0.0.1:18789`. It is runnable as-is.

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio
import urllib.request

from boxlite import SimpleBox

async def main() -> None:
    try:
        # ports=[(host_port, guest_port)]: forward host port 18789 to sandbox port 18789
        async with SimpleBox(
            image="python:alpine",
            name="port-forward-demo",
            ports=[(18789, 18789)],
            reuse_existing=True,
        ) as box:
            print(f"Box started: {box.id}")

            # the service must bind to 0.0.0.0 (not 127.0.0.1):
            # gvproxy forwards host traffic to the sandbox NIC (192.168.127.2), not the sandbox loopback.
            await box.exec(
                "sh", "-c",
                "nohup python -m http.server 18789 --bind 0.0.0.0 > /dev/null 2>&1 &",
            )
            await asyncio.sleep(1)  # wait for the service to come up

            # access from the host
            with urllib.request.urlopen("http://127.0.0.1:18789/", timeout=5) as resp:
                print(f"Host -> guest: HTTP {resp.status}")
    except Exception as exc:  # startup failure / port in use / no virtualization, etc.
        print(f"Failed: {type(exc).__name__}: {exc}")

if __name__ == "__main__":
    asyncio.run(main())
```

### Egress allowlist: permit only specific hosts

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio

import boxlite
from boxlite import NetworkSpec, OutboundNetworkSpec, SimpleBox

async def main() -> None:
    try:
        # only example.com may be resolved/accessed; all other hosts are sinkholed to 0.0.0.0
        async with SimpleBox(
            image="alpine:latest",
            network=NetworkSpec(outbound=OutboundNetworkSpec(mode="enabled", allow_net=["example.com"])),
        ) as box:
            # allowed host -> resolves to a real IP
            allowed = await box.exec("nslookup", "example.com")
            print(f"example.com  exit={allowed.exit_code} (allowed)")

            # disallowed host -> resolves to 0.0.0.0 (blocked)
            blocked = await box.exec("nslookup", "github.com")
            print(f"github.com   exit={blocked.exit_code}")
            print("sinkholed:", "0.0.0.0" in blocked.stdout)
    except Exception as exc:
        print(f"Failed: {type(exc).__name__}: {exc}")

if __name__ == "__main__":
    asyncio.run(main())
```

### Node: port forwarding plus egress allowlist

```typescript theme={"theme":{"light":"github-light","dark":"github-dark"}}
// npm install @boxlite-ai/boxlite  (note the package name)
import { SimpleBox } from "@boxlite-ai/boxlite";

async function main(): Promise<void> {
  try {
    // port forwarding: ports is an array of objects { hostPort, guestPort, protocol? }
    // egress allowlist: network = { outbound: { mode: "enabled", allowNet: [...] } }
    const box = new SimpleBox({
      image: "python:alpine",
      name: "net-demo-node",
      reuseExisting: true,
      ports: [{ hostPort: 18790, guestPort: 18790 }],
      network: { outbound: { mode: "enabled", allowNet: ["example.com"] } },
    });

    // likewise must bind to 0.0.0.0
    await box.exec(
      "sh",
      "-c",
      "nohup python -m http.server 18790 --bind 0.0.0.0 > /dev/null 2>&1 &",
    );

    const r = await box.exec("nslookup", "example.com");
    console.log(`example.com exitCode=${r.exitCode}`);

    await box.stop();
  } catch (err) {
    console.error("Failed:", err instanceof Error ? err.message : err);
  }
}

main();
```

## Parameters and Returns

### Port forwarding (`ports`)

Accepted by `SimpleBox(..., ports=[...])` and `BoxOptions(ports=[...])`.

Each element may be a **tuple** or a **dict**:

| Element form | Description |
| - | - |
| `(host_port, guest_port)` | 2-tuple, TCP, forwards host `host_port` to sandbox `guest_port` |
| `(host_port, guest_port, protocol)` | 3-tuple; `protocol` is the string `"tcp"`/`"udp"` |
| `(host_port, guest_port, protocol, host_ip)` | 4-tuple; additionally specifies the host bind IP |
| `{"guest_port": 8080, "host_port": 18080, "protocol": "tcp"}` | dict form; `guest_port` is required, the rest are optional |

Underlying `PortSpec` fields (source: `sdks/python/src/options.rs`):

| Field | Type | Required | Default | Description |
| - | - | - | - | - |
| `host_port` | `int` (u16) | Optional | `None` = same as `guest_port` | Host listening port |
| `guest_port` | `int` (u16) | Required | — | In-sandbox service port |
| `protocol` | `str` | Optional | `tcp` | `tcp` / `udp` |
| `host_ip` | `str` | Optional | `None` | Host bind IP |

> Node: `ports` is `Array<{ hostPort?: number; guestPort: number; protocol?: string }>` (camelCase).

### Network policy `network` (`NetworkSpec`)

`NetworkSpec` has two independent halves. **Outbound** is what the box may reach on the
way out; **inbound** is whether anything outside may reach the services it exposes.

Python constructor: `NetworkSpec(outbound=None, inbound=None)`

| Parameter | Type | Required | Default | Description |
| - | - | - | - | - |
| `outbound` | `OutboundNetworkSpec` | Optional | `None` — full egress | What the box may reach |
| `inbound` | `InboundNetworkSpec` | Optional | `None` — resolved as `disabled`, i.e. private | Whether anything outside may reach the box |

`OutboundNetworkSpec(mode, allow_net=[])`:

| Parameter | Type | Required | Default | Description |
| - | - | - | - | - |
| `mode` | `str` | Required | — | `"enabled"` (networking on) / `"disabled"` (no network interface at all) |
| `allow_net` | `list[str]` | Optional | `[]` | Egress allowlist hosts; an empty list means no restriction (full internet). When non-empty, only these hosts resolve to real IPs and all others are sinkholed to `0.0.0.0`. Supports exact matches and `*.example.com` wildcards |

`InboundNetworkSpec(mode, allow_net=[])`:

| Parameter | Type | Required | Default | Description |
| - | - | - | - | - |
| `mode` | `str` | Required | — | `"enabled"` (services the box exposes are publicly reachable) / `"disabled"` (private) |
| `allow_net` | `list[str]` | Optional | `[]` | **Must stay empty.** It exists for shape symmetry with the outbound side; no layer enforces an inbound allowlist, and a non-empty value raises `InvalidArgumentError` before the request is sent |

Typical combinations:

| Configuration | Effect |
| - | - |
| Omitting `network` entirely (the default) | Full egress, and private — nothing outside can reach the box |
| `NetworkSpec(outbound=OutboundNetworkSpec(mode="enabled", allow_net=["example.com"]))` | Only the listed hosts are reachable; all others are sinkholed to `0.0.0.0` |
| `NetworkSpec(outbound=OutboundNetworkSpec(mode="disabled"))` | The sandbox has no network interface; DNS and outbound connections all fail, while local commands and file operations work normally |
| `NetworkSpec(inbound=InboundNetworkSpec(mode="enabled"))` | The box's services are publicly reachable. On Cloud this is the public flag — see [Network policy](/cloud/network-policy#a-new-box-is-private) |

> [!WARNING]
>
> **The flat `mode` and `allow_net` keywords configure outbound only.** They are a
> deprecated compatibility shim kept so older code keeps working:
> `NetworkSpec(mode="enabled")` has never been a way to make a box reachable from
> outside, and since 0.10.5 inbound defaults to `disabled`, so code relying on the older
> implicit default now gets a private box. Use the nested form.
>
> Mixing the two shapes is refused outright, in the constructor:
>
> ```
> ValueError: NetworkSpec cannot mix outbound with legacy mode/allow_net
> ```

> Node: there are no `NetworkSpec` classes — pass a plain object, with camelCase
> `allowNet`: `{ outbound: { mode: "enabled", allowNet: ["example.com"] }, inbound: { mode: "disabled" } }`.
> Its deprecated flat `mode` / `allowNet` behave as above.

### Return value (for verification)

`SimpleBox.exec(...)` returns an `ExecResult`:

| Field | Type | Description |
| - | - | - |
| `exit_code` | `int` | Process exit code. A non-zero value **does not raise**; check it yourself |
| `stdout` | `str` | Standard output (for allowlist verification, check whether it contains `0.0.0.0`) |
| `stderr` | `str` | Standard error |
| `error_message` | `str \| None` | Non-`None` only when the process died abnormally |

## Troubleshooting

### Port forwarding succeeds but the host cannot connect: the service bound to 127.0.0.1

This is the most common issue. If the in-sandbox service binds to `127.0.0.1` (loopback), traffic forwarded in by gvproxy arrives on the sandbox NIC (`192.168.127.2`) and cannot reach loopback.

* Symptom: `urllib.request.urlopen` / `curl` on the host reports `Connection refused` or times out.
* Fix: the in-sandbox service must bind to `0.0.0.0`, for example `python -m http.server 18789 --bind 0.0.0.0`, Flask `app.run(host="0.0.0.0")`, or uvicorn `--host 0.0.0.0`.

### The egress allowlist appears not to work / mistaking "blocked" for "errors out"

An allowlist block is not "the connection errors out"; it is a **DNS sinkhole**: a disallowed host resolves to `0.0.0.0`.

* How to verify: run `exec("nslookup", "<host>")` and check whether `result.stdout` contains `0.0.0.0`, rather than checking `exit_code` (a sinkholed `nslookup` may still return `exit_code == 0`).
* So to decide "was it blocked", inspect the stdout content, as in the second Quick Example.

### After `mode="disabled"`, all networking commands fail (this is expected)

In disabled mode the sandbox has no network interface: `nslookup`, `pip install`, `apk add`, and similar commands fail (`exit_code != 0`), while `echo`, `ls`, and reading or writing files work normally. This is by design. To use the network, switch to `mode="enabled"`.

### `exec` returns a non-zero exit code without raising

`exec` **does not raise** on a non-zero exit code; instead it returns `ExecResult(exit_code != 0)`. Always check `result.exit_code`. When the command itself does not exist (for example, `nslookup` is not installed in the image), a standard `RuntimeError` / bare `Error` may be raised (not a `BoxliteError` subclass), so use a broad `try/except Exception`.

### Host port already in use / re-creating a box with the same name

Startup fails when the host `host_port` is already in use. Switch to a free port, or confirm no leftover box from a previous run is still holding the port. When using `name=`, combining it with `reuse_existing=True` lets you reuse an existing box of the same name and avoid "already exists" errors.

### Notes on UDP port forwarding

`protocol="udp"` is accepted at the SDK layer.

> Current limitation: the CLI `-p` port forwarding treats forwarding as TCP. Configure UDP port forwarding through the SDK.

### No hardware virtualization prevents the sandbox from starting

The network code itself is fine, but if the environment lacks virtualization (Linux without `/dev/kvm`, KVM not passed through in a container, Windows without WSL2 + KVM), the box fails during startup and raises an exception. macOS (Apple Silicon) uses Hypervisor.framework automatically and does not need `/dev/kvm`. Catch it with `try/except` (Python) or `try/catch` (Node); the process will not crash.

## Related pages

* [Compute resources](/manage-sandbox/compute-resources)
* [Box types](/manage-sandbox/sandbox-types)
