using HarnessLab.Domain.Todos;

namespace HarnessLab.Domain.Tests;

public class TodoItemTests
{
    [Fact]
    public void Create_SetsPendingStatus_TrimsTitle_AndGeneratesId()
    {
        var item = TodoItem.Create("  写博客系列  ");

        Assert.Equal("写博客系列", item.Title);
        Assert.Equal(TodoStatus.Pending, item.Status);
        Assert.NotEqual(Guid.Empty, item.Id);
    }

    [Fact]
    public void Create_WithBlankTitle_Throws()
    {
        Assert.Throws<ArgumentException>(() => TodoItem.Create("   "));
    }

    [Fact]
    public void Start_MovesPending_ToInProgress()
    {
        var item = TodoItem.Create("写文章");

        item.Start();

        Assert.Equal(TodoStatus.InProgress, item.Status);
    }

    [Fact]
    public void Complete_WithoutStart_Throws()
    {
        var item = TodoItem.Create("写文章");

        Assert.Throws<InvalidOperationException>(() => item.Complete());
    }

    [Fact]
    public void Complete_AfterStart_MarksDone_AndRecordsCompletedAt()
    {
        var item = TodoItem.Create("写文章");
        item.Start();

        item.Complete();

        Assert.Equal(TodoStatus.Done, item.Status);
        Assert.NotNull(item.CompletedAtUtc);
    }

    [Fact]
    public void Start_OnDone_Throws()
    {
        var item = TodoItem.Create("写文章");
        item.Start();
        item.Complete();

        Assert.Throws<InvalidOperationException>(() => item.Start());
    }

    [Fact]
    public void Start_OnInProgress_IsIdempotent()
    {
        var item = TodoItem.Create("写文章");
        item.Start();

        item.Start();

        Assert.Equal(TodoStatus.InProgress, item.Status);
    }
}
