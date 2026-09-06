# 第 5 篇：harness.ps1 一键质量门 + CI

> 系列导航：[总览](README.md) · [上一篇](part-04-lint-tdd.md) · [下一篇](part-06-review-entropy.md)

> 目标：把前几篇的门禁（build / test / tdd-check / lint / check-docs / format / security）
> 编排成一个脚本 `harness.ps1`，形成"**改码 → 一键 → 全绿或拿到修复指引**"的闭环，
> 并给出 GitHub Actions CI 配置。

---

## 1. 编排层：不重复实现规则

`harness.ps1` 的角色不是"再写一遍规则"，而是**按阶段串联已有脚本并聚合退出码**：

| 阶段 | 内容 | 阻塞性 |
|---|---|---|
| `quick`（默认） | restore → build → test（TRX 输出到 `test-results/`）→ tdd-check → lint → check-docs | 阻塞 |
| `format` | `dotnet format --verify-no-changes` | 阻塞（显式跑该阶段） |
| `security` | `dotnet list package --vulnerable/--deprecated`（含传递依赖） | 本地默认 WARN；CI `-Strict` 阻塞 |
| `all` | quick + format + security | — |

```powershell
powershell -ExecutionPolicy Bypass -File scripts/harness.ps1            # quick
powershell -ExecutionPolicy Bypass -File scripts/harness.ps1 -Stage all   # 提交前
powershell -ExecutionPolicy Bypass -File scripts/harness.ps1 -Stage all -Strict  # CI 模式
```

## 2. 核心骨架（其余是细节，可直接抄示例工程）

```powershell
# scripts/harness.ps1（结构要点；完整版见 harness-blog-sample/scripts/harness.ps1）
param([string]$Stage = 'quick', [switch]$Strict)

$script:Failures = [System.Collections.Generic.List[string]]::new()
$script:Steps    = [System.Collections.Generic.List[object]]::new()

function Invoke-Step {
    param([string]$Name, [scriptblock]$Body, [string]$OutcomeIfThrows = 'Fail')
    Write-Host "==> $Name"
    try {
        & $Body
        $script:Steps.Add([pscustomobject]@{ Name = $Name; Outcome = 'Pass' })
        Write-Host "[PASS] $Name" -ForegroundColor Green
    }
    catch {
        $script:Steps.Add([pscustomobject]@{ Name = $Name; Outcome = $OutcomeIfThrows })
        if ($OutcomeIfThrows -eq 'Warn') { Write-Host "[WARN] $Name" -ForegroundColor Yellow }
        else { $script:Failures.Add($Name); Write-Host "[FAIL] $Name" -ForegroundColor Red }
    }
}

# quick 阶段示例
Invoke-Step '编译全部工程' { dotnet build HarnessLab.sln --no-restore -v q; if ($LASTEXITCODE -ne 0) { throw 'build failed' } }
Invoke-Step '全部测试'    { dotnet test  HarnessLab.sln --no-build --logger "trx;LogFileNamePrefix=harness" --results-directory "test-results"; if ($LASTEXITCODE -ne 0) { throw 'test failed' } }
Invoke-Step 'TDD 门禁'    { & .\scripts\tdd-check.ps1;  if ($LASTEXITCODE -ne 0) { throw 'tdd-check failed' } }
Invoke-Step '规范扫描'    { & .\scripts\lint.ps1;       if ($LASTEXITCODE -ne 0) { throw 'lint failed' } }
Invoke-Step '文档检查'    { & .\scripts\check-docs.ps1; if ($LASTEXITCODE -ne 0) { throw 'check-docs failed' } }

if ($script:Failures.Count -gt 0) {
    Write-Host ("[GATE: BLOCKED] 失败阶段：{0}" -f ($script:Failures -join ', ')) -ForegroundColor Red
    exit 1
}
Write-Host '[GATE: PASSED]' -ForegroundColor Green
exit 0
```

## 3. 给 Agent 的"省 token"设计（这是可用的关键）

质量门的消费方不只有人，还有 AI Agent。三条设计让它对 Agent 友好：

1. **测试失败只输出摘要**：失败时解析 TRX，只打印「失败用例名 + 断言消息（截断 500 字符）」，
   不 dump 整个 10 万字符的 TRX；完整结果落 `test-results/`（已 gitignore）供深入排查。
2. **失败的下一步是明确的**：`[GATE: BLOCKED] 失败阶段：xxx` → Agent 的迭代路径固定为
   「读错误 → 改 → 重跑 → 全绿进 Review」，不需要人告诉它怎么办。
3. **环境性失败与代码失败分开**：`security` 阶段遇到"漏洞库不可达"这类环境问题，
   本地降级 WARN 不阻塞；CI 用 `-Strict` 才阻塞——**规则强度随运行环境分级**。

## 4. 把质量门接进 CI

`harness.ps1` 是在"运行它的机器"上执行验证。要让它在每次 PR 都跑，需要 CI。
GitHub Actions 模板（本地脚本与 CI 共用同一套门禁，避免两处逻辑漂移）：

```yaml
# .github/workflows/harness.yml
name: harness
on:
  pull_request:
  push:
    branches: [main]

jobs:
  gate:
    runs-on: ubuntu-latest   # 用 pwsh（PowerShell Core）跨平台跑 .ps1
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'
      - name: Run Harness Gate (all, strict)
        shell: pwsh
        run: pwsh -File scripts/harness.ps1 -Stage all -Strict
```

> CI 模式注意两点：
> - 用 `-Strict`：CI 环境稳定，环境性失败也阻塞，杜绝"CI 红了但没人管"；
> - Agent 时代把 CI 当成**额外的跑者**：本地门禁全绿 + CI 全绿，才允许 Agent 合并（见第 6 篇的合并理念）。

## 5. 运行效果（本系列示例工程实测）

```text
==> 编译全部工程            [PASS]
==> 全部测试                [PASS]  (7+5+5+3+4 = 24 passed)
==> TDD 门禁                [PASS]  (9 个生产文件全部有配对测试)
==> 规范扫描                [PASS]
==> 文档一致性检查           [PASS]
==================== Harness Gate 汇总 ====================
[GATE: PASSED] 全部阶段通过，可进入 Review 流程
```

## 小结与作业

- [ ] `harness.ps1` quick 与 `-Stage all` 全绿
- [ ] 能解释：为什么测试失败只打印摘要？（token 友好）
- [ ] 在自己的仓库加 GitHub Actions（或 GitLab CI），用 `-Stage all -Strict`
- [ ] 提交：`git commit -m "ci: add harness gate pipeline"`

下一篇：Review 分级、熵清理（还技术债）、以及这套体系的"常见坑与复盘"。
