# 第 3 篇：用架构测试锁死分层依赖（让越层"立即变红"）

> 系列导航：[总览](README.md) · [上一篇](part-02-agents-docs.md) · [下一篇](part-04-lint-tdd.md)

> 目标：写一个特殊的测试工程 `HarnessLab.Architecture.Tests`，用 xUnit **解析每个 .csproj 的
> ProjectReference**，断言依赖方向。从此，"Domain 偷偷引用 Infrastructure"这类漂移会被测试当场抓住。

---

## 1. 问题：文档管不住依赖漂移

第 1 篇我们约定"Application 只能依赖 Domain"。但约定不落地就只是文档：
- 某个赶工晚上，谁给 `Domain` 加了 `Infrastructure` 引用 —— build 照样绿；
- Agent 特别喜欢"哪里方便引哪里"，几周后依赖图就成一团乱麻；
- 等你想重构时，才发现底层被上层反向依赖，牵一发动全身。

对策：**把依赖矩阵写成一个测试**。测试工程本身不引用任何生产工程（避免把自己卷进依赖图），
只用 `System.Xml.Linq` 解析各 `.csproj`，与白名单比对。

## 2. 新建架构测试工程（前面已建好）

在 `tests/HarnessLab.Architecture.Tests` 里写测试。核心只有三件事：

### (1) 白名单矩阵（真源，与 docs/architecture.md 一一对应）

```csharp
using System.Text.RegularExpressions;
using System.Xml.Linq;

namespace HarnessLab.Architecture.Tests;

public class DependencyMatrixTests
{
    // 生产工程：key 工程 -> 允许依赖的工程（不含自身）
    private static readonly IReadOnlyDictionary<string, string[]> SrcAllowed = new Dictionary<string, string[]>
    {
        ["HarnessLab.Domain"] = Array.Empty<string>(),
        ["HarnessLab.Application"] = ["HarnessLab.Domain"],
        ["HarnessLab.Infrastructure"] = ["HarnessLab.Domain"],
        ["HarnessLab.WebApi"] = ["HarnessLab.Application", "HarnessLab.Infrastructure"],
    };

    // 测试工程：key 测试工程 -> 允许引用的生产工程（只准引用"被测对象"）
    private static readonly IReadOnlyDictionary<string, string[]> TestAllowed = new Dictionary<string, string[]>
    {
        ["HarnessLab.Domain.Tests"] = ["HarnessLab.Domain"],
        ["HarnessLab.Application.Tests"] = ["HarnessLab.Application", "HarnessLab.Domain"],
        ["HarnessLab.Infrastructure.Tests"] = ["HarnessLab.Infrastructure", "HarnessLab.Domain"],
        ["HarnessLab.WebApi.Tests"] = ["HarnessLab.WebApi"],
        ["HarnessLab.Architecture.Tests"] = Array.Empty<string>(),
    };
```

### (2) 解析 ProjectReference 并比对

```csharp
    private static string RepoRoot = FindRepoRoot();   // 从 AppContext.BaseDirectory 向上找含 HarnessLab.sln 的目录

    [Fact]
    public void EverySrcProjectReference_IsAllowedByMatrix()
    {
        var violations = new List<string>();

        foreach (var projectFile in EnumerateProjectsIn(Path.Combine(RepoRoot, "src")))
        {
            var projectName = Path.GetFileNameWithoutExtension(projectFile);
            foreach (var reference in ParseProjectReferences(projectFile))
            {
                if (reference != projectName && !SrcAllowed[projectName].Contains(reference))
                    violations.Add($"{projectName} 不允许依赖 {reference}");
            }
        }

        Assert.True(violations.Count == 0,
            "生产工程存在未登记的 ProjectReference：\n" + string.Join("\n", violations));
    }

    [Fact]
    public void EveryTestProjectReference_IsAllowedByMatrix() { /* 同上，用 TestAllowed + tests 目录 */ }

    [Fact]
    public void EverySrcProject_IsCoveredByMatrix()
    {
        // 反例保护：src 下新工程没登记也会被发现（tests 目录同理用 TestAllowed）
    }

    private static IEnumerable<string> ParseProjectReferences(string projectFile) =>
        XDocument.Load(projectFile).Descendants()
            .Where(e => e.Name.LocalName == "ProjectReference")
            .Select(e => Path.GetFileNameWithoutExtension(e.Attribute("Include")!.Value));

    private static IEnumerable<string> EnumerateProjectsIn(string root) =>
        Directory.Exists(root)
            ? Directory.EnumerateFiles(root, "*.csproj", SearchOption.AllDirectories)
                .Where(p => !p.Contains("\\obj\\") && !p.Contains("\\bin\\"))
            : Enumerable.Empty<string>();
```

