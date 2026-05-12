param(
  [Parameter(Mandatory = $true)]
  [string]$Workspace,
  [string]$Manifest = ".codex-session-generated-files.json",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$allowedExtensions = @(
  ".ppt", ".pptx", ".odp", ".key",
  ".doc", ".docx", ".odt", ".rtf",
  ".xls", ".xlsx", ".ods", ".csv", ".tsv",
  ".pdf", ".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg", ".bmp", ".tif", ".tiff",
  ".html", ".htm", ".css", ".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx",
  ".py", ".ps1", ".sh", ".bat", ".cmd",
  ".json", ".jsonl", ".md", ".markdown", ".txt", ".log", ".xml", ".yaml", ".yml",
  ".zip", ".7z", ".tar", ".gz"
)

$protectedExactNames = @(
  "agents.md", "claude.md", "gemini.md", "license", "license.md", "license.txt",
  ".gitignore", ".gitattributes", ".env", ".env.local", ".env.production"
)

$protectedNamePrefixes = @("readme")
$protectedExtensions = @(".env", ".pem", ".key", ".pfx", ".p12", ".crt", ".cer", ".der", ".sqlite", ".sqlite3", ".db", ".bak")

function Test-InWorkspace {
  param([string]$ResolvedPath, [string]$RootPath)
  return $ResolvedPath.StartsWith($RootPath, [System.StringComparison]::OrdinalIgnoreCase)
}

function Test-ProtectedLeafName {
  param([string]$Path)
  $leaf = [System.IO.Path]::GetFileName($Path).ToLowerInvariant()
  if ($protectedExactNames -contains $leaf) { return $true }
  foreach ($prefix in $protectedNamePrefixes) {
    if ($leaf.StartsWith($prefix)) { return $true }
  }
  return $false
}

function Test-ProtectedPath {
  param([string]$ResolvedPath)
  $parts = $ResolvedPath -split '[\\/]+'
  foreach ($part in $parts) {
    if ($part.ToLowerInvariant() -eq ".git") { return "contains .git" }
  }
  if (Test-ProtectedLeafName -Path $ResolvedPath) { return "protected file name" }
  $ext = [System.IO.Path]::GetExtension($ResolvedPath).ToLowerInvariant()
  if ($protectedExtensions -contains $ext) { return "protected extension $ext" }
  return $null
}

function Test-AllowedExtension {
  param([string]$ResolvedPath)
  if ((Get-Item -LiteralPath $ResolvedPath -Force).PSIsContainer) { return $true }
  $ext = [System.IO.Path]::GetExtension($ResolvedPath).ToLowerInvariant()
  return $allowedExtensions -contains $ext
}

function Test-DirectoryContainsProtectedContent {
  param([string]$DirectoryPath)
  $items = Get-ChildItem -LiteralPath $DirectoryPath -Force -Recurse -ErrorAction Stop
  foreach ($item in $items) {
    $reason = Test-ProtectedPath -ResolvedPath $item.FullName
    if ($reason) { return "$reason inside directory: $($item.FullName)" }
  }
  return $null
}

$workspacePath = (Resolve-Path -LiteralPath $Workspace).Path.TrimEnd('\', '/')
$manifestPath = Join-Path $workspacePath $Manifest

if (-not (Test-Path -LiteralPath $manifestPath)) {
  Write-Output "Manifest not found: $manifestPath"
  exit 0
}

$data = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$generated = @($data.generated) | Where-Object { $_ -and $_.ToString().Trim() -ne "" }
$keep = @($data.keep) | ForEach-Object { $_.ToString() }

$results = New-Object System.Collections.Generic.List[object]
foreach ($item in $generated) {
  $text = $item.ToString()
  if ($keep -contains $text) {
    $results.Add([pscustomobject]@{ Target=$text; Resolved=""; Status="Skipped"; Reason="listed in keep" })
    continue
  }

  $candidate = if ([System.IO.Path]::IsPathRooted($text)) { $text } else { Join-Path $workspacePath $text }
  if (-not (Test-Path -LiteralPath $candidate)) {
    $results.Add([pscustomobject]@{ Target=$text; Resolved=$candidate; Status="Missing"; Reason="not found" })
    continue
  }

  $resolved = (Resolve-Path -LiteralPath $candidate).Path
  if (-not (Test-InWorkspace -ResolvedPath $resolved -RootPath $workspacePath)) {
    $results.Add([pscustomobject]@{ Target=$text; Resolved=$resolved; Status="Skipped"; Reason="outside workspace" })
    continue
  }

  $protectedReason = Test-ProtectedPath -ResolvedPath $resolved
  if (-not $protectedReason) {
    $itemObj = Get-Item -LiteralPath $resolved -Force
    if ($itemObj.PSIsContainer -and -not ($itemObj.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
      $protectedReason = Test-DirectoryContainsProtectedContent -DirectoryPath $resolved
    }
  }
  if ($protectedReason) {
    $results.Add([pscustomobject]@{ Target=$text; Resolved=$resolved; Status="Protected"; Reason=$protectedReason })
    continue
  }

  if (-not (Test-AllowedExtension -ResolvedPath $resolved)) {
    $ext = [System.IO.Path]::GetExtension($resolved).ToLowerInvariant()
    $results.Add([pscustomobject]@{ Target=$text; Resolved=$resolved; Status="Skipped"; Reason="unlisted extension $ext" })
    continue
  }

  $results.Add([pscustomobject]@{ Target=$text; Resolved=$resolved; Status="Ready"; Reason="" })
}

$results | Sort-Object { $_.Resolved.Length } -Descending | Format-Table -AutoSize | Out-String | Write-Output

foreach ($target in ($results | Where-Object { $_.Status -eq "Ready" } | Sort-Object { $_.Resolved.Length } -Descending)) {
  if ($DryRun) {
    Write-Output "DryRun: would delete $($target.Resolved)"
    continue
  }
  $itemObj = Get-Item -LiteralPath $target.Resolved -Force
  if ($itemObj.PSIsContainer -and ($itemObj.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    Remove-Item -LiteralPath $target.Resolved -Force
  } else {
    Remove-Item -LiteralPath $target.Resolved -Recurse -Force
  }
  Write-Output "Deleted: $($target.Resolved)"
}

if (-not $DryRun) {
  Remove-Item -LiteralPath $manifestPath -Force
  Write-Output "Deleted manifest: $manifestPath"
} else {
  Write-Output "DryRun: manifest retained: $manifestPath"
}
