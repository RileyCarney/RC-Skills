# Inspect an in-box browser from your DevTools
Source: https://docs.boxlite.ai/human-tools/browser-access

Attach your own Chrome DevTools to a browser running inside a sandbox, to watch or drive it by hand.

Your automation code stays on the host; only the browser and everything it downloads run in the microVM, so a malicious script or a leaking process cannot reach your machine. Useful for scraping untrusted sites, parallel cross-browser testing, and giving an agent a controllable browser.

## Quick Example

The simplest happy path: start a BrowserBox, get a WebSocket endpoint, connect with local Playwright, and open a page.

```python Python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio
import boxlite

# Connecting to the in-box browser requires the playwright client library on this machine
# pip install "playwright==1.58.0"   # must match the in-box Playwright Server
from playwright.async_api import async_playwright

async def main():
    try:
        # Default chromium, 2 CPU / 2048 MiB; the box only starts on entering async with
        async with boxlite.BrowserBox() as browser:
            # Start the Playwright Server inside the box, return a host-connectable WebSocket endpoint
            ws_endpoint = await browser.playwright_endpoint()
            print(f"Ready, endpoint: {ws_endpoint}")  # e.g. ws://localhost:3000/

            async with async_playwright() as p:
                # Connect from the host to the browser inside the box
                browser_ctx = await p.chromium.connect(ws_endpoint)
                page = await browser_ctx.new_page()

                await page.goto("https://example.com")
                print("title:", await page.title())

                await browser_ctx.close()
    except Exception as exc:
        # Image pull failure, no virtualization, etc. raise standard exceptions; catch-all here
        print(f"BrowserBox failed: {type(exc).__name__}: {exc}")

if __name__ == "__main__":
    asyncio.run(main())
```

```typescript Node.js theme={"theme":{"light":"github-light","dark":"github-dark"}}
// npm install @boxlite-ai/boxlite playwright-core
import { BrowserBox } from "@boxlite-ai/boxlite";
import { chromium } from "playwright-core";

async function main(): Promise<void> {
  try {
    // Default chromium, 2 CPU / 2048 MiB; the box only starts on first use
    await using browser = new BrowserBox();
    // Start the Playwright Server inside the box, return a host-connectable WebSocket endpoint
    const wsEndpoint = await browser.playwrightEndpoint();
    console.log(`Ready, endpoint: ${wsEndpoint}`); // e.g. ws://localhost:3000/

    const browserCtx = await chromium.connect(wsEndpoint);
    const page = await browserCtx.newPage();

    await page.goto("https://example.com");
    console.log("title:", await page.title());

    await browserCtx.close();
  } catch (err) {
    // Image pull failure, no virtualization, etc. throw standard Errors; catch-all here
    console.error(`BrowserBox failed: ${err instanceof Error ? err.message : err}`);
  }
}

main();
```

When the `async with` block exits, the box stops and is cleaned up automatically (`auto_remove` is enabled by default).

***

## Reference and troubleshooting

`BrowserBox` construction options, the two connection modes, the port model, and the full troubleshooting list
(Playwright version pinning, WebKit limits, port conflicts, connection timeouts) are documented once on
[Browser automation](/agent-tools/browser-automation) — that page is the reference for both the agent-driven
and the human-driven paths.

## Take over the browser from your own DevTools

The Quick Example above connects a *script* to the box. To drive the browser by hand instead, ask for the Chrome
DevTools Protocol (CDP) address and paste it into `chrome://inspect` — you then inspect pages and tune selectors in
your own DevTools while the browser itself stays inside the sandbox.

```python Python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio
import boxlite

async def main():
    try:
        # Browser type is set through BrowserBoxOptions, not constructor keywords
        async with boxlite.BrowserBox(
            boxlite.BrowserBoxOptions(browser="chromium")
        ) as browser:
            cdp_endpoint = await browser.endpoint(timeout=60)
            print(f"Paste into Chrome's chrome://inspect -> Configure: {cdp_endpoint}")

            input("Press Enter when you are done to close the sandbox...")
    except ValueError as exc:
        # webkit has no CDP; use playwright_endpoint() for that browser
        print(f"This browser does not support CDP direct connect: {exc}")
    except RuntimeError as exc:
        print(f"Sandbox failed to start: {exc}")

if __name__ == "__main__":
    asyncio.run(main())
```

```typescript Node.js theme={"theme":{"light":"github-light","dark":"github-dark"}}
import { BoxliteError, BrowserBox } from "@boxlite-ai/boxlite";

async function main(): Promise<void> {
  try {
    // Browser type is set through the constructor options, not separate keywords
    await using browser = new BrowserBox({ browser: "chromium" });
    const cdpEndpoint = await browser.endpoint(60);
    console.log(`Paste into Chrome's chrome://inspect -> Configure: ${cdpEndpoint}`);
  } catch (err) {
    // webkit has no CDP; use playwrightEndpoint() for that browser
    console.error(`error: ${err instanceof BoxliteError ? err.message : err}`);
  }
}

main();
```

> `endpoint()` and `playwright_endpoint()` are mutually exclusive on one instance — calling the second one after the
> first raises `RuntimeError`. Pick the CDP endpoint for hands-on debugging, the Playwright endpoint for scripts.

## Related pages

* [Browser automation](/agent-tools/browser-automation) — full `BrowserBox` reference, both connection modes, and troubleshooting
* [Share a desktop](/human-tools/desktop-access) — when you need a full graphical desktop rather than a browser
* [Network access](/manage-sandbox/network-access) — port publishing model
