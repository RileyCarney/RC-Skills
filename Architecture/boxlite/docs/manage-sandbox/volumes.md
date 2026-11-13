# Volumes and mounts
Source: https://docs.boxlite.ai/manage-sandbox/volumes

Mount a host directory into the sandbox so both sides read and write the same files.

A file written inside the sandbox appears on the host immediately, and the reverse. Use it to feed in a dataset or repository, to mount weights and configuration read-only, or to keep results after a box is destroyed. The host path must be **absolute and already exist**.

## Quick Example

Mount a host directory read-write at `/workspace` in the sandbox, write a file from inside the sandbox, then return to the host to verify that it appears.

```python Python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio
import os
import tempfile

import boxlite

async def main():
    # 1. prepare a host directory and place a file in it
    #    in production, replace with your own directory, e.g. "<YOUR_PATH>/data"
    with tempfile.TemporaryDirectory() as host_dir:
        with open(os.path.join(host_dir, "hello.txt"), "w") as f:
            f.write("from host\n")

        try:
            # 2. mount: tuple (host path, in-sandbox path) -- read-write by default
            async with boxlite.SimpleBox(
                image="alpine:latest",
                volumes=[(host_dir, "/workspace")],
            ) as box:
                # 3. the sandbox can see the file the host placed in
                ls = await box.exec("cat", "/workspace/hello.txt")
                print("guest reads host file:", ls.stdout.strip())

                # 4. write a new file from inside the sandbox
                await box.exec(
                    "sh", "-c",
                    "echo 'from guest' > /workspace/from_guest.txt",
                )

            # 5. verify back on the host (after with exits the sandbox is destroyed, but files in the mounted directory remain)
            guest_file = os.path.join(host_dir, "from_guest.txt")
            with open(guest_file) as f:
                print("host reads guest file:", f.read().strip())

        except RuntimeError as e:
            # image pull failure / no virtualization raises a standard RuntimeError
            print("box failed to start:", e)

if __name__ == "__main__":
    asyncio.run(main())
```

```typescript Node.js theme={"theme":{"light":"github-light","dark":"github-dark"}}
import { SimpleBox } from "@boxlite-ai/boxlite";
import { mkdtempSync, writeFileSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

async function main() {
  // in production, replace with your own directory, e.g. "<YOUR_PATH>/data"
  const hostDir = mkdtempSync(join(tmpdir(), "boxlite-"));
  writeFileSync(join(hostDir, "hello.txt"), "from host\n");

  try {
    // Node uses an array of objects: { hostPath, guestPath, readOnly? }
    await using box = new SimpleBox({
      image: "alpine:latest",
      volumes: [{ hostPath: hostDir, guestPath: "/workspace" }],
    });

    const ls = await box.exec("cat", "/workspace/hello.txt");
    console.log("guest reads host file:", ls.stdout.trim());

    await box.exec("sh", "-c", "echo 'from guest' > /workspace/from_guest.txt");

    // await using exit automatically destroys the sandbox; files in the mounted directory remain on the host
    const back = readFileSync(join(hostDir, "from_guest.txt"), "utf8");
    console.log("host reads guest file:", back.trim());
  } catch (e) {
    console.error("box failed to start:", e);
  }
}

main();
```

***

## Parameters and Returns

Mounts are configured through the `volumes` parameter on `BoxOptions` / `SimpleBox`. Each element describes one mount.

### Python: a `volumes` element accepts three forms

| Form | Shape | Description |
| - | - | - |
| 2-tuple | `(host, guest)` | Host path plus in-sandbox path; **read-write by default** |
| 3-tuple | `(host, guest, read_only)` | The third element is a **bool**: `True` = read-only, `False` = read-write |
| dict | `{"host": ..., "guest": ..., "read_only": ...}` | Also accepts the keys `host_path` / `guest_path` / `ro`; when `read_only` is omitted, the mount is read-write |

Field types:

