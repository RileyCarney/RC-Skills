# GitHub operations
Source: https://docs.boxlite.ai/agent-tools/github-operations

Let an agent clone, commit, push, and open pull requests from inside a sandbox — with your GITHUB_TOKEN never entering it.

A sandbox is a networked Linux machine, so `git` and `gh` work as they always do through `SimpleBox.exec(...)`. What BoxLite adds is the safety layer around them: the token stays on the host, and outbound access narrows to GitHub.

## Quick Example

Install git inside an Ubuntu sandbox, clone a **public** repository, and read the most recent commit. The whole snippet is ready to copy and run (cloning a public repo needs no token).

```python Python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio
from boxlite import SimpleBox, BoxliteError

async def main() -> None:
    # ubuntu base image makes it convenient to install git via apt-get;
    # disk_size_gb=8 leaves room for git's full dependency chain (measured at 3% used)
    try:
        async with SimpleBox(image="ubuntu:24.04", disk_size_gb=8) as box:
            # 1) Install git (a non-zero exit from exec does not raise; check exit_code yourself)
            setup = await box.exec("bash", "-lc", "apt-get update && apt-get install -y git")
            if setup.exit_code != 0:
                print("git install failed:\n", setup.stderr)
                return

            # 2) Clone a public repository
            clone = await box.exec(
                "git", "clone", "--depth", "1",
                "https://github.com/octocat/Hello-World.git", "/work/repo",
            )
            if clone.exit_code != 0:
                print("clone failed:\n", clone.stderr)
                return

            # 3) Read the most recent commit
            log = await box.exec(
                "git", "-C", "/work/repo", "log", "-1", "--pretty=%h %s",
            )
            print("latest commit:", log.stdout.strip())
    except BoxliteError as exc:
        # Wrapper-layer error (e.g. validation failure); an image pull failure may be a standard RuntimeError
        print("BoxLite error:", exc)
    except RuntimeError as exc:
        print("runtime error (commonly image pull / virtualization unavailable):", exc)

if __name__ == "__main__":
    asyncio.run(main())
```

```typescript Node.js theme={"theme":{"light":"github-light","dark":"github-dark"}}
import { BoxliteError, SimpleBox } from "@boxlite-ai/boxlite";

async function main(): Promise<void> {
  // ubuntu base image makes it convenient to install git via apt-get;
  // diskSizeGb: 8 leaves room for git's full dependency chain (measured at 3% used)
  try {
    await using box = new SimpleBox({ image: "ubuntu:24.04", diskSizeGb: 8 });
    // 1) Install git (a non-zero exit from exec does not throw; check exitCode yourself)
    const setup = await box.exec("bash", "-lc", "apt-get update && apt-get install -y git");
    if (setup.exitCode !== 0) {
      console.error("git install failed:\n", setup.stderr);
      return;
    }

    // 2) Clone a public repository
    const clone = await box.exec(
      "git", "clone", "--depth", "1",
      "https://github.com/octocat/Hello-World.git", "/work/repo",
    );
    if (clone.exitCode !== 0) {
      console.error("clone failed:\n", clone.stderr);
      return;
    }

    // 3) Read the most recent commit
    const log = await box.exec("git", "-C", "/work/repo", "log", "-1", "--pretty=%h %s");
    console.log("latest commit:", log.stdout.trim());
  } catch (err) {
    // Wrapper-layer error, or a standard Error for image pull / virtualization failures
    console.error(`${err instanceof BoxliteError ? "BoxLite error" : "runtime error"}: ${err instanceof Error ? err.message : err}`);
  }
}

main();
```

Verified: real run prints `latest commit: 7fd1a60 Merge pull request #6 from Spaceghost/patch-1`.

## Injecting GITHUB_TOKEN with Secret (push / private repos)

The command-line arguments and logs of `exec` may be recorded, so **do not** embed the token in a URL or on the command line. `Secret` provides stronger isolation: **the real token never enters the sandbox**.

How `Secret` works (note how it differs from "injecting an environment variable"):

