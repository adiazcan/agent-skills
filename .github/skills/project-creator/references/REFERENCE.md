# Reference: Manual Workflow

Complete step-by-step commands when automation scripts cannot be used.

## Table of Contents

1. [Create Solution Structure](#1-create-solution-structure)
2. [Create Aspire AppHost](#2-create-aspire-apphost)
3. [Create Service Defaults](#3-create-service-defaults)
4. [Create Backend API](#4-create-backend-api)
5. [Create Frontend Web](#5-create-frontend-web)
6. [Configure Aspire Orchestration](#6-configure-aspire-orchestration)
7. [Final Setup](#7-final-setup)

---

## 1. Create Solution Structure

Replace `{SolutionName}` with the actual solution name throughout.

```bash
# Create root directory and solution
mkdir -p {SolutionName}/src
cd {SolutionName}
dotnet new sln -n {SolutionName}
```

## 2. Create Aspire AppHost

```bash
# Create AppHost project
mkdir -p src/{SolutionName}.AppHost/Properties
cd src/{SolutionName}.AppHost

# Create project file
cat > {SolutionName}.AppHost.csproj << 'EOF'
<Project Sdk="Microsoft.NET.Sdk">

  <Sdk Name="Aspire.AppHost.Sdk" Version="13.0.0" />

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <UserSecretsId>{SolutionName}-apphost</UserSecretsId>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Aspire.Hosting.AppHost" Version="13.*" />
    <PackageReference Include="Aspire.Hosting.JavaScript" Version="13.*" />
    <PackageReference Include="CommunityToolkit.Aspire.Hosting.Dapr" Version="9.*" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\{SolutionName}.Api\{SolutionName}.Api.csproj" />
  </ItemGroup>

</Project>
EOF

# Create launchSettings.json with dashboard configuration
cat > Properties/launchSettings.json << 'EOF'
{
  "$schema": "https://json.schemastore.org/launchsettings.json",
  "profiles": {
    "https": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "applicationUrl": "https://localhost:17134;http://localhost:15170",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development",
        "DOTNET_ENVIRONMENT": "Development",
        "ASPIRE_DASHBOARD_OTLP_ENDPOINT_URL": "https://localhost:21030",
        "ASPIRE_RESOURCE_SERVICE_ENDPOINT_URL": "https://localhost:22057",
        "DASHBOARD__TELEMETRYLIMITS__MAXLOGCOUNT": "50000",
        "DASHBOARD__TELEMETRYLIMITS__MAXTRACECOUNT": "50000",
        "DASHBOARD__TELEMETRYLIMITS__MAXMETRICSCOUNT": "100000"
      }
    }
  }
}
EOF

# Create AppHost.cs (see Step 6 for final content)
cd ../..
```

## 3. Create Service Defaults

```bash
mkdir -p src/{SolutionName}.ServiceDefaults
cd src/{SolutionName}.ServiceDefaults

# Create project file
cat > {SolutionName}.ServiceDefaults.csproj << 'EOF'
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <IsAspireSharedProject>true</IsAspireSharedProject>
  </PropertyGroup>

  <ItemGroup>
    <FrameworkReference Include="Microsoft.AspNetCore.App" />
    <PackageReference Include="Microsoft.Extensions.Http.Resilience" Version="10.*" />
    <PackageReference Include="Microsoft.Extensions.ServiceDiscovery" Version="10.*" />
    <PackageReference Include="OpenTelemetry.Exporter.OpenTelemetryProtocol" Version="1.*" />
    <PackageReference Include="OpenTelemetry.Extensions.Hosting" Version="1.*" />
    <PackageReference Include="OpenTelemetry.Instrumentation.AspNetCore" Version="1.*" />
    <PackageReference Include="OpenTelemetry.Instrumentation.Http" Version="1.*" />
    <PackageReference Include="OpenTelemetry.Instrumentation.Runtime" Version="1.*" />
  </ItemGroup>

</Project>
EOF

# Create Extensions.cs
cat > Extensions.cs << 'EOF'
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Logging;
using OpenTelemetry;
using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;

namespace Microsoft.Extensions.Hosting;

public static class Extensions
{
    public static IHostApplicationBuilder AddServiceDefaults(this IHostApplicationBuilder builder)
    {
        builder.ConfigureOpenTelemetry();
        builder.AddDefaultHealthChecks();
        builder.Services.AddServiceDiscovery();
        builder.Services.ConfigureHttpClientDefaults(http =>
        {
            http.AddStandardResilienceHandler();
            http.AddServiceDiscovery();
        });
        return builder;
    }

    public static IHostApplicationBuilder ConfigureOpenTelemetry(this IHostApplicationBuilder builder)
    {
        builder.Logging.AddOpenTelemetry(logging =>
        {
            logging.IncludeFormattedMessage = true;
            logging.IncludeScopes = true;
        });

        builder.Services.AddOpenTelemetry()
            .WithMetrics(metrics =>
            {
                metrics.AddAspNetCoreInstrumentation()
                    .AddHttpClientInstrumentation()
                    .AddRuntimeInstrumentation();
            })
            .WithTracing(tracing =>
            {
                tracing.AddSource(builder.Environment.ApplicationName)
                    .AddAspNetCoreInstrumentation()
                    .AddHttpClientInstrumentation();
            });

        builder.AddOpenTelemetryExporters();
        return builder;
    }

    private static IHostApplicationBuilder AddOpenTelemetryExporters(this IHostApplicationBuilder builder)
    {
        var useOtlpExporter = !string.IsNullOrWhiteSpace(builder.Configuration["OTEL_EXPORTER_OTLP_ENDPOINT"]);
        if (useOtlpExporter)
        {
            builder.Services.AddOpenTelemetry().UseOtlpExporter();
        }
        return builder;
    }

    public static IHostApplicationBuilder AddDefaultHealthChecks(this IHostApplicationBuilder builder)
    {
        builder.Services.AddHealthChecks()
            .AddCheck("self", () => HealthCheckResult.Healthy(), ["live"]);
        return builder;
    }

    public static WebApplication MapDefaultEndpoints(this WebApplication app)
    {
        app.MapHealthChecks("/health");
        app.MapHealthChecks("/alive", new HealthCheckOptions
        {
            Predicate = r => r.Tags.Contains("live")
        });
        return app;
    }
}
EOF

cd ../..
```

## 4. Create Backend API

See [TEMPLATE_API.md](TEMPLATE_API.md) for the complete API template.

```bash
mkdir -p src/{SolutionName}.Api
cd src/{SolutionName}.Api

# Create project file
cat > {SolutionName}.Api.csproj << 'EOF'
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
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
EOF

# Create Program.cs
cat > Program.cs << 'EOF'
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
        return Task.CompletedTask;
    });
});

// Add Dapr
builder.Services.AddDaprClient();

var app = builder.Build();

// Configure pipeline
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}

app.UseHttpsRedirection();

// Map default health endpoints
app.MapDefaultEndpoints();

// Sample endpoint
app.MapGet("/api/weather", () =>
{
    var forecast = Enumerable.Range(1, 5).Select(index =>
        new WeatherForecast
        (
            DateOnly.FromDateTime(DateTime.Now.AddDays(index)),
            Random.Shared.Next(-20, 55),
            ["Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"][Random.Shared.Next(10)]
        ))
        .ToArray();
    return forecast;
})
.WithName("GetWeatherForecast");

app.Run();

record WeatherForecast(DateOnly Date, int TemperatureC, string? Summary)
{
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}
EOF

# Create appsettings.json
cat > appsettings.json << 'EOF'
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
EOF

# Create appsettings.Development.json
cat > appsettings.Development.json << 'EOF'
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  }
}
EOF

# Create Properties/launchSettings.json
mkdir -p Properties
cat > Properties/launchSettings.json << 'EOF'
{
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
EOF

cd ../..
```

## 5. Create Frontend Web

See [TEMPLATE_WEB.md](TEMPLATE_WEB.md) for the complete frontend template.

```bash
mkdir -p src/{SolutionName}.Web
cd src/{SolutionName}.Web

# Initialize Vite + React + TypeScript project
npm create vite@latest . -- --template react-ts

# Install dependencies
npm install
npm install zustand @tanstack/react-query axios
npm install react-router-dom
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p

# Configuration files will be created by the template
cd ../..
```

## 6. Configure Aspire Orchestration

Create the final AppHost.cs:

```bash
cd src/{SolutionName}.AppHost

cat > AppHost.cs << 'EOF'
var builder = DistributedApplication.CreateBuilder(args);

// Add the API service with Dapr sidecar
var api = builder.AddProject<Projects.{SolutionName}_Api>("api")
    .WithDaprSidecar()
    .WithHttpHealthCheck("/health");

// Add the web frontend (Vite + React)
var web = builder.AddViteApp("web", "../{SolutionName}.Web")
    .WithReference(api)
    .WaitFor(api);

builder.Build().Run();
EOF

cd ../..
```

## 7. Final Setup

```bash
# Add all projects to solution
dotnet sln add src/{SolutionName}.AppHost/{SolutionName}.AppHost.csproj
dotnet sln add src/{SolutionName}.ServiceDefaults/{SolutionName}.ServiceDefaults.csproj
dotnet sln add src/{SolutionName}.Api/{SolutionName}.Api.csproj

# Restore and build
dotnet restore
dotnet build

# Install frontend dependencies
cd src/{SolutionName}.Web
npm install
cd ../..
```

## Running the Solution

```bash
# Using Aspire CLI (recommended)
aspire run

# Or run individual services manually:
# Terminal 1 - API
cd src/{SolutionName}.Api && dotnet run

# Terminal 2 - Web
cd src/{SolutionName}.Web && npm run dev
```

## Port Configuration

To change default ports, modify:

1. **API ports**: `src/{SolutionName}.Api/Properties/launchSettings.json`
2. **Web port**: `src/{SolutionName}.AppHost/AppHost.cs` (WithHttpEndpoint)
3. **Vite config**: `src/{SolutionName}.Web/vite.config.ts`

---

## Adding a New Microservice

To add a new microservice to an existing solution manually:

### Step 1: Create the Service Project

Replace `{ServiceName}` with your service name (e.g., `Orders`, `Products`).

```bash
cd {SolutionName}

# Create project directory
mkdir -p src/{SolutionName}.{ServiceName}/Properties
cd src/{SolutionName}.{ServiceName}

# Create project file
cat > {SolutionName}.{ServiceName}.csproj << 'EOF'
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
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
EOF
```

### Step 2: Create Program.cs

```bash
cat > Program.cs << 'EOF'
using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

builder.Services.AddOpenApi("v1", options =>
{
    options.AddDocumentTransformer((document, context, cancellationToken) =>
    {
        document.Info.Title = "{ServiceName} Service API";
        document.Info.Version = "v1";
        return Task.CompletedTask;
    });
});

builder.Services.AddDaprClient();

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}

app.UseHttpsRedirection();
app.UseCors();
app.MapDefaultEndpoints();

// TODO: Add your endpoints here
app.MapGet("/api/{servicename}", () =>
{
    return Results.Ok(new { message = "Hello from {ServiceName} service!" });
})
.WithName("Get{ServiceName}");

app.Run();
EOF
```

### Step 3: Create Configuration Files

```bash
# appsettings.json
cat > appsettings.json << 'EOF'
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
EOF

# launchSettings.json (adjust ports as needed)
cat > Properties/launchSettings.json << 'EOF'
{
  "$schema": "https://json.schemastore.org/launchsettings.json",
  "profiles": {
    "https": {
      "commandName": "Project",
      "launchBrowser": true,
      "launchUrl": "scalar/v1",
      "applicationUrl": "https://localhost:{HTTPS_PORT};http://localhost:{HTTP_PORT}",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    }
  }
}
EOF

cd ../..
```

### Step 4: Add to Solution and AppHost

```bash
# Add to solution
dotnet sln add src/{SolutionName}.{ServiceName}/{SolutionName}.{ServiceName}.csproj

# Add ProjectReference to AppHost.csproj
# Edit src/{SolutionName}.AppHost/{SolutionName}.AppHost.csproj and add:
#   <ProjectReference Include="..\{SolutionName}.{ServiceName}\{SolutionName}.{ServiceName}.csproj" />
```

### Step 5: Register in AppHost.cs

Add to `src/{SolutionName}.AppHost/AppHost.cs`:

```csharp
// Add {ServiceName} service
var {servicename} = builder.AddProject<Projects.{SolutionName}_{ServiceName}>("{servicename}")
    .WithHttpHealthCheck("/health");

// If this service needs to call another service:
// .WithReference(api)
// .WaitFor(api)
```

### Step 6: Build and Test

```bash
dotnet build
aspire run
```
