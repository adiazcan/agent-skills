# Template: .NET 10 Minimal API

Complete template for the backend API project with OpenAPI + Scalar, Dapr, and Kruchten 4+1 architecture.

## Table of Contents

1. [Project Structure](#project-structure)
2. [Project File](#project-file)
3. [Program.cs](#programcs)
4. [Configuration Files](#configuration-files)
5. [Architecture Layers](#architecture-layers)
6. [Sample Endpoints](#sample-endpoints)

---

## Project Structure

```
{SolutionName}.Api/
├── Program.cs
├── {SolutionName}.Api.csproj
├── appsettings.json
├── appsettings.Development.json
├── Properties/
│   └── launchSettings.json
├── Endpoints/                    # Scenario View (Use Cases)
│   └── WeatherEndpoints.cs
├── Models/                       # Logical View
│   └── WeatherForecast.cs
├── Services/                     # Process View
│   └── WeatherService.cs
└── Infrastructure/               # Physical View
    └── DaprStateStore.cs
```

## Project File

**{SolutionName}.Api.csproj:**
```xml
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <RootNamespace>{SolutionName}.Api</RootNamespace>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Dapr.AspNetCore" Version="1.*" />
    <PackageReference Include="Microsoft.AspNetCore.OpenApi" Version="10.*" />
    <PackageReference Include="Scalar.AspNetCore" Version="2.*" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\{SolutionName}.ServiceDefaults\{SolutionName}.ServiceDefaults.csproj" />
  </ItemGroup>

</Project>
```

## Program.cs

```csharp
using {SolutionName}.Api.Endpoints;
using {SolutionName}.Api.Services;
using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

// Add service defaults (OpenTelemetry, health checks, service discovery)
builder.AddServiceDefaults();

// Add OpenAPI (native .NET 10 support)
builder.Services.AddOpenApi("v1", options =>
{
    options.AddDocumentTransformer((document, context, cancellationToken) =>
    {
        document.Info.Title = "{SolutionName} API";
        document.Info.Version = "v1";
        document.Info.Description = "Microservices API following Kruchten 4+1 architecture";
        return Task.CompletedTask;
    });
});

// Add Dapr
builder.Services.AddDaprClient();

// Add CORS for frontend
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins("http://localhost:5173")
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

// Register services (Process View)
builder.Services.AddScoped<IWeatherService, WeatherService>();

var app = builder.Build();

// Configure pipeline
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference(options =>
    {
        options.WithTitle("{SolutionName} API")
               .WithDefaultHttpClient(ScalarTarget.CSharp, ScalarClient.HttpClient);
    });
}

app.UseHttpsRedirection();
app.UseCors();

// Map default health endpoints
app.MapDefaultEndpoints();

// Map API endpoints (Scenario View)
app.MapWeatherEndpoints();

app.Run();
```

## Configuration Files

**appsettings.json:**
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "Dapr": {
    "StateStoreName": "statestore",
    "PubSubName": "pubsub"
  }
}
```

**appsettings.Development.json:**
```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Debug",
      "Microsoft.AspNetCore": "Information"
    }
  }
}
```

**Properties/launchSettings.json:**
```json
{
  "$schema": "https://json.schemastore.org/launchsettings.json",
  "profiles": {
    "http": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "launchUrl": "scalar/v1",
      "applicationUrl": "http://localhost:5080",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    },
    "https": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "launchUrl": "scalar/v1",
      "applicationUrl": "https://localhost:7080;http://localhost:5080",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    }
  }
}
```

## Architecture Layers

### Models (Logical View)

**Models/WeatherForecast.cs:**
```csharp
namespace {SolutionName}.Api.Models;

/// <summary>
/// Weather forecast model (Logical View - Domain Model)
/// </summary>
public record WeatherForecast(
    DateOnly Date,
    int TemperatureC,
    string? Summary)
{
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}
```

### Services (Process View)

**Services/IWeatherService.cs:**
```csharp
using {SolutionName}.Api.Models;