* Inside the sandbox, only a **placeholder** environment variable appears: `BOXLITE_SECRET_<UPPERCASE_NAME>`, whose value is the placeholder string `<BOXLITE_SECRET:<name>>` (**not** the real token).
* When a program inside the sandbox makes an HTTP(S) request to a host in the `hosts` list and the **placeholder appears in a request header, the URL query string, or the request body** (the URL path is not substituted), BoxLite's MITM proxy substitutes the placeholder with the real value on the outbound path before forwarding. The real value exists only in the host proxy and never lands inside the sandbox.
* So the usage is: put the placeholder in headers such as `Authorization`. This fits naturally with Bearer auth in `curl` / `gh api`, and with `git -c http.extraHeader=...`.

> Note: embedding credentials in a URL such as `git clone https://user:token@github.com/...` **does not work with** Secret — git Base64-encodes the credentials into `Authorization: Basic ...`, and once encoded the placeholder can no longer be matched verbatim for substitution. For git, use `http.extraHeader` to place the placeholder in **plaintext** in a request header (see the example below).

`SimpleBox(..., secrets=[...])` works too — it forwards the list to `BoxOptions`. The example below uses the low-level `Boxlite` + `Box` only to make the runtime lifecycle explicit.

```python Python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio
from boxlite import BoxOptions, Boxlite, BoxliteError, NetworkSpec, OutboundNetworkSpec, Secret

# TODO: replace with your real token; prefer reading from an environment variable over hardcoding
GITHUB_TOKEN = "<YOUR_GITHUB_TOKEN>"  # e.g. os.environ["GITHUB_TOKEN"]

# After the Secret is injected, the placeholder env var is named BOXLITE_SECRET_GITHUB_TOKEN,
# whose value is the placeholder string (below); the real token is not inside the sandbox.
PLACEHOLDER = "<BOXLITE_SECRET:github_token>"

async def main() -> None:
    options = BoxOptions(
        image="ubuntu:24.04",
        disk_size_gb=8,  # leaves room for git's full dependency chain (measured at 3% used)
        # Disable auto-remove so the runtime.remove in finally is the single cleanup point (default auto_remove=True)
        auto_remove=False,
        # Narrow outbound network to GitHub (default NetworkSpec is Enabled with allow_net=[], i.e. allow all)
        network=NetworkSpec(outbound=OutboundNetworkSpec(mode="enabled", allow_net=["github.com", "api.github.com"])),
        # Inject via Secret: the MITM proxy replaces the placeholder with the real token only when
        # an outbound request matches hosts and the placeholder appears in the header/body.
        secrets=[
            Secret(
                name="github_token",
                value=GITHUB_TOKEN,
                hosts=["github.com", "api.github.com"],
            ),
        ],
    )

    try:
        # Boxlite is a synchronous context manager (do not await); but runtime.create/remove are coroutines and must be awaited.
        with Boxlite.default() as runtime:
            box = await runtime.create(options)
            try:
                async with box:  # Box is an async context manager
                    # Install git inside the sandbox
                    # The native Box.exec returns an Execution (streaming handle); await wait() to get the exit code
                    setup = await box.exec(
                        "bash", args=["-lc", "apt-get update && apt-get install -y git"],
                    )
                    setup_result = await setup.wait()
                    if setup_result.exit_code != 0:
                        print("git install failed")
                        return

                    # Clone a private repo: use http.extraHeader to put the placeholder in plaintext in the Authorization header;
                    # the real token is substituted by the MITM proxy on the outbound request. The placeholder itself is not a secret and may appear on the command line.
                    clone = await box.exec(
                        "git",
                        args=[
                            "-c", f"http.extraHeader=Authorization: Bearer {PLACEHOLDER}",
                            "clone", "--depth", "1",
                            # TODO: replace with your private repository
                            "https://github.com/<YOUR_ORG>/<YOUR_PRIVATE_REPO>.git",
                            "/work/repo",
                        ],
                    )
                    clone_result = await clone.wait()
                    print("clone exit code:", clone_result.exit_code)
            finally:
                await runtime.remove(box.id, force=True)  # runtime method: remove lives on the runtime
    except BoxliteError as exc:
        print("BoxLite error:", exc)
    except RuntimeError as exc:
        print("runtime error:", exc)

if __name__ == "__main__":
    asyncio.run(main())
```

