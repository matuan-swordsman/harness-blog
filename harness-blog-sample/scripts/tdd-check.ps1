<#
.SYNOPSIS
    TDD 门禁：新增 / 修改的生产代码必须配套测试。

.DESCRIPTION
    TDD 的"红-绿-重构"是工作流约束，机器无法验证"是否先写了测试"；
    机械上可验证的是"事后不变量"：新增(A)/修改(M) 的生产 *.cs 在 tests/ 是否有配对测试。
      - 新增文件(A) 无配对测试  -> 阻塞（exit 1）
      - 修改文件(M) 无配对测试  -> 默认 WARN，-Strict 时阻塞
      - 豁免：源文件含 'tdd-ignore' 注释；生成代码 / AssemblyInfo / GlobalUsings

    配对判定三级：① test/**/<名>Tests.cs 精确文件；② <名>*Tests.cs 前缀；③ 任一测试文件引用该类型名。

    注意：需要 HarnessLab 根目录是一个独立的 git 仓库（git init）；非仓库 / 嵌套在上级仓库时跳过并提示。

    用法：
        tdd-check.ps1          # 检查工作区改动
        tdd-check.ps1 -Strict  # CI 模式：修改未配测也阻塞
#>
[CmdletBinding()]
param(
    [string]$Root = '',
    [switch]$Strict
)

$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = Join-Path $PSScriptRoot '..' }
$Root = [System.IO.Path]::GetFullPath($Root)

function Test-ProductionPath {
    param([string]$Path)
    $p = $Path.Replace('/', '\')
    if ($p -notmatch '\.cs$') { return $false }
    if ($p -notmatch '^src\\') { return $false }
    if ($p -match '\\(bin|obj)\\' ) { return $false }
    return $true
}

function Get-SourceTypes {
    param([string]$FullPath)
    $content = Get-Content -LiteralPath $FullPath -Raw
    $names = [regex]::Matches($content,
        '(?m)^\s*(public|internal)\s+(sealed\s+|static\s+|abstract\s+|partial\s+|readonly\s+)*(class|record|struct|interface)\s+([A-Za-z_]\w*)') |
        ForEach-Object { $_.Groups[4].Value } | Select-Object -Unique
    if ($names.Count -eq 0) { return @([IO.Path]::GetFileNameWithoutExtension($FullPath)) }
    return @($names)
}

function Test-PairedTest {
    param([string]$TestRoot, [string]$FullPath, [string[]]$TypeNames)
    $baseName = [IO.Path]::GetFileNameWithoutExtension($FullPath)
    $allTestFiles = @(Get-ChildItem -Path $TestRoot -Recurse -Filter '*.cs' -ErrorAction SilentlyContinue)

    # ① 精确文件名：test/**/<baseName>Tests.cs
    if ($allTestFiles | Where-Object { $_.Name -eq "$baseName`Tests.cs" } | Select-Object -First 1) { return $true }

    # ② 前缀文件名：test/**/<baseName>*Tests.cs
    $escaped = [regex]::Escape($baseName)
    if ($allTestFiles | Where-Object { $_.Name -match "^$escaped.*Tests\.cs$" } | Select-Object -First 1) { return $true }

    # ③ 内容匹配：任一测试文件引用该类型名（宽匹配，降低误报）
    foreach ($type in $TypeNames) {
        foreach ($testFile in $allTestFiles) {
            if (Select-String -LiteralPath $testFile.FullName -Pattern "\b$([regex]::Escape($type))\b" -Quiet -ErrorAction SilentlyContinue) {
                return $true
            }
        }
    }
    return $false
}

# ---- git 检查：需要 HarnessLab 根目录本身是 git 仓库 ----
$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    Write-Host '[TDD] 未找到 git，跳过 TDD 配对检查。' -ForegroundColor Yellow
    exit 0
}

$ErrorActionPreference = 'Continue'
$topLevel = (& git -C $Root rev-parse --show-toplevel 2>$null) | Out-String
$topLevel = $topLevel.Trim()
$gitOk = ($LASTEXITCODE -eq 0 -and $topLevel)
$ErrorActionPreference = 'Stop'

