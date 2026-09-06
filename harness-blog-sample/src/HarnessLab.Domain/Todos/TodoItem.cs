namespace HarnessLab.Domain.Todos;

/// <summary>
/// 任务聚合根：把"状态流转"的领域规则集中在这里，
/// 而不是散落在 Service / Controller 里（便于用领域测试锁定规则）。
/// </summary>
public sealed class TodoItem
{
    public Guid Id { get; private set; }

    public string Title { get; private set; }

    public TodoStatus Status { get; private set; }

    public DateTimeOffset CreatedAtUtc { get; private set; }

    public DateTimeOffset? CompletedAtUtc { get; private set; }

    // 私有构造：只能通过 Create() / EF 反序列化创建，防止外部绕过不变量。
    private TodoItem()
    {
        Title = string.Empty;
    }

    public static TodoItem Create(string title)
    {
        if (string.IsNullOrWhiteSpace(title))
        {
            throw new ArgumentException("标题不能为空", nameof(title));
        }

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
        {
            throw new InvalidOperationException("已完成的任务不能再次开始");
        }

        if (Status == TodoStatus.InProgress)
        {
            return; // 幂等
        }

        Status = TodoStatus.InProgress;
    }

    public void Complete()
    {
        if (Status == TodoStatus.Done)
        {
            return; // 幂等
        }

        if (Status == TodoStatus.Pending)
        {
            throw new InvalidOperationException("待处理的任务必须先 Start 才能 Complete");
        }

        Status = TodoStatus.Done;
        CompletedAtUtc = DateTimeOffset.UtcNow;
    }
}
