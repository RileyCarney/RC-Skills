<#
.SYNOPSIS
    Search offline BoxLite documentation under ../docs/.
.DESCRIPTION
    Searches extracted BoxLite .md files (excluding llms-full.txt by default) for a keyword or regex pattern.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Query,
    [int]$MaxResults = 25,
    [string]$DocsDir = (Join-Path (Split-Path -Parent $PSScriptRoot) "docs")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $DocsDir)) {
    throw "Docs directory not found: $DocsDir. Run sync_docs.ps1 first."
}

$files = Get-ChildItem -Path $DocsDir -Recurse -Filter "*.md"
$hits = @()

foreach ($file in $files) {
    $matches = Select-String -Path $file.FullName -Pattern $Query -AllMatches
    if ($matches) {
        $rel = $file.FullName.Substring($DocsDir.Length).TrimStart('\', '/') -replace '\\', '/'
        $first = $matches[0]
        $hits += [PSCustomObject]@{
            File       = $rel
            MatchCount = $matches.Count
            FirstLine  = $first.LineNumber
            Preview    = $first.Line.Trim()
        }
    }
}

$hits | Sort-Object -Property MatchCount -Descending | Select-Object -First $MaxResults | Format-Table -AutoSize
