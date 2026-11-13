# Run Python code in a box
Source: https://docs.boxlite.ai/agent-tools/code-execution-python

Run Python inside an isolated microVM with CodeBox and read stdout back — the shortest path for an agent's "write code, execute, read result" loop.

One call, `await cb.run(code)`, starts a `python:slim` sandbox, runs the code, and returns its stdout. `pip install` works inside the box, and everything is cleaned up on exit.

## Quick Example (minimal happy path)

This runs as-is. The first run pulls the image first, which can take tens of seconds.

```python Python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio

import boxlite

async def main() -> None:
    # CodeBox defaults to the "python:slim" image; no arguments required
    try:
        async with boxlite.CodeBox() as cb:
            # run() hands the code to python -c inside the sandbox and returns the stdout string
            output = await cb.run("print('Hello from a microVM!')")
            print(output)  # -> Hello from a microVM!
    except RuntimeError as e:
        # Startup issues such as image pull failure / no virtualization raise a standard RuntimeError
        print(f"CodeBox failed to start: {e}")

if __name__ == "__main__":
    asyncio.run(main())
```

```typescript Node.js theme={"theme":{"light":"github-light","dark":"github-dark"}}
import { CodeBox, ExecError } from "@boxlite-ai/boxlite";

async function main(): Promise<void> {
  const cb = new CodeBox(); // default image "python:slim"
  try {
    const output = await cb.run("print('Hello from Node + microVM!')");
    console.log(output);
  } catch (err) {
    if (err instanceof ExecError) {
      console.error(`Python execution failed exitCode=${err.exitCode}: ${err.stderr}`);
    } else {
      console.error(`CodeBox failed to start: ${err}`);
    }
  } finally {
    await cb.stop();
  }
}

main();
```

