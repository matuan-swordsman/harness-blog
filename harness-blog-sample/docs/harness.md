# Harness — 质量门与 Review 体系

> 核心思想：**让 Agent（或人）产生代码，让机器决定"能不能合并"；人负责审查规则、架构和高风险变更。**
> 本文件与 `AGENTS.md`「提交与 PR」相互补充：AGENTS.md 只留入口，完整规则在此。

## 1. 一键质量门

```powershell
powershell -ExecutionPolicy Bypass -File scripts/harness.ps1            # quick（每次改码后必跑）
powershell -ExecutionPolicy Bypass -File scripts/harness.ps1 -Stage format  # dotnet format --verify-no-changes
powershell -ExecutionPolicy Bypass -File scripts/harness.ps1 -Stage security # dotnet list package --vulnerable
powershell -ExecutionPolicy Bypass -File scripts/harness.ps1 -Stage all      # quick + format + security
powershell -ExecutionPolicy Bypass -File scripts/harness.ps1 -Stage all -Strict # CI 模式：环境性失败也阻塞
```

| 阶段 | 内容 | 阻塞性 |
|---|---|---|
| quick | restore → build(Debug) → test(TRX→`test-results/`) → TDD 门禁(`tdd-check.ps1`) → lint(`lint.ps1`) → check-docs(`check-docs.ps1`) | 阻塞 |
| format | `dotnet format --verify-no-changes` | 阻塞（显式运行该阶段时） |
| security | `dotnet list package --vulnerable/--deprecated` | 本地默认降级 WARN；`-Strict`（CI）时阻塞 |

- **Fail 闭环**：失败信息（编译错误 / TRX 失败用例 / 违规列表）就是给 Agent 的结构化反馈，修复后重跑直至全绿。
- **全绿 ≠ 可合并**：全绿只是进入 Review 的门票；最终合并按第 3 节分级。

## 2. 各门禁脚本

| 脚本 | 职责 |
|---|---|
| `scripts/harness.ps1` | 编排层：按阶段串联并聚合退出码（不重复实现规则） |
| `scripts/lint.ps1` | 禁止模式扫描（`Console.WriteLine` / `Thread.Sleep` / `new HttpClient` / `async void` / `#region`），报错带 Fix 指引 + 基线机制（只拦新增违规） |
| `scripts/tdd-check.ps1` | TDD 门禁：新增(A)/修改(M) 的生产代码必须配套测试（`-Strict` 阻塞修改未配测）；`tdd-ignore` 注释豁免 |
| `scripts/check-docs.ps1` | 文档门禁：所有 `docs/*.md` 已编目、内部链接可解析、AGENTS.md 引用路径存在 |

## 3. Review 分级（风险越高，越严格）

| 变更类型 | 自动测试 | AI Review | 人工 Review |
|---|---|---|---|
| 注释 / 文档 / 脚本 | ✓ | 可选 | 否 |
| 普通业务代码 | ✓ | ✓ | ✓ |
| 新增 API / 接口契约 | ✓ | ✓ | ✓ |
| 依赖方向 / ProjectReference | ✓ | ✓ | **必须** |
| DB 结构 / EF 映射 | ✓ | ✓ | **必须** |
| 认证 / 凭据 / 生产配置 | ✓ | ✓ | **必须** |

## 4. 问题分级：只有 Blocker / Major 阻塞合并

**Blocker**：安全漏洞、数据丢失、API 契约破坏、并发安全、架构依赖违规、凭据硬编码。
**Major**：异常处理缺失、明显性能问题（N+1 / 阻塞调用）、破坏日志/DI/配置约定、生产逻辑缺测试且未 `tdd-ignore`。
**Minor（不阻塞）**：命名、注释、可拆分重构建议。

> Review 的目的不是"发现所有问题"，而是**拦截 Blocker/Major**；Minor 不阻塞，避免噪音淹没高风险变更。

## 5. 把经验编码回仓库（新规则流程）

Review 中反复出现某类问题时：

1. 判断能否机器化：架构测试 / lint 规则 / 单元测试 / tdd-check / 新 harness 阶段；
2. 机器化不了的 → 写进本文档第 3 / 4 节，并注明原因；
3. 规则变更走"必须"级人工 Review。

## 6. 演进方向（未实现，登记为计划）

- `doc-gardener.ps1`：孤儿文档 / 失效引用 / 过期路径的门禁（当前由 check-docs 覆盖编目与链接）。
- 覆盖率门禁：在 CI 中接入 `--collect:"XPlat Code Coverage;Format=cobertura"` + 覆盖率下限。
- 这些属于"阶段 3 熵清理"的增强，见 [QUALITY_SCORE.md](QUALITY_SCORE.md)。
