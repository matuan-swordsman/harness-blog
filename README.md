# Harness Engineering 知识库

> 本目录集中存放「**ASP.NET Core 的 Harness Engineering**」的全部内容：
> 一篇**原理长文**、一套**6 篇手把手博客系列**、一个**可运行的示例工程**。
>
> **代码仓库**：<https://github.com/matuan-swordsman/harness-blog>

---

## 目录总览

| 路径 | 类型 | 说明 |
|---|---|---|
| [`harness-engineering-aspnetcore.md`](harness-engineering-aspnetcore.md) | 原理长文 | 讲清 **Why + How**：harness 的三支柱、原理、.NET 落地、路线图与误区 |
| [`harness-blog/`](harness-blog/README.md) | 博客系列（6 篇） | 手把手从零把一个 WebAPI 武装成"质量门"工程，每篇可独立阅读 |
| [`harness-blog-sample/`](harness-blog-sample/README.md) | 配套示例工程 | .NET 8 四层 WebAPI（Todo），含架构测试 / lint / TDD 门禁 / harness.ps1 / docs，可直接运行 |

---

## 快速开始（示例工程）

```bash
cd harness-blog-sample
git init          # TDD 门禁依赖 git 工作区
dotnet restore
dotnet build HarnessLab.sln
dotnet test HarnessLab.sln           # 28 个测试
powershell -ExecutionPolicy Bypass -File scripts/harness.ps1            # 一键质量门 quick
powershell -ExecutionPolicy Bypass -File scripts/harness.ps1 -Stage all # 提交前全量
```

---

## 阅读路径建议

1. **只想快速理解思想** → 读 [`harness-engineering-aspnetcore.md`](harness-engineering-aspnetcore.md) 的「原理篇」；
2. **想动手实践** → 从 [`harness-blog/part-01-hello-harness.md`](harness-blog/part-01-hello-harness.md) 开始，按顺序敲；
3. **想直接看成品 / 对照** → 打开 [`harness-blog-sample/`](harness-blog-sample/README.md)。

> 核心一句话（源于 OpenAI 的 *Harness engineering* 文章）：
> 构建软件仍然需要纪律，但纪律更多地体现在**支撑结构**（地图 / 机械强制 / 反馈闭环）上，而不是代码上。

---

## 博客系列目录

| 篇 | 主题 | 产出 |
|---|---|---|
| [第 1 篇](harness-blog/part-01-hello-harness.md) | 认识 Harness + 搭四层骨架 | 能 build/test 的分层 WebAPI |
| [第 2 篇](harness-blog/part-02-agents-docs.md) | AGENTS.md 地图 + docs 知识库 | `check-docs.ps1` 文档门禁 |
| [第 3 篇](harness-blog/part-03-architecture-tests.md) | 架构测试锁死依赖 | 依赖矩阵机械门禁 |
| [第 4 篇](harness-blog/part-04-lint-tdd.md) | lint 规则 + TDD 门禁 | 禁止模式扫描 + 配对测试保障 |
| [第 5 篇](harness-blog/part-05-harness-gate.md) | harness.ps1 一键质量门 + CI | 一键全绿/阻塞闭环 + CI 模板 |
| [第 6 篇](harness-blog/part-06-review-entropy.md) | Review 分级 + 熵清理 + 复盘 | 分级 Review 与"垃圾回收"机制 |

---

## 仓库结构（发布视角）

```
docs/
├── README.md                        ← 本文件（总导航）
├── harness-engineering-aspnetcore.md ← 原理长文
├── harness-blog/                    ← 博客系列（6 篇 + README）
└── harness-blog-sample/             ← 示例工程（独立 .NET 8 解决方案）
    ├── AGENTS.md / README.md / .editorconfig / .gitignore
    ├── src/       Domain → Application → Infrastructure → WebApi
    ├── tests/     5 个测试工程（含 Architecture.Tests）
    ├── docs/      知识库（index / architecture / harness / CODING_STANDARDS / TECH_DEBT / QUALITY_SCORE）
    └── scripts/   harness.ps1 / lint.ps1 / tdd-check.ps1 / check-docs.ps1
```

---

## 反馈与改进

- 发现示例跑不通、文章有误，或想补充某篇：请在代码仓库提 **Issue / PR**。
- 原则：内容与示例**互为镜像**——文章教"怎么做"，示例是"做出来的答案"，两者随仓库一起演进。
