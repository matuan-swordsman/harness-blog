<#
.SYNOPSIS
    HarnessLab 轻量规范扫描（lint）—— 把 docs/CODING_STANDARDS.md 的禁止项变成可执行规则。

.DESCRIPTION
    用法：
        lint.ps1                 # 扫描 src 下的禁止模式（新增违规才阻塞）
        lint.ps1 -SelfTest       # 规则自测（反向校验：规范禁止项都必须有 lint 规则）
        lint.ps1 -UpdateBaseline # 用当前违规重写基线文件

    基线机制：存量违规记入 scripts/lint-baseline.txt（= 已知技术债），
    门禁只对"不在基线中的新增违规"返回失败——避免历史债阻塞新代码（小步偿还原则）。

    每条报错自带 Fix 指引（指向 docs/CODING_STANDARDS.md），Agent 据此自我修复。
    退出码：0 = 通过；1 = 发现新增违规（或自测失败）。
#>
[CmdletBinding()]
param(
    # 注意：PS 5.1 下 $PSScriptRoot 在 param 默认值求值时为空，故默认留空、在函数体解析。
    [string]$Root = '',
    [switch]$SelfTest,
    [switch]$UpdateBaseline
)

$ErrorActionPreference = 'Stop'
if (-not $Root) { $Root = Join-Path $PSScriptRoot '..' }
$Root = [System.IO.Path]::GetFullPath($Root)

# 生产代码目录（仅扫描 src；bin/obj 排除）。
$SourceDirs = @((Join-Path $Root 'src'))

# ---- 规则表（扫描 + 自测共用同一真源）----
$Rules = @(
    @{ Name = 'Console/Debug.WriteLine'; Pattern = '^\s*(Console|Debug)\.Write(Line|)\s*\('; Fix = 'use ILogger<T>' }
    @{ Name = 'Thread.Sleep';            Pattern = 'Thread\.Sleep\s*\(';                    Fix = 'use Task.Delay(..., ct)' }
    @{ Name = 'new HttpClient()';        Pattern = 'new\s+HttpClient\s*\(';                 Fix = 'inject IHttpClientFactory' }
    @{ Name = 'async void';              Pattern = '\basync\s+void\b';                      Fix = 'use async Task (event handlers excepted)' }
    @{ Name = '#region/#endregion';      Pattern = '^\s*#region|^\s*#endregion';             Fix = 'split into separate classes/files' }
)

function Test-RuleOnLine {
    param([string]$Line, [hashtable]$Rule)
    return ($Line -match $Rule['Pattern'])
}

