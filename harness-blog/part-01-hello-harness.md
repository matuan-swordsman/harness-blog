# 第 1 篇：认识 Harness Engineering，搭出第一版分层骨架

> 系列导航：[总览](README.md) · 下一篇：[第 2 篇 · 给 Agent 一张地图](part-02-agents-docs.md)

> 目标：理解"为什么需要 Harness"，并创建一个**四层单向依赖**的 ASP.NET Core WebAPI 工程骨架，
> 保证它随时可以 `build` / `test`。这是后面所有质量门的载体。

---

## 1. 先回答：为什么要做 Harness Engineering？

想象一个用 AI 编码代理（比如 Codex / CodeBuddy / Copilot Agent）写代码的团队：

- Agent 能读到的只有**仓库里存在的东西**。存在聊天记录、会议纪要和同事脑子里的架构约定，对它"不存在"。
- Agent 会忠实地**复制仓库里已有的模式**——包括不合理的模式。今天没人管，三个月后仓库就"熵增"了。
- 人类 Review 是稀缺资源，给每行代码做人工审查会变成瓶颈；但**机器执行规则是免费的**。

于是 OpenAI 在其 *Harness engineering* 文章里总结的做法是：

> 把**纪律编码成支撑结构**：给 Agent 一张地图（AGENTS.md），把架构与规范变成**机器可执行的测试与 lint**，
> 用一个**质量门脚本**决定"能不能合并"，并持续做**熵清理**（还技术债、刷新文档）。

本系列就是把这套思想，用一个 .NET 8 WebAPI 一步步做出来。

本系列的整体形态（可以贴在工位）：

```
                    你的代码（人写 or Agent 写）
                                 │
           ① 知识层   AGENTS.md（地图） + docs/（知识库，渐进式披露）
                                 │
           ② 机械层   架构测试 + lint + TDD 门禁（把"规矩"变成可执行规则）
                                 │
           ③ 反馈层   harness.ps1 一键质量门 → 全绿进 Review → 分级合并
                                 │
                                 ▼
                              merge
```

## 2. 准备

```bash
# 确认 SDK 版本（>= 8.0）
dotnet --list-sdks
# 创建并进入你的练习目录
mkdir HarnessLab
cd HarnessLab
git init          # 本系列所有"门禁"都依赖 git，先初始化
```

> 配套示例工程是 `harness-blog-sample`（本系列答案）。建议你在 `HarnessLab` 里独立照做，
> 不要直接拿答案跑——否则会错过"看它变红"的乐趣。

## 3. 创建解决方案与四层工程

我们采用经典的**干净架构分层**（本系列后面会让这个分层"不可被破坏"）：

| 层 | 工程 | 职责 | 允许依赖 |
|---|---|---|---|
| 领域 | `HarnessLab.Domain` | 实体、状态机、仓储接口 | 无 |
| 应用 | `HarnessLab.Application` | 用例编排、DTO | Domain |
| 基础设施 | `HarnessLab.Infrastructure` | EF Core 实现 | Domain |
| 入口 | `HarnessLab.WebApi` | Web API（Composition Root） | Application + Infrastructure |

```bash
# 解决方案（若你的 SDK 很新，可能默认生成 .slnx；本系列用经典 .sln：
# dotnet new sln -n HarnessLab --format sln）
dotnet new sln -n HarnessLab

dotnet new classlib -n HarnessLab.Domain        -o src/HarnessLab.Domain
dotnet new classlib -n HarnessLab.Application   -o src/HarnessLab.Application
dotnet new classlib -n HarnessLab.Infrastructure -o src/HarnessLab.Infrastructure
dotnet new webapi  -n HarnessLab.WebApi         -o src/HarnessLab.WebApi --use-controllers --no-openapi

# 测试工程（5 个：四层各一 + 一个特殊的"架构测试"工程）
dotnet new xunit -n HarnessLab.Domain.Tests        -o tests/HarnessLab.Domain.Tests
dotnet new xunit -n HarnessLab.Application.Tests   -o tests/HarnessLab.Application.Tests
dotnet new xunit -n HarnessLab.Infrastructure.Tests -o tests/HarnessLab.Infrastructure.Tests
dotnet new xunit -n HarnessLab.WebApi.Tests         -o tests/HarnessLab.WebApi.Tests
dotnet new xunit -n HarnessLab.Architecture.Tests   -o tests/HarnessLab.Architecture.Tests

# 全部加入解决方案
dotnet sln add src/HarnessLab.Domain src/HarnessLab.Application src/HarnessLab.Infrastructure src/HarnessLab.WebApi `
              tests/HarnessLab.Domain.Tests tests/HarnessLab.Application.Tests tests/HarnessLab.Infrastructure.Tests `
              tests/HarnessLab.WebApi.Tests tests/HarnessLab.Architecture.Tests
```

## 4. 按依赖方向添加引用（这行命令决定了"架构纪律"）

```bash
dotnet add src/HarnessLab.Application    reference src/HarnessLab.Domain
dotnet add src/HarnessLab.Infrastructure reference src/HarnessLab.Domain
dotnet add src/HarnessLab.WebApi         reference src/HarnessLab.Application src/HarnessLab.Infrastructure

dotnet add tests/HarnessLab.Domain.Tests        reference src/HarnessLab.Domain
dotnet add tests/HarnessLab.Application.Tests   reference src/HarnessLab.Application src/HarnessLab.Domain
dotnet add tests/HarnessLab.Infrastructure.Tests reference src/HarnessLab.Infrastructure src/HarnessLab.Domain
dotnet add tests/HarnessLab.WebApi.Tests         reference src/HarnessLab.WebApi
```

