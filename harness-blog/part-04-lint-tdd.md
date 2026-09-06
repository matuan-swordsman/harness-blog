# 第 4 篇：lint 规则（禁止模式 + Fix + 基线）与 TDD 门禁

> 系列导航：[总览](README.md) · [上一篇](part-03-architecture-tests.md) · [下一篇](part-05-harness-gate.md)

> 目标：把"坏味道"变成 lint 规则（报错自带 Fix 指引 + 基线机制只拦新增），
> 再实现一个 TDD 门禁：**新增/修改的生产代码必须配套测试**。

---

## 1. lint：比"文档规范"更硬的规矩

第 2 篇我们把规范写进了 `CODING_STANDARDS.md`。但"写了文档"不等于"会被遵守"。
lint 的思路：**把禁止项写成正则，扫到就报错，并告诉你怎么修**。

### (1) 规则 = (名称, 正则, Fix 指引)

```powershell
# scripts/lint.ps1（规则表片段）
$Rules = @(
    @{ Name = 'Console/Debug.WriteLine'; Pattern = '^\s*(Console|Debug)\.Write(Line|)\s*\('; Fix = 'use ILogger<T>' }
    @{ Name = 'Thread.Sleep';            Pattern = 'Thread\.Sleep\s*\(';                    Fix = 'use Task.Delay(..., ct)' }
    @{ Name = 'new HttpClient()';        Pattern = 'new\s+HttpClient\s*\(';                 Fix = 'inject IHttpClientFactory' }
    @{ Name = 'async void';              Pattern = '\basync\s+void\b';                      Fix = 'use async Task (event handlers excepted)' }
    @{ Name = '#region/#endregion';      Pattern = '^\s*#region|^\s*#endregion';             Fix = 'split into separate classes/files' }
)
```

注意两点（这是"给 Agent 用"的关键）：

- **每条都带 `Fix`**：Agent 看到 `[N] src/.../X.cs:12 new HttpClient() => inject IHttpClientFactory`，
  就能直接照做；
- **扫描范围只有 `src/` 生产代码**：测试里出现 `Thread.Sleep(100)` 这种字符串样例不该算违规。

### (2) 基线机制：让门禁"第一天就绿"

存量代码几乎必然有历史违规。如果 lint 直接全量阻塞，团队第二天就会放弃。
解法：存量违规记入 `scripts/lint-baseline.txt`，**门禁只拦"不在基线中的新增违规"**。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/lint.ps1            # 扫描（新增违规才 exit 1）
powershell -ExecutionPolicy Bypass -File scripts/lint.ps1 -SelfTest   # 规则自测
powershell -ExecutionPolicy Bypass -File scripts/lint.ps1 -UpdateBaseline  # 重写基线（只在新接入/调整规则时用）
```

### (3) 红-绿实验

```csharp
// 随便在 src 下加一行（故意违规）：
Console.WriteLine("debug");
```

```powershell
powershell -ExecutionPolicy Bypass -File scripts/lint.ps1
# 输出： [N] src/HarnessLab.Application/...  Console/Debug.WriteLine => use ILogger<T>
# exit 1
```

改成 `logger.LogInformation(...)` 或删掉后重跑 → 绿色。删除 `#region` 标记类问题同理，
但**要按 Fix 语义修**：`#region` 的 Fix 是"拆分为独立类/文件"，直接删标记不算修（详见第 6 篇的坑）。

### (4) 元机制：lint 也要自测 + 与规范反向校验

```powershell
# ① -SelfTest：每条规则在"样例行"上应该触发/不触发
# ② $StandardsCoverage：CODING_STANDARDS.md 里的每个禁止项都必须有 lint 规则覆盖
```

也就是说：**"规范新增禁止项但 lint 没落地"本身也会被自测抓住**——文档和代码互相咬合，防漂移闭环。

## 2. TDD 门禁：机器怎么验证"你写了测试"？

"先写测试再写实现"是**时序**约束，机器验证不了。但机器能验证两条**事后不变量**：

1. **新增(A) / 修改(M) 的生产代码，在 `tests/` 里有配对测试**；
2. （进阶）覆盖率不低于下限（本篇先做 1）。

### (1) 配对判定（三级，够用且少误报）

```text
① tests/**/<源文件名>Tests.cs             —— 精确命名
② tests/**/<源文件名>*Tests.cs            —— 前缀命名
③ 任一测试文件里引用了该源文件的类型名     —— 宽匹配兜底
```

### (2) 脚本逻辑（要点）

```powershell
# scripts/tdd-check.ps1（要点）
# 1) git status --porcelain 找 A/M 文件
# 2) 只保留 src\ 下的 *.cs（排除 bin/obj）
# 3) 豁免：*.g.cs / AssemblyInfo / GlobalUsings；源文件含 tdd-ignore 注释
# 4) 逐个 Test-PairedTest：
#    - A 且无配对  -> FAIL（阻塞）
#    - M 且无配对  -> WARN；-Strict 时 FAIL（CI 建议开 -Strict）
```

注意：`tdd-check.ps1` 需要你的工程根目录是**独立 git 仓库**（所以第 1 篇就让你 `git init`）。
不在仓库里它不会误报，只会提示跳过。

### (3) 红-绿实验

先提交当前干净基线，然后：

```csharp
// 新增 src/HarnessLab.Domain/Todos/TodoReminder.cs（故意不带测试）
public sealed class TodoReminder { }
```

```powershell
powershell -ExecutionPolicy Bypass -File scripts/tdd-check.ps1
# [FAIL] src/HarnessLab.Domain/Todos/TodoReminder.cs => 新增生产代码无配对测试
# exit 1
```

补一个 `TodoReminderTests.cs` 再跑 → 绿。

**如果某文件确实不需要测试**（比如纯注册/生成代码），显式声明豁免并说明理由：

```csharp
// tdd-ignore: 纯静态注册代码，由集成测试覆盖
```

> 豁免要"显式 + 留理由"，禁止静默跳过——这本身就是可审计的纪律。

## 3. 现在把两个门禁并进一条命令

虽然分开能跑，但"每次改码后只跑一条命令"才是 Agent 会执行的形态。第 5 篇就做这件事。

## 小结与作业

- [ ] `lint.ps1` 全绿；能演示"新增违规变红 → 按 Fix 修复变绿"
- [ ] `tdd-check.ps1` 全绿；能演示"新增无测试文件变红 → 补测变绿"
- [ ] 理解：基线 = 小步偿还技术债；`tdd-ignore` = 显式豁免
- [ ] 提交：`git commit -m "feat: add lint and TDD gates"`