namespace {SolutionName}.Api.Services;

/// <summary>
/// Weather service interface (Process View - Service Contract)
/// </summary>
public interface IWeatherService
{
    Task<IEnumerable<WeatherForecast>> GetForecastAsync(int days = 5);
}
```

**Services/WeatherService.cs:**
```csharp
using {SolutionName}.Api.Models;

namespace {SolutionName}.Api.Services;

/// <summary>
/// Weather service implementation (Process View - Business Logic)
/// </summary>
public class WeatherService : IWeatherService
{
    private static readonly string[] Summaries =
    [
        "Freezing", "Bracing", "Chilly", "Cool", "Mild",
        "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
    ];

    public Task<IEnumerable<WeatherForecast>> GetForecastAsync(int days = 5)
    {
        var forecast = Enumerable.Range(1, days).Select(index =>
            new WeatherForecast(
                DateOnly.FromDateTime(DateTime.Now.AddDays(index)),
                Random.Shared.Next(-20, 55),
                Summaries[Random.Shared.Next(Summaries.Length)]
            ));

        return Task.FromResult(forecast);
    }
}
```

### Endpoints (Scenario View)

**Endpoints/WeatherEndpoints.cs:**
```csharp
using {SolutionName}.Api.Services;

namespace {SolutionName}.Api.Endpoints;

/// <summary>
/// Weather API endpoints (Scenario View - Use Cases)
/// </summary>
public static class WeatherEndpoints
{
    public static void MapWeatherEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/weather")
            .WithTags("Weather");

        group.MapGet("/", async (IWeatherService service) =>
        {
            var forecast = await service.GetForecastAsync();
            return Results.Ok(forecast);
        })
        .WithName("GetWeatherForecast")
        .WithDescription("Get a 5-day weather forecast");

        group.MapGet("/{days:int}", async (int days, IWeatherService service) =>
        {
            if (days < 1 || days > 14)
                return Results.BadRequest("Days must be between 1 and 14");
            
            var forecast = await service.GetForecastAsync(days);
            return Results.Ok(forecast);
        })
        .WithName("GetWeatherForecastByDays")
        .WithDescription("Get weather forecast for specified number of days");
    }
}
```

### Infrastructure (Physical View)

**Infrastructure/DaprStateStore.cs:**
```csharp
using Dapr.Client;

namespace {SolutionName}.Api.Infrastructure;

/// <summary>
/// Dapr state store abstraction (Physical View - Infrastructure)
/// </summary>
public interface IStateStore<T>
{
    Task<T?> GetAsync(string key);
    Task SaveAsync(string key, T value);
    Task DeleteAsync(string key);
}

public class DaprStateStore<T>(DaprClient daprClient, IConfiguration configuration) : IStateStore<T>
{
    private readonly string _storeName = configuration["Dapr:StateStoreName"] ?? "statestore";

    public async Task<T?> GetAsync(string key)
    {
        return await daprClient.GetStateAsync<T>(_storeName, key);
    }

    public async Task SaveAsync(string key, T value)
    {
        await daprClient.SaveStateAsync(_storeName, key, value);
    }

    public async Task DeleteAsync(string key)
    {
        await daprClient.DeleteStateAsync(_storeName, key);
    }
}
```

## Sample Endpoints

### Additional endpoint patterns:

**POST endpoint:**
```csharp
group.MapPost("/", async (CreateForecastRequest request, IWeatherService service) =>
{
    // Validate and create
    return Results.Created($"/api/weather/{id}", result);
})
.WithName("CreateForecast");
```

**With Dapr pub/sub:**
```csharp
app.MapPost("/api/events/weather-updated", 
    [Topic("pubsub", "weather-updated")] async (WeatherUpdatedEvent @event) =>
{
    // Handle event
    return Results.Ok();
});
```
