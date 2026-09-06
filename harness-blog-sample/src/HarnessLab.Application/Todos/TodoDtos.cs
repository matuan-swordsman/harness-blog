using HarnessLab.Domain.Todos;

namespace HarnessLab.Application.Todos;

/// <summary>对外输出的任务 DTO（跨层不直接暴露实体）。</summary>
public sealed record TodoDto(
    Guid Id,
    string Title,
    string Status,
    DateTimeOffset CreatedAtUtc,
    DateTimeOffset? CompletedAtUtc)
{
    public static TodoDto From(TodoItem item) =>
        new(item.Id, item.Title, item.Status.ToString(), item.CreatedAtUtc, item.CompletedAtUtc);
}
