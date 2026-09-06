# AGENTS.md — HarnessLab（博客系列配套示例）

> 本文件是代码仓库的**地图**（不是操作手册）。详细内容在 `docs/`，入口见 `docs/index.md`。
> 修改代码前先读与本任务相关的文档。

## 项目

- **运行时**：.NET 8 / ASP.NET Core 8，EF Core 8（示例用 InMemory Provider，无真实数据库）
- **解决方案**：`HarnessLab.sln`
- **分层（严格单向）**：`src/HarnessLab.Domain` → `src/HarnessLab.Application` → `src/HarnessLab.Infrastructure`，入口 `src/HarnessLab.WebApi`（Composition Root，唯一允许认识所有层的地方）
- **领域**：Todo 任务（状态机 `Pending → InProgress → Done`）

## 改码后一键质量门（必跑）

```powershell
powershell -ExecutionPolicy Bypass -File scripts/harness.ps1            # quick：restore→build→test→TDD门禁→lint→check-docs
powershell -ExecutionPolicy Bypass -File scripts/harness.ps1 -Stage all # 提交前：quick + format + security
```

分级规则与说明见 `docs/harness.md`。

## 必读（渐进式披露）

- `docs/index.md` — 知识库编目索引
- `docs/architecture.md` — 分层与依赖矩阵。**改动任何 ProjectReference 前必读**（由架构测试机械强制）
- `docs/harness.md` — 质量门与 Review 分级。**提交 / Review 前必读**
- `docs/CODING_STANDARDS.md` — 编码规范唯一真源。**写 C# 前加载**
- `docs/TECH_DEBT.md` — 已知技术债登记表。**新增偏差时登记**

## 铁律（违反即退回）

1. **依赖方向**：只允许 入口 → 业务层；禁止跨层 / 反向依赖。由架构测试机械强制，新增 `ProjectReference` 前先确认方向。
2. **TDD（先红后绿）**：新增 / 修改生产代码必须配套测试（`scripts/tdd-check.ps1` 机械门禁）；豁免用 `// tdd-ignore: <理由>`。
3. **异步**：所有 IO 用 `Async` + `CancellationToken` 传播。
4. **日志**：统一 `ILogger<T>`，禁止 `Console.WriteLine` / `Debug.WriteLine`（lint 机械拦截）。
5. **数据访问**：只读查询用 `AsNoTracking()`；禁止 `new HttpClient()`（lint 机械拦截）。
6. **随改随文档**：改动同步更新 `docs/` 受影响文档（`scripts/check-docs.ps1` 机械校验文档编目与链接）。

## 常用命令

```bash
dotnet build HarnessLab.sln
dotnet test HarnessLab.sln
dotnet run --project src/HarnessLab.WebApi   # 启动 API，访问 /api/todos
```

## 提交与 PR

- 提交信息用 conventional commits（`feat/fix/refactor/docs/chore(scope): subject`），提交前跑 `harness.ps1` quick 全绿。
- 高风险变更（依赖方向、接口契约、DB 结构）必须人工 Review，分级见 `docs/harness.md`。
