# Use your own image
Source: https://docs.boxlite.ai/cloud/use-your-image

Start a Cloud box from any image on a public registry, and see what your catalog recorded about it.

Name the image. There is nothing to upload, build, or approve first.

## Before you start

* An API key exported as `BOXLITE_API_KEY`, and the REST URL as `BOXLITE_REST_URL`. See [API keys](/cloud/api-keys).
* `pip install boxlite`.

## Start the box

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio, os
from boxlite import ApiKeyCredential, Boxlite, BoxliteRestOptions, BoxOptions

rt = Boxlite.rest(BoxliteRestOptions(
    url=os.environ["BOXLITE_REST_URL"],
    credential=ApiKeyCredential(os.environ["BOXLITE_API_KEY"]),
))

async def main() -> None:
    box = await rt.create(BoxOptions(image="docker.io/library/alpine:3.20"), name="demo")
    print(box.id)

asyncio.run(main())
```

From the console it is **New box**, then type the reference. From the CLI:

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
boxlite run docker.io/library/alpine:3.20
```

## Writing the reference

A short name means Docker Hub: `alpine` is `docker.io/library/alpine:latest`.

> [!WARNING]
>
> **`base`, `python`, and `node` are BoxLite's images, not Docker Hub's.** `image="python"` boots BoxLite's Python box. Write `docker.io/library/python:3.12-slim` for Docker Hub's.

## What gets recorded

The first box to boot an image adds it to your [catalog](/cloud/image-catalog), and from then on that reference boots the same build — a box's image reads back by digest, not by tag:

```text theme={"theme":{"light":"github-light","dark":"github-dark"}}
docker.io/library/alpine@sha256:c64c687cbea9…
```

The registry is not consulted again, so a tag someone moves upstream does not move for you. When you do want to move it, that is [an alias](/cloud/image-aliases).

See what you have used:

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
images = await rt.images.list()
```

> [!NOTE]
>
> Recording happens when the box **boots**, not when `create()` returns — about 12 seconds later in a measured run. Reading the catalog immediately usually finds nothing. The [catalog page](/cloud/image-catalog#two-things-about-the-timing) has the polling pattern.

## When a pull fails

```text theme={"theme":{"light":"github-light","dark":"github-dark"}}
Box state transition failed: Failed to pull image 'acme/api:1.4.0':
docker.io refused the pull (UNAUTHORIZED). The image is private or does
not exist, and no registry login of the organization covers it.
```

Three causes, in order of likelihood: the reference has a typo, the image is private and needs [a registry login](/cloud/private-images), or the tag does not exist.

> [!WARNING]
>
> **A create that fails on its image still leaves the box behind**, and you never received its id. Remove it by the name you passed to `create()`.

## Next

> [card] [Pin a build](/cloud/image-aliases)
>
> Name the exact build production should boot.

> [card] [Private images](/cloud/private-images)
>
> Register a login so boxes can pull images that are not public.
