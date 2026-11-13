<#
.SYNOPSIS
    Sync and split BoxLite documentation from https://docs.boxlite.ai/ into local Markdown files.
.DESCRIPTION
    Downloads llms.txt and llms-full.txt (unless -SkipDownload is passed) into ../docs/
    and splits llms-full.txt into individual .md files matching each URL path.
#>
[CmdletBinding()]
param(
    [switch]$SkipDownload,
    [string]$DocsDir = (Join-Path (Split-Path -Parent $PSScriptRoot) "docs")
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force -Path $DocsDir | Out-Null

$llmsTxtPath = Join-Path $DocsDir "llms.txt"
$llmsFullPath = Join-Path $DocsDir "llms-full.txt"

if (-not $SkipDownload) {
    Write-Host "Downloading https://docs.boxlite.ai/llms.txt ..."
    curl.exe -fsSL "https://docs.boxlite.ai/llms.txt" -o $llmsTxtPath
    Write-Host "Downloading https://docs.boxlite.ai/llms-full.txt ..."
    curl.exe -fsSL "https://docs.boxlite.ai/llms-full.txt" -o $llmsFullPath
}

if (-not (Test-Path $llmsFullPath)) {
    throw "llms-full.txt not found at $llmsFullPath"
}

$lines = Get-Content -Path $llmsFullPath -Encoding UTF8
$pages = @()

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^Source: https://docs\.boxlite\.ai/(.+)$') {
        $relPath = $Matches[1].Trim()
        $startLine = if ($i -gt 0 -and $lines[$i - 1] -match '^# ') { $i - 1 } else { $i }
        $pages += [PSCustomObject]@{
            RelPath   = $relPath
            StartLine = $startLine
        }
    }
}

Write-Host "Found $($pages.Count) documentation pages in llms-full.txt."

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
for ($j = 0; $j -lt $pages.Count; $j++) {
    $start = $pages[$j].StartLine
    $end = if ($j + 1 -lt $pages.Count) { $pages[$j + 1].StartLine - 1 } else { $lines.Count - 1 }

    while ($end -gt $start -and [string]::IsNullOrWhiteSpace($lines[$end])) {
        $end--
    }

    $rel = $pages[$j].RelPath -replace '/', [IO.Path]::DirectorySeparatorChar
    if (-not $rel.EndsWith(".md")) {
        $rel = "$rel.md"
    }
    $outPath = Join-Path $DocsDir $rel
    $outParent = Split-Path -Parent $outPath
    New-Item -ItemType Directory -Force -Path $outParent | Out-Null

    $content = ($lines[$start..$end] -join "`n") + "`n"
    [System.IO.File]::WriteAllText($outPath, $content, $utf8NoBom)
}

Write-Host "Extracted $($pages.Count) Markdown files to $DocsDir"
