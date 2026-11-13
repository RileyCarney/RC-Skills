---
name: boxlite-human-tools
description: Hand a running BoxLite sandbox to a human operator — share an interactive XFCE desktop in any browser via ComputerBox noVNC (HTTP/HTTPS) or inspect/drive an isolated Chromium/Firefox browser directly from host Chrome DevTools via BrowserBox CDP/Playwright endpoints.
---

# Human Tools (Desktop & Browser Access)

Give a human operator live visual access to a running BoxLite microVM without exposing the host machine.

## Documentation Map (3 Pages)

| Tool | Local Doc | Live Docs |
| - | - | - |
| Overview | [index.md](../../docs/human-tools/index.md) | [human-tools](https://docs.boxlite.ai/human-tools/index.md) |
| Browser Access (`BrowserBox` / DevTools) | [browser-access.md](../../docs/human-tools/browser-access.md) | [browser-access](https://docs.boxlite.ai/human-tools/browser-access.md) |
| Desktop Access (`ComputerBox` / noVNC) | [desktop-access.md](../../docs/human-tools/desktop-access.md) | [desktop-access](https://docs.boxlite.ai/human-tools/desktop-access.md) |

---

## 1. Browser Access (`BrowserBox` + Chrome DevTools)

Run Chromium (`mcr.microsoft.com/playwright:v1.58.0-jammy`) inside the VM and hand the DevTools WebSocket URL to a human's local Chrome (`chrome://inspect` -> Configure) or host Playwright script (`playwright==1.58.0` / `playwright-core@1.58.0`).

```python
import asyncio, boxlite

async def main():
    async with boxlite.BrowserBox(boxlite.BrowserBoxOptions(browser="chromium")) as browser:
        cdp_endpoint = await browser.endpoint(timeout=60)
        print(f"Open Chrome -> chrome://inspect -> Configure -> {cdp_endpoint}")
        input("Press Enter to close sandbox...")

asyncio.run(main())
```

### Rules & Limitations

* **Two mutually exclusive modes** (both bind host port `3000` by default):
  * `await browser.endpoint(timeout=60)` returns direct **CDP** (Chromium) or **WebDriver BiDi** (Firefox). **WebKit raises `ValueError` (Python) / `BoxliteError` (Node)**.
  * `await browser.playwright_endpoint(timeout=60)` returns the **Playwright Server WS endpoint** (supports `chromium`, `firefox`, and `webkit`; requires exact Playwright `1.58.0` client).
* On exit from `async with` (Python) or `await using` / `await box.stop()` (Node), `auto_remove=True` destroys the browser and all downloaded files/cookies.

---

## 2. Desktop Access (`ComputerBox` + Browser noVNC)

`ComputerBox` runs XFCE (`lscr.io/linuxserver/webtop:ubuntu-xfce`, `1024x768`, `DISPLAY=:1`) with a built-in noVNC web server — no local VNC client needed.

```python
import asyncio, boxlite

async def main():
    async with boxlite.ComputerBox(
        cpu=2,
        memory=2048,
        gui_http_port=3000,   # host port -> guest 3000
        gui_https_port=3001,  # host port -> guest 3001 (self-signed cert)
    ) as desktop:
        await desktop.wait_until_ready(timeout=60)
        print("Share HTTP : http://localhost:3000")
        print("Share HTTPS: https://localhost:3001")
        while True:
            await asyncio.sleep(3600)

asyncio.run(main())
```

### Parameters & Methods

| Parameter / Method | Python | Node (`@boxlite-ai/boxlite`) | Default / Notes |
| - | - | - | - |
| CPU cores | `cpu` | `cpus` | `2` (>= 2 recommended) |
| Memory (MiB) | `memory` | `memoryMib` | `2048` (>= 2048 recommended) |
| Host HTTP port | `gui_http_port` | `guiHttpPort` | `3000` (maps to guest `3000`) |
| Host HTTPS port | `gui_https_port` | `guiHttpsPort` | `3001` (maps to guest `3001`, self-signed cert) |
| Wait until rendered | `await desktop.wait_until_ready(timeout=60)` | `await desktop.waitUntilReady(60)` | Raises `TimeoutError` if exceeded |
| Preview snapshot | `await desktop.screenshot()` | `await desktop.screenshot()` | `{ data (base64 PNG), width, height, format }` |
| Resolution | `await desktop.get_screen_size()` | `await desktop.getScreenSize()` | `(1024, 768)` |

### Remote Access, Volumes & Traditional VNC

* **Remote users**: Replace `localhost` with the host's reachable IP/hostname and open `gui_http_port`/`gui_https_port` in your host firewall (`ComputerBox` only maps guest -> host ports).
* **Self-signed HTTPS warning**: Expected for port `3001`; click *Advanced -> Proceed* or use `http://localhost:3000`.
* **Traditional VNC clients (RealVNC / TigerVNC)**: There is **no** standalone `VncBox` / `DesktopBox` or `vnc://` SDK helper. Prefer built-in noVNC; if native VNC protocol is strictly required, install `x11vnc`/`tigervnc` inside a custom box and expose its TCP port via `ports=[(host_port, 5900)]`.
* **Mounted volume gotcha**: In Python `ComputerBox(..., volumes=[("/host", "/mnt", True)])`, the 3rd element **must be a `bool`** (`True`/`False`). Passing `"ro"`/`"rw"` raises `TypeError`.
