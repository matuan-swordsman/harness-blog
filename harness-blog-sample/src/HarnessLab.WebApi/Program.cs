using HarnessLab.Application.Todos;
using HarnessLab.Domain.Todos;
using HarnessLab.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

// Composition Root：一切依赖在此组装（唯一允许"认识所有层"的地方）。
var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddScoped<ITodoService, TodoService>();
builder.Services.AddScoped<ITodoRepository, TodoRepository>();
builder.Services.AddDbContext<HarnessLabDbContext>(options =>
    options.UseInMemoryDatabase("harnesslab-demo"));

var app = builder.Build();

app.MapControllers();

app.Run();

// 供 WebApplicationFactory<Program>（WebApi 集成测试）引用。
public partial class Program
{
}
