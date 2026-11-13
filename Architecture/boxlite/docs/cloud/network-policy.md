# Control inbound and outbound access to a box
Source: https://docs.boxlite.ai/cloud/network-policy

Decide who may reach a Cloud box — keep it private, share one port through a signed link, or make it public — and set what the box itself is allowed to reach on the way out.

Two questions decide a box's network posture: who is allowed to reach it, and what it is allowed to reach. The inbound half is the public flag and preview URLs; the outbound half is `NetworkSpec`. Dialing a box port from your own code is a different job, and [Network](/cloud/network) covers it.

> [!NOTE]
>
> The routes on this page live under `/api/box/...` — the **platform API**, which is a separate surface from the SDK REST API at `/v1/boxes/...` used everywhere else in these docs. The singular `box` and the missing version segment are intentional, not typos.

## Prerequisites

* An API key exported as `BOXLITE_API_KEY`, and the base URL as `BOXLITE_REST_URL`. See [API keys](/cloud/api-keys).
* A running box with a service listening on a TCP port, bound to `0.0.0.0`.
* Write access to boxes in your organization, for the public flag.

## Inbound: who can reach a box

A box is private or public, and any single port on it can be shared through a preview URL. Those are two independent decisions: the flag governs the box, the URL governs one port.

### A new box is private

Inbound access is **disabled unless you ask for it**. Create a box without saying
anything about inbound and nothing outside it can reach its services — which is the
posture you want for almost every box, and the reason you rarely need the public flag
at all.

Ask for the other posture at creation time with `inbound`:

```python Python theme={"theme":{"light":"github-light","dark":"github-dark"}}
from boxlite import BoxOptions, InboundNetworkSpec, NetworkSpec

opts = BoxOptions(
    image="python",
    network=NetworkSpec(inbound=InboundNetworkSpec(mode="enabled")),
)
```

```bash CLI theme={"theme":{"light":"github-light","dark":"github-dark"}}
boxlite create --image python --inbound enabled
```

`mode` takes `"enabled"` or `"disabled"`, and `"disabled"` is what you get by omission.
Writing it out explicitly sends the same request as leaving it off — it documents the
intent for the next reader, nothing more.

| What you create the box with | How Cloud records it |
| - | - |
| no `network` field | private |
| `NetworkSpec()` | private |
| `inbound=InboundNetworkSpec(mode="disabled")` | private |
| `inbound=InboundNetworkSpec(mode="enabled")` | **public** |
| `NetworkSpec(mode="enabled")` — the flat form | private |

> [!NOTE]
>
> The SDK does not read this back: `BoxInfo.network` is `None` on Cloud, so you cannot
> check a box's inbound posture from `await box.info()`. Read it from the box's row in
> the console instead.

> [!WARNING]
>
> **This default changed in 0.10.5, and the old spelling for "public" no longer means
> that.** `NetworkSpec` used to take a flat `mode` and `allow_net`; those now configure
> **outbound only**. Code that said:
>
> ```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
> network=NetworkSpec(mode="enabled")       # outbound — never makes the box public
> ```
>
> produced a public box before 0.10.5 and produces a **private** one now, so a tunnel
> against it fails:
>
> ```
> Box ${boxId} is not public; set public: true before opening a tunnel
> ```
>
> Add the inbound half:
>
> ```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
> from boxlite import InboundNetworkSpec, NetworkSpec, OutboundNetworkSpec
>
> network=NetworkSpec(
>     inbound=InboundNetworkSpec(mode="enabled"),
>     outbound=OutboundNetworkSpec(mode="enabled"),
> )
> ```

`InboundNetworkSpec` carries an `allow_net` field for symmetry with the outbound side,
but no layer enforces an inbound allowlist, so a non-empty value is refused before the
request leaves your process:

```
InvalidArgumentError: invalid argument: inbound.allow_net is not supported yet; remove it (inbound access is controlled by mode only)
```