if (-not $gitOk) {
    Write-Host '[TDD] HarnessLab 根目录不是 git 仓库，跳过配对检查（建议 git init 后纳入版本控制再启用）。' -ForegroundColor Yellow
    exit 0
}
if (([System.IO.Path]::GetFullPath($topLevel).TrimEnd('\')) -ne $Root.TrimEnd('\')) {
    Write-Host '[TDD] HarnessLab 位于上级 git 仓库内，配对检查需在 HarnessLab 根目录的独立仓库中运行；已跳过。' -ForegroundColor Yellow
    exit 0
}

# ---- 收集 git 改动（porcelain 覆盖未跟踪/新增/修改/重命名）----
$output = @(& git -C $Root status --porcelain=v1 --untracked-files=all 2>&1)
$diffs = [System.Collections.Generic.List[object]]::new()
foreach ($item in $output) {
    if ($item -is [System.Management.Automation.ErrorRecord]) { continue }
    $line = [string]$item
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $x = $line.Substring(0, 1)
    $y = $line.Substring(1, 1)
    $path = $line.Substring(3).Trim()
    if (-not $path) { continue }
    if ($x -eq 'R' -or $x -eq 'C') {
        $arrow = $path.IndexOf(' -> ')
        if ($arrow -ge 0) { $path = $path.Substring($arrow + 4) }
    }
    $isNew = ($x -eq '?' -or $x -eq 'A')
    $isMod = (-not $isNew) -and ($x -eq 'M' -or $y -eq 'M' -or $y -ne ' ')
    if (-not $isNew -and -not $isMod) { continue }
    $diffs.Add([pscustomobject]@{ Status = if ($isNew) { 'A' } else { 'M' }; Path = $path.Replace('/', '\') })
}

$testRoot = Join-Path $Root 'tests'
if (-not (Test-Path $testRoot)) {
    Write-Host "[TDD] tests 目录不存在：$testRoot" -ForegroundColor Red
    exit 1
}

$violations = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$checked = 0

foreach ($d in $diffs) {
    $path = $d.Path
    if (-not (Test-ProductionPath -Path $path)) { continue }
    $fileName = [IO.Path]::GetFileName($path)

    # 自动豁免：生成代码 / 基础设施类文件。
    if ($fileName -match '\.(g|g\.i)\.cs$' -or $fileName -eq 'AssemblyInfo.cs' -or $fileName -eq 'GlobalUsings.cs') { continue }

    $fullPath = Join-Path $Root $path
    if (-not (Test-Path -LiteralPath $fullPath)) { continue } # 删除/重命名目标可能不存在

    # 显式豁免：源文件含 tdd-ignore 注释（必须注明理由）。
    if ((Get-Content -LiteralPath $fullPath -Raw) -match 'tdd-ignore') { continue }

    $typeNames = Get-SourceTypes -FullPath $fullPath
    $hasTest = Test-PairedTest -TestRoot $testRoot -FullPath $fullPath -TypeNames $typeNames
    $checked++

    if (-not $hasTest) {
        if ($d.Status -eq 'A') {
            $violations.Add("$path => 新增生产代码无配对测试（TDD：先写测试，再写实现）")
        }
        else {
            if ($Strict) {
                $violations.Add("$path => 修改的生产代码无配对测试（-Strict：要求补测）")
            }
            else {
                $warnings.Add("$path => 修改的生产代码无配对测试（建议补测；-Strict 时阻塞）")
            }
        }
    }
}

foreach ($w in $warnings) { Write-Host "  [WARN] $w" -ForegroundColor Yellow }
foreach ($v in $violations) { Write-Host "  [FAIL] $v" -ForegroundColor Red }

Write-Host ("[TDD] 检查 {0} 个生产代码改动，{1} 个进入配对校验。" -f @($diffs).Count, $checked) -ForegroundColor Cyan

if ($violations.Count -gt 0) {
    Write-Host ''
    Write-Host 'TDD 工作流：红（先写失败测试）-> 绿（最小实现）-> 重构。' -ForegroundColor Yellow
    Write-Host '豁免：在源文件添加注释 "// tdd-ignore: <理由>"。' -ForegroundColor Yellow
    exit 1
}
Write-Host '[TDD] 通过：新增/修改代码均配套测试。' -ForegroundColor Green
exit 0
