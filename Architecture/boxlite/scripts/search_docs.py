#!/usr/bin/env python3
"""Search offline BoxLite documentation under ../docs/."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


def main() -> None:
    default_docs = Path(__file__).resolve().parent.parent / "docs"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("query", help="Regex or substring to search for (case-insensitive)")
    parser.add_argument("--max-results", type=int, default=25)
    parser.add_argument("--docs-dir", type=Path, default=default_docs)
    args = parser.parse_args()

    pattern = re.compile(args.query, re.IGNORECASE)
    results: list[tuple[int, str, int, str]] = []

    for md_file in sorted(args.docs_dir.rglob("*.md")):
        lines = md_file.read_text(encoding="utf-8", errors="replace").splitlines()
        matches = [(idx + 1, line.strip()) for idx, line in enumerate(lines) if pattern.search(line)]
        if matches:
            rel = md_file.relative_to(args.docs_dir).as_posix()
            results.append((len(matches), rel, matches[0][0], matches[0][1][:100]))

    results.sort(key=lambda item: item[0], reverse=True)
    for count, rel, line_no, preview in results[: args.max_results]:
        print(f"{count:3d}x  {rel}:{line_no}  {preview}")


if __name__ == "__main__":
    main()