Inbound is governed by `mode` alone. To let one audience in rather than everyone, keep
the box private and share a [signed URL](#share-a-port-temporarily-with-a-signed-url).

You are not locked in: the public flag below flips an existing box either way, without
recreating it or losing its filesystem.

### Where to do each of these

Most of this section is shown as HTTP because that is the only surface some of it
has. Two of the four operations are also in the console, and those are the ones you
will reach for by hand:

| Operation | Console | SDK / CLI | HTTP |
| - | - | - | - |
| Set inbound when you create a box | — | **Yes** — `inbound`, or `--inbound` | Yes |
| Change inbound on an existing box | **Yes** — the box's **network** panel | No | Yes |
| Get a preview URL for a port | **Yes** — **get url** on the same panel | No | Yes |
| Issue an expiring signed URL | No | No | **Only here** |
| Revoke a signed URL | No | No | **Only here** |

The SDK's network handle exposes `tunnel(port)` and nothing else, and `boxlite
network` has only `tunnel`, so neither can change inbound or mint a preview URL.
Reach for HTTP when you are automating; reach for the console when you are not.

### A preview URL and an SDK tunnel are different tools

A preview URL is an HTTPS address for one port on one box, served by BoxLite's preview proxy. Anything that speaks HTTPS can fetch it — a browser, `curl`, a webhook sender, a reviewer on their phone — and none of them needs the BoxLite SDK.

An SDK tunnel is the other shape. Your code asks the box for a tunnel and dials it with your API key, and the tunnel carries any TCP protocol rather than only HTTP.

Reach for a **preview URL** when something outside your own code has to fetch an HTTP service in the box: a browser preview, a webhook receiver, a link you send someone. Reach for a **tunnel** when your program is the client, or when the protocol is not HTTP — SSH, a database wire protocol, a raw byte stream. Tunnels are documented on [Network](/cloud/network).

### Make a box public or private

> [tab] Console
>
> Open the box, find the **network** panel, and use the **Inbound access** switch.
>
> The panel states the current posture in the terms that matter:
>
> | It reads | What it means |
> | - | - |
> | `inbound · disabled · your organization` | A preview URL sends an unknown visitor through sign-in, and serves only members of your organization |
> | `inbound · enabled · anyone` | A preview URL serves anyone who holds it, with no sign-in |
>
> Turning it on asks you to confirm — *"Open this box's preview URLs to anyone?"* —
> because that is exactly what it does. **`outbound` on the same panel is read-only:**
> nothing changes a box's egress after it is created.

> [tab] HTTP
>
> ```http theme={"theme":{"light":"github-light","dark":"github-dark"}}
> POST /api/box/{boxIdOrName}/public/{isPublic}
> ```
>
> Both values travel in the path. There is no request body, and a `200` returns the box.
>
> | Path parameter | Type | Required | Description |
> | - | - | - | - |
> | `boxIdOrName` | string | Required | The box id, or the name you gave the box when you created it |
> | `isPublic` | boolean | Required | `true` opens the box to unauthenticated access, `false` returns it to private |
>
> The call needs write access to boxes in your organization, and it is recorded in your organization's audit trail.

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
# Make a box public. Read the key from the environment -- never inline it.
BOXLITE_REST_URL="${BOXLITE_REST_URL:-https://api.boxlite.ai}"

curl -fsS -X POST \
  "${BOXLITE_REST_URL}/box/review-app-142/public/true" \
  -H "Authorization: Bearer ${BOXLITE_API_KEY}"
```

Be clear-eyed about what you just did. **A public box drops the credential requirement in front of it: anyone who has a URL to it can reach the service, from anywhere, with no API key and no token, and that holds until you set the flag back to `false`.** A URL is a string — it travels in chat messages, tickets, browser history, referrer headers, and screenshots. Anything the service in that box can read or write is now guarded by the secrecy of a link, so treat the box's files, its environment variables, and its network credentials as exposed for as long as the flag is on. Set it back to private the moment you no longer need it:

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
BOXLITE_REST_URL="${BOXLITE_REST_URL:-https://api.boxlite.ai}"

curl -fsS -X POST \
  "${BOXLITE_REST_URL}/box/review-app-142/public/false" \
  -H "Authorization: Bearer ${BOXLITE_API_KEY}"
```

If what you actually want is to let one person see one port for a short while, do not touch this flag at all — use a signed preview URL instead.

### Get a preview URL for a port

> [tab] Console
>
> On the box's **network** panel, choose **get url** and type the port.
>
> > [!NOTE]
> >
> > **That button is disabled while inbound is disabled.** The HTTP route is not — it
> > returns a URL and a token for a private box too, which is what the token flow below
> > is for. If **get url** is greyed out and you expected otherwise, the box is private,
> > not broken.

> [tab] HTTP
>
> ```http theme={"theme":{"light":"github-light","dark":"github-dark"}}
> GET /api/box/{boxIdOrName}/ports/{port}/preview-url
> ```
>
> ```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
> BOXLITE_REST_URL="${BOXLITE_REST_URL:-https://api.boxlite.ai}"
>
> curl -fsS \
>   "${BOXLITE_REST_URL}/box/review-app-142/ports/8080/preview-url" \
>   -H "Authorization: Bearer ${BOXLITE_API_KEY}" | jq
> ```
>
> A `200` returns:
>
> | Field | Type | Description |
> | - | - | - |
> | `boxId` | string | The box the URL points at |
> | `url` | string | The preview address, shaped `https://{port}-{encodedBoxId}.{proxyDomain}` |
> | `token` | string | The access token for that URL |

The port is part of the URL, so **a preview URL addresses one port, not the whole box.** A box running an app on `8080` and a metrics endpoint on `9090` has two preview URLs, and you fetch each one separately. Change the port your service listens on and the old URL no longer describes it.

> [!WARNING]
>
> **Holding the URL is not enough — a tunnel has to be open on that port.** The endpoint
> hands you a URL for any port you name, including one nothing is listening on. The proxy
> then checks, on every request, that the port has a live tunnel, and answers `404`
> when it does not:
>
> ```json theme={"theme":{"light":"github-light","dark":"github-dark"}}
> {"statusCode":404,"message":"not found: tunnel not found","code":"NOT_FOUND"}
> ```
>
> A `404` here is therefore about the *tunnel*, not about your path. Open one for each
> port you intend to expose — `box.network.tunnel(<PORT>)` in the SDK — and a port
> without one stays unreachable no matter how well-formed its URL looks.

#### Present the token when the box is private

A private box's preview URL is not open, so a request has to carry the `token` from the response above. The preview proxy accepts it three ways, and tries them in this order:

| How | Form | Use it for |
| - | - | - |
| `Authorization` header | `Authorization: Bearer <token>` | A programmatic client you control |
| Dedicated header | `X-BoxLite-Preview-Token: <token>` | A client that already uses `Authorization` for something else |
| Query parameter | `?BOXLITE_BOX_AUTH_KEY=<token>` | A browser, or any client that can only follow a URL |

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
# A private preview URL, fetched with the token in a header
curl -fsS "https://8080-<ENCODED_BOX_ID>.<PROXY_DOMAIN>/health" \
  -H "X-BoxLite-Preview-Token: ${BOXLITE_PREVIEW_TOKEN}"
```

The query-parameter form is what makes a private preview URL openable in a browser: append it once, and the proxy strips the parameter before the request reaches your service, then sets a cookie so the following requests on that host carry the authorization for you. Because that form puts a credential in a URL, treat such a link like a password — it lands in browser history, server logs, and anything the recipient pastes it into. For sharing with a person, a [signed URL](#share-a-port-temporarily-with-a-signed-url) is the better instrument: it expires on its own and you can revoke it.

A request that carries no credential the proxy accepts is redirected to sign in, so a human reaching a private box in a browser can authenticate instead of being refused outright.

### Share a port temporarily with a signed URL

> [!NOTE]
>
> Signed URLs are **HTTP-only**. There is no console control and no SDK or CLI method
> for issuing or revoking one, so the calls below are the whole of it.

```http theme={"theme":{"light":"github-light","dark":"github-dark"}}
GET /api/box/{boxIdOrName}/ports/{port}/signed-preview-url?expiresInSeconds=N
```

This is the call to prefer when you want to hand someone a working link and keep the box private. The signature is what authorizes the request, so the recipient needs no API key and you never flip the public flag — the box stays closed to everyone who does not hold the link, and the link stops working on its own.

`expiresInSeconds` is an optional query parameter, and **the default is 60 seconds**. Sixty seconds is the right size for a link your own code generates and redirects to immediately; pass a larger value when a person has to open it, read it, and click around.

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
BOXLITE_REST_URL="${BOXLITE_REST_URL:-https://api.boxlite.ai}"

# 900 seconds gives a reviewer a quarter of an hour with the link
curl -fsS \
  "${BOXLITE_REST_URL}/box/review-app-142/ports/8080/signed-preview-url?expiresInSeconds=900" \
  -H "Authorization: Bearer ${BOXLITE_API_KEY}" | jq -r '.url, .token'
```

A `200` returns:

| Field | Type | Description |
| - | - | - |
| `boxId` | string | The box the URL points at |
| `port` | number | The port inside the box that the URL addresses |
| `token` | string | Identifies this signed URL. Keep it — revoking the URL needs it |
| `url` | string | The signed address, shaped `https://{port}-{token}.{proxyDomain}` |

Generate a fresh signed URL per recipient and per sharing session rather than reusing one. Each is independently revocable, so one leaked link is one link you can kill.

### Revoke a signed URL before it expires

```http theme={"theme":{"light":"github-light","dark":"github-dark"}}
POST /api/box/{boxIdOrName}/ports/{port}/signed-preview-url/{token}/expire
```

The `token` in the path is the `token` field from the signed-URL response — that is the reason to keep it rather than discarding everything but the `url`. A `200` returns no body.

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
BOXLITE_REST_URL="${BOXLITE_REST_URL:-https://api.boxlite.ai}"
SIGNED_TOKEN="<TOKEN_FROM_THE_SIGNED_URL_RESPONSE>"

curl -fsS -X POST \
  "${BOXLITE_REST_URL}/box/review-app-142/ports/8080/signed-preview-url/${SIGNED_TOKEN}/expire" \
  -H "Authorization: Bearer ${BOXLITE_API_KEY}"
```

Revoke as soon as the review is over, the demo ends, or the link lands somewhere you did not intend. Waiting for an expiry you set generously is a choice to stay exposed.

### Choose between the three

| Approach | Who can reach the box | Suits |
| - | - | - |
| Private box, SDK tunnel | Only code holding your API key | Your own program as the client, any TCP protocol, agent traffic that should never be addressable from outside |
| Private box, signed preview URL | Anyone holding the link, until it expires or you revoke it | A preview for a reviewer, a teammate, or an end user; a link your app generates per session |
| Public box | Anyone holding any URL to the box, until you set the flag back | A demo you are content to have indexed, crawled, and forwarded |

The order matters: start private, escalate to a signed URL when a human needs to see something, and reserve the public flag for a box whose contents you would publish deliberately.

## Outbound: what the box can reach

Outbound is a per-box setting you make at creation, not a toggle you flip afterwards. Pass a `NetworkSpec` as the `network` field of `BoxOptions`, and the SDK sends that specification — the mode and the allowlist — to Cloud as part of the create call.

There are exactly two modes, `enabled` and `disabled`, plus the `allow_net` allowlist that narrows egress to named hosts. The `NetworkSpec` parameter table, the useful mode and allowlist combinations, and the verification recipe live on [Network access](/manage-sandbox/network-access), which owns them.

One property of the allowlist decides whether you can debug it. **A host outside the allowlist is a DNS sinkhole, not a connection error: it resolves to `0.0.0.0`.** Your code therefore reports a failed connection to `0.0.0.0` rather than a refusal or a policy message, and a `nslookup` of a blocked host can still exit `0` because the lookup itself succeeded. Read the resolved address, never the exit code, when you want to know what a box's DNS returned for a host.

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
# cloud_egress_allowlist.py — create a Cloud box with an outbound allowlist
# Run: python cloud_egress_allowlist.py
import asyncio
import os
import time

from boxlite import (
    ApiKeyCredential,
    Boxlite,
    BoxliteRestOptions,
    BoxOptions,
    NetworkSpec,
    OutboundNetworkSpec,
)

IMAGE = "ghcr.io/boxlite-ai/boxlite-agent-base:v0.1.0"

# The hosts this box is meant to talk to. Everything else is left off the list.
ALLOWED_HOSTS = ["pypi.org", "files.pythonhosted.org"]


async def resolve(box, host: str) -> str:
    """Run nslookup inside the box and return its stdout."""
    execution = await box.exec("nslookup", args=[host])
    output = ""
    async for line in execution.stdout():
        output += line
    await execution.wait()  # exit code says nothing about a sinkhole
    return output


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
                network=NetworkSpec(outbound=OutboundNetworkSpec(mode="enabled", allow_net=ALLOWED_HOSTS)),
            ),
            name=f"egress-allowlist-{int(time.time())}",
        )
        box_id = box.id
        await box.start()

        # Read the resolved address for a listed host and an unlisted one.
        for host in ("pypi.org", "example.com"):
            print(f"--- nslookup {host} ---")
            print(await resolve(box, host))
    except Exception as exc:
        print(f"allowlist demo failed: {type(exc).__name__}: {exc}")
    finally:
        # Teardown on the runtime, in finally, so a failure above leaves nothing running.
        if box_id:
            try:
                await rt.remove(box_id, force=True)
            except Exception as exc:
                print(f"remove failed: {exc}")


if __name__ == "__main__":
    asyncio.run(main())
```

`mode="disabled"` is the other end of the range. The mode means a box with no network interface at all: DNS and every outbound connection fail, while commands and file operations work as normal. That is the mode to ask for when a box's only job is to run code you do not trust with a network. [Network access](/manage-sandbox/network-access) documents both modes in full.

One more thing to know about a box you did not configure yourself. A box created without a `network` field inherits your organization's default, and that default can be limited egress rather than open egress — so a box that resolves fewer hosts than you expect may be following the organization default rather than misbehaving. That default is set at the platform level; it is not a field of `BoxOptions` and not part of the boxes API.

## Troubleshooting

| Symptom | Cause | Fix |
| - | - | - |
| Fetching a preview URL returns unauthorized | The box is private, and the request carried no credential that the preview proxy accepts | Choose deliberately: issue a signed preview URL for the port, or set the box public with `POST /api/box/{boxIdOrName}/public/true` and accept that anyone with a URL can reach it |
| A signed URL that worked a minute ago now fails | Its lifetime elapsed — the default is 60 seconds when you omit `expiresInSeconds` — or the token was revoked through the expire route | Request a new signed URL, passing an `expiresInSeconds` that matches how long a person actually needs |
| A signed URL fails immediately after you issue it | The token was already revoked, or the URL was truncated in transit through a chat client or ticket field | Issue a fresh signed URL and paste the whole `url` value, including its token |
| The preview URL loads but nothing answers, or the connection is refused | The service inside the box is bound to `127.0.0.1`, so traffic arriving on the box's network interface cannot reach it | Bind `0.0.0.0` — `python3 -m http.server 8080 --bind 0.0.0.0`, Flask `app.run(host="0.0.0.0")`, uvicorn `--host 0.0.0.0`. Background: [Network](/cloud/network) |
| The first request to a stopped box hangs for about half a minute, then returns `503 {"message":"box is starting; retry shortly"}` with `Retry-After: 3` | **That request woke the box.** A preview request no longer fails against a stopped box — it starts it, waits, and tells you when to come back if the box is not ready in time | Honour `Retry-After` and retry. Raise or disable the idle timeout for a box that must answer immediately — see [Stop when idle](/cloud/box-lifecycle#stop-when-idle) |
| `502 {"message":"box unreachable","code":"BAD_GATEWAY"}` right after a box wakes | The box is running again, but the service inside it is not. A process you started with `exec` does not come back by itself — only the box's main command does | Start your service as the box's **main command** rather than with `exec`, so waking the box is enough to serve it. See [The main command](/manage-sandbox/lifecycle#the-main-command) |
| `404 {"message":"not found: tunnel not found"}` from a preview URL | No tunnel is open on that port. Being handed a URL does not open one | Open a tunnel for the port — see [Get a preview URL for a port](#get-a-preview-url-for-a-port) |
| The preview URL answers for one port and 404s for another | A preview URL addresses a single port. The second port needs its own | Fetch `GET /api/box/{boxIdOrName}/ports/{port}/preview-url` again with the other port number |
| An outbound request in the box connects to `0.0.0.0` and fails there | The host is not on the box's `allow_net` list, and a blocked host is sinkholed rather than refused | Add the host to `allow_net` when the box legitimately needs it. Verify by reading the resolved address, not the exit code — see [Network access](/manage-sandbox/network-access) |
| `nslookup` of a blocked host exits `0`, so a script treats it as reachable | The lookup succeeded; it just answered `0.0.0.0` | Test the resolved address in your script, for example by checking whether the output contains `0.0.0.0` |
| Opening a tunnel fails with `Box ${boxId} is not public; set public: true before opening a tunnel`, on code that used to work | Inbound has defaulted to `disabled` since 0.10.5, and the flat `NetworkSpec(mode=...)` configures outbound only | Create the box with `inbound=InboundNetworkSpec(mode="enabled")`, or flip the existing box with the public flag — see [A new box is private](#a-new-box-is-private) |
| `InvalidArgumentError: ... inbound.allow_net is not supported yet` | An inbound allowlist was passed. Inbound is governed by `mode` alone | Drop `allow_net` from the `InboundNetworkSpec`. To admit one audience rather than everyone, keep the box private and issue a signed URL |
| The public flag call returns forbidden | The key's holder lacks write access to boxes in your organization | Use a credential with write access to boxes, or ask whoever administers the organization to make the change |
| A box resolves fewer hosts than you expect, and you passed no `network` field | The box inherited your organization's default for limited outbound egress | Pass an explicit `NetworkSpec` with the hosts the box needs, so the box's egress is stated in your code rather than inherited |

## Next steps

> [card] [Network](/cloud/network)
>
> Dial a port inside a box from your own code with an SDK tunnel, for HTTP, WebSocket, or any TCP protocol.

> [card] [Boxes on Cloud](/cloud/boxes)
>
> Images, sizes, and the lifecycle controls that decide whether a shared URL still has a box behind it.

> [card] [Network access](/manage-sandbox/network-access)
>
> The `NetworkSpec` parameter table and the egress allowlist in full.
