# docs — HarnessLab 知识库（记录系统）

> 本目录是示例工程的知识库与**唯一真相来源**：架构、规范、流程都以版本化文档沉淀于此。
> 任何涉及架构、质量门、规范的改动，必须同步更新本文档对应条目（`scripts/check-docs.ps1` 机械校验编目与链接）。

## 目录结构

| 路径 | 内容 |
|---|---|
| [index.md](index.md) | 本索引（内容地图） |
| [architecture.md](architecture.md) | 分层与依赖矩阵（与架构测试一一对应） |
| [harness.md](harness.md) | 质量门（harness.ps1）与 Review 分级规则 |
| [CODING_STANDARDS.md](CODING_STANDARDS.md) | 编码规范唯一真源（lint 规则源头） |
| [TECH_DEBT.md](TECH_DEBT.md) | 已知技术债登记表（新增偏差时登记） |
| [QUALITY_SCORE.md](QUALITY_SCORE.md) | 分层与文档质量评分 |

## 维护约定

- **新鲜度**：文档与代码同步演进，不允许漂移；check-docs 门禁发现孤儿文档 / 死链 / 未登记文件时立即修复。
- **先文档后代码**：涉及架构/规范的调整先在 docs 留痕，再进实现。
- **交叉链接**：文档互相引用，避免信息孤岛。
- **机械校验**：`[scripts/check-docs.ps1](../scripts/check-docs.ps1)` 强制：所有 `docs/*.md` 已编目、内部链接可解析、`AGENTS.md` 引用路径存在。
