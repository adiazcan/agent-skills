var builder = DistributedApplication.CreateBuilder(args);

// Add the API service with Dapr sidecar
var api = builder.AddProject<Projects.{{SOLUTION_NAME}}_Api>("api")
    .WithDaprSidecar()
    .WithHttpHealthCheck("/health");

// Add the web frontend (Vite + React)
var web = builder.AddViteApp("web", "../{{SOLUTION_NAME}}.Web")
    .WithReference(api)
    .WaitFor(api);

builder.Build().Run();
