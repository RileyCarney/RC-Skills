# What the catalog records
Source: https://docs.boxlite.ai/cloud/image-catalog

Every image your boxes have booted is recorded once, outlives the box, and counts against a limit — here is how to see it and clear it.

The first time a box boots an image, that image is recorded in your organization's **catalog**. The catalog is what makes [aliases](/cloud/image-aliases) possible, and it is what the image limit counts.

## Seeing it

> [tab] Console
>
> The **Images** page lists every recorded image with its tags, size, how many boxes use it, and when it last started. The header shows where you stand against the limit:
>
> ```text theme={"theme":{"light":"github-light","dark":"github-dark"}}
> 1 of 20 images · 3.5 MiB
> ```
>
> Built-in images appear in their own row at the bottom, marked **free · not counted**.

> [tab] SDK
>
> ```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
> images = await rt.images.list()        # one entry per reference
> usage  = await rt.images.usage()       # count, limit, bytes
> detail = await rt.images.get("docker.io/library/alpine")
> ```
>
> `usage()` answers with the three numbers behind the console's header:
>
> ```text theme={"theme":{"light":"github-light","dark":"github-dark"}}
> ImageUsage(count=1, limit=20, known_bytes=3630321)
> ```
>
> `list()` gives one entry per reference — enough to know what you have used. `get()` opens one name up into every build the catalog has seen of it, which aliases point where, and how those aliases have moved. Versions and history live only on `get()`.

> [!WARNING]
>
> **`boxlite images` does not read this catalog.** It lists the images on the machine you run it from, whether or not `BOXLITE_REST_URL` is set.

## Two things about the timing

**Recording happens when the box boots, not when `create()` returns.** In a measured run the entry appeared about **12 seconds** later. Code that creates a box and immediately reads the catalog usually finds nothing, so poll:

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
for _ in range(10):
    if await rt.images.list():
        break
    await asyncio.sleep(4)
```

A box removed before it boots leaves nothing recorded at all.

**The record outlives the box.** Removing a box does not remove its image. That is normally what you want — the next box from the same image starts without re-pulling — but it is also why a catalog fills up with nothing running.

## The limit

Each organization's catalog holds **20** images.

**Built-in images do not count.** `base`, `python`, `node`, and the others BoxLite maintains are free and sit outside the limit, so a catalog can read `0 of 20` while boxes run on them continuously.

Aliases do not count either. Ten aliases on one image are still one image.

Once the limit is reached, creating a box from an image not already recorded fails. The create is refused; no box is left behind.

## Clearing space

`last_used_at` on each version is the signal — a build nothing has booted in weeks is the safe one to drop.

> [tab] Console
>
> Find the image on the **Images** page. The **BOXES** column shows whether anything still uses it; remove it from the row's action menu.

> [tab] SDK
>
> ```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
> detail = await rt.images.get("docker.io/library/alpine")
> for v in detail.versions:
>     print(v.digest[:19], v.last_used_at, v.size_bytes)
>
> await rt.images.remove("docker.io/library/alpine")
> ```

Removing an image takes its versions, aliases, and history with it. An image a running box still uses cannot be removed.

## Next

> [card] [Pin a build](/cloud/image-aliases)
>
> Name a build so you know which one to keep and which to clear.

> [card] [What a box costs](/cloud/box-costs)
>
> Images are not metered. Boxes and their disks are.
