#!/usr/bin/env python3
"""Sync and split BoxLite documentation from https://docs.boxlite.ai/ into local Markdown files."""

from __future__ import annotations

import argparse
import re
import urllib.request
from pathlib import Path

SOURCE_RE = re.compile(r"^Source: https://docs\.boxlite\.ai/(.+)$")


def download(url: str, dest: Path) -> None:
    req = urllib.request.Request(url, headers={"User-Agent": "boxlite-skill-sync/1.0"})
    with urllib.request.urlopen(req, timeout=60) as resp:
        dest.write_bytes(resp.read())


def extract_pages(docs_dir: Path) -> int:
    llms_full = docs_dir / "llms-full.txt"
    if not llms_full.exists():
        raise FileNotFoundError(f"Missing {llms_full}")

    lines = llms_full.read_text(encoding="utf-8").splitlines()
    pages: list[tuple[str, int]] = []
    for i, line in enumerate(lines):
        m = SOURCE_RE.match(line.strip())
        if m:
            rel_path = m.group(1).strip()
            start = i - 1 if i > 0 and lines[i - 1].startswith("# ") else i
            pages.append((rel_path, start))

    for idx, (rel_path, start) in enumerate(pages):
        end = pages[idx + 1][1] - 1 if idx + 1 < len(pages) else len(lines) - 1
        while end > start and not lines[end].strip():
            end -= 1
        rel_file = rel_path if rel_path.endswith(".md") else f"{rel_path}.md"
        out_path = docs_dir / rel_file
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text("\n".join(lines[start : end + 1]) + "\n", encoding="utf-8")

    return len(pages)


def main() -> None:
    default_docs = Path(__file__).resolve().parent.parent / "docs"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skip-download", action="store_true", help="Only split existing llms-full.txt")
    parser.add_argument("--docs-dir", type=Path, default=default_docs)
    args = parser.parse_args()

    args.docs_dir.mkdir(parents=True, exist_ok=True)
    if not args.skip_download:
        download("https://docs.boxlite.ai/llms.txt", args.docs_dir / "llms.txt")
        download("https://docs.boxlite.ai/llms-full.txt", args.docs_dir / "llms-full.txt")

    count = extract_pages(args.docs_dir)
    print(f"Extracted {count} documentation pages to {args.docs_dir}")


if __name__ == "__main__":
    main()
