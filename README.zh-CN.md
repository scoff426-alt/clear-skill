# clearing-generated-files

[English](README.md) | 简体中文

`clearing-generated-files` 是一个用于清理“当前对话中生成文件”的 Codex skill。它适合这类场景：用户让 Codex 临时生成 PPT、Word、Excel、PDF、图片、HTML 预览、JSON/Markdown 辅助文件、脚本或其他临时产物，用户复制或下载完结果后，只需要发送 `clear`，Codex 就会删除本次对话产生的临时文件。

## 这个 skill 会做什么

1. 创建产物时，Codex 会把生成的文件和目录记录到当前工作区的 `.codex-session-generated-files.json`。
2. 当用户发送 `clear` 时，Codex 会读取这个清单。
3. 它会把每个路径解析为绝对路径。
4. 它只删除位于当前工作区内部的路径。
5. 它会跳过受保护的文件名、受保护的文件格式、`keep` 列表中的文件、已不存在的文件，以及任何工作区外的路径。
6. 它会最后删除 manifest 清单本身。

这个 skill 面向临时产物清理，不用于项目维护、源码清理或仓库重构。

## skill 文件结构

- `SKILL.md`：Codex 使用的触发规则和操作流程。
- `scripts/clear-generated-files.ps1`：Windows 清理脚本，包含工作区校验、受保护文件检查和 dry-run 支持。
- `agents/openai.yaml`：skill 的 UI 元数据。
- `README.md`：英文说明文档。
- `README.zh-CN.md`：简体中文说明文档。

## Manifest 清单格式

在当前工作区创建 `.codex-session-generated-files.json`：

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

建议优先使用相对当前工作区的路径。也可以使用绝对路径，但绝对路径必须解析到当前工作区内部，否则不会被删除。

`generated` 用来记录当前对话中新生成的文件、目录和临时依赖链接。

`keep` 用来记录需要保留的生成文件。即使这些路径出现在 `generated` 中，也不会被删除。

## 可以删除的文件格式

当这些文件被记录在 manifest 中，并且位于当前工作区内部时，清理脚本可以删除以下类型的临时文件：

| 类别 | 扩展名 |
| --- | --- |
| PowerPoint / 幻灯片 | `.ppt`, `.pptx`, `.odp`, `.key` |
| Word / 文本文档 | `.doc`, `.docx`, `.odt`, `.rtf`, `.txt`, `.md`, `.markdown` |
| Excel / 数据表 | `.xls`, `.xlsx`, `.ods`, `.csv`, `.tsv` |
| PDF | `.pdf` |
| 图片 / 预览图 | `.png`, `.jpg`, `.jpeg`, `.webp`, `.gif`, `.svg`, `.bmp`, `.tif`, `.tiff` |
| 网页预览 | `.html`, `.htm`, `.css` |
| JavaScript / TypeScript 辅助脚本 | `.js`, `.mjs`, `.cjs`, `.ts`, `.tsx`, `.jsx` |
| Python / Shell 辅助脚本 | `.py`, `.ps1`, `.sh`, `.bat`, `.cmd` |
| 结构化临时数据 | `.json`, `.jsonl`, `.xml`, `.yaml`, `.yml` |
| 日志 | `.log` |
| 压缩包 | `.zip`, `.7z`, `.tar`, `.gz` |

它也可以删除生成的目录，例如 `outputs/example`，以及仅为本次任务创建的本地依赖链接，例如临时的 `node_modules` junction。前提是这些路径已写入 manifest，且目录中不包含受保护内容。

## 不能自动删除的文件格式和路径

以下内容即使出现在 manifest 中，也会被跳过或保护。除非用户明确点名目标并再次确认删除，否则 `clear` 自动清理流程不会删除它们。

| 受保护内容 | 原因 |
| --- | --- |
| 当前工作区外的任何内容 | 防止误删用户文件或系统文件 |
| `.git` 目录或 `.git` 内部内容 | 保护仓库历史 |
| `AGENTS.md` | 保护项目指令 |
| `README*`，包括 `README.md` 和 `README.txt` | 保护项目说明文档 |
| `CLAUDE.md`, `GEMINI.md` | 保护 agent / 项目指令 |
| `LICENSE`, `LICENSE.md`, `LICENSE.txt` | 保护开源协议和法律元数据 |
| `.gitignore`, `.gitattributes` | 保护仓库配置 |
| `.env`, `.env.local`, `.env.production` | 保护环境变量和敏感配置 |
| `.pem`, `.key`, `.pfx`, `.p12`, `.crt`, `.cer`, `.der` | 保护密钥和证书 |
| `.sqlite`, `.sqlite3`, `.db` | 保护可能包含用户数据的数据库 |
| `.bak` | 避免自动删除备份文件 |
| 未列在“可以删除”表格中的扩展名 | 异常文件类型需要人工确认 |
| 用户提供的源文件 | manifest 不应该记录这些文件 |
| 已存在的项目源码或配置文件 | 这个 skill 只清理生成的临时产物 |

## 关于 Markdown 文件的重要说明

这个 skill 可以删除生成的 `.md` 和 `.markdown` 文件，例如临时笔记、构建日志、文本提取结果或生成的会议草稿。它不会自动删除受保护的 Markdown 文件，例如 `README.md`、`AGENTS.md`、`CLAUDE.md` 或 `GEMINI.md`。

## 推荐清理命令

不确定时，先执行 dry run：

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\30316\.codex\skills\clearing-generated-files\scripts\clear-generated-files.ps1 -Workspace <active-workspace> -DryRun
```

确认无误后正式删除：

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\30316\.codex\skills\clearing-generated-files\scripts\clear-generated-files.ps1 -Workspace <active-workspace>
```

## 预期用户指令

最主要的触发词是：

```text
clear
```

下面这些中文或英文表达也应该触发同一个 skill：

- `清理本次生成的文件`
- `删除这次生成的所有文件`
- `清除临时产物`
- `clean up generated files`
- `remove the temporary outputs`

## 安全状态说明

脚本会为每个目标输出一个状态：

- `Ready`：可以安全删除。
- `Deleted`：已经成功删除。
- `Missing`：路径已经不存在。
- `Skipped`：未删除，通常是因为路径位于工作区外、在 `keep` 列表中，或扩展名不在允许列表中。
- `Protected`：未删除，因为路径或子路径匹配了受保护文件名、受保护扩展名或 `.git` 规则。

只有在正式清理时，manifest 才会被删除。使用 `-DryRun` 时，manifest 会被保留。
