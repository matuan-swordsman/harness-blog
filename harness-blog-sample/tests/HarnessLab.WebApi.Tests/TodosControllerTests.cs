using System.Net;
using System.Net.Http.Json;
using HarnessLab.Application.Todos;
using Microsoft.AspNetCore.Mvc.Testing;

namespace HarnessLab.WebApi.Tests;

/// <summary>
/// 端到端 HTTP 集成测试：启动真实 Composition Root（Program），走完整请求管线。
/// </summary>
public class TodosControllerTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient _client;

    public TodosControllerTests(WebApplicationFactory<Program> factory) => _client = factory.CreateClient();

    [Fact]
    public async Task Create_Then_List_ReturnsCreatedTodo()
    {
        var created = await CreateTodoAsync("写博客第 1 篇");

        Assert.Equal("写博客第 1 篇", created.Title);
        Assert.Equal("Pending", created.Status);

        var list = await _client.GetFromJsonAsync<List<TodoDto>>("/api/todos");
        Assert.Contains(list!, todo => todo.Id == created.Id);
    }

    [Fact]
    public async Task Complete_Without_Start_Returns_409Conflict()
    {
        var created = await CreateTodoAsync("不能直接完成");

        var response = await _client.PostAsync($"/api/todos/{created.Id}/complete", content: null);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    [Fact]
    public async Task Start_Then_Complete_Returns_200()
    {
        var created = await CreateTodoAsync("先开始再完成");

        var started = await PostExpectTodoDtoAsync($"/api/todos/{created.Id}/start");
        Assert.Equal("InProgress", started.Status);

        var completed = await PostExpectTodoDtoAsync($"/api/todos/{created.Id}/complete");
        Assert.Equal("Done", completed.Status);
        Assert.NotNull(completed.CompletedAtUtc);
    }

    [Fact]
    public async Task Start_UnknownId_Returns_404NotFound()
    {
        var response = await _client.PostAsync($"/api/todos/{Guid.NewGuid()}/start", content: null);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task GetById_AfterCreate_ReturnsTodo()
    {
        var created = await CreateTodoAsync("按 id 查询");

        var response = await _client.GetAsync($"/api/todos/{created.Id}");
        response.EnsureSuccessStatusCode();

        var todo = await response.Content.ReadFromJsonAsync<TodoDto>();
        Assert.NotNull(todo);
        Assert.Equal(created.Id, todo.Id);
    }

    [Fact]
    public async Task GetById_UnknownId_Returns_404NotFound()
    {
        var response = await _client.GetAsync($"/api/todos/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    private async Task<TodoDto> CreateTodoAsync(string title)
    {
        var response = await _client.PostAsJsonAsync("/api/todos", new { title });
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<TodoDto>())!;
    }

    private async Task<TodoDto> PostExpectTodoDtoAsync(string url)
    {
        var response = await _client.PostAsync(url, content: null);
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<TodoDto>())!;
    }
}
