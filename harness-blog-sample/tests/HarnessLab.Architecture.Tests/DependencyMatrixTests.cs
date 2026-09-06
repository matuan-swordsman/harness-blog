using System.Text.RegularExpressions;
using System.Xml.Linq;

namespace HarnessLab.Architecture.Tests;

/// <summary>
/// 依赖矩阵机械门禁（真源与 docs/architecture.md 一一对应）。
/// 通过解析各 .csproj 的 ProjectReference，强制"入口 → 业务层"的单向依赖。
/// </summary>
public class DependencyMatrixTests
{
    // src 生产工程：key 工程 -> 允许依赖的生产工程（不含自身）。
    private static readonly IReadOnlyDictionary<string, string[]> SrcAllowed = new Dictionary<string, string[]>
    {
        ["HarnessLab.Domain"] = Array.Empty<string>(),
        ["HarnessLab.Application"] = ["HarnessLab.Domain"],
        ["HarnessLab.Infrastructure"] = ["HarnessLab.Domain"],
        ["HarnessLab.WebApi"] = ["HarnessLab.Application", "HarnessLab.Infrastructure"],
    };

    // tests 测试工程：key 测试工程 -> 允许引用的生产工程。
    // 约定：测试工程只引用"被测对象"对应的生产工程，禁止跨层测试耦合。
    private static readonly IReadOnlyDictionary<string, string[]> TestAllowed = new Dictionary<string, string[]>
    {
        ["HarnessLab.Domain.Tests"] = ["HarnessLab.Domain"],
        ["HarnessLab.Application.Tests"] = ["HarnessLab.Application", "HarnessLab.Domain"],
        ["HarnessLab.Infrastructure.Tests"] = ["HarnessLab.Infrastructure", "HarnessLab.Domain"],
        ["HarnessLab.WebApi.Tests"] = ["HarnessLab.WebApi"],
        ["HarnessLab.Architecture.Tests"] = Array.Empty<string>(),
    };

    private static readonly string RepoRoot = FindRepoRoot();

    [Fact]
    public void EverySrcProject_IsCoveredByMatrix()
    {
        var uncovered = EnumerateProjectsIn(Path.Combine(RepoRoot, "src"))
            .Select(ProjectNameFromFile)
            .Where(name => !SrcAllowed.ContainsKey(name))
            .ToList();

        Assert.True(uncovered.Count == 0,
            "以下生产工程未在依赖矩阵登记（新增工程必须登记，见 docs/architecture.md）：\n" + string.Join("\n", uncovered));
    }

    [Fact]
    public void EveryTestProject_IsCoveredByMatrix()
    {
        var uncovered = EnumerateProjectsIn(Path.Combine(RepoRoot, "tests"))
            .Select(ProjectNameFromFile)
            .Where(name => !TestAllowed.ContainsKey(name))
            .ToList();

        Assert.True(uncovered.Count == 0,
            "以下测试工程未在测试依赖矩阵登记：\n" + string.Join("\n", uncovered));
    }

    [Fact]
    public void EverySrcProjectReference_IsAllowedByMatrix()
    {
        var violations = AssertAllowedReferences(SrcAllowed, Path.Combine(RepoRoot, "src"));

        Assert.True(violations.Count == 0,
            "生产工程存在未登记的 ProjectReference：\n" + string.Join("\n", violations));
    }

    [Fact]
    public void EveryTestProjectReference_IsAllowedByMatrix()
    {
        var violations = AssertAllowedReferences(TestAllowed, Path.Combine(RepoRoot, "tests"));

        Assert.True(violations.Count == 0,
            "测试工程存在跨层/未登记的 ProjectReference：\n" + string.Join("\n", violations));
    }

    [Fact]
    public void SrcNamespaces_MustStartWithProjectName()
    {
        var violations = new List<string>();

        foreach (var projectFile in EnumerateProjectsIn(Path.Combine(RepoRoot, "src")))
        {
            var projectName = ProjectNameFromFile(projectFile);
            var projectDir = Path.GetDirectoryName(projectFile)!;

            foreach (var csFile in Directory.EnumerateFiles(projectDir, "*.cs", SearchOption.AllDirectories))
            {
                if (csFile.Contains("\\obj\\") || csFile.Contains("\\bin\\"))
                {
                    continue;
                }

                var match = Regex.Match(File.ReadAllText(csFile), @"\bnamespace\s+([\w.]+)");
                if (!match.Success)
                {
                    continue;
                }

                var ns = match.Groups[1].Value;
                if (!ns.StartsWith(projectName + ".", StringComparison.Ordinal) && ns != projectName)
                {
                    violations.Add($"{Path.GetFileName(csFile)} 的命名空间 {ns} 必须以工程名 {projectName} 为前缀");
                }
            }
        }

        Assert.True(violations.Count == 0,
            "命名空间前缀违规：\n" + string.Join("\n", violations));
    }

    private static List<string> AssertAllowedReferences(
        IReadOnlyDictionary<string, string[]> allowed,
        string projectsRoot)
    {
        var violations = new List<string>();

        foreach (var projectFile in EnumerateProjectsIn(projectsRoot))
        {
            var projectName = ProjectNameFromFile(projectFile);
            var allowedSet = allowed[projectName];
            var references = ParseProjectReferences(projectFile);

            foreach (var reference in references)
            {
                if (reference == projectName)
                {
                    continue; // 自引用
                }

                if (!allowedSet.Contains(reference))
                {
                    violations.Add($"{projectName} 不允许依赖 {reference}");
                }
            }
        }

        return violations;
    }

    private static IEnumerable<string> EnumerateProjectsIn(string root) =>
        Directory.Exists(root)
            ? Directory.EnumerateFiles(root, "*.csproj", SearchOption.AllDirectories)
                .Where(p => !p.Contains("\\obj\\") && !p.Contains("\\bin\\"))
            : Enumerable.Empty<string>();

    private static string ProjectNameFromFile(string projectFile) =>
        Path.GetFileNameWithoutExtension(projectFile);

    private static IEnumerable<string> ParseProjectReferences(string projectFile)
    {
        var document = XDocument.Load(projectFile);
        return document.Descendants()
            .Where(e => e.Name.LocalName == "ProjectReference")
            .Select(e => Path.GetFileNameWithoutExtension(e.Attribute("Include")!.Value));
    }

    private static string FindRepoRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            if (File.Exists(Path.Combine(directory.FullName, "HarnessLab.sln")))
            {
                return directory.FullName;
            }

            directory = directory.Parent;
        }

        throw new InvalidOperationException("未找到 HarnessLab.sln，无法定位仓库根目录");
    }
}
