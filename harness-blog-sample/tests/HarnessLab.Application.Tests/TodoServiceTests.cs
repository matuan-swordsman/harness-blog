using HarnessLab.Application.Tests.TestDoubles;
using HarnessLab.Application.Todos;
using HarnessLab.Domain.Todos;

namespace HarnessLab.Application.Tests;

public class TodoServiceTests
{
    private readonly TodoService _service;
    private readonly InMemoryTodoRepository _repository = new();

    public TodoServiceTests() => _service = new TodoService(_repository);

    [Fact]
    public async Task CreateAsync_PersistsPendingTodo()
    {
        var dto = await _service.CreateAsync(" 买牛奶 ");

        Assert.Equal("买牛奶", dto.Title);
        Assert.Equal(TodoStatus.Pending.ToString(), dto.Status);

        var stored = await _repository.GetByIdAsync(dto.Id);
        Assert.NotNull(stored);
    }

    [Fact]
    public async Task StartAsync_MovesTodoToInProgress()
    {
        var created = await _service.CreateAsync("开始任务");

        var dto = await _service.StartAsync(created.Id);

        Assert.Equal(TodoStatus.InProgress.ToString(), dto.Status);
    }

    [Fact]
    public async Task CompleteAsync_WithoutStart_Throws()
    {
        var created = await _service.CreateAsync("直接完成");

        await Assert.ThrowsAsync<InvalidOperationException>(() => _service.CompleteAsync(created.Id));
    }

    [Fact]
    public async Task StartThenComplete_MarksDone()
    {
        var created = await _service.CreateAsync("正常流程");
        await _service.StartAsync(created.Id);

        var done = await _service.CompleteAsync(created.Id);

        Assert.Equal(TodoStatus.Done.ToString(), done.Status);
        Assert.NotNull(done.CompletedAtUtc);
    }

    [Fact]
    public async Task OperateOnUnknownId_ThrowsKeyNotFound()
    {
        var unknownId = Guid.NewGuid();

        await Assert.ThrowsAsync<KeyNotFoundException>(() => _service.StartAsync(unknownId));
    }

    [Fact]
    public async Task GetByIdAsync_ReturnsExistingTodo()
    {
        var created = await _service.CreateAsync("查询");

        var dto = await _service.GetByIdAsync(created.Id);

        Assert.NotNull(dto);
        Assert.Equal(created.Id, dto.Id);
    }

    [Fact]
    public async Task GetByIdAsync_ForUnknownId_ReturnsNull()
    {
        var dto = await _service.GetByIdAsync(Guid.NewGuid());

        Assert.Null(dto);
    }
}
