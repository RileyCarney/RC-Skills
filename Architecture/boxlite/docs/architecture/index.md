# Architecture
Source: https://docs.boxlite.ai/architecture/index

What BoxLite actually is under the API: the components, the path one exec takes, and how isolation, networking, storage, and boot latency work.

BoxLite starts a real lightweight VM per box. Understanding the layers helps when you are choosing security settings, diagnosing a slow start, or explaining the isolation story to a security reviewer.

The chain, end to end:

```
Your code → SDK → Rust core → Shim → Jailer → MicroVM → Guest Agent
```

## In this section

> [card] [Core components](/architecture/core-components)
>
> What each module owns, where its state lives, and which metrics it emits. **Start here.**

> [card] [Security and isolation](/architecture/security-and-isolation)
>
> How isolation is layered against a guest assumed hostile from boot.

> [card] [Networking](/architecture/networking)
>
> The user-mode stack, the fixed subnet, and DNS handling.

> [card] [Storage](/architecture/storage)
>
> The digest-keyed image cache and the copy-on-write rootfs.

> [card] [Boot latency](/architecture/boot-latency)
>
> Where the time goes, and why the second start is faster.

## Which page do I want?

| You are asking | Page |
| - | - |
| What are the moving parts? | [core components](/architecture/core-components) |
| How strong is the isolation, really? | [security and isolation](/architecture/security-and-isolation) |
| Why is my first box slow? | [boot latency](/architecture/boot-latency) |
| How does a box reach the internet? | [networking](/architecture/networking) |
| Where do the bytes live on my disk? | [storage](/architecture/storage) |
