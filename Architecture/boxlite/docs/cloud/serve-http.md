# Serve HTTP from a box and get a public URL
Source: https://docs.boxlite.ai/cloud/serve-http

Start an HTTP server inside a Cloud box, open a tunnel to its port, and use the public URL the tunnel gives you.

A box running a web app, a dev server, or an API is only useful once something outside can reach it. Ask the box for a tunnel to the port your server listens on, and the tunnel hands you a public URL.

## Prerequisites

* An API key from the console, exported as `BOXLITE_API_KEY`. See [API keys](/cloud/api-keys).
* `pip install boxlite`, and the REST URL exported as `BOXLITE_REST_URL`. See [Quickstart](/cloud/quickstart).
* A box you can start, and a service inside it that listens on a TCP port.
* **The box must be created with inbound enabled.** A tunnel against a private
  box is refused, and inbound has defaulted to `disabled` since 0.10.5 — see
  [Network policy](/cloud/network-policy#a-new-box-is-private).

Every example reads both values from the environment, so nothing hard-codes a credential.

## Get the URL

> [tab] CLI
>
> If a box is already running your service, one command prints its URL:
>
> ```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
> boxlite network tunnel mybox 18080
> # https://18080-d-6574546e6e4b787a4c596d52.proxy.boxlite.ai
> ```

> [tab] SDK
>
> Ask the box for a tunnel to the port, then read `uri()`. The script below does the
> whole thing: create a box, start a server inside it, print the URL, make a request
> over the tunnel, and remove the box in `finally`.

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
# cloud_tunnel_http.py — serve HTTP from a Cloud box and reach it through a tunnel
# Run: python cloud_tunnel_http.py
import asyncio
import os
import time

from boxlite import (
    ApiKeyCredential,
    Boxlite,
    BoxliteRestOptions,
    BoxOptions,
    InboundNetworkSpec,
    NetworkSpec,
)

GUEST_PORT = 18080
IMAGE = "ghcr.io/boxlite-ai/boxlite-agent-base:v0.1.0"


async def http_get(tunnel, path: str = "/") -> bytes:
    """Send one HTTP request over one tunnel. connect() consumes the tunnel."""
    connection = await tunnel.connect()
    try:
        request = (
            f"GET {path} HTTP/1.1\r\n"
            "Host: localhost\r\n"
            "Connection: close\r\n\r\n"
        ).encode()
        await connection.write(request)

        response = bytearray()
        while True:
            chunk = await connection.read(64 * 1024)
            if not chunk:  # an empty read means the far side closed the stream
                break
            response.extend(chunk)
        return bytes(response)
    finally:
        await connection.close()


async def main() -> None:
    # export BOXLITE_API_KEY=<YOUR_API_KEY> before running
    rt = Boxlite.rest(BoxliteRestOptions(
        url=os.environ.get("BOXLITE_REST_URL", "https://api.boxlite.ai"),
        credential=ApiKeyCredential(os.environ["BOXLITE_API_KEY"]),
    ))

    box_id = None
    try:
        box = await rt.create(
            BoxOptions(
                image=IMAGE,
                # Required for a tunnel: inbound is disabled by default,
                # and a tunnel against a private box is refused.
                network=NetworkSpec(inbound=InboundNetworkSpec(mode="enabled")),
            ),
            name=f"tunnel-http-{int(time.time())}",
        )
        box_id = box.id
        await box.start()

        # Bind 0.0.0.0: the tunnel arrives on the box's network interface,
        # so a server on 127.0.0.1 inside the box cannot be reached.
        launch = await box.exec("sh", args=[
            "-c",
            f"nohup python3 -m http.server {GUEST_PORT} --bind 0.0.0.0 "
            "> /tmp/server.log 2>&1 & echo launched",
        ])
        await launch.wait()

        # uri() is synchronous and does not consume the tunnel.
        tunnel = await box.network.tunnel(GUEST_PORT)
        print(f"tunnel URL: {tunnel.uri()}")

        # The server needs a moment. Each attempt needs its own tunnel.
        response = b""
        for attempt in range(20):
            try:
                response = await http_get(tunnel)
                if response.startswith(b"HTTP/1."):
                    break
            except Exception as exc:
                print(f"attempt {attempt + 1}: {type(exc).__name__}: {exc}")
            await asyncio.sleep(1)
            tunnel = await box.network.tunnel(GUEST_PORT)  # the previous one is spent

        if response.startswith(b"HTTP/1."):
            print(response.split(b"\r\n", 1)[0].decode())
        else:
            log = await box.exec("cat", args=["/tmp/server.log"])
            text = ""
            async for line in log.stdout():
                text += line
            await log.wait()
            print(f"no HTTP response. server log:\n{text}")
    except Exception as exc:
        print(f"tunnel demo failed: {type(exc).__name__}: {exc}")
    finally:
        # Teardown on the runtime, in finally, so a failure above cannot leave a box running.
        if box_id:
            try:
                await rt.remove(box_id, force=True)
            except Exception as exc:
                print(f"remove failed: {exc}")


if __name__ == "__main__":
    asyncio.run(main())
```

Expected output:

```text theme={"theme":{"light":"github-light","dark":"github-dark"}}
tunnel URL: https://...
HTTP/1.0 200 OK
```

## Read the URL without spending the tunnel

`uri()` returns the public URL of a tunnel served remotely, which is what a Cloud tunnel
is. On a local runtime the same call returns `None`, because a local tunnel is already a
live connection with no address to publish.

**Reading `uri()` leaves the tunnel usable** — only `connect()` and `forward()` spend it.
Build a fresh tunnel for each of those.

## Troubleshooting

| Symptom | Cause | Fix |
| - | - | - |
| `InvalidStateError: ... Box <ID> is not public; set public: true before opening a tunnel` | The box was created without inbound. It has defaulted to `disabled` since 0.10.5 | Create it with `inbound=InboundNetworkSpec(mode="enabled")`, as the script above does |
| The server log says `python3: not found` | The image ships no interpreter | Install one into the box first, or start a service the image already has |
| The URL resolves but nothing answers | The server bound `127.0.0.1` | Bind `0.0.0.0` — a tunnel arrives on the guest's network interface, not its loopback |

## Next steps

> [card] [Network](/cloud/network)
>
> How tunnels work, the full parameter reference, and the outbound boundary.

> [card] [Network policy](/cloud/network-policy)
>
> Control what the box itself is allowed to reach.