function Scan-Sources {
    $violations = [System.Collections.Generic.List[object]]::new()
    $files = Get-ChildItem -Path $SourceDirs -Recurse -Filter '*.cs' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\(bin|obj)\\' }

    foreach ($file in $files) {
        $relFile = $file.FullName.Substring($Root.Length).TrimStart('\', '/').Replace('\', '/')
        $suppressNext = $false
        $lineNo = 0
        foreach ($line in (Get-Content -LiteralPath $file.FullName)) {
            $lineNo++
            # 'lint-ignore' 注释抑制"下一条非注释代码行"。
            if ($line -match 'lint-ignore') { $suppressNext = $true; continue }
            if ($line -match '^\s*(//|///|/\*|\*)') { continue }
            if ($suppressNext) { $suppressNext = $false; continue }
            foreach ($rule in $Rules) {
                if (Test-RuleOnLine -Line $line -Rule $rule) {
                    $violations.Add([pscustomobject]@{
                        File = $relFile
                        Line = $lineNo
                        Rule = $rule['Name']
                        Fix  = $rule['Fix']
                    })
                }
            }
        }
    }
    return $violations
}

# ---- 基线文件 ----
$BaselineFile = Join-Path $PSScriptRoot 'lint-baseline.txt'

function Get-BaselineKeys {
    $set = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    if (-not (Test-Path -LiteralPath $BaselineFile)) { return $set }
    $text = [System.IO.File]::ReadAllText($BaselineFile, [System.Text.Encoding]::UTF8)
    foreach ($line in ($text -split "`r?`n")) {
        $t = $line.Trim()
        if ($t -eq '' -or $t.StartsWith('#')) { continue }
        [void]$set.Add($t)
    }
    return $set
}

function Get-ViolationKey {
    param([object]$V)
    return ("{0}:{1}:{2}" -f $V.File, $V.Line, $V.Rule)
}

# ---- 反向一致性：CODING_STANDARDS 禁止项必须被 lint 规则覆盖（防"规范加项、规则漏加"）----
$StandardsCoverage = @('WriteLine', 'Thread.Sleep', 'HttpClient', 'async void', '#region')

function Invoke-SelfTest {
    $failures = [System.Collections.Generic.List[string]]::new()

    foreach ($keyword in $StandardsCoverage) {
        $covered = $Rules | Where-Object { $_.Name.Contains($keyword) } | Select-Object -First 1
        if ($null -eq $covered) {
            $failures.Add("CODING_STANDARDS 禁止项 '$keyword' 在 lint 规则中无对应规则")
        }
    }

    $cases = @(
        @{ Rule = 'Console/Debug.WriteLine'; Line = '        Console.WriteLine("hi");';            Expected = $true }
        @{ Rule = 'Console/Debug.WriteLine'; Line = '        logger.LogInformation("hi");';        Expected = $false }
        @{ Rule = 'Thread.Sleep';            Line = '        Thread.Sleep(100);';                  Expected = $true }
        @{ Rule = 'Thread.Sleep';            Line = '        await Task.Delay(100, ct);';          Expected = $false }
        @{ Rule = 'new HttpClient()';        Line = '        var c = new HttpClient();';           Expected = $true }
        @{ Rule = 'new HttpClient()';        Line = '        var c = factory.CreateClient();';     Expected = $false }
        @{ Rule = 'async void';              Line = '        private async void Load();';          Expected = $true }
        @{ Rule = '#region/#endregion';      Line = '    #region Foo';                             Expected = $true }
        @{ Rule = '#region/#endregion';      Line = '    // plain comment';                        Expected = $false }
    )

    foreach ($tc in $cases) {
        $rule = $Rules | Where-Object { $_.Name -eq $tc.Rule } | Select-Object -First 1
        $actual = Test-RuleOnLine -Line $tc.Line -Rule $rule
        if ($actual -ne $tc.Expected) {
            $failures.Add("rule '$($tc.Rule)' on line '$($tc.Line)' expected=$($tc.Expected) got=$actual")
        }
    }

    if ($failures.Count -eq 0) {
        Write-Host "Self-test OK: $($cases.Count) rule assertions passed." -ForegroundColor Green
        exit 0
    }
    Write-Host "$($failures.Count) self-test failure(s):" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" }
    exit 1
}

if ($SelfTest) { Invoke-SelfTest }

$violations = @(Scan-Sources)

if ($UpdateBaseline) {
    $keys = $violations | ForEach-Object { Get-ViolationKey -V $_ } | Sort-Object -Unique
    $content = "# lint baseline - 存量规范违规登记（由 scripts/lint.ps1 -UpdateBaseline 自动生成）`r`n# 格式：文件名:行号:规则名。门禁只拦截不在基线中的新增违规；存量违规为已知债务。`r`n"
    $content += ($keys -join "`r`n")
    if ($keys.Count -gt 0) { $content += "`r`n" }
    [System.IO.File]::WriteAllText($BaselineFile, $content, (New-Object System.Text.UTF8Encoding($true)))
    Write-Host "Baseline updated: $($keys.Count) known violation(s) recorded in lint-baseline.txt" -ForegroundColor Green
    exit 0
}

if ($violations.Count -eq 0) {
    Write-Host 'OK: no violations found.' -ForegroundColor Green
    exit 0
}

$baseline = Get-BaselineKeys
$newViolations = @($violations | Where-Object { -not $baseline.Contains((Get-ViolationKey -V $_)) })
$known = $violations.Count - $newViolations.Count

Write-Host ("{0} violation(s) found（存量/基线 {1}，新增 {2}）:" -f $violations.Count, $known, $newViolations.Count) -ForegroundColor Cyan
foreach ($v in $violations) {
    $tag = if ($baseline.Contains((Get-ViolationKey -V $v))) { 'K' } else { 'N' }
    if ($tag -eq 'N') {
        Write-Host ("  [{0}] {1}:{2} {3} => {4}" -f $tag, $v.File, $v.Line, $v.Rule, $v.Fix) -ForegroundColor Red
    }
    else {
        Write-Host ("  [{0}] {1}:{2} {3}" -f $tag, $v.File, $v.Line, $v.Rule) -ForegroundColor DarkGray
    }
}

if ($newViolations.Count -gt 0) {
    Write-Host ''
    Write-Host ("STRICT: {0} 条新增违规（不在基线中）—— 必须修复后才能进入 Review；修复指引见 docs/CODING_STANDARDS.md。" -f $newViolations.Count) -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host ("OK: 无新增违规（存量 {0} 条为已知债务，随改动逐步清零）。" -f $known) -ForegroundColor Green
exit 0
