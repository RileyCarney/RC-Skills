# Computer use (desktop)
Source: https://docs.boxlite.ai/agent-tools/computer-use

Boot a full Linux desktop inside a sandbox so an agent can see the screen, move the mouse, click, type, and scroll.

Screenshots come back as base64 PNG, ready to feed to a vision model. Use it when there is no API to call and the interface is the only path — filling forms, operating desktop software, driving GUI-only tools. The high-level `ComputerBox` API is Python and Node; other SDKs drive the desktop through low-level `exec`.

## Quick Example

The minimal flow: start the desktop, wait until ready, then take a screenshot and save it locally. The code is ready to copy and run.

```python Python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio
import base64

import boxlite

async def main() -> None:
    # ComputerBox is an async context manager: entering creates and starts the desktop box
    try:
        async with boxlite.ComputerBox(cpu=2, memory=2048) as desktop:
            # The desktop environment (XFCE + selkies) takes time to initialize; wait until ready first
            await desktop.wait_until_ready(timeout=60)

            # screenshot() returns a dict: {data: base64 PNG, width, height, format}
            shot = await desktop.screenshot()
            print(f"screenshot: {shot['width']}x{shot['height']} {shot['format']}")

            # data is a base64 string; decode it and write a PNG
            with open("desktop.png", "wb") as f:
                f.write(base64.b64decode(shot["data"]))
            print("saved to desktop.png")
    except RuntimeError as e:
        # Image pull failure / no virtualization raises a standard RuntimeError
        print(f"desktop failed to start: {e}")

if __name__ == "__main__":
    asyncio.run(main())
```

```typescript Node.js theme={"theme":{"light":"github-light","dark":"github-dark"}}
import { writeFileSync } from "node:fs";
import { ComputerBox } from "@boxlite-ai/boxlite";

async function main(): Promise<void> {
  const desktop = new ComputerBox({ cpus: 2, memoryMib: 2048 });
  try {
    // Desktop initialization takes time; wait until ready first
    await desktop.waitUntilReady(60);

    // screenshot() returns { data: base64 PNG, width, height, format }
    const shot = await desktop.screenshot();
    console.log(`screenshot: ${shot.width}x${shot.height} ${shot.format}`);

    writeFileSync("desktop.png", Buffer.from(shot.data, "base64"));
    console.log("saved to desktop.png");
  } catch (err) {
    // Image pull failure / no virtualization raises a standard Error
    console.error(`desktop failed to start: ${(err as Error).message}`);
  } finally {
    // Stop manually to release resources; ComputerBox extends SimpleBox and also supports `await using` auto-release
    await desktop.stop();
  }
}

main();
```

## Parameters & Returns

### Constructor parameters

Python `ComputerBox(...)` (keyword arguments):

| Parameter | Type | Required | Default | Description |
| - | - | - | - | - |
| `cpu` | `int` | No | `2` | Number of CPU cores |
| `memory` | `int` | No | `2048` | Memory (MiB) |
| `gui_http_port` | `int` | No | `3000` | Host-mapped HTTP desktop port |
| `gui_https_port` | `int` | No | `3001` | Host-mapped HTTPS desktop port |
| `runtime` | `Boxlite \| None` | No | `None` | Reuse an existing runtime; `None` uses the global default |
| `**kwargs` | — | No | — | Passed through to `SimpleBox` (e.g. `volumes`, `env`, `name`) |

Node `new ComputerBox(options?)` (`ComputerBoxOptions`):

| Field | Type | Required | Default | Description |
| - | - | - | - | - |
| `cpus` | `number` | No | `2` | Number of CPU cores |
| `memoryMib` | `number` | No | `2048` | Memory (MiB) |
| `guiHttpPort` | `number` | No | `3000` | Host-mapped HTTP desktop port |
| `guiHttpsPort` | `number` | No | `3001` | Host-mapped HTTPS desktop port |
| (others) | — | No | — | Inherited from `SimpleBoxOptions` (`image` / `cpus` / `memoryMib` are fixed by ComputerBox; the image cannot be overridden) |

> The image is fixed to `lscr.io/linuxserver/webtop:ubuntu-xfce`, and the display resolution is fixed to `1024x768` (`DISPLAY=:1`). These are set by environment variables injected by the SDK and are not changed via constructor parameters.

### GUI automation methods (Python / Node equivalents)

| Python | Node | Returns | Description |
| - | - | - | - |
| `wait_until_ready(timeout=60)` | `waitUntilReady(timeout=60)` | `None` | Poll until the desktop is ready; raises `TimeoutError` on timeout |
| `screenshot()` | `screenshot()` | `dict` / `Screenshot` | base64 PNG plus width, height, and format |
| `mouse_move(x, y)` | `mouseMove(x, y)` | `None` | Move the mouse to absolute coordinates |
| `left_click()` | `leftClick()` | `None` | Left click at the current position |
| `right_click()` | `rightClick()` | `None` | Right click |
| `middle_click()` | `middleClick()` | `None` | Middle click |
| `double_click()` | `doubleClick()` | `None` | Double click |
| `triple_click()` | `tripleClick()` | `None` | Triple click |
| `left_click_drag(sx, sy, ex, ey)` | `leftClickDrag(sx, sy, ex, ey)` | `None` | Hold the left button and drag from start to end |
| `cursor_position()` | `cursorPosition()` | `(x, y)` / `[x, y]` | Current cursor coordinates |
| `type(text)` | `type(text)` | `None` | Type text from the keyboard |
| `key(text)` | `key(keySequence)` | `None` | Press a key or key combination, e.g. `"Return"`, `"ctrl+c"`, `"alt+Tab"` |
| `scroll(x, y, direction, amount=3)` | `scroll(x, y, direction, amount=3)` | `None` | Scroll at the given coordinates; `direction` is one of `up` / `down` / `left` / `right` |
| `get_screen_size()` | `getScreenSize()` | `(w, h)` / `[w, h]` | Screen resolution |