> 注意：**测试工程只引用"被测对象"对应层**（Application.Tests 不许引 Infrastructure），
> 否则测试会跨层耦合，后面第 3 篇会用架构测试强制这条。

## 5. 装 EF Core InMemory（踩坑预警）

WebApi 需要一个数据访问实现。为了示例**零数据库依赖**，用 EF Core 的 InMemory Provider：

```bash
dotnet add src/HarnessLab.Infrastructure package Microsoft.EntityFrameworkCore.InMemory --version 8.0.16
dotnet add tests/HarnessLab.WebApi.Tests package Microsoft.AspNetCore.Mvc.Testing --version 8.0.16
```

**坑**：`dotnet add package X` 不给版本时，会装当前最新（比如 10.x），而它可能只支持 `net10.0`，
对目标 `net8.0` 的项目直接报 `NU1202`。教训：**给包版本时先对齐项目目标框架**（这本身就可以是一条质量门规则，见第 5 篇的 security 阶段）。

## 6. 先跑通一个领域模型 + 第一个测试（感受"层"）

删掉各工程的 `Class1.cs` / `UnitTest1.cs` 模板文件后，先写**领域层**（只有这一层"懂业务"）：

```csharp
// src/HarnessLab.Domain/Todos/TodoStatus.cs
namespace HarnessLab.Domain.Todos;

public enum TodoStatus
{
    Pending = 0,
    InProgress = 1,
    Done = 2,
}
```

```csharp
// src/HarnessLab.Domain/Todos/TodoItem.cs
namespace HarnessLab.Domain.Todos;

public sealed class TodoItem
{
    public Guid Id { get; private set; }
    public string Title { get; private set; }
    public TodoStatus Status { get; private set; }
    public DateTimeOffset CreatedAtUtc { get; private set; }
    public DateTimeOffset? CompletedAtUtc { get; private set; }

    private TodoItem() { Title = string.Empty; }

    public static TodoItem Create(string title)
    {
        if (string.IsNullOrWhiteSpace(title))
            throw new ArgumentException("标题不能为空", nameof(title));

        return new TodoItem
        {
            Id = Guid.NewGuid(),
            Title = title.Trim(),
            Status = TodoStatus.Pending,
            CreatedAtUtc = DateTimeOffset.UtcNow,
        };
    }

    public void Start()
    {
        if (Status == TodoStatus.Done)
            throw new InvalidOperationException("已完成的任务不能再次开始");
        if (Status == TodoStatus.InProgress) return;   // 幂等
        Status = TodoStatus.InProgress;
    }

    public void Complete()
    {
        if (Status == TodoStatus.Done) return;          // 幂等
        if (Status == TodoStatus.Pending)
            throw new InvalidOperationException("待处理的任务必须先 Start 才能 Complete");
        Status = TodoStatus.Done;
        CompletedAtUtc = DateTimeOffset.UtcNow;
    }
}
```

再写第一个测试（**先想清楚规则，再写代码去锁住它**）：

```csharp
// tests/HarnessLab.Domain.Tests/TodoItemTests.cs
using HarnessLab.Domain.Todos;

namespace HarnessLab.Domain.Tests;

public class TodoItemTests
{
    [Fact]
    public void Complete_WithoutStart_Throws()
    {
        var item = TodoItem.Create("写文章");

        Assert.Throws<InvalidOperationException>(() => item.Complete());
    }
}
```

```bash
dotnet build HarnessLab.sln
dotnet test HarnessLab.sln
```

> 这一步想说明的是：**"业务规则长在领域模型里"是后面能做 TDD 门禁的前提**——
> 规则越靠里，越容易写小测试、越不容易被 HTTP/DB 细节污染。

Application / Infrastructure / WebApi 三层的完整代码不用在本篇贴全
（请看示例工程的 [`src/`](../harness-blog-sample/src/)），你至少要有：

- `Application`：`TodoService`（用例编排，只依赖 `Domain` 的接口）
- `Infrastructure`：`HarnessLabDbContext` + `TodoRepository`（EF InMemory）
- `WebApi`：`Program.cs`（Composition Root：注册 DI）+ `TodosController`（薄控制器）

## 7. 提交一个"干净基线"

完成骨架后提交一次（本系列之后每次改动都建议小步提交）：

```bash
# 先加一个 .gitignore（bin/obj/test-results/.vs 等，见示例工程）
git add -A
git commit -m "chore: scaffold four-layer solution with domain state machine"
```

## 小结与作业

- [ ] 能一条命令 `dotnet build` 通过、`dotnet test` 通过
- [ ] 说出四个工程各自的依赖方向，并解释为什么"测试工程不许跨层引用"
- [ ] 思考：如果把 `Domain` 悄悄引用了 `Infrastructure`，什么情况下会发现？
- [ ] 阅读 [`../harness-engineering-aspnetcore.md`](../harness-engineering-aspnetcore.md) 的「原理篇」加深理解

下一篇我们解决"**Agent 一进仓库不知道该看什么**"的问题：写 AGENTS.md 和 docs 知识库。
