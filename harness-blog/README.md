# ASP.NET Core 的 Harness Engineering 手把手实践（博客系列）

> 一个**分 6 篇**的动手实践系列：从零把一个 ASP.NET Core WebAPI 改造成
> 「AI 时代靠谱工程」——让 AI 编码代理（和人类协作者）在**机械强制的质量门**保护下快速产出代码。

- **配套示例工程**：[`../harness-blog-sample/`](../harness-blog-sample/README.md)（本系列每一篇的"最终答案"，可直接 clone 对照）
- **原理长文**：[`../harness-engineering-aspnetcore.md`](../harness-engineering-aspnetcore.md)（harness engineering 的原理与理论，本系列重"动手"）

## 为什么值得读

AI 编码代理能 10 倍速写出代码，也会 10 倍速写出**架构漂移、技术债和坏味道**。
只靠"文档约定"约束不住 Agent——文档它可能看都不看；只有把规则变成**机器可执行的测试与脚本**，
把知识变成**它打开仓库就能读到的地图**，你才敢放开吞吐量。

本系列用一个小型 Todo WebAPI 演示这套被称为 **Harness Engineering** 的做法。

## 前置要求

| 项 | 版本/说明 |
|---|---|
| .NET SDK | 8.0 及以上（示例目标 `net8.0`） |
| 操作系统 | Windows（PowerShell 脚本）/ macOS、Linux 也适用（把 `.ps1` 换成等价 shell 命令即可） |
| git | 需要（TDD 门禁依赖工作区状态） |
| 编辑器 | VS Code / Visual Studio / JetBrains 任选；建议装一个 AI 编码代理（CodeBuddy / Cursor / Copilot 等）体验"Agent 视角" |

## 系列目录

| 篇 | 主题 | 你将会得到 |
|---|---|---|
| [第 1 篇](part-01-hello-harness.md) | 认识 Harness + 搭出四层骨架 | 一个能 build/test 的分层 WebAPI 工程 |
| [第 2 篇](part-02-agents-docs.md) | 给 Agent 一张地图：AGENTS.md + docs 知识库 | 文档门禁 check-docs.ps1 雏形 |
| [第 3 篇](part-03-architecture-tests.md) | 用架构测试锁死分层依赖 | 依赖矩阵机械门禁（违例即红） |
| [第 4 篇](part-04-lint-tdd.md) | lint 规则 + TDD 门禁 | 规范扫描 + “先红后绿”的机械保障 |
| [第 5 篇](part-05-harness-gate.md) | harness.ps1 一键质量门 + CI | 一键全绿/阻塞闭环，CI 模板 |
| [第 6 篇](part-06-review-entropy.md) | Review 分级 + 熵清理 + 复盘 | 分级 Review 与“垃圾回收”机制 |

## 篇章 ↔ 示例工程文件对照

| 篇 | 关键产出 | 示例工程对应文件 |
|---|---|---|
| 1 | 四层骨架 | `src/**`、`tests/**`、`HarnessLab.sln` |
| 2 | AGENTS.md + docs + check-docs | `AGENTS.md`、`docs/`、`scripts/check-docs.ps1` |
| 3 | 架构测试 | `tests/HarnessLab.Architecture.Tests/DependencyMatrixTests.cs` |
| 4 | lint + TDD 门禁 | `scripts/lint.ps1`、`scripts/lint-baseline.txt`、`scripts/tdd-check.ps1` |
| 5 | 一键质量门 + CI | `scripts/harness.ps1`（CI 见第 5 篇内 yaml） |
| 6 | Review 分级 + 熵清理 | `docs/harness.md`、`docs/TECH_DEBT.md`、`docs/QUALITY_SCORE.md` |

## 怎么跟着做

1. 强烈建议**不要直接复制示例工程**，而是按每篇步骤在自己的新目录里敲一遍（踩坑也是学习的一部分）；
2. 每篇都是独立主题，但推荐按顺序读——第 n+1 篇会使用第 n 篇的产物；
3. 卡住时对照 [`harness-blog-sample`](../harness-blog-sample/) 里对应阶段的文件；
4. 每篇结尾有「小结与作业」。

> 示例工程如何初始化：`cd docs/harness-blog-sample && git init && dotnet restore`，
> 之后 `powershell -ExecutionPolicy Bypass -File scripts/harness.ps1` 即可看到一键质量门输出。
