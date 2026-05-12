---
name: clearing-generated-files
description: Use when the user asks to clear, clean up, delete, remove, discard, or reset files generated during the current conversation; also use when creating short-lived PPT, Word, Excel, PDF, image, JSON, Markdown, code, or scratch artifacts the user may later want removed.
---

# Clearing Generated Files

## Core Rule
Generated artifacts are temporary unless the user asks to keep them. During artifact-producing work, maintain `.codex-session-generated-files.json` in the active workspace. When the user says `clear`, remove only the recorded current-conversation generated artifacts after verifying every resolved path stays inside the active workspace.

## Record Generated Artifacts

Add each file, directory, or dependency link created for the current conversation to the manifest:

```json
{
  "generated": [
    "outputs/example/result.xlsx",
    "outputs/example",
    "build_result.mjs"
  ],
  "keep": []
}
```

Record:
- Final deliverables: PPT/Word/Excel/PDF/images/exports.
- Helper artifacts: scripts, `.json`, `.md`, `.csv`, previews, render outputs, scratch folders.
- Local dependency links or generated folders created only for the task.

Do not record user-provided sources, files that existed before the task, repository source/config files, or anything the user asked to preserve.

## Responding to `clear`

1. Load `.codex-session-generated-files.json` from the active workspace.
2. If there is no manifest, infer cautiously from the current conversation and ask if the target set is ambiguous.
3. Resolve all targets to absolute paths and refuse paths outside the active workspace.
4. Skip protected names/extensions and anything listed in `keep`.
5. Delete deepest paths first, then delete the manifest last.
6. Report deleted, skipped, missing, and protected items.

Prefer the bundled Python script:

```bash
python <skill-dir>/scripts/clear_generated_files.py --workspace <active-workspace>
```

Use `--dry-run` when the target set is uncertain.

## Safety Boundary

Never delete outside the active workspace. Never delete `AGENTS.md`, `README*`, `CLAUDE.md`, `GEMINI.md`, `.git`, secrets/keys, databases, or user-provided source files unless the user explicitly names them and confirms deletion. Recursive directory deletion must first scan for protected content.

For detailed allowed and protected file types, read `README.md` in this skill.
