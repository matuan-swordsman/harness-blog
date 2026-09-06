using HarnessLab.Domain.Todos;
using Microsoft.EntityFrameworkCore;

namespace HarnessLab.Infrastructure.Persistence;

public sealed class TodoRepository : ITodoRepository
{
    private readonly HarnessLabDbContext _db;

    public TodoRepository(HarnessLabDbContext db) => _db = db;

    public Task<TodoItem?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default) =>
        _db.Todos.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id, cancellationToken);

    public async Task<IReadOnlyList<TodoItem>> ListAsync(CancellationToken cancellationToken = default)
    {
        var items = await _db.Todos
            .AsNoTracking()
            .OrderBy(x => x.CreatedAtUtc)
            .ToListAsync(cancellationToken);
        return items;
    }

    public async Task AddAsync(TodoItem item, CancellationToken cancellationToken = default)
    {
        await _db.Todos.AddAsync(item, cancellationToken);
        await _db.SaveChangesAsync(cancellationToken);
    }

    public async Task UpdateAsync(TodoItem item, CancellationToken cancellationToken = default)
    {
        _db.Todos.Update(item);
        await _db.SaveChangesAsync(cancellationToken);
    }
}
