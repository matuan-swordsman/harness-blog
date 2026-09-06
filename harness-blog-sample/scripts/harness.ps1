<#
.SYNOPSIS
    HarnessLab 质量门（Harness Gate）—— Agent 与人工共用的自动化验证入口。

.DESCRIPTION
    Agent 修改代码后必须执行本脚本并全部通过，才允许进入 Review 环节：
        harness.ps1                            # quick（默认）：restore -> build -> test -> TDD门禁 -> lint -> check-docs
        harness.ps1 -Stage format              # 格式检查（dotnet format --verify-no-changes）
        harness.ps1 -Stage security            # 依赖漏洞/弃用扫描
        harness.ps1 -Stage all                 # quick + format + security
        harness.ps1 -Stage all -Strict         # CI 模式：环境性失败（漏洞库不可达等）也阻塞

    本脚本是各验证脚本的编排层：不重复实现规则逻辑，只负责按阶段串联并聚合退出码。
    测试结果以 TRX 输出到 test-results/（不入库），供 Agent 解析失败用例迭代修复。

    退出码：0 = 全部通过；1 = 存在失败（Blocker）。
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('quick', 'format', 'security', 'all')]
    [string]$Stage = 'quick',

    # security 阶段：环境性失败（漏洞库不可达等）是否视为 Blocker（CI 建议开启）
    [switch]$Strict
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$solution = Join-Path $repoRoot 'HarnessLab.sln'
$testResultsDir = Join-Path $repoRoot 'test-results'
$scriptsDir = $PSScriptRoot

$script:Failures = [System.Collections.Generic.List[string]]::new()
$script:Warnings = [System.Collections.Generic.List[string]]::new()
$script:Steps = [System.Collections.Generic.List[object]]::new()

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Body,
        [ValidateSet('Pass', 'Fail', 'Warn')]
        [string]$OutcomeIfThrows = 'Fail'
    )
    Write-Host ''
    Write-Host "==> $Name" -ForegroundColor Cyan
    try {
        & $Body
        $script:Steps.Add([pscustomobject]@{ Name = $Name; Outcome = 'Pass' })
        Write-Host "[PASS] $Name" -ForegroundColor Green
    }
    catch {
        $script:Steps.Add([pscustomobject]@{ Name = $Name; Outcome = $OutcomeIfThrows })
        if ($OutcomeIfThrows -eq 'Warn') {
            $script:Warnings.Add($Name)
            Write-Host "[WARN] $Name（环境性失败，不阻塞）" -ForegroundColor Yellow
        }
        else {
            $script:Failures.Add($Name)
            Write-Host "[FAIL] $Name" -ForegroundColor Red
        }
    }
}

function Invoke-External {
    # 运行外部命令并按 $LASTEXITCODE 判失败；stdout/stderr 原样透出（供 Agent 解析）。
    param([scriptblock]$Body)
    & $Body
    if ($LASTEXITCODE -ne 0) { throw "命令失败（exit $LASTEXITCODE）：$($Body.ToString())" }
}

$runQuick = ($Stage -eq 'quick' -or $Stage -eq 'all')
$runFormat = ($Stage -eq 'format' -or $Stage -eq 'all')
$runSecurity = ($Stage -eq 'security' -or $Stage -eq 'all')

