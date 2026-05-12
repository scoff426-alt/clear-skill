# clearing-generated-files

English | [简体中文](README.zh-CN.md)

## Installation

Requirements:

- Git
- Python 3.9+ for the bundled cleanup helper
- Codex or another agent runtime that supports Skills

PowerShell:

```powershell
git clone https://github.com/scoff426-alt/clear-skill.git "$env:USERPROFILE\.codex\skills\clearing-generated-files"
```

Bash:

```bash
git clone https://github.com/scoff426-alt/clear-skill.git ~/.codex/skills/clearing-generated-files
```

Or, in Codex or another agent that supports Skills, say:

```text
Please install this skill: https://github.com/scoff426-alt/clear-skill
```

## Usage

After installation, use the skill through your agent conversation. The normal cleanup trigger is:

```text
clear
```

Codex records generated artifacts in `.codex-session-generated-files.json` while it works, then uses the bundled Python helper to remove those recorded artifacts when cleanup is requested.

`clearing-generated-files` is a Codex skill for cleaning up files created during short artifact-oriented conversations. It is intended for cases where the user asks Codex to generate a PPT, Word document, Excel workbook, PDF, image, HTML preview, JSON/Markdown helper file, script, or other temporary output, copies the result, and then says `clear` to remove everything generated in that conversation.

## What the skill does

1. While creating artifacts, Codex records generated files and directories in `.codex-session-generated-files.json` in the active workspace.
2. When the user says `clear`, Codex loads that manifest.
3. It resolves every path to an absolute path.
4. It deletes only paths inside the active workspace.
5. It skips protected names, protected formats, files listed in `keep`, missing files, and anything outside the workspace.
6. It deletes the manifest last.

The skill is designed for temporary outputs, not project maintenance or source-code cleanup.

## Files in this skill

- `SKILL.md`: trigger rules and operational instructions for Codex.
- `scripts/clear_generated_files.py`: Python cleanup helper with workspace, protected-file, and dry-run checks.
- `agents/openai.yaml`: UI metadata for the skill.
- `README.md`: English reference.
- `README.zh-CN.md`: Simplified Chinese reference.

## Manifest format

Create `.codex-session-generated-files.json` in the active workspace:

```json
{
  "generated": [
    "outputs/report/report.xlsx",
    "outputs/report",
    "build_report.mjs"
  ],
  "keep": []
}
```

Use workspace-relative paths when possible. Absolute paths are allowed only if they resolve inside the active workspace.

`generated` contains files, directories, and dependency links created in the current conversation.

`keep` contains generated paths that should not be deleted even if they appear in `generated`.

## File formats it can delete

The cleanup script can delete these formats when they are listed in the manifest and are inside the active workspace.

| Category | Extensions |
| --- | --- |
| PowerPoint / slides | `.ppt`, `.pptx`, `.odp`, `.key` |
| Word / text documents | `.doc`, `.docx`, `.odt`, `.rtf`, `.txt`, `.md`, `.markdown` |
| Excel / data tables | `.xls`, `.xlsx`, `.ods`, `.csv`, `.tsv` |
| PDF | `.pdf` |
| Images / previews | `.png`, `.jpg`, `.jpeg`, `.webp`, `.gif`, `.svg`, `.bmp`, `.tif`, `.tiff` |
| Web previews | `.html`, `.htm`, `.css` |
| JavaScript / TypeScript helpers | `.js`, `.mjs`, `.cjs`, `.ts`, `.tsx`, `.jsx` |
| Python / shell helpers | `.py`, `.ps1`, `.sh`, `.bat`, `.cmd` |
| Structured scratch data | `.json`, `.jsonl`, `.xml`, `.yaml`, `.yml` |
| Logs | `.log` |
| Archives | `.zip`, `.7z`, `.tar`, `.gz` |

It can also delete generated directories, such as `outputs/example`, and generated local dependency links, such as a temporary `node_modules` junction, if they are listed in the manifest and do not contain protected content.

## File formats and paths it must not delete automatically

These are blocked or protected even if they appear in the manifest, unless the user explicitly names the target and confirms deletion outside the automatic `clear` flow.

| Protected item | Reason |
| --- | --- |
| Anything outside the active workspace | Prevents accidental deletion of user/system files |
| `.git` directories or anything inside `.git` | Protects repository history |
| `AGENTS.md` | Protects project instructions |
| `README*` including `README.md` and `README.txt` | Protects project documentation |
| `CLAUDE.md`, `GEMINI.md` | Protects agent/project instructions |
| `LICENSE`, `LICENSE.md`, `LICENSE.txt` | Protects legal/project metadata |
| `.gitignore`, `.gitattributes` | Protects repository configuration |
| `.env`, `.env.local`, `.env.production` | Protects environment and secret configuration |
| `.pem`, `.key`, `.pfx`, `.p12`, `.crt`, `.cer`, `.der` | Protects credentials and certificates |
| `.sqlite`, `.sqlite3`, `.db` | Protects databases that may contain user data |
| `.bak` | Avoids deleting backups automatically |
| File extensions not listed in the allowed table | Forces review before unusual deletions |
| User-provided source files | The manifest should never include them |
| Existing project source/config files | The skill is for generated temporary artifacts only |

## Important Markdown note

The skill can delete generated `.md` and `.markdown` files such as temporary notes, build logs, extracted text, or generated meeting drafts. It does not automatically delete protected Markdown files such as `README.md`, `AGENTS.md`, `CLAUDE.md`, or `GEMINI.md`.

## Expected user command

The primary trigger is simply:

```text
clear
```

Equivalent requests such as "清理本次生成的文件", "删除这次生成的所有文件", "clean up generated files", and "remove the temporary outputs" should use the same skill.

## Safety behavior

The script reports each target with a status:

- `Ready`: safe to delete.
- `Deleted`: removed successfully.
- `Missing`: the path no longer exists.
- `Skipped`: not deleted, usually because it is outside the workspace, in `keep`, or has an unlisted extension.
- `Protected`: not deleted because the path or a child path matches a protected name, extension, or `.git` rule.

The manifest is deleted only after a real cleanup run. During `-DryRun`, the manifest is retained.
