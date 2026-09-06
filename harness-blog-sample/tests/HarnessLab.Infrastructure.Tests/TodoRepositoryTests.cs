using HarnessLab.Domain.Todos;
using HarnessLab.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace HarnessLab.Infrastructure.Tests;

public class TodoRepositoryTests
{
    private static HarnessLabDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<HarnessLabDbContext>()
            .UseInMemoryDatabase($"repo-tests-{Guid.NewGuid():N}")
            .Options;
        return new HarnessLabDbContext(options);
    }

    [Fact]
    public async Task AddAsync_Then_ListAsync_ReturnsPersistedItem()
    {
        await using var db = CreateDbContext();
        var repository = new TodoRepository(db);

        await repository.AddAsync(TodoItem.Create("写博客系列"));

        var items = await repository.ListAsync();
        var item = Assert.Single(items);
        Assert.Equal("写博客系列", item.Title);
        Assert.Equal(TodoStatus.Pending, item.Status);
    }

    [Fact]
    public async Task UpdateAsync_PersistsStateChange()
    {
        await using var db = CreateDbContext();
        var repository = new TodoRepository(db);
        var item = TodoItem.Create("改状态");
        await repository.AddAsync(item);

        item.Start();
        await repository.UpdateAsync(item);

        var reloaded = await repository.GetByIdAsync(item.Id);
        Assert.NotNull(reloaded);
        Assert.Equal(TodoStatus.InProgress, reloaded.Status);
    }

    [Fact]
    public async Task GetByIdAsync_ForUnknownId_ReturnsNull()
    {
        await using var db = CreateDbContext();
        var repository = new TodoRepository(db);

        var item = await repository.GetByIdAsync(Guid.NewGuid());

        Assert.Null(item);
    }
}