| Field | Type | Required | Description |
| - | - | - | - |
| `host` (or `host_path`) | `str` | Yes | An **existing absolute path** on the host |
| `guest` (or `guest_path`) | `str` | Yes | The mount point inside the sandbox, e.g. `/workspace` |
| `read_only` (or `ro`) | `bool` | No (default `False`) | `True` = read-only mount; `False` = read-write |

> Key point (the most common mistake): the third element is a **boolean** `True`/`False`, **not** the string `"ro"`/`"rw"`. The string syntax is only for the CLI form `boxlite -v host:guest:ro` and is not interchangeable with the SDK.

Read-only mount example:

```python Python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio
import boxlite

async def main():
    try:
        async with boxlite.SimpleBox(
            image="alpine:latest",
            volumes=[
                # read-only mount: writes to /config from inside the sandbox will fail
                ("<YOUR_PATH>/config", "/config", True),
                # read-write mount (default): outputs are written back to the host
                ("<YOUR_PATH>/output", "/output", False),
            ],
        ) as box:
            r = await box.exec("ls", "-la", "/config")
            print(r.stdout)
    except RuntimeError as e:
        print("box failed to start:", e)

if __name__ == "__main__":
    asyncio.run(main())
```

```typescript Node.js theme={"theme":{"light":"github-light","dark":"github-dark"}}
import { SimpleBox } from "@boxlite-ai/boxlite";

async function main() {
  try {
    await using box = new SimpleBox({
      image: "alpine:latest",
      volumes: [
        { hostPath: "<YOUR_PATH>/config", guestPath: "/config", readOnly: true },
        { hostPath: "<YOUR_PATH>/output", guestPath: "/output" },
      ],
    });
    const r = await box.exec("ls", "-la", "/config");
    console.log(r.stdout);
  } catch (e) {
    console.error("box failed to start:", e);
  }
}

main();
```

In Node, a `volumes` element is an object:

| Field | Type | Required | Description |
| - | - | - | - |
| `hostPath` | `string` | Yes | An existing absolute path on the host |
| `guestPath` | `string` | Yes | The mount point inside the sandbox |
| `readOnly` | `boolean` | No (default `false`) | `true` = read-only |

### Return value

`volumes` is a creation-time configuration option and has no return value of its own. Whether a mount took effect is observed by inspecting files with `exec` inside the sandbox. `exec` returns an `ExecResult`:

| Field | Type | Description |
| - | - | - |
| `exit_code` / `exitCode` | `int` | Command exit code (a non-zero value **does not raise**; check it yourself) |
| `stdout` | `str` | Standard output |
| `stderr` | `str` | Standard error |

***

## Moving files without a mount

A mount is the right tool when the host and the sandbox need to share a directory for the whole session. For a one-off transfer — ship in a script, pull back a result — copy the file directly. This also works when the target is a read-only mount or a tmpfs path, where writing from inside the box would not reach the host.

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
import asyncio
from boxlite import SimpleBox

async def main():
    try:
        async with SimpleBox(image="python:slim") as box:
            # Host -> sandbox
            await box.copy_in("<YOUR_HOST_PATH>/script.py", "/workspace/script.py")

            result = await box.exec("python", "/workspace/script.py")
            if result.exit_code != 0:
                print(f"script failed: {result.stderr}")
                return

            # Sandbox -> host
            await box.copy_out("/workspace/output.json", "<YOUR_HOST_PATH>/output.json")
    except FileNotFoundError as exc:
        print(f"host path not found: {exc}")
    except RuntimeError as exc:
        print(f"sandbox error: {exc}")

asyncio.run(main())
```

| Parameter | Type | Required | Default | Description |
| - | - | - | - | - |
| `host_path` / `container_src` | `str` | Yes | — | Source path. `copy_in` reads from the host; `copy_out` reads from the sandbox |
| `container_dest` / `host_dest` | `str` | Yes | — | Destination path |
| `overwrite` | `bool` | No | `True` | Replace an existing destination |
| `follow_symlinks` | `bool` | No | `False` | Copy link targets instead of the links themselves |

Both methods are `async` and return `None`; failures raise.

### Copying a directory, or its contents

A directory copies **under its own name** by default: `copy_in("./dist", "/srv/www")` leaves
you with `/srv/www/dist`.

To copy what is *inside* it instead, end the source with `/.` — the same spelling `docker cp`
uses:

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
await box.copy_in("./dist/.", "/srv/www")   # the files land directly in /srv/www
```

