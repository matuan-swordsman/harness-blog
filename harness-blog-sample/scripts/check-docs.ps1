<#
.SYNOPSIS
    docs/ 知识库一致性检查（文档门禁）。

.DESCRIPTION
    校验：
      1. 每个 docs/*.md 都已编目到 docs/index.md
      2. 文档内的相对 markdown 链接可解析（文件存在）
      3. AGENTS.md 中以反引号引用的 src/tests/docs/scripts 路径存在

    用法：powershell -ExecutionPolicy Bypass -File scripts/check-docs.ps1
    退出码：0 = 通过；1 = 存在问题。
#>
[CmdletBinding()]
param(
    # 注意：PS 5.1 下 $PSScriptRoot 在 param 默认值求值时为空，故默认留空、在函数体解析。
    [string]$Root = ''
)

$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = Join-Path $PSScriptRoot '..' }
$Root = [System.IO.Path]::GetFullPath($Root)
$docsDir = Join-Path $Root 'docs'
$indexFile = Join-Path $docsDir 'index.md'
$problems = [System.Collections.Generic.List[string]]::new()

if (-not (Test-Path -LiteralPath $docsDir)) {
    Write-Host "docs directory not found: $docsDir" -ForegroundColor Red
    exit 1
}
if (-not (Test-Path -LiteralPath $indexFile)) {
    Write-Host "docs/index.md not found: $indexFile" -ForegroundColor Red
    exit 1
}

$indexContent = [System.IO.File]::ReadAllText($indexFile, [System.Text.Encoding]::UTF8)

# ---- 1. 每个 docs/*.md 都必须在 index.md 中被编目 ----
$allDocs = Get-ChildItem -Path $docsDir -Filter '*.md' | Where-Object { $_.Name -ne 'index.md' }
foreach ($doc in $allDocs) {
    if ($indexContent -notmatch [regex]::Escape($doc.Name)) {
        $problems.Add("uncataloged doc: '$($doc.Name)' - add it to docs/index.md")
    }
}

# ---- 2. 文档内的相对链接可解析 ----
foreach ($doc in Get-ChildItem -Path $docsDir -Filter '*.md') {
    $docDir = Split-Path $doc.FullName -Parent
    foreach ($line in [System.IO.File]::ReadAllLines($doc.FullName, [System.Text.Encoding]::UTF8)) {
        foreach ($match in [regex]::Matches($line, '\[[^\]]*\]\(([^)]+)\)')) {
            $target = $match.Groups[1].Value.Trim()
            if ($target -match '^(https?://|#|mailto:)') { continue }
            $clean = ($target -split '#')[0]
            if (-not $clean) { continue }
            $resolved = Join-Path $docDir $clean
            if (-not (Test-Path -LiteralPath $resolved)) {
                $problems.Add("broken link in '$($doc.Name)': -> '$target'")
            }
        }
    }
}

# ---- 3. AGENTS.md 引用的路径必须存在 ----
$agentsFile = Join-Path $Root 'AGENTS.md'
if (Test-Path -LiteralPath $agentsFile) {
    $agentsContent = [System.IO.File]::ReadAllText($agentsFile, [System.Text.Encoding]::UTF8)
    foreach ($m in [regex]::Matches($agentsContent, '`(?<target>(src|tests|docs|scripts)/[^`\s]+)`')) {
        $target = $m.Groups['target'].Value
        if (-not (Test-Path -LiteralPath (Join-Path $Root $target))) {
            $problems.Add("AGENTS.md references missing path: '$target'")
        }
    }
}

if ($problems.Count -eq 0) {
    Write-Host 'OK: docs are cataloged, links resolve, AGENTS.md references valid.' -ForegroundColor Green
    exit 0
}

Write-Host "$($problems.Count) problem(s):" -ForegroundColor Red
$problems | ForEach-Object { Write-Host "  - $_" }
exit 1
