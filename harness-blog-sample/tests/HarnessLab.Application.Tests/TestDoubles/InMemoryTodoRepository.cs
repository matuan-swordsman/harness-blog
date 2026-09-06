using HarnessLab.Domain.Todos;

namespace HarnessLab.Application.Tests.TestDoubles;

/// <summary>测试替身：让应用层测试不依赖 EF，保持"被测对象只依赖接口"的纯度。</summary>
internal sealed class InMemoryTodoRepository : ITodoRepository
{
    private readonly Dictionary<Guid, TodoItem> _items = new();

    public Task<TodoItem?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default) =>
        Task.FromResult(_items.TryGetValue(id, out var item) ? item : null);

    public Task<IReadOnlyList<TodoItem>> ListAsync(CancellationToken cancellationToken = default) =>
        Task.FromResult<IReadOnlyList<TodoItem>>(
            _items.Values.OrderBy(x => x.CreatedAtUtc).ToList());

    public Task AddAsync(TodoItem item, CancellationToken cancellationToken = default)
    {
        _items[item.Id] = item;
        return Task.CompletedTask;
    }

    public Task UpdateAsync(TodoItem item, CancellationToken cancellationToken = default)
    {
        _items[item.Id] = item;
        return Task.CompletedTask;
    }
}
