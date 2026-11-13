# Images
Source: https://docs.boxlite.ai/cloud/images

The images BoxLite maintains for you, and how to start a box from one of your own instead.

Every box starts from an image. BoxLite maintains four of them, ready to use with no setup:

| Image | What it is |
| - | - |
| `base` | A general-purpose Linux box you install into yourself |
| `python` | Python, ready to run |
| `node` | Node.js, ready to run |
| `sandbaseai-hermes` | The Hermes agent, preinstalled |

They are free and do not count against your image limit.

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
box = await rt.create(BoxOptions(image="python"), name="demo")
```

## Or bring your own

Name any image on a public registry and a box boots it — nothing to upload, build, or approve first:

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
box = await rt.create(BoxOptions(image="ghcr.io/acme/api:1.4.0"), name="demo")
```

> [card] [Use your own image](/cloud/use-your-image)
>
> Start a box from any public registry, and see what gets recorded. **Start here.**

> [card] [Pin a build](/cloud/image-aliases)
>
> Make production boot the exact build you tested, and move it back when a release goes wrong.

> [card] [Private images](/cloud/private-images)
>
> Register a registry login once, then reference private images like any other.

> [card] [The catalog](/cloud/image-catalog)
>
> What is recorded when a box boots, and the limit it counts against.

## Where to do what

| | Console | SDK | CLI |
| - | - | - | - |
| Start a box from any image | Yes | Yes | `boxlite run <image>` |
| See which images you have used | **Images** page | `rt.images.list()` | No |
| Pin a build, roll one back | **Images** page | `rt.images.create_alias()` | No |
| Register a private registry login | **Private registries** tab | `rt.images.registries` | No |

> [!WARNING]
>
> **`boxlite images` does not show the Cloud catalog.** It lists images on the machine you run it from, with or without `BOXLITE_REST_URL` set. Use the console or `rt.images.list()`.

Reach for the console to do something once. Reach for the SDK when it has to happen without you.
