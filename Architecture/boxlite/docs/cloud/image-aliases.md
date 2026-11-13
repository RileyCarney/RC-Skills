# Pin a build, and roll it back
Source: https://docs.boxlite.ai/cloud/image-aliases

Give the build you tested a name production can boot, move that name on release, and move it back when a release goes wrong.

A tag moves whenever someone pushes. An **alias** does not: it is a name you attach to one exact build in [your catalog](/cloud/image-catalog), and it only moves when you move it.

Point `stable` at the build you tested, create boxes from `stable`, and when the next release is ready, move the alias. When that release is wrong, move it back. Nothing touches the registry.

## Pin the build you tested

> [tab] Console
>
> Open **Images**, choose the image, and pin a name to the version you want from its row.

> [tab] SDK
>
> An alias points at a build, identified by its digest, so read the build first:
>
> ```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
> detail = await rt.images.get("ghcr.io/acme/api")
> digest = detail.versions[0].digest
>
> await rt.images.create_alias(
>     name="ghcr.io/acme/api",
>     alias="stable",
>     digest=digest,
> )
> ```
>
> `alias` must be valid tag syntax; `digest` must be `sha256:` and 64 hex digits. Anything else is refused before it reaches the catalog.

## Boot it

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
box = await rt.create(
    BoxOptions(image="ghcr.io/acme/api:stable"),
    name="prod-worker",
)
```

## Promoting and rolling back are one operation

There is no separate move call. Point the same alias at a different build and it is there instead:

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
# Promote: stable now means the build you just tested
await rt.images.create_alias(
    name="ghcr.io/acme/api", alias="stable", digest=new_digest,
)

# Roll back: stable means the previous one again
await rt.images.create_alias(
    name="ghcr.io/acme/api", alias="stable", digest=previous_digest,
)
```

Boxes created afterwards boot the build the alias now names. **Boxes already running are untouched** — a rollback does not restart anything, so recycle them yourself if that is what you need.

## Finding the build to roll back to

The catalog keeps every move, naming the build on each side of it. That history is how you find what `stable` meant before:

> [tab] Console
>
> The image's page shows each version and the names currently on it.

> [tab] SDK
>
> ```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
> detail = await rt.images.get("ghcr.io/acme/api")
> for event in detail.history:
>     print(event.alias, event.from_digest, "->", event.to_digest, event.recorded_at)
> ```
>
> `from_digest` is empty the first time an alias is created.

## Remove an alias

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
await rt.images.delete_alias(name="ghcr.io/acme/api", alias="stable")
```

The build stays in the catalog; only the name you gave it is gone.

## Things that will bite you

* **An alias is not a tag.** A tag is part of the reference the image was pulled as, and the catalog records it read-only. An alias is yours, and is the only part you can move.
* **An alias belongs to one image name.** `stable` on `ghcr.io/acme/api` has nothing to do with `stable` on another repository.
* **The CLI cannot do this.** Aliases are a console or SDK operation.

## Next

> [card] [The catalog](/cloud/image-catalog)
>
> Where builds and their history are kept, and the limit they count against.

> [card] [Private images](/cloud/private-images)
>
> Pinning works the same on images from a private registry.