```typescript Node.js theme={"theme":{"light":"github-light","dark":"github-dark"}}
import { BoxliteError, JsBoxlite } from "@boxlite-ai/boxlite";

// TODO: replace with your real token; prefer reading from an environment variable over hardcoding
const GITHUB_TOKEN = process.env.GITHUB_TOKEN ?? "<YOUR_GITHUB_TOKEN>";

// After the Secret is injected, the sandbox sees only this placeholder string;
// the real token is not inside the sandbox.
const PLACEHOLDER = "<BOXLITE_SECRET:github_token>";

async function main(): Promise<void> {
  const runtime = JsBoxlite.withDefaultConfig();
  let boxId: string | null = null;
  try {
    const box = await runtime.create({
      image: "ubuntu:24.04",
      diskSizeGb: 8, // leaves room for git's full dependency chain (measured at 3% used)
      // Disable auto-remove so the runtime.remove in finally is the single cleanup point
      autoRemove: false,
      // Narrow outbound network to GitHub (default is enabled with allowNet=[], i.e. allow all)
      network: { outbound: { mode: "enabled", allowNet: ["github.com", "api.github.com"] } },
      // Inject via Secret: the MITM proxy replaces the placeholder with the real token only when
      // an outbound request matches hosts and the placeholder appears in the header/body.
      secrets: [{ name: "github_token", value: GITHUB_TOKEN, hosts: ["github.com", "api.github.com"] }],
    });
    boxId = box.id;

    // Install git inside the sandbox
    const setup = await (await box.exec("bash", ["-lc", "apt-get update && apt-get install -y git"])).wait();
    if (setup.exitCode !== 0) {
      console.error("git install failed");
      return;
    }

    // Clone a private repo: use http.extraHeader to put the placeholder in plaintext in the
    // Authorization header; the real token is substituted by the MITM proxy on the outbound request.
    const clone = await (
      await box.exec("git", [
        "-c", `http.extraHeader=Authorization: Bearer ${PLACEHOLDER}`,
        "clone", "--depth", "1",
        // TODO: replace with your private repository
        "https://github.com/<YOUR_ORG>/<YOUR_PRIVATE_REPO>.git",
        "/work/repo",
      ])
    ).wait();
    console.log("clone exit code:", clone.exitCode);
  } catch (err) {
    console.error(`${err instanceof BoxliteError ? "BoxLite error" : "runtime error"}: ${err instanceof Error ? err.message : err}`);
  } finally {
    if (boxId) await runtime.remove(boxId, true);
    runtime.close();
  }
}

main();
```

> Tip: the low-level `Box.exec(...)` returns an `Execution` (a streaming handle); call `await execution.wait()` to get the exit code. If you only need the three fields `exit_code` / `stdout` / `stderr` and want something simpler, prefer `SimpleBox` (as in the Quick Example), whose `exec` returns an `ExecResult` directly. The low-level `Box` is used here only to make the runtime lifecycle explicit. The low-level `JsBox.exec(...)` (via `JsBoxlite.create`) accepts `args` as a plain array with `env` optional, unlike `SimpleBox.exec`'s array overload, which requires `env`.
>
> Likewise, when calling the GitHub REST API, put the placeholder in the Bearer header (the proxy substitutes the real value). If `gh` is not pre-installed, use `curl`, for example:
> `curl -H "Authorization: Bearer <BOXLITE_SECRET:github_token>" https://api.github.com/user`.

## Parameters & Returns

This page introduces no new API; it only reuses existing capabilities. The tables below list the real parameters relevant to "running Git inside a sandbox".

### `SimpleBox.exec(cmd, *args, ...)` key parameters

| Parameter | Type | Required | Description |
| - | - | - | - |
| `cmd` | `str` | Yes | The executable to run, e.g. `"git"`, `"bash"` |
| `*args` | `str` | No | Command arguments, e.g. `"clone"`, `"--depth"`, `"1"` |
| `env` | `dict[str, str]` | No | Environment variables; **SimpleBox uses a dict** (the low-level `Box.exec` uses `list[tuple]`) |
| `user` | `str` | No | Run as the given user |
| `timeout` | `float` | No | Timeout in seconds (the corresponding parameter on the low-level `Box.exec` is `timeout_secs`) |
| `cwd` | `str` | No | Working directory |

