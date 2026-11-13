# Manage sandboxes
Source: https://docs.boxlite.ai/manage-sandbox/index

Create, configure, and reclaim boxes — the type, the lifecycle, and the four dials that shape what a box can see, use, and reach.

Two objects, and everything here is one of them. The **runtime** creates, finds, and reclaims boxes. A **box** is one microVM you run things in.

A box you create is yours until you remove it, and every configuration choice below is made at creation time.

## In this section

> [card] [Box types](/manage-sandbox/sandbox-types)
>
> Six constructors, each tuned for one job. **Start here** — the type decides most of the rest.

> [card] [Lifecycle](/manage-sandbox/lifecycle)
>
> Created, running, stopped, removed — and what survives each transition.

> [card] [Compute resources](/manage-sandbox/compute-resources)
>
> CPU, memory, and disk, so a workload is neither starved nor wasteful.

> [card] [Environment](/manage-sandbox/environment)
>
> Variables, run user, and working directory inside the box.

> [card] [Volumes](/manage-sandbox/volumes)
>
> Mount a host directory so both sides read and write the same files.

> [card] [Network access](/manage-sandbox/network-access)
>
> Expose a service to the host, and bound what the box can reach.

> [card] [Secrets and security](/manage-sandbox/secrets-and-security)
>
> Deliver credentials without the sandbox seeing them; tighten isolation.

> [card] [Snapshots](/manage-sandbox/snapshots)
>
> Save disk state, clone a box, or pack one into an archive.

## Which page do I want?

| You are asking | Page |
| - | - |
| Which box type do I need? | [sandbox types](/manage-sandbox/sandbox-types) |
| What happens when my program exits? | [lifecycle](/manage-sandbox/lifecycle) |
| How much CPU and memory should I give it? | [compute resources](/manage-sandbox/compute-resources) |
| How do I get a file in or out? | [volumes](/manage-sandbox/volumes) |
| How do I reach a server running inside? | [network access](/manage-sandbox/network-access) |
| How do I pass an API key without leaking it? | [secrets and security](/manage-sandbox/secrets-and-security) |
