# HarnessLab — Harness Engineering 示例工程

> 《ASP.NET Core 的 Harness Engineering 手把手实践》博客系列（`../harness-blog/`）的配套示例工程。
> 它演示了一个小型 ASP.NET Core WebAPI 如何从 0 构建出一整套「质量门（Harness）」，
> 让你（和 AI 编码代理）可以放心的、可重复地产出代码。

- **运行时**：.NET 8（ASP.NET Core 8、EF Core 8 InMemory、xUnit）
- **架构**：四层单向依赖 —— `Domain → Application → Infrastructure → WebApi(Composition Root)`
- **质量门（scripts/harness.ps1）**：restore → build → test → TDD 门禁 → lint → check-docs（+ format / security）

## 快速开始

```bash
git init          # 教程假设在独立 git 仓库中实践（TDD 门禁依赖 git）
dotnet build HarnessLab.sln
dotnet test HarnessLab.sln
dotnet run --project src/HarnessLab.WebApi
# 启动后按控制台输出端口访问（端口见 src/HarnessLab.WebApi/Properties/launchSettings.json），如 http://localhost:5xxx/api/todos
```

改码后跑质量门：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/harness.ps1            # quick
powershell -ExecutionPolicy Bypass -File scripts/harness.ps1 -Stage all # 提交前全量
```

## 目录地图

```
HarnessLab.sln
├── src/
│   ├── HarnessLab.Domain/          # 领域模型 + 状态机规则 + 仓储接口（不依赖任何第三方）
│   ├── HarnessLab.Application/     # 用例编排（只依赖 Domain 接口）
│   ├── HarnessLab.Infrastructure/  # EF Core 实现（DbContext / 仓储）
│   └── HarnessLab.WebApi/          # Web API（Composition Root：注册 DI + 控制器）
├── tests/
│   ├── HarnessLab.Domain.Tests/
│   ├── HarnessLab.Application.Tests/
│   ├── HarnessLab.Infrastructure.Tests/
│   ├── HarnessLab.WebApi.Tests/        # WebApplicationFactory 端到端
│   └── HarnessLab.Architecture.Tests/  # 依赖矩阵机械门禁
├── docs/           # 知识库（唯一真相来源）
├── scripts/        # harness.ps1 / lint.ps1 / tdd-check.ps1 / check-docs.ps1
└── AGENTS.md       # 给 AI 编码代理的"地图"
```

## 相关文档

- 博客系列：`../harness-blog/README.md`
- Harness Engineering 原理长文：`../harness-engineering-aspnetcore.md`
