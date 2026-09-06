# 编码规范（唯一真源）

> 高频铁律常驻 `AGENTS.md`；本文件是完整约定。
> lint / 架构测试的机械规则以本文件为源头——**修改机械规则时须同步更新本文对应条目**。
> `scripts/lint.ps1` 内置反向校验：本文禁止项必须都有 lint 规则覆盖（`$StandardsCoverage`）。

## 一、分层与依赖

1. 依赖方向严格遵循 [architecture.md](architecture.md)：入口 → 业务层，禁止跨层 / 反向依赖。
2. 新增 `ProjectReference` 前先确认方向；依赖边界变更属「必须人工 Review」级。
3. 命名空间：src 工程源文件命名空间必须以所属工程名为根前缀（架构测试机械校验）。

## 二、异步与并发

1. 所有 IO 使用 `Async` + `CancellationToken` 传播。
2. 禁止 `async void`（事件处理器除外）——lint 机械拦截。
3. 禁止 `Thread.Sleep`，用 `Task.Delay(..., ct)`——lint 机械拦截。

## 三、日志

1. 统一 `ILogger<T>` 结构化日志；禁止 `Console.WriteLine` / `Debug.WriteLine`——lint 机械拦截。
2. 敏感信息（口令 / Token / 手机号）不得进入日志与错误消息。

## 四、数据访问与基础设施

1. 只读查询使用 `AsNoTracking()`。
2. 禁止 `new HttpClient()`，应注入 `IHttpClientFactory`——lint 机械拦截。
3. 基础设施（HttpClient / DbContext / 连接）通过 DI 注入，禁止 `new`。

## 五、可读性

1. 不新增 `#region/#endregion`——lint 机械拦截（Fix：拆分为独立类/文件，**删除标记不算修**）。
2. 正确、可维护、对未来的 Agent / 协作者清晰即可；必要时用中文注释说明业务意图。

## 六、测试

1. TDD：新增 / 修改生产代码必须配套测试（`scripts/tdd-check.ps1` 机械门禁），豁免用 `// tdd-ignore: <理由>`。
2. 测试工程只引用被测对象（架构测试校验）。
3. 测试命名：`<被测类型>Tests`。

## 附：lint 规则 ↔ 规范条目映射

lint 内置自测会反向校验以下禁止项均有机械规则覆盖（`scripts/lint.ps1` `$StandardsCoverage`）：

`WriteLine` · `Thread.Sleep` · `new HttpClient` · `async void` · `#region`
