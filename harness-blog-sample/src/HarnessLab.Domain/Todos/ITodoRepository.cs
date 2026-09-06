namespace HarnessLab.Domain.Todos;

/// <summary>
/// 仓储接口：属于 Domain 层（依赖倒置），具体实现放 Infrastructure 层。
/// </summary>
public interface ITodoRepository
{
    Task<TodoItem?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<TodoItem>> ListAsync(CancellationToken cancellationToken = default);

    Task AddAsync(TodoItem item, CancellationToken cancellationToken = default);

    Task UpdateAsync(TodoItem item, CancellationToken cancellationToken = default);
}