### (3) 命名空间前缀门禁（可选但强烈推荐）

```csharp
    [Fact]
    public void SrcNamespaces_MustStartWithProjectName()
    {
        var violations = new List<string>();
        foreach (var projectFile in EnumerateProjectsIn(Path.Combine(RepoRoot, "src")))
        {
            var projectName = Path.GetFileNameWithoutExtension(projectFile);
            var projectDir = Path.GetDirectoryName(projectFile)!;
            foreach (var csFile in Directory.EnumerateFiles(projectDir, "*.cs", SearchOption.AllDirectories))
            {
                if (csFile.Contains("\\obj\\") || csFile.Contains("\\bin\\")) continue;
                var m = Regex.Match(File.ReadAllText(csFile), @"\bnamespace\s+([\w.]+)");
                if (m.Success)
                {
                    var ns = m.Groups[1].Value;
                    if (ns != projectName && !ns.StartsWith(projectName + ".", StringComparison.Ordinal))
                        violations.Add($"{Path.GetFileName(csFile)} 命名空间 {ns} 必须以 {projectName} 为前缀");
                }
            }
        }
        Assert.True(violations.Count == 0,
            "命名空间前缀违规：\n" + string.Join("\n", violations));
    }
```

> 完整文件见示例工程：[`tests/HarnessLab.Architecture.Tests/DependencyMatrixTests.cs`](../harness-blog-sample/tests/HarnessLab.Architecture.Tests/DependencyMatrixTests.cs)

## 3. 运行：全绿

```bash
dotnet test tests/HarnessLab.Architecture.Tests
# 通过！说明当前依赖矩阵是合法的
```

## 4. 红-绿实验：真的能拦住越层吗？

现在故意制造一次违规，验证"机器把关"：

```bash
# 让 Domain 反向依赖 Application（错误示范）
dotnet add src/HarnessLab.Domain reference src/HarnessLab.Application
dotnet test tests/HarnessLab.Architecture.Tests
# ❌ EverySrcProjectReference_IsAllowedByMatrix 失败：
#    "HarnessLab.Domain 不允许依赖 HarnessLab.Application"
```

看到红了，立刻撤销：

```bash
dotnet remove src/HarnessLab.Domain reference src/HarnessLab.Application
dotnet test tests/HarnessLab.Architecture.Tests   # 恢复全绿
```

> 这就是机械强制的意义：**Agent 没法"悄悄"越层**——它要么被拦下，要么必须改白名单+改文档+说明理由。

## 5. 两个容易忽略的细节

1. **新增工程也必须登记**：`EverySrcProject_IsCoveredByMatrix` / `EveryTestProject_IsCoveredByMatrix` 这两条测试保证"新工程建了但没进矩阵"会被抓到。
2. **测试工程不许跨层耦合**：`Application.Tests` 若引了 `Infrastructure` 也会红——因为那样测的其实是
   "组装是否正确"，而不是"Application 逻辑是否正确"。各层测试用**替身**（如内存仓储）保持纯净。

## 6. 同步文档

架构测试的白名单和 `docs/architecture.md` 是**互为镜像**：改矩阵必改文档，改文档必改矩阵。
check-docs（第 2 篇）管"文档是否编目"，架构测试管"代码是否越层"，两者配合文档就不会过期。

## 小结与作业

- [ ] `Architecture.Tests` 全绿，包含：依赖矩阵、新工程登记、命名空间前缀
- [ ] 亲手做一次"越层实验"并恢复
- [ ] 把 `docs/architecture.md` 的矩阵与代码对齐
- [ ] 提交：`git commit -m "test: enforce dependency matrix with architecture tests"`

下一篇：给代码风格装"红绿灯"——lint 规则（带 Fix 指引和基线）+ TDD 门禁。