> Node's `run()` **does throw** `ExecError` on a non-zero exit — the opposite of Python's `run()`, which never raises. This is the one behavior that does not carry over between the two languages; see [Parameters and Returns](#await-cbruncode-timeoutnone-str) below.

### Install a package, then execute

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio

import boxlite

async def main() -> None:
    try:
        async with boxlite.CodeBox() as cb:
            # Install a third-party library at runtime (equivalent to pip install requests inside the sandbox)
            await cb.install_package("requests")

            output = await cb.run(
                "import requests; "
                "print(requests.get('https://api.github.com/zen').text)"
            )
            print(output)
    except RuntimeError as e:
        print(f"CodeBox failed to start: {e}")

if __name__ == "__main__":
    asyncio.run(main())
```

> Note: `run()` returns **stdout only**. If the code writes to stderr (for example, a traceback), use `exec()` below to get the full result.

### Need both stdout and stderr / check the exit code

`run()` **does not raise** on a non-zero exit and **does not return stderr**. To get the error output or exit code, use `exec()`, which is inherited from `SimpleBox`:

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio

import boxlite

async def main() -> None:
    try:
        async with boxlite.CodeBox() as cb:
            # Intentionally run code that raises an exception
            result = await cb.exec(
                "/usr/local/bin/python", "-c", "raise ValueError('boom')"
            )
            print("exit_code:", result.exit_code)  # non-zero
            print("stdout:", result.stdout)
            print("stderr:", result.stderr)        # the traceback appears here
    except RuntimeError as e:
        print(f"CodeBox failed to start: {e}")

if __name__ == "__main__":
    asyncio.run(main())
```

## Parameters and Returns

### `CodeBox(...)` constructor parameters

`CodeBox` extends `SimpleBox`; other parameters (`volumes`, `network`, `secrets`, `advanced`, and so on) pass through via `**kwargs`. To lock a `CodeBox` down for untrusted code, see [Harden the box for untrusted code](/agent-tools/code-execution-any-language#harden-the-box-for-untrusted-code).

| Parameter | Type | Required | Default | Description |
| - | - | - | - | - |
| `image` | `str` | No | `"python:slim"` | A container image that includes Python |
| `memory_mib` | `int \| None` | No | `None` (system default) | Memory limit in MiB. When `None`, the runtime applies its system default — see [Compute resources](/manage-sandbox/compute-resources#defaults) |
| `cpus` | `int \| None` | No | `None` (system default) | Number of CPU cores. When `None`, the runtime applies its system default — see [Compute resources](/manage-sandbox/compute-resources#defaults) |
| `runtime` | `Boxlite \| None` | No | `None` (global default runtime) | Reuse an existing runtime handle |
| `**kwargs` | — | No | — | Passed through to `SimpleBox` / `BoxOptions` (for example `name`, `auto_remove`, `volumes`, `network`) |

> `CodeBox` passes `memory_mib` / `cpus` straight through, so an unset value resolves to the same VM defaults as every other Box type. [Compute resources → Defaults](/manage-sandbox/compute-resources#defaults) is the single source of truth for those numbers; set both explicitly in production rather than relying on them.

### `await cb.run(code, timeout=None) -> str`

| Parameter | Type | Required | Description |
| - | - | - | - |
| `code` | `str` | Yes | The Python source to execute (run internally as `python -c <code>`) |
| `timeout` | `int \| None` | No | Accepted for API compatibility but **not enforced**. For a hard timeout, use `exec(..., timeout=<seconds>)` |

Returns: the **stdout string** of the execution. A non-zero exit does not raise (unlike the Node SDK's `run`, which throws `ExecError`).

### Other common methods (all `async`)

| Method | Signature | Returns | Description |
| - | - | - | - |
| `run_script` | `run_script(script_path: str)` | `str` (stdout) | Read a `.py` file from the host and execute it |
| `install_package` | `install_package(package: str)` | `str` (stdout + stderr) | `pip install <package>` (for example `"numpy==1.24.0"`) |
| `install_packages` | `install_packages(*packages: str)` | `str` (stdout + stderr) | Install several packages at once |
| `exec` | `exec(cmd, *args, env=None, user=None, timeout=None, cwd=None)` | `ExecResult` | Inherited from `SimpleBox`; runs any command |

> `install_package` and `install_packages` return `result.stdout + result.stderr` concatenated, because pip writes progress to both streams.

### `ExecResult` fields (returned by `exec()`)

| Field | Type | Description |
| - | - | - |
| `exit_code` | `int` | Process exit code; a non-zero value **does not** raise — check it yourself |
| `stdout` | `str` | Standard output |
| `stderr` | `str` | Standard error |
| `error_message` | `str \| None` | Non-`None` only when the process died unexpectedly |

> Timeout naming / type reminder: `SimpleBox.exec`'s `timeout` is a `float` (seconds), while `CodeBox.run`'s `timeout` is an `int`. Use `exec` when you need a hard timeout.

## Troubleshooting

### `run()` returns no error info / an empty string

`run()` returns stdout only and does not raise on a non-zero exit. If the code errors, the traceback is on stderr, which `run()` does not see. Use `exec("/usr/local/bin/python", "-c", code)` instead and read `result.stderr` and `result.exit_code` (see the example above).

### `ModuleNotFoundError: No module named 'xxx'`

`python:slim` ships only the standard library. A third-party library must be installed with `await cb.install_package("xxx")` (or `install_packages(...)`) before `run()`. Installing packages requires PyPI to be reachable.

### `RuntimeError` (image pull failure / no virtualization)

* A network hiccup during image pull raises a standard `builtins.RuntimeError` (not `BoxliteError`); you can retry with `try/except RuntimeError`.
* Starting a sandbox requires hardware virtualization: Linux needs KVM (the user in the `kvm` group; same on WSL2); macOS Apple Silicon uses Hypervisor.framework and needs no `/dev/kvm`; macOS Intel is not supported. Without virtualization, startup fails but the process does not crash, so the exception can be caught.

### `RuntimeError: Box not started ...`

`CodeBox` is an **async context manager**; the sandbox is actually created and started when you enter `async with`. Call `run`/`exec` inside the `async with boxlite.CodeBox() as cb:` block, or call `await cb.start()` first.

### Limiting execution time

`CodeBox.run`'s `timeout` is not enforced. When you need an enforced timeout, use `exec`:

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
result = await cb.exec("/usr/local/bin/python", "-c", code, timeout=10.0)  # 10 seconds
```

`exec`'s `timeout` is in seconds (float).
