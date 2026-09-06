# 第 2 篇：给 Agent 一张地图——AGENTS.md + docs 知识库

> 系列导航：[总览](README.md) · [上一篇](part-01-hello-harness.md) · [下一篇](part-03-architecture-tests.md)

> 目标：把"团队想让 Agent（和人）遵守的上下文"放进仓库，用**渐进式披露**组织；
> 再写一个最小的 `check-docs.ps1`，让"文档是否齐全"也成为机器可检查的门禁。

---

## 1. 为什么仓库里必须有一张"地图"

回顾上一篇的比喻：Agent 的上下文 = 它打开仓库后能看到的一切。

如果约定只存在于：
- 某次 Slack 讨论 → Agent 看不到；
- 老同事的大脑 → Agent 看不到；
- 一篇没进仓库的长文档 → 它也不会主动去读（读完了还会挤爆上下文）。

所以我们要做的第一件事：**把"入口指引"放在 Agent 一定读得到的地方，且只放稳定、高层的信息**。

agents.md 开放规范（Linux Foundation 维护）把这份入口文件规范化为 **`AGENTS.md`**：
普通 Markdown、放在仓库根、大仓库可嵌套（**离被编辑文件最近的 AGENTS.md 优先级最高**）。

## 2. 两条写作原则（先记住）

1. **AGENTS.md 是地图，不是操作手册**：只写"去哪看什么、跑什么命令、几条铁律"，细节全部放 `docs/`。
2. **渐进式披露**：先给一个小而稳定的入口，再告诉 Agent"下一步去哪"——别把 300 行规范糊它一脸。

> 反例（手册式，会快速过时并挤爆上下文）：
> ```markdown
> ## 仓储层规范（第 3 章）
> - 仓储必须实现 IXxxRepository ...
> - AsNoTracking 的使用前提是 ...
> -（……还有 300 行）
> ```

## 3. 写一个"地图式" AGENTS.md

直接在你的工程根目录创建 `AGENTS.md`，只放五类内容。示例（可直接改）：

```markdown
# AGENTS.md — HarnessLab

> 本文件是仓库的**地图**（不是操作手册）。详细内容在 `docs/`，入口见 `docs/index.md`。

## 项目
- .NET 8 / ASP.NET Core 8 / EF Core 8（示例用 InMemory Provider，无真实数据库）
- 分层：Domain → Application → Infrastructure → WebApi（Composition Root）

## 改码后一键质量门（必跑）
powershell -ExecutionPolicy Bypass -File scripts/harness.ps1   # quick

## 必读（渐进式披露）
- docs/index.md — 知识库索引
- docs/architecture.md — 依赖矩阵，改 ProjectReference 前必读
- docs/harness.md — 质量门与 Review 分级，提交前必读
- docs/CODING_STANDARDS.md — 编码规范唯一真源

## 铁律（违反即退回）
1. 依赖方向由架构测试机械强制，禁止跨层/反向依赖
2. TDD：新增/修改生产代码必须配套测试
3. 所有 IO 用 Async + CancellationToken
4. 统一 ILogger<T>，禁止 Console.WriteLine（lint 拦截）
5. 随改随文档
```

> 现在就打开你装了 AI 代理的编辑器，问它"这个仓库怎么构建、有什么规矩"——
> 如果它答得上来，说明你的地图合格了。

## 4. 建立 docs/ 知识库（真源放在这里）

```
docs/
├── index.md             # 编目索引（地图的地图）
├── architecture.md      # 分层与依赖矩阵
├── harness.md           # 质量门与 Review 分级
├── CODING_STANDARDS.md  # 编码规范唯一真源
├── TECH_DEBT.md         # 已知技术债
└── QUALITY_SCORE.md     # 分层/文档质量分
```

关键约定（后面用机器校验）：

1. **所有 *.md 必须在 `index.md` 编目** —— 防止文档"孤岛化"；
2. **文档之间互相链接** —— 防止"找不到入口"；
3. **先文档后代码** —— 涉及架构/规范的调整先在 docs 留痕。

> 完整的六份文件不必手敲——示例工程的 [`docs/`](../harness-blog-sample/docs/) 就是模板，直接抄过来改。

## 5. 让文档"可被机器检查"：check-docs.ps1

文档规矩不写进脚本等于没说。写一个最小的检查脚本：

```powershell
# scripts/check-docs.ps1（要点；完整版见示例工程）
param([string]$Root = '')
if (-not $Root) { $Root = Join-Path $PSScriptRoot '..' }
$Root = [System.IO.Path]::GetFullPath($Root)
$docsDir = Join-Path $Root 'docs'
$indexFile = Join-Path $docsDir 'index.md'
$problems = [System.Collections.Generic.List[string]]::new()

# 1) 每个 docs/*.md 都必须在 index.md 中编目
$indexContent = [IO.File]::ReadAllText($indexFile, [Text.Encoding]::UTF8)
Get-ChildItem $docsDir -Filter '*.md' | Where-Object { $_.Name -ne 'index.md' } | ForEach-Object {
    if ($indexContent -notmatch [regex]::Escape($_.Name)) {
        $problems.Add("uncataloged doc: '$($_.Name)' - add it to docs/index.md")
    }
}
# 2) 文档内相对链接可解析（略：解析 [x](y) 并检查文件存在）
# 3) AGENTS.md 引用的路径存在（略：检查 `docs/...`、`scripts/...` 等是否真实存在）

if ($problems.Count -eq 0) { Write-Host 'OK: docs are cataloged.' -ForegroundColor Green; exit 0 }
$problems | ForEach-Object { Write-Host "  - $_" }
exit 1
```

运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check-docs.ps1
```

**现在做一次"红-绿"实验**（这也是本系列反复出现的验证姿势）：

```powershell
# 故意把 docs/index.md 里的某一列删掉 -> 应该报 "uncataloged doc"
# 然后补回去 -> 恢复绿色
```

> 体会一下：以后每新增一份文档，忘登记，门禁就会拦你。这正是"**先文档后代码 + 机器把关**"。

## 6. 一个"给 Agent 的彩蛋"：让失败输出可执行

如果你想让 Agent 真正修复 check-docs 报错，报错文案要"**像给同事的指令**"而不是玄学：
`uncataloged doc: 'xxx.md' - add it to docs/index.md` 就比 `ERROR: docs invalid` 有用得多。
本系列从第 3 篇起，lint 的每条报错都会带 `Fix` 指引，就是这个道理。

## 小结与作业

- [ ] 仓库根有地图式 `AGENTS.md`，`docs/` 有编目好的知识库
- [ ] 让一个 AI 代理（或新同事）只靠读仓库回答出：构建命令、质量门命令、依赖方向
- [ ] `check-docs.ps1` 能通过；故意删编目会变红
- [ ] 提交：`git add -A && git commit -m "docs: add AGENTS map and knowledge base with check-docs gate"`

下一篇：把"分层依赖"从文档承诺变成**架构测试**——谁想偷偷越层，测试立刻红给你看。
