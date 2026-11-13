# BoxLite Cloud
Source: https://docs.boxlite.ai/cloud/index

The managed cloud for AI agents — compute, a filesystem that outlives the box, a public URL, and hardware isolation around all of it, from a URL and an API key.

**The managed cloud for AI agents.** Your agent gets compute, a filesystem that survives a restart, a public URL for whatever it builds, and hardware-level isolation around all of it — from a URL and an API key.

You run no hosts, cache no images, and plan no capacity. A box starts in about a second, stops itself when it goes idle, and wakes when something reaches for it again.

Cloud is not a separate client library. It is the same `boxlite` package you install locally, and the runtime handle is the only line that changes:

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import os

from boxlite import ApiKeyCredential, Boxlite, BoxliteRestOptions

# The one line that differs from running BoxLite on your own machine.
rt = Boxlite.rest(
    BoxliteRestOptions(
        url=os.environ["BOXLITE_REST_URL"],  # https://api.boxlite.ai
        credential=ApiKeyCredential(os.environ["BOXLITE_API_KEY"]),
    )
)
```

Everything after that line — `create`, `exec`, volumes, tunnels — is the API you already know. The [Quickstart](/cloud/quickstart) has the whole first script, end to end.

## Start here

> [card] [Quickstart](/cloud/quickstart)
>
> Create a key, install the SDK, run your first command on Cloud.

> [card] [Hand it to a coding agent](https://boxlite.ai/agent.md)
>
> `agent.md` is a single file written for coding agents. Every code block in it is executed against the live API before release.

> [card] [Cloud vs open source](/cloud/vs-opensource)
>
> Every difference between the hosted runtime and self-hosted BoxLite, in one table — plus how to port existing code.

## Two shapes, one API

The same `rt.create()` call gives you either shape. What differs is how long the box lives.

> [card] A disposable box
>
> Run untrusted or model-generated code, take the result, throw the box away. Hardware-level isolation without a virtualization host of your own.

> [card] A home for an agent
>
> One box that keeps its filesystem, its packages, and its working state across sessions. The agent installs its tools once instead of rebuilding its world on every run.

The second shape is what a stateful microVM makes possible, and it is the part a plain sandbox API cannot do: an agent writes files, stops, and picks the work back up a week later.

> [!NOTE]
>
> **Idle means no SDK, terminal, or preview traffic.** Work running *inside* the box does not count, so a long unattended job can be stopped mid-run. Set the idle window per box — see [Stop when idle](/cloud/box-lifecycle#stop-when-idle).

## What you get

> [card] [Boxes](/cloud/boxes)
>
> Shared Linux base images, three preset sizes, and a managed lifecycle. Up to **4 vCPU, 32 GiB memory, and 120 GiB storage** per box.

> [card] [Volumes](/cloud/volumes)
>
> Managed storage that outlives the box that wrote it. Mount by a name you choose, and volumes are not metered at all.

> [card] [Network](/cloud/network)
>
> A tunnel to a port inside the box, carrying a public URL — so what your agent builds is reachable without you deploying it.

> [card] [Checkpoints](/cloud/checkpoints)
>
> Save a prepared box and create independent workers from its disk and configuration.

> [card] [Secrets](/cloud/secrets)
>
> Let a box authenticate to external APIs without storing real keys in its environment.

> [card] [Domains](/cloud/domains)
>
> Give a service a fixed public HTTPS address, and keep it when you move to another box.

> [card] [Pricing](/cloud/pricing)
>
> Three metered rates and nothing else. Run wallet-only with no subscription, or take a plan whose quota covers usage first.

Concurrency is set by your plan — 20 boxes on Starter, 100 on Pro, 1000 on Max. See [Wallet or a plan?](/cloud/plans) for which one your usage argues for.

## Build something

Six things people ship on Cloud, each a complete runnable guide:

> [card] [Run Claude Code in a box](/agent-in-box/run-claude-code)
>
> An autonomous coding agent with root inside its own kernel and nothing outside the box.

> [card] [Code interpreter for an LLM](/use-cases/code-interpreter)
>
> A model writes Python, it executes in a disposable box, the box is thrown away.

> [card] [Review untrusted pull requests](/use-cases/sandboxed-ci)
>
> Clone the PR into a box, run the suite, read the diff — with no access to your machine.

> [card] [Data analysis agent](/use-cases/data-analysis-agent)
>
> CSV in, model-written pandas analysis and a chart out.

> [card] [Scrape the web safely](/use-cases/web-scraping-agent)
>
> A browser box feeding clean data to a model, with parsing in a separate box.

> [card] [A persistent shell per user](/use-cases/interactive-dev-environment)
>
> State survives stop and restart, so every user or branch keeps its own environment.
