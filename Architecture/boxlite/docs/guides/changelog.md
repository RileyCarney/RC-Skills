# Release notes and your version
Source: https://docs.boxlite.ai/guides/changelog

Where BoxLite's release history lives, and how to check which version you are running.

Release notes are generated per release and published on GitHub Releases — that is the authoritative record of what changed between versions, including security advisories.

* BoxLite installed in at least one SDK (Python `boxlite`, Node `@boxlite-ai/boxlite`), or the CLI binary `boxlite`.
* For browsing release notes: a web browser; no API key required.

## Current state

* **Latest published version:** check the registry directly — `pip index versions boxlite` or `npm view @boxlite-ai/boxlite version`. GitHub Releases is the authoritative changelog.
* There is **no `CHANGELOG.md`** in the repository. Per-version notes are auto-generated on each GitHub Release.
* Release notes include a **Security** section when an advisory applies (for example, the 0.9.0 release documents two Critical CVEs fixed in `< 0.9.0`).

### Where the version history actually lives

| Source | What it gives you | Link |
| - | - | - |
| GitHub Releases | Per-version notes ("What's Changed", security advisories, contributor PRs) | [https://github.com/boxlite-ai/boxlite/releases](https://github.com/boxlite-ai/boxlite/releases) |
| Git tags | The exact commit each version points to (`v0.5.x` onward) | [https://github.com/boxlite-ai/boxlite/tags](https://github.com/boxlite-ai/boxlite/tags) |
| Security advisories | Published CVEs / GHSAs and affected version ranges | [https://github.com/boxlite-ai/boxlite/security/advisories](https://github.com/boxlite-ai/boxlite/security/advisories) |
| PyPI | Python package release history | [https://pypi.org/project/boxlite/#history](https://pypi.org/project/boxlite/#history) |
| npm | Node package release history | [https://www.npmjs.com/package/@boxlite-ai/boxlite?activeTab=versions](https://www.npmjs.com/package/@boxlite-ai/boxlite?activeTab=versions) |

## Quick Example — check which version you have

The most useful "changelog" action you can take right now is confirming your installed version, then comparing it against the GitHub Releases list.

### Python

```python theme={"theme":{"light":"github-light","dark":"github-dark"}}
# Requires: pip install boxlite
import boxlite

try:
    # boxlite.__version__ reads importlib.metadata.version("boxlite")
    print("Installed boxlite version:", boxlite.__version__)
except Exception as err:  # importlib metadata can fail in odd install layouts
    print("Could not resolve boxlite version:", err)
```

### Node

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
# @boxlite-ai/boxlite is the real package name (NOT 'boxlite')
npm ls @boxlite-ai/boxlite
```

### CLI

```bash theme={"theme":{"light":"github-light","dark":"github-dark"}}
# The CLI binary is named 'boxlite'
boxlite --version
```

The C SDK exposes the version string via the `boxlite_version()` function (declared in `boxlite.h`) if you need it from native code.

## Parameters & Returns

This page describes no callable API. The single programmatic touchpoint is the version accessor:

| SDK | Accessor | Type / Returns | Notes |
| - | - | - | - |
| Python | `boxlite.__version__` | `str` | Backed by `importlib.metadata.version("boxlite")` |
| Node | `npm ls @boxlite-ai/boxlite` (shell) | text | No JS constant is exported for the version |
| C | `boxlite_version()` | `const char *` | Declared in `boxlite.h` |
| CLI | `boxlite --version` | text | — |

## Troubleshooting

| Symptom | Cause | Fix |
| - | - | - |
| Looking for a `CHANGELOG.md` in the repo | None exists; release notes are generated per GitHub Release | Use the GitHub Releases page, not a repo file |
| `boxlite.__version__` shows an older version than expected | A stale install is shadowing the new one (e.g. another virtualenv) | Reinstall: `pip install --upgrade boxlite`, then re-run the Quick Example |
| `npm ls @boxlite-ai/boxlite` reports `(empty)` | The package is installed under the wrong name | Install the correct package: `npm install @boxlite-ai/boxlite` (the bare name `boxlite` is a different/unrelated package) |
| The version in the source tree differs from the one you installed | The source tree may be ahead of the last published release | Trust the registry (`pip index versions boxlite` / `npm view @boxlite-ai/boxlite version`) and GitHub Releases for what actually shipped |
| Running BoxLite `< 0.9.0` | Two Critical CVEs were fixed in 0.9.0 (read-only volume remount bypass; OCI layer symlink escape) | Upgrade immediately; see the security advisories link above |

## Why this is a stub

A documentation Changelog should be curated and stable, with human-written highlights per release. BoxLite's history today is auto-generated at release time and not mirrored into a docs source file. Until that source of truth is decided (curated notes vs. mirroring GitHub Releases), this page intentionally points you to the live, authoritative sources rather than duplicating a snapshot that would immediately go stale.