> [!NOTE]
>
> `include_parent` was removed in 0.10.6. `SRC/.` is now the only way to ask for a directory's
> contents. Code still passing `include_parent` raises `TypeError`.

## Troubleshooting

### Passing the string `"ro"`/`"rw"` for `read_only` -> `TypeError`

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
# Wrong: the third element is written as a string
volumes=[("/data", "/workspace", "ro")]
```

Error:

```text theme={"theme":{"light":"github-light","dark":"github-dark"}}
TypeError: argument 'volumes': 'str' object cannot be cast as 'bool'
```

Fix: use a boolean for the third element. Use `True` for read-only, `False` for read-write (or omit the third element to get read-write):

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
volumes=[("/data", "/workspace", True)]   # read-only
volumes=[("/data", "/workspace")]         # read-write (default)
```

The strings `ro`/`rw` apply only to the CLI form `-v host:guest:ro` and should not be used with the SDK.

### A tuple whose length is not 2 or 3 -> `RuntimeError`

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
volumes=[("/data",)]              # only one element given
volumes=[("/data", "/g", True, 1)]  # one element too many
```

Error:

```text theme={"theme":{"light":"github-light","dark":"github-dark"}}
RuntimeError: volumes tuples must be (host, guest[, read_only])
```

Fix: each mount must be written exactly as `(host, guest)` or `(host, guest, read_only)`.

### A dict missing the host / guest key -> `RuntimeError`

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
volumes=[{"guest": "/workspace"}]   # missing host
```

Error:

```text theme={"theme":{"light":"github-light","dark":"github-dark"}}
RuntimeError: volume dict missing host/host_path
```

Fix: the dict must contain both a host key (`host` or `host_path`) and a guest key (`guest` or `guest_path`).

### Files written to `/tmp` or `/dev/shm` are not found on the host

Inside the sandbox, `/tmp` and `/dev/shm` are **tmpfs (in-memory filesystems)** provided automatically by the runtime. They are not part of any mounted host directory, and they are not persisted with the sandbox: they disappear once the sandbox is destroyed.

Fix:

* To write data back to the host: write to a **mounted directory** (such as `/workspace` in the example), not to `/tmp`.
* The destination of `copy_in` / `copyIn` should also avoid tmpfs paths (such as `/tmp`, `/dev/shm`); otherwise the copied files will not land in the expected persistent layer of the container. Use a non-tmpfs path such as `/root/` instead.
* The SDK **does not** expose parameters to customize the tmpfs size or mount point; tmpfs is managed entirely by the runtime internally.

### Writing a file fails on a read-only mount

On a read-only mount (`read_only=True`), any write to that path from inside the sandbox fails (typically `Read-only file system`). A non-zero exit code from `exec` **does not raise**; check `exit_code` yourself:

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
r = await box.exec("sh", "-c", "echo x > /config/test.txt")
if r.exit_code != 0:
    print("write blocked (expected for read-only mount):", r.stderr.strip())
```

To allow writes, make the mount read-write (`read_only=False`, or omit the third element).

### The host directory does not exist / the path is relative

When the mount point shows no content, or startup reports a path-related error, first confirm that the host path **exists and is absolute**. Relative paths are not resolved to the directory you expect. In Python, normalize with `os.path.abspath(...)` before passing the path.

### The sandbox fails to start (no virtualization)

In an environment without hardware virtualization (Linux without KVM, WSL2 without KVM enabled, and so on), startup fails and raises `RuntimeError` (the process itself does not crash and the error is catchable). This is an environment constraint: you need Linux with KVM, or run on macOS (which uses Hypervisor.framework automatically).
