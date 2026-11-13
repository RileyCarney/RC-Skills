---
name: boxlite-cloud
description: Complete guide to BoxLite Cloud (https://api.boxlite.ai), covering API keys and profiles, pricing/billing/plans/cost controls, box lifecycle and auto-stop/auto-delete/wake-on-access, persistent managed volumes, one-shot SDK tunnels, fixed domains, preview and signed URLs, egress allowlists, outbound secret proxy injection, image catalog/aliases/private registries, checkpoints, and Cloud SSH.
---

# BoxLite Cloud

Managed microVM cloud for AI agents (`https://api.boxlite.ai`). Uses the **exact same `boxlite` / `@boxlite-ai/boxlite` / Go / Rust SDK and `boxlite` CLI** — only the runtime constructor switches to REST (`Boxlite.rest(...)`).

## BoxLite Cloud Documentation Index (All 33 Core Pages + 6 Agent-in-Box Pages)

| Category | Topic | Local Mirror | Live Docs |
| - | - | - | - |
| Overview | BoxLite Cloud Overview | [cloud/index.md](../../docs/cloud/index.md) | [docs.boxlite.ai/cloud/index](https://docs.boxlite.ai/cloud/index.md) |
| Overview | Quickstart | [cloud/quickstart.md](../../docs/cloud/quickstart.md) | [docs.boxlite.ai/cloud/quickstart](https://docs.boxlite.ai/cloud/quickstart.md) |
| Overview | Cloud vs Open Source | [cloud/vs-opensource.md](../../docs/cloud/vs-opensource.md) | [docs.boxlite.ai/cloud/vs-opensource](https://docs.boxlite.ai/cloud/vs-opensource.md) |
| Auth | API Keys & Authentication | [cloud/api-keys.md](../../docs/cloud/api-keys.md) | [docs.boxlite.ai/cloud/api-keys](https://docs.boxlite.ai/cloud/api-keys.md) |
| Boxes | Boxes Overview | [cloud/boxes.md](../../docs/cloud/boxes.md) | [docs.boxlite.ai/cloud/boxes](https://docs.boxlite.ai/cloud/boxes.md) |
| Boxes | Create, Reuse & Remove from Code | [cloud/box-from-code.md](../../docs/cloud/box-from-code.md) | [docs.boxlite.ai/cloud/box-from-code](https://docs.boxlite.ai/cloud/box-from-code.md) |
| Boxes | Box Sizes & Ceilings | [cloud/box-sizes.md](../../docs/cloud/box-sizes.md) | [docs.boxlite.ai/cloud/box-sizes](https://docs.boxlite.ai/cloud/box-sizes.md) |
| Boxes | Box Lifecycle (Idle/Wake) | [cloud/box-lifecycle.md](../../docs/cloud/box-lifecycle.md) | [docs.boxlite.ai/cloud/box-lifecycle](https://docs.boxlite.ai/cloud/box-lifecycle.md) |
| Boxes | Checkpoints & Forking | [cloud/checkpoints.md](../../docs/cloud/checkpoints.md) | [docs.boxlite.ai/cloud/checkpoints](https://docs.boxlite.ai/cloud/checkpoints.md) |
| Storage | Volumes Overview | [cloud/volumes.md](../../docs/cloud/volumes.md) | [docs.boxlite.ai/cloud/volumes](https://docs.boxlite.ai/cloud/volumes.md) |
| Storage | Create & Mount a Volume | [cloud/mount-a-volume.md](../../docs/cloud/mount-a-volume.md) | [docs.boxlite.ai/cloud/mount-a-volume](https://docs.boxlite.ai/cloud/mount-a-volume.md) |
| Storage | Keep Data Across Boxes | [cloud/data-across-boxes.md](../../docs/cloud/data-across-boxes.md) | [docs.boxlite.ai/cloud/data-across-boxes](https://docs.boxlite.ai/cloud/data-across-boxes.md) |
| Storage | Volume Operations | [cloud/volume-operations.md](../../docs/cloud/volume-operations.md) | [docs.boxlite.ai/cloud/volume-operations](https://docs.boxlite.ai/cloud/volume-operations.md) |
| Storage | Volume API Reference | [cloud/volume-reference.md](../../docs/cloud/volume-reference.md) | [docs.boxlite.ai/cloud/volume-reference](https://docs.boxlite.ai/cloud/volume-reference.md) |
| Images | Images Overview | [cloud/images.md](../../docs/cloud/images.md) | [docs.boxlite.ai/cloud/images](https://docs.boxlite.ai/cloud/images.md) |
| Images | Use Your Own Image | [cloud/use-your-image.md](../../docs/cloud/use-your-image.md) | [docs.boxlite.ai/cloud/use-your-image](https://docs.boxlite.ai/cloud/use-your-image.md) |
| Images | Pin & Roll Back Image Aliases | [cloud/image-aliases.md](../../docs/cloud/image-aliases.md) | [docs.boxlite.ai/cloud/image-aliases](https://docs.boxlite.ai/cloud/image-aliases.md) |
| Images | Image Catalog & Limits | [cloud/image-catalog.md](../../docs/cloud/image-catalog.md) | [docs.boxlite.ai/cloud/image-catalog](https://docs.boxlite.ai/cloud/image-catalog.md) |
| Images | Private Images & Registries | [cloud/private-images.md](../../docs/cloud/private-images.md) | [docs.boxlite.ai/cloud/private-images](https://docs.boxlite.ai/cloud/private-images.md) |
| Network | Network Overview | [cloud/network.md](../../docs/cloud/network.md) | [docs.boxlite.ai/cloud/network](https://docs.boxlite.ai/cloud/network.md) |
| Network | How Tunnels Work | [cloud/tunnels.md](../../docs/cloud/tunnels.md) | [docs.boxlite.ai/cloud/tunnels](https://docs.boxlite.ai/cloud/tunnels.md) |
| Network | Serve HTTP & Public URLs | [cloud/serve-http.md](../../docs/cloud/serve-http.md) | [docs.boxlite.ai/cloud/serve-http](https://docs.boxlite.ai/cloud/serve-http.md) |
| Network | Port Forwarding | [cloud/port-forwarding.md](../../docs/cloud/port-forwarding.md) | [docs.boxlite.ai/cloud/port-forwarding](https://docs.boxlite.ai/cloud/port-forwarding.md) |
| Network | Raw TCP Byte Streams | [cloud/raw-streams.md](../../docs/cloud/raw-streams.md) | [docs.boxlite.ai/cloud/raw-streams](https://docs.boxlite.ai/cloud/raw-streams.md) |
| Network | Fixed Public Domains | [cloud/domains.md](../../docs/cloud/domains.md) | [docs.boxlite.ai/cloud/domains](https://docs.boxlite.ai/cloud/domains.md) |
| Network | Network Policy (Inbound/Outbound) | [cloud/network-policy.md](../../docs/cloud/network-policy.md) | [docs.boxlite.ai/cloud/network-policy](https://docs.boxlite.ai/cloud/network-policy.md) |
| Security & Access | Secrets Proxy Injection | [cloud/secrets.md](../../docs/cloud/secrets.md) | [docs.boxlite.ai/cloud/secrets](https://docs.boxlite.ai/cloud/secrets.md) |
| Security & Access | SSH into a Cloud Box | [cloud/ssh.md](../../docs/cloud/ssh.md) | [docs.boxlite.ai/cloud/ssh](https://docs.boxlite.ai/cloud/ssh.md) |
| Pricing & Billing | Pricing Overview | [cloud/pricing.md](../../docs/cloud/pricing.md) | [docs.boxlite.ai/cloud/pricing](https://docs.boxlite.ai/cloud/pricing.md) |
| Pricing & Billing | What a Box Costs | [cloud/box-costs.md](../../docs/cloud/box-costs.md) | [docs.boxlite.ai/cloud/box-costs](https://docs.boxlite.ai/cloud/box-costs.md) |
| Pricing & Billing | Cost Controls (`auto_stop`/`auto_delete`) | [cloud/cost-controls.md](../../docs/cloud/cost-controls.md) | [docs.boxlite.ai/cloud/cost-controls](https://docs.boxlite.ai/cloud/cost-controls.md) |
| Pricing & Billing | Managing Billing & Wallet | [cloud/billing.md](../../docs/cloud/billing.md) | [docs.boxlite.ai/cloud/billing](https://docs.boxlite.ai/cloud/billing.md) |
| Pricing & Billing | Wallet or a Plan? | [cloud/plans.md](../../docs/cloud/plans.md) | [docs.boxlite.ai/cloud/plans](https://docs.boxlite.ai/cloud/plans.md) |
| Cloud Agents | All 6 Hosted Agent Guides (`/cloud/agent-in-box/*`) | See [boxlite-agent-in-box](../boxlite-agent-in-box/SKILL.md) | [docs.boxlite.ai/cloud/agent-in-box](https://docs.boxlite.ai/cloud/agent-in-box/index.md) |

---

## 1. Authentication, Endpoints & CLI Profiles

- **API Host**: `https://api.boxlite.ai` (`BOXLITE_REST_URL`). **Never** use `https://app.boxlite.ai` (the web console serves dashboard HTML with HTTP `200` on unknown paths).
- **API Keys**: `blk_live_...` format, sent via `Authorization: Bearer <YOUR_API_KEY>` (`BOXLITE_API_KEY`). Keys are fleet-level (`Full` permissions on new keys; legacy `Boxes` keys get `403` on image endpoints). No permissive/unauthenticated mode exists.
- **`path_prefix` Trap**: On BoxLite Cloud, **leave `path_prefix` unset** (`None` / `undefined`, and unset `BOXLITE_REST_PATH_PREFIX`). Cloud serves routes directly under `/v1/boxes`; setting a prefix routes to `/v1/{prefix}/boxes` and causes `Not Found`.
- **SDK Client**:
  ```python
  import os
  from boxlite import ApiKeyCredential, Boxlite, BoxliteRestOptions

  rt = Boxlite.rest(BoxliteRestOptions(
      url=os.environ.get("BOXLITE_REST_URL", "https://api.boxlite.ai"),
      credential=ApiKeyCredential(os.environ["BOXLITE_API_KEY"]),
  ))
  # Or load BOXLITE_REST_URL + BOXLITE_API_KEY directly:
  rt = Boxlite.rest(BoxliteRestOptions.from_env())
  ```
- **CLI Persistence & Contexts**:
  ```bash
  printf '%s' "$BOXLITE_API_KEY" | boxlite auth login --url https://api.boxlite.ai --api-key-stdin
  boxlite --context app auth login --url https://api.boxlite.ai --method api-key
  boxlite auth status   # local only
  boxlite auth whoami   # calls GET /v1/me
  boxlite auth logout
  ```
  Note: `BOXLITE_API_KEY` env var overrides ONLY the bearer token from a saved profile, not its URL or path prefix.

---

## 2. Cloud Differences vs Open Source

| Feature | BoxLite Cloud | Open-Source Local |
| - | - | - |
| `BoxOptions.name` | Passed to `rt.create(..., name="...")` (not `BoxOptions`) | Same |
| `box.exec` arguments | `box.exec("sh", args=["-c", "..."])` (keyword/list `args=`) | `SimpleBox` supports positional args; native `Box.exec` uses list `args` |
| Volumes | Platform-managed storage via `(vol_name_or_id, guest_path)` (`managed_volume` in REST) | Host bind mounts `(host_path, guest_path, bool read_only)` |
| Network default (0.10.5+) | Inbound `disabled` by default; `NetworkSpec(mode="enabled")` is outbound-only | `NetworkSpec(inbound=InboundNetworkSpec(mode="enabled"))` required for Cloud tunnels |
| `BoxInfo.network` | Always `None` on Cloud SDK responses (read posture in Console) | Populated locally |
| `auto_stop` / `auto_delete` | `auto_stop=900` (15m idle default), `auto_delete=0` (disabled default) | Same option fields; Cloud meters stopped disks |
| `auto_delete` in CLI `create` | Disallowed (`remove-on-stop is incompatible with detach=true`); set `auto_delete` via SDK | Same |
| Images | Free built-in (`base`, `python`, `node`, `sandbaseai-hermes`) + 20-image custom catalog | Local OCI cache (`boxlite images` reads LOCAL machine, NOT Cloud catalog!) |

---

## 3. Box Sizes, Billing, Plans & Cost Controls

### Metered Rates (No Minimum, Per-Second/Exact Transition Billing)
```text
hourly = vCPU * $0.0504 + memory_GiB * $0.0144 + disk_GiB * $0.00018
```
- **Unmetered (Free)**: network egress/ingress traffic, API requests, managed volumes (`rt.volumes`), preview URLs, boot time, unstarted boxes.
- **vCPU dominates**: `1 vCPU-hour == 3.5 GiB-hours memory == 280 GiB-hours disk`.

### Preset Sizes & Organization Ceilings

| Size | Spec (vCPU / Memory / Disk) | Hourly | 30 Days Running | 30 Days Stopped (Disk Only) |
| - | - | - | - | - |
| Small | 1 vCPU / 1 GiB / 10 GiB | `$0.0666` | `$47.95` | `$1.30` |
| Medium | 2 vCPU / 4 GiB / 20 GiB | `$0.1620` | `$116.64` | `$2.59` |
| Large | 4 vCPU / 8 GiB / 50 GiB | `$0.3258` | `$234.58` | `$6.48` |
| Org Ceiling | **4 vCPU / 32 GiB / 120 GiB** | `$0.6840` | `$492.48` | `$15.55` |

### Lifecycle Cost Traps & Controls
- **Compute vs Disk Clocks**: Stopping a box stops vCPU/memory billing immediately when the stop is requested, **NOT** disk billing! A stopped box still pays `$0.00018/GiB-hour` for its root disk indefinitely until deleted (`rt.remove(box.id, force=True)`).
- **`auto_stop` & `auto_delete`**:
  - Defaults: `auto_stop = 900` (15m idle), `auto_delete = 0` (off — disk bills forever!).
  - Idle means **no SDK, terminal, or preview traffic** (background jobs running inside the VM do NOT reset the idle timer!).
  - Constraint: when both are non-zero, **`auto_delete` MUST be strictly greater than `auto_stop`**, otherwise create fails with `auto_delete must be greater than auto_stop`.
- **Subscriptions & Wallet**:
  - Plans apply quota first, then draw from prepaid wallet: **Starter** (`$19/mo`, `$30` quota, `20` concurrent boxes), **Pro** (`$149/mo`, `$250` quota, `100` concurrent boxes), **Max** (`$499/mo`, `$900` quota, `1000` concurrent boxes), Enterprise (negotiated).
  - Cost crossovers: > `$20/mo` -> Starter, > `$161/mo` -> Pro, > `$601/mo` -> Max (or upgrade earlier for concurrency limit).
  - Attaching a card earns `$100` credits and unlocks **automatic reload** (default threshold `$20` -> target `$100`). Upgrades apply immediately (prorated); downgrades/cancellations apply at cycle roll.

---

## 4. Persistent Managed Volumes (Unmetered)

- Volumes are **unmetered** and survive box deletion (`Only what is written under the guest mount path survives` — files in `/root`, `/tmp`, etc. die with the box).
- **Create & Mount**:
  - CLI: `boxlite volume create --name myvol`, then `boxlite create python --name worker -v myvol:/data`
  - Python/Node SDK: `vol = await rt.volumes.create("myvol")`, then `BoxOptions(image=..., volumes=[(vol.name, "/data")])` (`rt.volumes.remove(vol.id)` deletes it).
  - REST (`POST /v1/volumes`, `POST /v1/boxes`): `{"volumes": [{"managed_volume": "myvol", "guest_path": "/data"}]}`. Note: REST `POST /v1/boxes/{id}/exec` is asynchronous (returns `id`), so poll `GET /v1/boxes/{id}/executions/{exec_id}` for `state == "completed"` before removing the box!

---

## 5. Images, Catalog, Aliases & Private Registries

- **Free Built-in Images** (`0` against catalog limit): `base`, `python`, `node`, `sandbaseai-hermes`.
- **Custom Catalog**: Holds **20 custom images** per organization. Recording occurs asynchronously when the box **boots** (~12s observed after `create()` — poll `rt.images.list()`, `usage()`, `get(name)`). `boxlite images` CLI shows **local** images only, NOT the Cloud catalog!
- **Aliases (`rt.images.create_alias` / `delete_alias`)**: Pin an immutable `sha256:...` digest to a movable tag-like alias (e.g. `stable`) per repository (`name="ghcr.io/acme/api"`, `alias="stable"`, `digest=digest`). Running boxes keep their booted digest until recreated. Console/SDK only (not CLI).

---

## 6. Networking: Tunnels, Preview URLs, Fixed Domains, Policy & SSH

### Two Critical Tunnel Rules
1. **Service inside the box MUST bind `0.0.0.0`**, never `127.0.0.1`.
2. **A `BoxTunnel` is strictly one-shot**: `tunnel.connect()` and `tunnel.forward(listen)` **consume** the tunnel (reusing it raises `tunnel connection has already been consumed`). Reading `tunnel.uri()` does NOT consume it. Request a fresh `await box.network.tunnel(port)` per connection/retry/client!
   - `SocketAddress.tcp(host="127.0.0.1", port=0)` requires a **numeric IP** (not `"localhost"`); `SocketAddress.unix(path)` requires an **absolute path**.
   - `BoxConnection.read(max_bytes)` fails if `max_bytes == 0`. `shutdown_write()` half-closes locally but TCP half-close is **not** propagated end-to-end — frame protocols explicitly (`Content-Length`, newlines, length prefixes) rather than relying on EOF!
   - A `CONNECT` to a stopped box may accept briefly before dropping; treat first successful read/write as readiness.

### Inbound Access & Network Policy (`/api/box/...` Platform API vs `/v1/boxes/...`)
Since `0.10.5`, boxes default to **private** (`inbound=disabled`). Flat `NetworkSpec(mode="enabled")` sets **outbound only**! To allow public tunnels or unauthenticated preview URLs:
```python
from boxlite import BoxOptions, InboundNetworkSpec, NetworkSpec, OutboundNetworkSpec

opts = BoxOptions(
    image="...",
    network=NetworkSpec(
        inbound=InboundNetworkSpec(mode="enabled"),   # inbound.allow_net is NOT supported
        outbound=OutboundNetworkSpec(mode="enabled", allow_net=["pypi.org"]),
    ),
)
```
- **Platform HTTP endpoints** (`/api/box/{boxIdOrName}/...` — singular `box`, no `/v1/`):
  - Flip public/private on live box: `POST /api/box/{boxIdOrName}/public/{true|false}`
  - Preview URL (requires active `box.network.tunnel(port)` or returns `404 tunnel not found`!): `GET /api/box/{boxIdOrName}/ports/{port}/preview-url`
    - For private boxes, authenticate with `Authorization: Bearer <token>`, `X-BoxLite-Preview-Token: <token>`, or `?BOXLITE_BOX_AUTH_KEY=<token>`.
  - Signed Expiring URL (HTTP-only, default `expiresInSeconds=60`): `GET /api/box/{boxIdOrName}/ports/{port}/signed-preview-url?expiresInSeconds=900`
  - Revoke Signed URL: `POST /api/box/{boxIdOrName}/ports/{port}/signed-preview-url/{token}/expire`
- **Wake on Access (`503` / `502` behavior)**: Hitting a stopped box's preview URL triggers startup (first request returns `503` with `Retry-After: 3`). Only the box's saved **main command** restarts automatically — backgrounded processes launched via `exec` do NOT!
- **Outbound DNS Sinkhole Trap**: Hosts omitted from `allow_net` resolve to **`0.0.0.0`** (so `nslookup blocked.com` exits `0`!). Always check the resolved IP, not exit code. Note also: an org-level default outbound policy may apply when `network` is omitted.

### Fixed Public Domains (`*.boxliteapp.com`)
Reserve in Console -> **Domains** -> **Request domain** (reserving consumes org quota permanently until deleted; unbinding keeps reservation). Custom own-domains are not supported. All 3 commands are required to publish a box port:
```bash
boxlite --context app network inbound "$BOX" enabled
boxlite --context app network tunnel "$BOX" "$PORT"
boxlite --context app domain bind "$DOMAIN" --type box --box "$BOX" --port "$PORT"
# Scripted requests can skip the preview interstitial banner:
curl -fsS -H 'X-BoxLite-Skip-Preview-Warning: true' "https://$DOMAIN/"
# Unbind keeps the raw generated tunnel URL alive until revoked:
boxlite --context app domain unbind "$DOMAIN"
boxlite --context app network tunnel --revoke "$BOX" "$PORT"
```

### Cloud SSH
Requires latest CLI + OpenSSH + inbound enabled:
```bash
boxlite --context app start "$BOX"
boxlite --context app network inbound "$BOX" enabled
boxlite --context app ssh "$BOX"            # sets up keys & prints exact ProxyCommand ssh cmd
boxlite --context app ssh --enable "$BOX"   # re-enable
boxlite --context app ssh --disable "$BOX"  # + tunnel --revoke "$BOX" 22 to close
```

---

## 7. Cloud Secrets (Proxy Header Injection)

Never put real API keys in `BoxOptions.env`, images, files, or prompts. Supply `Secret` at box creation; BoxLite's outbound HTTPS proxy replaces matching headers only for listed `hosts`:
```python
boxlite.Secret(
    name="model",
    value=openai_key,
    hosts=["api.openai.com"],
    headers={"Authorization": "Bearer {value}"},
)
```
Inside the box, pass the placeholder `Bearer <BOXLITE_SECRET:model>` in an **already-present** target header (e.g. `Authorization` or `X-Api-Key`), and ensure the guest uses its system CA bundle (`/etc/ssl/certs/ca-certificates.crt`). The proxy does NOT add missing headers or rewrite request bodies/URLs, and Secrets persist across stop/start (create a replacement box to rotate).

---

## 8. Checkpoints & Fleet Fan-Out

Use checkpoints (`/cloud/checkpoints`) when you want a pre-baked environment (dependencies installed, repos cloned) to fork independent worker boxes quickly without repeating setup.
