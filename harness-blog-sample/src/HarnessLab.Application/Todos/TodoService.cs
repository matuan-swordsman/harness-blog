using HarnessLab.Domain.Todos;

namespace HarnessLab.Application.Todos;

public interface ITodoService
{
    Task<TodoDto> CreateAsync(string title, CancellationToken cancellationToken = default);

    Task<TodoDto> StartAsync(Guid id, CancellationToken cancellationToken = default);

    Task<TodoDto> CompleteAsync(Guid id, CancellationToken cancellationToken = default);

    Task<IReadOnlyList<TodoDto>> ListAsync(CancellationToken cancellationToken = default);

    Task<TodoDto?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
}

/// <summary>
/// 用例编排层：只依赖 Domain 的接口与模型，不碰 EF / HTTP。
/// </summary>
public sealed class TodoService : ITodoService
{
    private readonly ITodoRepository _repository;

    public TodoService(ITodoRepository repository) => _repository = repository;

    public async Task<TodoDto> CreateAsync(string title, CancellationToken cancellationToken = default)
    {
        var item = TodoItem.Create(title);
        await _repository.AddAsync(item, cancellationToken);
        return TodoDto.From(item);
    }

    public async Task<TodoDto> StartAsync(Guid id, CancellationToken cancellationToken = default)
    {
        var item = await GetOrThrowAsync(id, cancellationToken);
        item.Start();
        await _repository.UpdateAsync(item, cancellationToken);
        return TodoDto.From(item);
    }

    public async Task<TodoDto> CompleteAsync(Guid id, CancellationToken cancellationToken = default)
    {
        var item = await GetOrThrowAsync(id, cancellationToken);
        item.Complete();
        await _repository.UpdateAsync(item, cancellationToken);
        return TodoDto.From(item);
    }

    public async Task<IReadOnlyList<TodoDto>> ListAsync(CancellationToken cancellationToken = default)
    {
        var items = await _repository.ListAsync(cancellationToken);
        return items.Select(TodoDto.From).ToList();
    }

    public async Task<TodoDto?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default)
    {
        var item = await _repository.GetByIdAsync(id, cancellationToken);
        return item is null ? null : TodoDto.From(item);
    }

    private async Task<TodoItem> GetOrThrowAsync(Guid id, CancellationToken cancellationToken) =>
        await _repository.GetByIdAsync(id, cancellationToken)
        ?? throw new KeyNotFoundException($"任务不存在：{id}");
}