Returns `ExecResult`:

| Field | Type | Description |
| - | - | - |
| `exit_code` | `int` | Exit code; **a non-zero exit does not raise** — check it yourself |
| `stdout` | `str` | Standard output |
| `stderr` | `str` | Standard error |
| `error_message` | `str \| None` | Non-None only when the process died abnormally |

### `Secret(...)` (credential injection entry point)

| Parameter | Type | Required | Description |
| - | - | - | - |
| `name` | `str` | Yes | Secret name; injects the placeholder env var `BOXLITE_SECRET_<UPPERCASE_NAME>` into the sandbox (value is the placeholder, not the real value) |
| `value` | `str` | Yes | The real value; lives **only in the host MITM proxy** and never enters the sandbox |
| `hosts` | `list[str]` | No | Restrict this secret to these hosts (supports `*.example.com` wildcards); default `[]` |
| `placeholder` | `str` | No | Custom placeholder text; defaults to `<BOXLITE_SECRET:<name>>` |

### `NetworkSpec(...)` (outbound narrowing)

| Parameter | Type | Required | Description |
| - | - | - | - |
| `mode` | `"enabled" \| "disabled"` | **Yes** | `"enabled"` turns networking on; `"disabled"` gives the box no network interface at all |
| `allow_net` | `list[str]` | No | Egress allowlist; default `[]` = allow all |

## Troubleshooting

| Symptom / error | Cause | Fix |
| - | - | - |
| Looking for `box.git_clone()` / `box.open_pr()` | Git and GitHub run through their own CLIs inside the sandbox | Use `box.exec("git", ...)` / `box.exec("gh", ...)` |
| `clone` returns `exit_code == 128` but the code raised nothing | A non-zero exit from `exec` **does not raise**; it returns `ExecResult(exit_code != 0)` | Check `result.exit_code` after every `exec` and read `result.stderr` as needed |
| `git: command not found` | The base image does not ship git | Install it first: `apt-get install -y git` (Debian/Ubuntu) or `apk add git` (Alpine) |
| `apt-get install -y git` fails with `dpkg: error processing archive ... failed to write (No space left on device)` | The default box disk is too small for git's full dependency chain on `ubuntu:24.04` (curl, ssh, ldap, and others) | `disk_size_gb=8` (measured at 3% used after install) |
| `RuntimeError` (image pull failed) | A network hiccup or a wrong image name | Catch `RuntimeError` and retry; confirm the image reference is correct |
| Token appears in logs | The token was embedded in a `git clone https://<token>@...` command-line argument | Use `Secret` and put only the placeholder on the command line (e.g. `git -c http.extraHeader="Authorization: Bearer <BOXLITE_SECRET:github_token>"`); the real value is substituted by the proxy on the outbound path, and restrict `hosts` |
| Secret is set but git/curl still gets 401/403 | The placeholder did not appear in the outbound request, so the proxy could not substitute it: common when credentials are embedded in a `https://user:token@host/...` URL (git Base64-encodes them and the placeholder is broken up), or the target host is not in the `hosts` list | Put the placeholder in a **plaintext request header** (git: `http.extraHeader`; curl/gh: `Authorization: Bearer`); confirm the target host is listed in `Secret.hosts` and `NetworkSpec.allow_net` |
| Push to a private repo returns 403 / auth failure | The PAT lacks permissions, or the placeholder does not match the `Secret` name | Confirm the PAT has `repo` / `workflow` scopes; confirm the placeholder is `<BOXLITE_SECRET:<Secret.name>>` (the name must match `Secret(name=...)` exactly, including case) |
| Sandbox fails to start | No hardware virtualization | Requires Linux + KVM / hardware virtualization; macOS uses the built-in microVM / Hypervisor.framework; without virtualization, startup fails (you can catch the exception and keep the process alive) |

## Related pages

* [Run Python code inside a sandbox](/agent-tools/code-execution-python)
