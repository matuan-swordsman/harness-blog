# 质量评分表

> 对每个分层与知识文档的"新鲜度 / 一致性"做评分，作为熵清理的输入。
> 演进方向：由定时任务（如 `update-quality-score.ps1`）自动刷新，见 [harness.md](harness.md) §6。

## 分层质量

| 层 | 依赖合规 | 测试覆盖 | 备注 |
|---|---|---|---|
| HarnessLab.Domain | ✓（架构测试） | ✓（Domain.Tests） | 状态机规则集中 |
| HarnessLab.Application | ✓（架构测试） | ✓（Application.Tests + Fake） | 不依赖 EF |
| HarnessLab.Infrastructure | ✓（架构测试） | ✓（Infrastructure.Tests） | InMemory Provider |
| HarnessLab.WebApi | ✓（架构测试） | ✓（WebApi.Tests 端到端） | Composition Root |

## 文档新鲜度

| 文档 | 是否最新 | 最近更新 | 说明 |
|---|---|---|---|
| index.md | ✓ | 创建 | 编目 |
| architecture.md | ✓ | 创建 | 与架构测试矩阵一致 |
| harness.md | ✓ | 创建 | 质量门与分级 |
| CODING_STANDARDS.md | ✓ | 创建 | 与 lint 规则一致 |
| TECH_DEBT.md | ✓ | 创建 | 零债务基线 |

> 若某项文档开始与实际代码漂移，请立即修复或登记 [TECH_DEBT.md](TECH_DEBT.md)。