if ($runQuick) {
    Invoke-Step '还原依赖（restore）' {
        Invoke-External { dotnet restore $solution --nologo -v q }
    }

    Invoke-Step '编译全部工程（build Debug）' {
        Invoke-External { dotnet build $solution -c Debug --no-restore --nologo -v q }
    }

    Invoke-Step '全部测试（test，TRX -> test-results/）' {
        if (Test-Path $testResultsDir) { Remove-Item $testResultsDir -Recurse -Force }
        dotnet test $solution -c Debug --no-build --nologo `
            --logger "trx;LogFileNamePrefix=harness" `
            --results-directory $testResultsDir
        if ($LASTEXITCODE -ne 0) {
            # 只打印失败用例的摘要（用例名 + 断言消息），不 dump 整个 TRX，省 token 且聚焦根因。
            $summary = [System.Collections.Generic.List[string]]::new()
            Get-ChildItem $testResultsDir -Filter *.trx -ErrorAction SilentlyContinue | ForEach-Object {
                [xml]$xml = Get-Content -LiteralPath $_.FullName
                $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
                $ns.AddNamespace('x', 'http://microsoft.com/schemas/VisualStudio/TeamTest/2010')
                foreach ($r in $xml.SelectNodes('//x:UnitTestResult[@outcome="Failed"]', $ns)) {
                    $node = $r.SelectSingleNode('x:Output/x:ErrorInfo/x:Message', $ns)
                    $message = if ($node) { $node.InnerText.Trim() } else { '（无断言消息，见 TRX）' }
                    if ($message.Length -gt 500) { $message = $message.Substring(0, 500) + '…' }
                    $summary.Add("  FAIL  $($r.testName)  ::  $message")
                }
            }
            throw ("测试失败（exit {0}）。失败用例摘要：`n{1}" -f $LASTEXITCODE, ($summary -join "`n"))
        }
    }

    Invoke-Step 'TDD 门禁（scripts/tdd-check.ps1）' {
        & (Join-Path $scriptsDir 'tdd-check.ps1')
        if ($LASTEXITCODE -ne 0) { throw 'TDD 门禁失败：新增/修改的生产代码缺少配套测试（见上方输出）。' }
    }

    Invoke-Step '规范扫描（scripts/lint.ps1）' {
        & (Join-Path $scriptsDir 'lint.ps1')
        if ($LASTEXITCODE -ne 0) { throw 'lint 扫描发现新增规范违规（见上方输出）。' }
    }

    Invoke-Step '文档一致性检查（scripts/check-docs.ps1）' {
        & (Join-Path $scriptsDir 'check-docs.ps1')
        if ($LASTEXITCODE -ne 0) { throw 'check-docs 发现文档漂移（见上方输出）。' }
    }
}

if ($runFormat) {
    Invoke-Step '格式与代码规范检查（dotnet format --verify-no-changes）' {
        Invoke-External { dotnet format $solution --verify-no-changes --no-restore }
    }
}

if ($runSecurity) {
    # 逐工程扫描依赖漏洞 / 弃用包（含传递依赖）。
    $scanTargets = Get-ChildItem -Path $repoRoot -Recurse -Filter *.csproj |
        Where-Object { $_.FullName -notmatch '\\(obj|bin)\\' } |
        Select-Object -ExpandProperty FullName

    Invoke-Step '依赖漏洞扫描（vulnerable，含传递依赖）' {
        foreach ($project in $scanTargets) {
            Write-Host ("  -> {0}" -f (Split-Path -Leaf $project))
            dotnet list $project package --vulnerable --include-transitive
            if ($LASTEXITCODE -ne 0) { throw ("漏洞扫描失败：{0}（exit {1}）。" -f $project, $LASTEXITCODE) }
        }
    } -OutcomeIfThrows $(if ($Strict) { 'Fail' } else { 'Warn' })

    Invoke-Step '弃用依赖扫描（deprecated，含传递依赖）' {
        foreach ($project in $scanTargets) {
            Write-Host ("  -> {0}" -f (Split-Path -Leaf $project))
            dotnet list $project package --deprecated --include-transitive
            if ($LASTEXITCODE -ne 0) { throw ("弃用扫描失败：{0}（exit {1}）。" -f $project, $LASTEXITCODE) }
        }
    } -OutcomeIfThrows $(if ($Strict) { 'Fail' } else { 'Warn' })
}

# ---------- 汇总 ----------
Write-Host ''
Write-Host '==================== Harness Gate 汇总 ====================' -ForegroundColor Cyan
$script:Steps | Format-Table Name, Outcome -AutoSize | Out-String | Write-Host

if ($script:Warnings.Count -gt 0) {
    Write-Host ("警告（不阻塞）：{0}" -f ($script:Warnings -join ', ')) -ForegroundColor Yellow
}

if ($script:Failures.Count -gt 0) {
    Write-Host ''
    Write-Host ("[GATE: BLOCKED] 失败阶段：{0}" -f ($script:Failures -join ', ')) -ForegroundColor Red
    Write-Host 'Agent 迭代路径：分析上方错误 / test-results/*.trx -> 修复代码 -> 重跑 harness.ps1 -> 全绿后进入 Review。' -ForegroundColor Red
    exit 1
}

Write-Host '[GATE: PASSED] 全部阶段通过，可进入 Review 流程（分级规则见 docs/harness.md）。' -ForegroundColor Green
exit 0