### `screenshot()` return fields

| Field | Type | Description |
| - | - | - |
| `data` | `str` | base64-encoded PNG data (no prefix; pass straight to `b64decode`) |
| `width` | `int` | Width in pixels (fixed at 1024) |
| `height` | `int` | Height in pixels (fixed at 768) |
| `format` | `str` | Always `"png"` |

### Watching the desktop live in a browser

The desktop ports are mapped to the host (default HTTP `3000` / HTTPS `3001`). After the box starts, open `https://localhost:3001` (or `http://localhost:3000`) in a browser to see the live desktop.

> HTTPS uses a self-signed certificate, so the browser will show a security warning: click "Advanced" then "Proceed" to continue.

### Full automation example (screenshot, click, type)

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio
import base64

import boxlite
from boxlite import ExecError, TimeoutError

async def main() -> None:
    try:
        async with boxlite.ComputerBox(cpu=2, memory=2048) as desktop:
            await desktop.wait_until_ready(timeout=60)

            width, height = await desktop.get_screen_size()
            print(f"screen: {width}x{height}")

            # Move to the center of the screen and click
            await desktop.mouse_move(width // 2, height // 2)
            await desktop.left_click()

            # Type text + press Enter
            await desktop.type("Hello BoxLite!")
            await desktop.key("Return")

            # Scroll
            await desktop.scroll(width // 2, height // 2, "down", amount=3)

            # Save the final screenshot
            shot = await desktop.screenshot()
            with open("after_action.png", "wb") as f:
                f.write(base64.b64decode(shot["data"]))
            print("saved after_action.png")
    except TimeoutError as e:
        print(f"desktop not ready: {e}")
    except ExecError as e:
        # GUI actions use xdotool underneath; a non-zero exit raises ExecError
        print(f"GUI action failed: {e}")
    except RuntimeError as e:
        print(f"desktop failed to start: {e}")

if __name__ == "__main__":
    asyncio.run(main())
```

## Troubleshooting

| Symptom / error | Cause | Fix |
| - | - | - |
| `RuntimeError` (box start / image pull failed) | No hardware virtualization, or a network hiccup during the image pull | On Linux, confirm `/dev/kvm` is available and the user is in the `kvm` group; on macOS Apple Silicon it works directly; wrap the pull in `try/except RuntimeError` and retry |
| `TimeoutError: Desktop did not become ready within 60 seconds` | Slow desktop image initialization (first pull, low-spec machine) | Increase `wait_until_ready(timeout=120)`; confirm the box has enough CPU/memory (default 2 cores / 2048 MiB) |
| `ExecError` (e.g. `mouse_move(...)` failed) | GUI actions call `xdotool` inside the container; a non-zero exit raises | Call `await wait_until_ready()` before acting; confirm coordinates are within the `1024x768` range |
| `ParseError: Failed to parse cursor position ...` | `xdotool` output did not parse as expected | Usually the desktop is not fully ready yet; call `wait_until_ready()` before retrying |
| Browser shows "certificate not secure" when opening the desktop page | HTTPS uses a self-signed certificate | Click "Advanced" then "Proceed"; this is expected |
| Screenshot is all black / blank | The desktop has not finished rendering, or it started moments ago | Call `await wait_until_ready()` before the screenshot, and wait a moment after an action if needed |
| Node: forgot to stop after `new ComputerBox({...})`, leaking resources | The constructor does not auto-stop; leaving scope does not release the box | Call `await desktop.stop()` in a `finally` block (see Quick Example); or use `await using desktop = new ComputerBox({...})` so `Symbol.asyncDispose` (inherited from `SimpleBox`) calls `stop()` automatically at end of scope |
| Want to change the desktop image / resolution, but constructor parameters have no effect | The image and resolution are fixed by the SDK (`lscr.io/linuxserver/webtop:ubuntu-xfce`, `1024x768`) | The current version does not support changing the image; treat the value returned by `get_screen_size()` as authoritative for resolution |

### Feeding screenshots to a vision model (computer-use loop)

The base64 PNG returned by `screenshot()` can be passed directly as image input to a model that supports computer-use. The actions the model emits (click coordinates, text to type, keys to press) are then mapped back to the `mouse_move` / `left_click` / `type` / `key` methods above, forming a "look at the screen, decide, act, look again" loop. The coordinate origin is the top-left corner, and the range matches the value returned by `get_screen_size()`.
