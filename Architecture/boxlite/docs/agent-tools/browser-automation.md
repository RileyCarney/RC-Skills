# Browser automation
Source: https://docs.boxlite.ai/agent-tools/browser-automation

BrowserBox runs a real Chromium, Firefox, or WebKit inside an isolated microVM and exposes a WebSocket endpoint — your Playwright script stays on the host, only the browser and what it downloads run in the sandbox.

`BrowserBox` does not run your automation script inside the box. It places the browser inside the box and exposes a WebSocket endpoint; **your script runs on the host** and drives the browser remotely, so untrusted page JavaScript, downloads, and cookies never reach your machine.

***

## Prerequisites

* A working BoxLite install (Python `boxlite` or Node `@boxlite-ai/boxlite`) and a machine with hardware virtualization — see [Installation](/getting-started/installation#platform-and-virtualization-requirements-common-to-all-sdks).
* Install the browser-driver client (used to connect from the host):
  * Python: `pip install "playwright==1.58.0"` (you do **not** need `playwright install`; the browser lives in the sandbox)
  * Node: `npm install playwright-core@1.58.0` (an optional peer dependency of `@boxlite-ai/boxlite`)
  * **The client version must match the Playwright Server version inside the sandbox (1.58.0).** If you install an unpinned `pip install playwright` that resolves to a newer version (for example 1.60.0), `connect()` receives `428 Precondition Required`, reports `Playwright version mismatch`, and fails. Pin `1.58.0` explicitly.
* The first run pulls the image `mcr.microsoft.com/playwright:v1.58.0-jammy` (several GB); this requires network access and takes a while.

***

## Quick Example (happy path)

The snippet below starts an isolated Chromium from the host, navigates to example.com, and prints the title. It is ready to copy and run.

```python Python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio
import boxlite

# Connecting to the in-sandbox browser from the host requires the pinned playwright client: pip install "playwright==1.58.0"
from playwright.async_api import async_playwright

async def main() -> None:
    # BrowserBox is an async context manager; entering sets up the browser environment inside the sandbox
    async with boxlite.BrowserBox() as browser_box:
        # Get the Playwright Server WebSocket endpoint (defaults to ws://localhost:3000/)
        ws_endpoint = await browser_box.playwright_endpoint()
        print(f"endpoint: {ws_endpoint}")

        async with async_playwright() as p:
            # Use connect() (not launch()) to attach to the browser inside the sandbox
            browser = await p.chromium.connect(ws_endpoint)
            try:
                page = await browser.new_page()
                await page.goto("https://example.com")
                print("title:", await page.title())
            finally:
                await browser.close()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception as exc:  # Catch startup/connection/pull failures to avoid an unhandled crash
        print(f"BrowserBox failed: {type(exc).__name__}: {exc}")
```

```typescript Node.js theme={"theme":{"light":"github-light","dark":"github-dark"}}
import { BrowserBox } from "@boxlite-ai/boxlite";
import { chromium } from "playwright-core";

async function main(): Promise<void> {
  // Note: BrowserBox is created lazily; the browser only starts on the first endpoint method call
  const box = new BrowserBox({ browser: "chromium" });
  try {
    const wsEndpoint = await box.playwrightEndpoint();
    console.log(`endpoint: ${wsEndpoint}`);

    const browser = await chromium.connect(wsEndpoint);
    try {
      const page = await browser.newPage();
      await page.goto("https://example.com");
      console.log("title:", await page.title());
    } finally {
      await browser.close();
    }
  } catch (err) {
    console.error("BrowserBox failed:", err);
  } finally {
    // When not using `await using` for auto-cleanup, stop manually to release the box
    // (SimpleBox also implements Symbol.asyncDispose, so you may use `await using`)
    await box.stop();
  }
}

main();
```

`@boxlite-ai/boxlite` is an ESM-only package, so the Node example uses ESM syntax.

***

## Two connection modes

`BrowserBox` offers two mutually exclusive ways to connect; a single instance can use only one of them:

| Mode | Method | Protocol | Supported browsers | Use for |
| - | - | - | - | - |
| Playwright Server (recommended) | `playwright_endpoint()` / `playwrightEndpoint()` | Playwright's own WS protocol | chromium / firefox / webkit | Most scenarios, paired with Playwright `connect()` |
| Direct CDP / BiDi | `endpoint()` | Chromium = CDP, Firefox = WebDriver BiDi | chromium / firefox (**WebKit not supported**) | Puppeteer, Selenium, or any CDP/BiDi client |

> A single instance cannot use both `playwright_endpoint()` and `endpoint()` — both bind host port 3000. If you need both modes, start a separate `BrowserBox` for each.

Convenience helper `connect()`: returns an already-connected Playwright `Browser` object directly (it uses Playwright Server mode internally), saving you the manual `connect(ws)` step.

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio
import boxlite

async def main() -> None:
    # WebKit only works in Playwright Server mode; connect() wraps exactly that
    async with boxlite.BrowserBox(boxlite.BrowserBoxOptions(browser="webkit")) as box:
        browser = await box.connect()  # requires pip install "playwright==1.58.0"
        try:
            page = await browser.new_page()
            await page.goto("https://example.com")
            print("title:", await page.title())
        finally:
            await browser.close()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception as exc:
        print(f"failed: {type(exc).__name__}: {exc}")
```

***

## Parameters & Returns

### `BrowserBoxOptions` (Python, dataclass)

Construct as `BrowserBox(options=BrowserBoxOptions(...))`.

| Field | Type | Required | Default | Description |
| - | - | - | - | - |
| `browser` | `str` | No | `"chromium"` | `chromium` / `firefox` / `webkit` |
| `memory` | `int` | No | `2048` | Sandbox memory (MiB) |
| `cpu` | `int` | No | `2` | Number of CPU cores |
| `port` | `int \| None` | No | `None` (i.e. 3000) | Host port for the Playwright Server |
| `cdp_port` | `int \| None` | No | `None` (i.e. 9222) | Host port for CDP / Puppeteer |

`BrowserBox` also accepts extra `**kwargs` that are passed through to the underlying `SimpleBox` (such as `volumes`, `env`, `ports`, `name`, `auto_remove`).

### Node options (`BrowserBoxOptions`, object)

`new BrowserBox({ ... })` inherits from `SimpleBoxOptions` (`Omit<SimpleBoxOptions, "image" | "cpus" | "memoryMib">` — that is, `image` is removed, and `cpus` / `memoryMib` are re-declared as optional fields with browser defaults) and adds browser-specific fields:

| Field | Type | Required | Default | Description |
| - | - | - | - | - |
| `browser` | `"chromium" \| "firefox" \| "webkit"` | No | `"chromium"` | Browser type |
| `port` | `number` | No | `3000` | Host port for the Playwright Server |
| `cdpPort` | `number` | No | `9222` | Host port for CDP |
| `memoryMib` | `number` | No | `2048` | Memory (MiB) |
| `cpus` | `number` | No | `2` | Number of CPU cores |

### Methods / return values

| Method (Python / Node) | Returns | Description |
| - | - | - |
| `playwright_endpoint(timeout=60)` / `playwrightEndpoint(timeout?)` | `str`, like `ws://localhost:3000/` | Playwright Server WS endpoint; starts the server automatically if not running. Works for all browsers |
| `endpoint(timeout=60)` / `endpoint(timeout?)` | `str`, a CDP/BiDi WS endpoint | Direct mode; WebKit not supported (Python raises `ValueError`, Node raises `BoxliteError`) |
| `connect(timeout=60)` / `connect(options?)` | A connected Playwright `Browser` | Convenience wrapper, internally uses Server mode |
| `browser` (property) | `str` | Current browser type |
| `stop()` | — | Stop and release the box (called explicitly in Node; in Python it happens automatically when the `async with` block exits) |

Image and version (fixed): the default image is `mcr.microsoft.com/playwright:v1.58.0-jammy`, corresponding to Playwright **1.58.0**. The client used to connect from the host **must** also be **1.58.0** (a mismatched client is rejected by the server; see Troubleshooting).

***

## Advanced: screenshots and form interaction

Once you have the endpoint, everything else is standard Playwright API (running on the host). The example below shows navigation, a screenshot, and filling a form, with the screenshot saved on the host (not inside the sandbox).

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio
import boxlite
from playwright.async_api import async_playwright

async def main() -> None:
    async with boxlite.BrowserBox() as browser_box:
        ws_endpoint = await browser_box.playwright_endpoint()

        async with async_playwright() as p:
            browser = await p.chromium.connect(ws_endpoint)
            try:
                page = await browser.new_page()
                await page.set_viewport_size({"width": 1280, "height": 720})

                await page.goto("https://httpbin.org/forms/post")
                await page.fill('input[name="custname"]', "John Doe")
                await page.fill('input[name="custemail"]', "john@example.com")
                await page.check('input[value="medium"]')

                # Write the screenshot to a local host path (replace with your own path)
                await page.screenshot(path="<YOUR_PATH>/form.png")  # e.g. ./form.png
                print("screenshot saved")
            finally:
                await browser.close()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception as exc:
        print(f"failed: {type(exc).__name__}: {exc}")
```

### Parallel / cross-browser (each on its own port)

When launching multiple browsers in parallel, you must assign a **different host port** to each instance, otherwise the ports collide.

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio
import boxlite
from playwright.async_api import async_playwright

async def run_one(browser_type: str, port: int) -> None:
    opts = boxlite.BrowserBoxOptions(browser=browser_type, port=port)
    async with boxlite.BrowserBox(opts) as box:
        ws = await box.playwright_endpoint()
        async with async_playwright() as p:
            launcher = getattr(p, browser_type)  # p.chromium / p.firefox / p.webkit (selected dynamically)
            browser = await launcher.connect(ws)
            try:
                page = await browser.new_page()
                await page.goto("https://example.com")
                print(f"{browser_type}: {await page.title()}")
            finally:
                await browser.close()

async def main() -> None:
    await asyncio.gather(
        run_one("chromium", 3000),
        run_one("firefox", 3001),
    )

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception as exc:
        print(f"failed: {type(exc).__name__}: {exc}")
```

***

## Troubleshooting

| Symptom / error | Cause | Fix |
| - | - | - |
| Box fails to start / hangs for a long time | The host has no hardware virtualization (KVM / Hypervisor.framework) | On Linux confirm `/dev/kvm` is available and the user is in the `kvm` group; WSL2 needs nested virtualization enabled; macOS Apple Silicon works by default. Without virtualization it cannot run |
| First run stuck pulling the image / `RuntimeError` | Pulling `mcr.microsoft.com/playwright:v1.58.0-jammy` (several GB), or a network hiccup caused the pull to fail | Reserve time and bandwidth; on failure, retry inside `try/except`. **Note: a pull failure raises a standard `RuntimeError`, not `BoxliteError`** |
| `ImportError: playwright is required for connect()` | The Playwright client is not installed on the host | `pip install "playwright==1.58.0"` (Node: `npm install playwright-core@1.58.0`). The browser is in the sandbox, so you do not need `playwright install` |
| `connect()` reports `428 Precondition Required` / `Playwright version mismatch` | The host Playwright client version differs from the in-sandbox server (1.58.0); Playwright's WS `connect` protocol enforces a major/minor version check | Pin the client to `1.58.0`: `pip install "playwright==1.58.0"` / `npm install playwright-core@1.58.0` |
| `Puppeteer does not support WebKit` (Python `ValueError` / Node `BoxliteError`) | `endpoint()` (direct CDP mode) was called for WebKit | WebKit can only use `playwright_endpoint()` + Playwright `connect()`, or the convenience `connect()` |
| `Cannot use endpoint() when Playwright Server is already running` (Python `RuntimeError` / Node `BoxliteError`) | The same instance called `playwright_endpoint()` first and then `endpoint()` | The two modes are mutually exclusive; start a separate `BrowserBox` for Puppeteer use |
| Port collisions / connection failures with parallel browsers | Multiple instances all use the default host port 3000 | Set a distinct `port` per instance explicitly (e.g. 3000, 3001, 3002) |
| `TimeoutError: Playwright Server ... did not start within 60s` | Wrong image (missing browser binaries) or insufficient resources | Confirm you are using the default Playwright image; raise `memory` / `cpu`; increase `playwright_endpoint(timeout=...)` |
| Firefox `new_page()` hangs in headless (direct BiDi mode) | A limitation of Puppeteer / Firefox BiDi mode | Prefer Playwright Server mode; if you must connect directly, use `browser.pages()[0]` instead of creating a new page |

***

## Related pages

* [Run Python code in a box](/agent-tools/code-execution-python)
* [Agent Tools overview](/agent-tools/index)
