# Deploy in Docker or Kubernetes
Source: https://docs.boxlite.ai/guides/deployment

Run a BoxLite-backed service inside Docker or on Kubernetes, where each sandbox still needs hardware virtualization.

One constraint shapes every decision here: your container must reach the host's virtualization device (`/dev/kvm` on Linux). Granting it is a privileged operation with a real security cost, and every decision below is about paying that cost deliberately.

## Prerequisites

* A working BoxLite install (Python `boxlite` or Node `@boxlite-ai/boxlite`) and a machine with hardware virtualization — see [Installation](/getting-started/installation#platform-and-virtualization-requirements-common-to-all-sdks).

| Item | Requirement | Notes |
| - | - | - |
| Architecture | Linux x86_64 or ARM64 | Matches BoxLite's released platforms |
| Container runtime | Docker, or a Kubernetes cluster whose nodes expose `/dev/kvm` | Nodes without KVM cannot start boxes |

> BoxLite needs hardware virtualization to start each sandbox microVM. A
> container has no access to `/dev/kvm` by default, so a box created inside an
> unprivileged container fails to start and raises a standard `RuntimeError`
> (Python) / `Error` (Node). The configuration below is what grants that access.

***

## Why privileged access is required

Each BoxLite sandbox is a microVM, not a shared-kernel container. Starting a
microVM requires the kernel virtualization interface, which on Linux is the
character device `/dev/kvm`. Two conditions must hold inside the container:

1. The `/dev/kvm` device node must be present in the container.
2. The process must have permission to open it.

Granting both typically means running the container with elevated privileges
(`--privileged` in Docker, `securityContext.privileged: true` in Kubernetes)
and passing the device through from the host. This is the same trust boundary
you accept whenever you run nested virtualization in a container.

Security consequence: a privileged container can largely bypass container
isolation from the host. The isolation BoxLite gives you is *inside* the
boxes (each box is a microVM that untrusted agent code cannot escape), not
between the agent service container and its host. Treat the host that runs the
agent service as part of your trusted compute base, and do not co-tenant it
with workloads you do not trust.

***

## Quick Example: minimal agent service

A minimal agent service is your code plus the SDK. The example below is a
small handler that runs untrusted code in a `CodeBox` and returns the result;
it is what you would containerize.

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
# app.py — minimal agent execution service
import asyncio

import boxlite

async def execute_untrusted(code: str) -> dict:
    """Run agent-generated Python in an isolated microVM and return the result."""
    try:
        async with boxlite.CodeBox() as codebox:
            # CodeBox defaults to the python:slim image; cpus/memory_mib default
            # to the engine's allocation unless set explicitly.
            output = await codebox.run(code)
            return {"ok": True, "output": output}
    except RuntimeError as exc:
        # No virtualization / image pull failure raises a standard RuntimeError
        return {"ok": False, "error": str(exc)}

if __name__ == "__main__":
    result = asyncio.run(execute_untrusted("print(40 + 2)"))
    print(result)
```

The rest of this page is about giving the container running `app.py` access to
`/dev/kvm`.

***

## Docker deployment

Run the agent service inside a Docker container. The container must run with
`--privileged` and have `/dev/kvm` passed through.

### Dockerfile

```dockerfile theme={"theme":{"light":"github-light","dark":"github-dark"}}
FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install the BoxLite SDK
RUN pip3 install boxlite

# Copy the agent service
COPY app.py /app/app.py

WORKDIR /app

CMD ["python3", "app.py"]
```

### Run with KVM access

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
docker run --privileged --device /dev/kvm:/dev/kvm myapp
```

| Flag | Why it is needed |
| - | - |
| `--privileged` | Grants the permissions the process needs to open the virtualization device and start microVMs |
| `--device /dev/kvm:/dev/kvm` | Passes the host KVM device node into the container so boxes can be created |

### Multi-tenancy warning

Running BoxLite inside a privileged Docker container is appropriate for
single-tenant deployments where you control everything on the host. It is
**not** recommended for multi-tenant environments: a privileged container
weakens the boundary between the container and its host, so a compromise of the
agent service container can affect the host and any neighbors on it. For
multi-tenant isolation, run each tenant's agent service on its own dedicated
VM rather than relying on the container boundary.

***

## Kubernetes deployment

On Kubernetes, the same two requirements apply: the pod must be privileged, and
`/dev/kvm` must be mounted from the host. Because only nodes that actually
expose `/dev/kvm` can start boxes, schedule the pod onto KVM-enabled nodes with
a node selector.

### Pod manifest

```yaml theme={"theme":{"light":"github-light","dark":"github-dark"}}
apiVersion: v1
kind: Pod
metadata:
  name: boxlite-app
spec:
  # Schedule only onto nodes that expose /dev/kvm. Label such nodes with, e.g.,
  #   kubectl label node <node> boxlite.ai/kvm=true
  nodeSelector:
    boxlite.ai/kvm: "true"
  containers:
  - name: app
    image: myapp:latest
    securityContext:
      privileged: true        # required to open /dev/kvm and start microVMs
    volumeMounts:
    - name: dev-kvm
      mountPath: /dev/kvm
    resources:
      limits:
        memory: "4Gi"
        cpu: "2"
  volumes:
  - name: dev-kvm
    hostPath:
      path: /dev/kvm
      type: CharDevice        # /dev/kvm is a character device, not a regular file
```

| Field | Why it is needed |
| - | - |
| `securityContext.privileged: true` | Lets the container process open `/dev/kvm` and create microVMs |
| `hostPath` volume with `type: CharDevice` | Mounts the host's KVM character device into the pod; `CharDevice` makes Kubernetes validate it as a character special file |
| `nodeSelector` | Pins the pod to nodes that actually have `/dev/kvm`; on a node without it the boxes fail to start |
| `resources.limits` | Bounds the pod itself; size it for the number of concurrent boxes the agent will run, since each box consumes host memory and CPU |

### Notes

* Privileged pods are a cluster-wide security consideration. If your cluster
  enforces Pod Security admission, a `privileged` pod requires the `privileged`
  policy level for its namespace.
* Only nodes with KVM available can run these pods. Label and select those
  nodes explicitly; do not rely on default scheduling.
* The container's `resources.limits` bound the agent service process, not the
  individual boxes. Set per-box limits with `cpus` / `memory_mib` on
  `BoxOptions` (see [Compute Resources](/manage-sandbox/compute-resources)),
  and ensure the pod limit is large enough for the sum of concurrent boxes plus
  overhead.

***

## Pre-deployment checklist

Before shipping a BoxLite-backed agent service:

* **Per-box resource limits set.** Configure `cpus` / `memory_mib` (and
  `disk_size_gb` if you need persistence) on every box so a runaway agent
  cannot exhaust the host. See
  [Running sandboxes at scale](/guides/at-scale).
* **Error handling covers low-level failures.** Catch standard `RuntimeError`
  (Python) / bare `Error` (Node) in addition to `BoxliteError`; image pull
  failures and missing virtualization do not subclass `BoxliteError`. See
  [Error Handling](/guides/error-handling).
* **Cleanup is guaranteed.** Use `async with` for one-shot boxes, or
  `runtime.remove(id, force=True)` for runtime-managed boxes, so sessions are
  reclaimed.
* **Concurrency is sized to the host.** Estimate total resource use as
  per-box limits times expected concurrency, and keep it under the pod/host
  limits.
* **Host trust is appropriate.** The privileged container does not isolate the
  agent service from its host; keep untrusted neighbors off the host.

***

## Troubleshooting

### Box fails to start inside the container with `RuntimeError`

The most common cause is that `/dev/kvm` is not accessible inside the container.
Verify:

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
# Inside the container
ls -l /dev/kvm                 # must exist
```

For Docker, confirm both `--privileged` and `--device /dev/kvm:/dev/kvm` are
set. For Kubernetes, confirm `securityContext.privileged: true`, the `hostPath`
mount with `type: CharDevice`, and that the pod landed on a KVM-enabled node.

### Pod is rejected by Pod Security admission

A `privileged` pod requires the `privileged` Pod Security level for its
namespace. Either run it in a namespace labeled for the privileged policy, or
move the agent service to a dedicated cluster/node pool that permits privileged
pods.

### Boxes start but the pod is OOM-killed under load

The pod's `resources.limits.memory` bounds the whole pod, including every box's
microVM memory. Either lower per-box `memory_mib` and concurrency, or raise the
pod memory limit to cover the sum of concurrent boxes plus overhead. See
[Compute Resources](/manage-sandbox/compute-resources).

### Node has no `/dev/kvm`

Not every node supports nested virtualization (this is common on cloud
instance types without nested-virt enabled). Label only the nodes that expose
`/dev/kvm` and use a `nodeSelector` so the pod is never scheduled onto a node
that cannot start boxes.

***

## See Also

* [Running sandboxes at scale](/guides/at-scale) — concurrency, resource limits, isolation, cleanup
* [Error Handling](/guides/error-handling) — distinguishing command failures from low-level runtime errors
* [Building from source](/development/building-from-source) — when you need a custom or locally built runtime
* [Compute Resources](/manage-sandbox/compute-resources) — `cpus` / `memory_mib` / `disk_size_gb`
* [Secrets and Security](/manage-sandbox/secrets-and-security) — locking down the blast radius
