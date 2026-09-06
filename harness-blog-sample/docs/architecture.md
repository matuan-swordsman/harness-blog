# 架构设计

## 概览

```
                       ┌──────────────────────────────┐
      HTTP              │ HarnessLab.WebApi（入口）      │
   ────────────────►    │  - Composition Root（组装 DI） │
                       │  - Controllers（薄）           │
                       └──────────────┬───────────────┘
                                      │ 仅依赖 ↓（禁止反向）
                  ┌───────────────────┴───────────────────┐
                  │  HarnessLab.Application（用例编排）      │
                  │  依赖：HarnessLab.Domain（仅接口/模型） │
                  └───────────────────┬───────────────────┘
                                      │ 仅依赖 ↓
                  ┌───────────────────┴───────────────────┐
                  │  HarnessLab.Infrastructure（EF 实现）   │
                  │  依赖：HarnessLab.Domain                │
                  └───────────────────┬───────────────────┘
                                      │ 仅依赖 ↓
                  ┌───────────────────┴───────────────────┐
                  │  HarnessLab.Domain（领域模型 / 仓储接口）│
                  └───────────────────────────────────────┘
```

## 依赖规则（机械强制）

> 真源实现：[tests/HarnessLab.Architecture.Tests/DependencyMatrixTests.cs](../tests/HarnessLab.Architecture.Tests/DependencyMatrixTests.cs)
> 新增工程 / 调整依赖边界时：先改白名单并说明理由 → 同步更新本文档 → 测试通过。**Agent 无法悄悄越层。**

| 工程 | 允许依赖 | 职责 |
|---|---|---|
| `HarnessLab.Domain` | （无） | 聚合根、状态机、仓储接口、领域异常 |
| `HarnessLab.Application` | `HarnessLab.Domain` | 用例编排、DTO 映射；不含 EF / HTTP |
| `HarnessLab.Infrastructure` | `HarnessLab.Domain` | EF Core DbContext、仓储实现 |
| `HarnessLab.WebApi` | `HarnessLab.Application`、`HarnessLab.Infrastructure` | 控制器（薄）、DI 组装（Composition Root） |

测试工程依赖矩阵：

| 测试工程 | 允许引用 |
|---|---|
| `HarnessLab.Domain.Tests` | `HarnessLab.Domain` |
| `HarnessLab.Application.Tests` | `HarnessLab.Application`、`HarnessLab.Domain` |
| `HarnessLab.Infrastructure.Tests` | `HarnessLab.Infrastructure`、`HarnessLab.Domain` |
| `HarnessLab.WebApi.Tests` | `HarnessLab.WebApi` |
| `HarnessLab.Architecture.Tests` | （无，只解析 csproj） |

附加门禁：

1. 命名空间前缀：src 工程源文件命名空间必须以工程名为前缀（如 `HarnessLab.Domain.Todos`），由架构测试机械校验。
2. 测试工程只引用"被测对象"，禁止跨层测试耦合。
3. Composition Root（`WebApi/Program.cs`）是唯一允许"认识所有层"的进程入口。

## 横切关注点

- **日志**：统一 `ILogger<T>` 结构化日志（lint 机械拦截 Console/Debug.WriteLine）。
- **数据访问**：EF Core InMemory（示例无真实库）；只读查询用 `AsNoTracking()`；状态机字段 `HasConversion<string>`。
- **配置**：`appsettings.json` + 强类型绑定；凭据禁止入仓库。
