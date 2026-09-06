namespace HarnessLab.Domain.Todos;

/// <summary>
/// 任务生命周期状态。
/// 状态机：Pending → InProgress → Done（单向，不可回退）。
/// </summary>
public enum TodoStatus
{
    Pending = 0,
    InProgress = 1,
    Done = 2,
}
