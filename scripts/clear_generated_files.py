#!/usr/bin/env python3
"""Clear generated files recorded in a Codex session manifest."""

from __future__ import annotations

import argparse
import json
import os
import shutil
from dataclasses import dataclass
from pathlib import Path


ALLOWED_EXTENSIONS = {
    ".ppt",
    ".pptx",
    ".odp",
    ".key",
    ".doc",
    ".docx",
    ".odt",
    ".rtf",
    ".xls",
    ".xlsx",
    ".ods",
    ".csv",
    ".tsv",
    ".pdf",
    ".png",
    ".jpg",
    ".jpeg",
    ".webp",
    ".gif",
    ".svg",
    ".bmp",
    ".tif",
    ".tiff",
    ".html",
    ".htm",
    ".css",
    ".js",
    ".mjs",
    ".cjs",
    ".ts",
    ".tsx",
    ".jsx",
    ".py",
    ".ps1",
    ".sh",
    ".bat",
    ".cmd",
    ".json",
    ".jsonl",
    ".md",
    ".markdown",
    ".txt",
    ".log",
    ".xml",
    ".yaml",
    ".yml",
    ".zip",
    ".7z",
    ".tar",
    ".gz",
}

PROTECTED_EXACT_NAMES = {
    "agents.md",
    "claude.md",
    "gemini.md",
    "license",
    "license.md",
    "license.txt",
    ".gitignore",
    ".gitattributes",
    ".env",
    ".env.local",
    ".env.production",
}

PROTECTED_NAME_PREFIXES = ("readme",)
PROTECTED_EXTENSIONS = {
    ".env",
    ".pem",
    ".key",
    ".pfx",
    ".p12",
    ".crt",
    ".cer",
    ".der",
    ".sqlite",
    ".sqlite3",
    ".db",
    ".bak",
}


@dataclass
class Result:
    target: str
    resolved: str
    status: str
    reason: str = ""


def is_relative_to(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def has_protected_leaf_name(path: Path) -> bool:
    leaf = path.name.lower()
    if leaf in PROTECTED_EXACT_NAMES:
        return True
    return any(leaf.startswith(prefix) for prefix in PROTECTED_NAME_PREFIXES)


def protected_path_reason(path: Path) -> str | None:
    if any(part.lower() == ".git" for part in path.parts):
        return "contains .git"
    if has_protected_leaf_name(path):
        return "protected file name"
    suffix = path.suffix.lower()
    if suffix in PROTECTED_EXTENSIONS:
        return f"protected extension {suffix}"
    return None


def directory_protected_reason(directory: Path) -> str | None:
    for item in directory.rglob("*"):
        reason = protected_path_reason(item)
        if reason:
            return f"{reason} inside directory: {item}"
    return None


def allowed_extension(path: Path) -> bool:
    return path.is_dir() or path.suffix.lower() in ALLOWED_EXTENSIONS


def resolve_target(text: str, workspace: Path) -> Path:
    candidate = Path(text)
    if not candidate.is_absolute():
        candidate = workspace / candidate
    return candidate.resolve()


def load_manifest(path: Path) -> tuple[list[str], set[str]]:
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    generated = [str(item) for item in data.get("generated", []) if str(item).strip()]
    keep = {str(item) for item in data.get("keep", [])}
    return generated, keep


def collect_results(workspace: Path, manifest_path: Path) -> list[Result]:
    generated, keep = load_manifest(manifest_path)
    results: list[Result] = []

    for text in generated:
        if text in keep:
            results.append(Result(text, "", "Skipped", "listed in keep"))
            continue

        candidate = Path(text) if Path(text).is_absolute() else workspace / text
        if not candidate.exists():
            results.append(Result(text, str(candidate), "Missing", "not found"))
            continue

        resolved = candidate.resolve()
        if not is_relative_to(resolved, workspace):
            results.append(Result(text, str(resolved), "Skipped", "outside workspace"))
            continue

        protected_reason = protected_path_reason(resolved)
        if not protected_reason and resolved.is_dir() and not resolved.is_symlink():
            protected_reason = directory_protected_reason(resolved)
        if protected_reason:
            results.append(Result(text, str(resolved), "Protected", protected_reason))
            continue

        if not allowed_extension(resolved):
            suffix = resolved.suffix.lower()
            results.append(Result(text, str(resolved), "Skipped", f"unlisted extension {suffix}"))
            continue

        results.append(Result(text, str(resolved), "Ready"))

    return results


def print_results(results: list[Result]) -> None:
    rows = sorted(results, key=lambda result: len(result.resolved), reverse=True)
    headers = ("Status", "Target", "Resolved", "Reason")
    widths = [
        max(len(headers[0]), *(len(row.status) for row in rows), 0),
        max(len(headers[1]), *(len(row.target) for row in rows), 0),
        max(len(headers[2]), *(len(row.resolved) for row in rows), 0),
        max(len(headers[3]), *(len(row.reason) for row in rows), 0),
    ]
    print("  ".join(header.ljust(width) for header, width in zip(headers, widths)))
    print("  ".join("-" * width for width in widths))
    for row in rows:
        values = (row.status, row.target, row.resolved, row.reason)
        print("  ".join(value.ljust(width) for value, width in zip(values, widths)))


def delete_path(path: Path) -> None:
    if path.is_symlink() or path.is_file():
        path.unlink()
    else:
        shutil.rmtree(path)


def main() -> int:
    parser = argparse.ArgumentParser(description="Delete generated files from a Codex session manifest.")
    parser.add_argument("--workspace", required=True, help="Active workspace path.")
    parser.add_argument("--manifest", default=".codex-session-generated-files.json", help="Manifest filename.")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be deleted without deleting.")
    args = parser.parse_args()

    workspace = Path(args.workspace).resolve()
    manifest_path = workspace / args.manifest

    if not manifest_path.exists():
        print(f"Manifest not found: {manifest_path}")
        return 0

    results = collect_results(workspace, manifest_path)
    print_results(results)

    for result in sorted(
        (item for item in results if item.status == "Ready"),
        key=lambda item: len(item.resolved),
        reverse=True,
    ):
        path = Path(result.resolved)
        if args.dry_run:
            print(f"DryRun: would delete {path}")
            continue
        delete_path(path)
        print(f"Deleted: {path}")

    if args.dry_run:
        print(f"DryRun: manifest retained: {manifest_path}")
    else:
        manifest_path.unlink()
        print(f"Deleted manifest: {manifest_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
