using HarnessLab.Domain.Todos;
using Microsoft.EntityFrameworkCore;

namespace HarnessLab.Infrastructure.Persistence;

/// <summary>
/// EF Core 数据上下文。示例使用 InMemory provider，无需真实数据库即可跑通全链路。
/// </summary>
public sealed class HarnessLabDbContext : DbContext
{
    public HarnessLabDbContext(DbContextOptions<HarnessLabDbContext> options) : base(options)
    {
    }

    public DbSet<TodoItem> Todos => Set<TodoItem>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<TodoItem>(entity =>
        {
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Title).IsRequired().HasMaxLength(200);
            entity.Property(x => x.Status).HasConversion<string>();
        });

        base.OnModelCreating(modelBuilder);
    }
}
