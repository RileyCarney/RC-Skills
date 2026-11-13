# Forward a box port to a local port
Source: https://docs.boxlite.ai/cloud/port-forwarding

Publish a port inside a Cloud box on an address on your own machine, so any TCP client can reach it without knowing about BoxLite.

Some clients cannot be taught to speak through an SDK — `curl`, a browser, a database driver, an existing library that only knows how to dial a socket. `forward()` publishes the tunnel on a local address so all of them just work.

## Prerequisites

* An API key from the console, exported as `BOXLITE_API_KEY`. See [API keys](/cloud/api-keys).
* `pip install boxlite`, and the REST URL exported as `BOXLITE_REST_URL`. See [Quickstart](/cloud/quickstart).
* A box you can start, and a service inside it that listens on a TCP port.
* **The box must be created with inbound enabled.** A tunnel against a private
  box is refused, and inbound has defaulted to `disabled` since 0.10.5 — see
  [Network policy](/cloud/network-policy#a-new-box-is-private).

Every example reads both values from the environment, so nothing hard-codes a credential.

## Publish a box port on your machine

> [tab] CLI
>
> One command, and it stays in the foreground forwarding until you stop it:
>
> ```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
> boxlite network tunnel mybox 18080 --listen 127.0.0.1:18080
> # tcp://127.0.0.1:18080
> ```
>
> Reach for this when you just need the port open while you work — no script to write,
> nothing to clean up. Flags are on the [CLI reference](/reference/cli#boxlite-network).

> [tab] SDK
>
> `forward()` publishes the tunnel on an address on your machine, so any TCP client can
> reach the service without knowing about BoxLite. Use this when the forward is part of
> something your program does, and it has to pick the port, hand it to something else,
> or shut down cleanly.

The script below is the SDK path end to end — start a service in a box, forward it, and
fetch it from the local address:

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
# cloud_tunnel_forward.py — publish a box port on a local port
# Run: python cloud_tunnel_forward.py
import asyncio
import os
import time
import urllib.request

from boxlite import (
    ApiKeyCredential,
    Boxlite,
    BoxliteRestOptions,
    BoxOptions,
    InboundNetworkSpec,
    NetworkSpec,
    SocketAddress,
)

GUEST_PORT = 18080
IMAGE = "ghcr.io/boxlite-ai/boxlite-agent-base:v0.1.0"


async def main() -> None:
    # export BOXLITE_API_KEY=<YOUR_API_KEY> before running
    rt = Boxlite.rest(BoxliteRestOptions(
        url=os.environ.get("BOXLITE_REST_URL", "https://api.boxlite.ai"),
        credential=ApiKeyCredential(os.environ["BOXLITE_API_KEY"]),
    ))

    box_id = None
    forwarder = None
    try:
        box = await rt.create(
            BoxOptions(
                image=IMAGE,
                # Required for a tunnel: inbound is disabled by default,
                # and a tunnel against a private box is refused.
                network=NetworkSpec(inbound=InboundNetworkSpec(mode="enabled")),
            ),
            name=f"tunnel-forward-{int(time.time())}",
        )
        box_id = box.id
        await box.start()

        launch = await box.exec("sh", args=[
            "-c",
            f"nohup python3 -m http.server {GUEST_PORT} --bind 0.0.0.0 "
            "> /tmp/server.log 2>&1 & echo launched",
        ])
        await launch.wait()
        await asyncio.sleep(2)  # give the server time to bind

        # host must be a numeric IP; port=0 asks the OS for a free port.
        listener = SocketAddress.tcp(host="127.0.0.1", port=0)

        tunnel = await box.network.tunnel(GUEST_PORT)
        forwarder = await tunnel.forward(listener)  # consumes the tunnel

        local = forwarder.local_addr()  # synchronous
        print(f"forwarding 127.0.0.1:{local.port} -> box port {GUEST_PORT}")

        # Any TCP client can now dial the local address. urllib is blocking,
        # so run it off the event loop.
        def fetch() -> int:
            url = f"http://127.0.0.1:{local.port}/"
            with urllib.request.urlopen(url, timeout=10) as resp:
                return resp.status

        print(f"local request status: {await asyncio.to_thread(fetch)}")
    except Exception as exc:
        print(f"forward demo failed: {type(exc).__name__}: {exc}")
    finally:
        if forwarder is not None:
            try:
                await forwarder.close()
            except Exception as exc:
                print(f"forwarder close failed: {exc}")
        if box_id:
            try:
                await rt.remove(box_id, force=True)
            except Exception as exc:
                print(f"remove failed: {exc}")


if __name__ == "__main__":
    asyncio.run(main())
```

## Choose the listening address

Three constraints, each of which raises rather than failing quietly:

* The host must be a **numeric IP**. `SocketAddress.tcp(host="localhost")` raises `ValueError: tunnel listener host must be a numeric IP` — pass `"127.0.0.1"`.
* `port=0` is the default and asks the operating system for a free port. Read the port you actually got from `forwarder.local_addr().port`.
* A Unix socket path must be **absolute**. `SocketAddress.unix("relative.sock")` raises `ValueError: tunnel Unix socket path must be absolute`.

## Keep it running, and shut it down

`await forwarder.wait()` blocks until the forwarder finishes — that is what a
long-running process awaits instead of exiting. `await forwarder.close()` shuts it down.

> [!WARNING]
>
> **`forward()` spends the tunnel it was built from.** Build each forwarder from its own
> fresh `await box.network.tunnel(port)`; reusing one will not work.

## Next steps

> [card] [Network](/cloud/network)
>
> How tunnels work, the full parameter reference, and the outbound boundary.

> [card] [Network policy](/cloud/network-policy)
>
> Control what the box itself is allowed to reach.
