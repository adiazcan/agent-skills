using {{PROJECT_NAME}}.Endpoints;
using {{PROJECT_NAME}}.Services;
using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

// Add service defaults (OpenTelemetry, health checks, service discovery)
builder.AddServiceDefaults();

// Add OpenAPI (native .NET 10 support)
builder.Services.AddOpenApi("v1", options =>
{
    options.AddDocumentTransformer((document, context, cancellationToken) =>
    {
        document.Info.Title = "{{SERVICE_NAME}} Service API";
        document.Info.Version = "v1";
        document.Info.Description = "{{SERVICE_NAME}} microservice following Kruchten 4+1 architecture";
        return Task.CompletedTask;
    });
});

// Add Dapr
builder.Services.AddDaprClient();

// Add CORS
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

// Register services (Process View)
builder.Services.AddSingleton<I{{SERVICE_NAME}}Service, {{SERVICE_NAME}}Service>();

var app = builder.Build();

// Configure pipeline
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference(options =>
    {
        options.WithTitle("{{SERVICE_NAME}} Service API")
               .WithDefaultHttpClient(ScalarTarget.CSharp, ScalarClient.HttpClient);
    });
}

app.UseHttpsRedirection();
app.UseCors();

// Map default health endpoints
app.MapDefaultEndpoints();

// Map API endpoints (Scenario View)
app.Map{{SERVICE_NAME}}Endpoints();

app.Run();
