using {{PROJECT_NAME}}.Models;
using {{PROJECT_NAME}}.Services;

namespace {{PROJECT_NAME}}.Endpoints;

/// <summary>
/// {{SERVICE_NAME}} API endpoints (Scenario View - Use Cases)
/// </summary>
public static class {{SERVICE_NAME}}Endpoints
{
    public static void Map{{SERVICE_NAME}}Endpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/{{SERVICE_NAME_LOWER}}")
            .WithTags("{{SERVICE_NAME}}");

        group.MapGet("/", async (I{{SERVICE_NAME}}Service service) =>
        {
            var items = await service.GetAllAsync();
            return Results.Ok(items);
        })
        .WithName("GetAll{{SERVICE_NAME}}")
        .WithDescription("Get all {{SERVICE_NAME}} items");

        group.MapGet("/{id:guid}", async (Guid id, I{{SERVICE_NAME}}Service service) =>
        {
            var item = await service.GetByIdAsync(id);
            return item is not null ? Results.Ok(item) : Results.NotFound();
        })
        .WithName("Get{{SERVICE_NAME}}ById")
        .WithDescription("Get {{SERVICE_NAME}} item by ID");

        group.MapPost("/", async (Create{{SERVICE_NAME}}Request request, I{{SERVICE_NAME}}Service service) =>
        {
            var item = await service.CreateAsync(request.Name);
            return Results.Created($"/api/{{SERVICE_NAME_LOWER}}/{item.Id}", item);
        })
        .WithName("Create{{SERVICE_NAME}}")
        .WithDescription("Create a new {{SERVICE_NAME}} item");
    }
}

public record Create{{SERVICE_NAME}}Request(string Name);
