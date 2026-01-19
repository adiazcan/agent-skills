#!/bin/bash
#
# create-solution.sh - Create a microservices solution with .NET Aspire + React
#
# Usage: ./create-solution.sh -n <SolutionName> [-p <RootPath>] [--api-http <port>] [--api-https <port>] [--web <port>]
#

set -e

# Default values
SOLUTION_NAME="MySolution"
ROOT_PATH="."
API_HTTP_PORT=5080
API_HTTPS_PORT=7080
WEB_PORT=5173

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            SOLUTION_NAME="$2"
            shift 2
            ;;
        -p|--path)
            ROOT_PATH="$2"
            shift 2
            ;;
        --api-http)
            API_HTTP_PORT="$2"
            shift 2
            ;;
        --api-https)
            API_HTTPS_PORT="$2"
            shift 2
            ;;
        --web)
            WEB_PORT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 -n <SolutionName> [-p <RootPath>] [--api-http <port>] [--api-https <port>] [--web <port>]"
            echo ""
            echo "Options:"
            echo "  -n, --name       Solution name (default: MySolution)"
            echo "  -p, --path       Root path for the solution (default: current directory)"
            echo "  --api-http       API HTTP port (default: 5080)"
            echo "  --api-https      API HTTPS port (default: 7080)"
            echo "  --web            Web dev server port (default: 5173)"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check prerequisites
print_step "Checking prerequisites..."

if ! command -v dotnet &> /dev/null; then
    print_error "dotnet CLI not found. Please install .NET 10 SDK."
    exit 1
fi

DOTNET_VERSION=$(dotnet --version | cut -d. -f1)
if [[ "$DOTNET_VERSION" -lt 10 ]]; then
    print_warning "Recommended .NET version is 10.x. Found: $(dotnet --version)"
fi

if ! command -v node &> /dev/null; then
    print_error "Node.js not found. Please install Node.js 20+."
    exit 1
fi

if ! command -v npm &> /dev/null; then
    print_error "npm not found. Please install Node.js with npm."
    exit 1
fi

if ! command -v aspire &> /dev/null; then
    print_warning "Aspire CLI not found. Installing..."
    curl -fsSL https://aspire.dev/install.sh | bash
fi

print_step "Creating solution: $SOLUTION_NAME in $ROOT_PATH"

# Create root directory
mkdir -p "$ROOT_PATH/$SOLUTION_NAME/src"
cd "$ROOT_PATH/$SOLUTION_NAME"

# Create solution file
print_step "Creating .NET solution..."
dotnet new sln -n "$SOLUTION_NAME"

# Create ServiceDefaults project
print_step "Creating ServiceDefaults project..."
mkdir -p "src/${SOLUTION_NAME}.ServiceDefaults"

cat > "src/${SOLUTION_NAME}.ServiceDefaults/${SOLUTION_NAME}.ServiceDefaults.csproj" << EOF
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

cat > "src/${SOLUTION_NAME}.ServiceDefaults/Extensions.cs" << 'EOF'
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

# Create API project with Kruchten 4+1 architecture
print_step "Creating API project with 4+1 architecture..."
mkdir -p "src/${SOLUTION_NAME}.Api/Properties"
mkdir -p "src/${SOLUTION_NAME}.Api/Models"          # Logical View
mkdir -p "src/${SOLUTION_NAME}.Api/Services"        # Process View
mkdir -p "src/${SOLUTION_NAME}.Api/Endpoints"       # Scenario View
mkdir -p "src/${SOLUTION_NAME}.Api/Infrastructure"  # Physical View

cat > "src/${SOLUTION_NAME}.Api/${SOLUTION_NAME}.Api.csproj" << EOF
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <RootNamespace>${SOLUTION_NAME}.Api</RootNamespace>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Dapr.AspNetCore" Version="1.*" />
    <PackageReference Include="Microsoft.AspNetCore.OpenApi" Version="10.*" />
    <PackageReference Include="Scalar.AspNetCore" Version="2.*" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\\${SOLUTION_NAME}.ServiceDefaults\\${SOLUTION_NAME}.ServiceDefaults.csproj" />
  </ItemGroup>

</Project>
EOF

# Models - Logical View
cat > "src/${SOLUTION_NAME}.Api/Models/WeatherForecast.cs" << EOF
namespace ${SOLUTION_NAME}.Api.Models;

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
EOF

# Services - Process View
cat > "src/${SOLUTION_NAME}.Api/Services/IWeatherService.cs" << EOF
using ${SOLUTION_NAME}.Api.Models;

namespace ${SOLUTION_NAME}.Api.Services;

/// <summary>
/// Weather service interface (Process View - Service Contract)
/// </summary>
public interface IWeatherService
{
    Task<IEnumerable<WeatherForecast>> GetForecastAsync(int days = 5);
}
EOF

cat > "src/${SOLUTION_NAME}.Api/Services/WeatherService.cs" << EOF
using ${SOLUTION_NAME}.Api.Models;

namespace ${SOLUTION_NAME}.Api.Services;

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
EOF

# Endpoints - Scenario View (Use Cases)
cat > "src/${SOLUTION_NAME}.Api/Endpoints/WeatherEndpoints.cs" << EOF
using ${SOLUTION_NAME}.Api.Services;

namespace ${SOLUTION_NAME}.Api.Endpoints;

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
EOF

# Infrastructure - Physical View
cat > "src/${SOLUTION_NAME}.Api/Infrastructure/DaprStateStore.cs" << EOF
using Dapr.Client;

namespace ${SOLUTION_NAME}.Api.Infrastructure;

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
EOF

# Program.cs - Application composition root
cat > "src/${SOLUTION_NAME}.Api/Program.cs" << EOF
using ${SOLUTION_NAME}.Api.Endpoints;
using ${SOLUTION_NAME}.Api.Services;
using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

// Add service defaults (OpenTelemetry, health checks, service discovery)
builder.AddServiceDefaults();

// Add OpenAPI (native .NET 10 support)
builder.Services.AddOpenApi("v1", options =>
{
    options.AddDocumentTransformer((document, context, cancellationToken) =>
    {
        document.Info.Title = "${SOLUTION_NAME} API";
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
        policy.WithOrigins("http://localhost:${WEB_PORT}")
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
        options.WithTitle("${SOLUTION_NAME} API")
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
EOF

cat > "src/${SOLUTION_NAME}.Api/appsettings.json" << 'EOF'
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

cat > "src/${SOLUTION_NAME}.Api/appsettings.Development.json" << 'EOF'
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  }
}
EOF

cat > "src/${SOLUTION_NAME}.Api/Properties/launchSettings.json" << EOF
{
  "\$schema": "https://json.schemastore.org/launchsettings.json",
  "profiles": {
    "http": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "launchUrl": "scalar/v1",
      "applicationUrl": "http://localhost:${API_HTTP_PORT}",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    },
    "https": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "launchUrl": "scalar/v1",
      "applicationUrl": "https://localhost:${API_HTTPS_PORT};http://localhost:${API_HTTP_PORT}",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    }
  }
}
EOF

# Create AppHost project
print_step "Creating AppHost project..."
mkdir -p "src/${SOLUTION_NAME}.AppHost/Properties"

cat > "src/${SOLUTION_NAME}.AppHost/${SOLUTION_NAME}.AppHost.csproj" << EOF
<Project Sdk="Microsoft.NET.Sdk">

  <Sdk Name="Aspire.AppHost.Sdk" Version="13.0.0" />

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <UserSecretsId>${SOLUTION_NAME}-apphost</UserSecretsId>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Aspire.Hosting.AppHost" Version="13.*" />
    <PackageReference Include="Aspire.Hosting.JavaScript" Version="13.*" />
    <PackageReference Include="CommunityToolkit.Aspire.Hosting.Dapr" Version="9.*" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\\${SOLUTION_NAME}.Api\\${SOLUTION_NAME}.Api.csproj" />
  </ItemGroup>

</Project>
EOF

cat > "src/${SOLUTION_NAME}.AppHost/AppHost.cs" << EOF
var builder = DistributedApplication.CreateBuilder(args);

// Add the API service with Dapr sidecar
var api = builder.AddProject<Projects.${SOLUTION_NAME}_Api>("api")
    .WithDaprSidecar()
    .WithHttpHealthCheck("/health");

// Add the web frontend (Vite + React)
var web = builder.AddViteApp("web", "../${SOLUTION_NAME}.Web")
    .WithReference(api)
    .WaitFor(api);

builder.Build().Run();
EOF

cat > "src/${SOLUTION_NAME}.AppHost/appsettings.json" << 'EOF'
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Aspire.Hosting.Dcp": "Warning"
    }
  }
}
EOF

cat > "src/${SOLUTION_NAME}.AppHost/appsettings.Development.json" << 'EOF'
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Aspire.Hosting.Dcp": "Warning"
    }
  }
}
EOF

cat > "src/${SOLUTION_NAME}.AppHost/Properties/launchSettings.json" << 'EOF'
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

# Create Web (React) project
print_step "Creating React frontend..."
mkdir -p "src/${SOLUTION_NAME}.Web/src/api"
mkdir -p "src/${SOLUTION_NAME}.Web/src/store"
mkdir -p "src/${SOLUTION_NAME}.Web/src/components"
mkdir -p "src/${SOLUTION_NAME}.Web/src/pages"
mkdir -p "src/${SOLUTION_NAME}.Web/src/types"
mkdir -p "src/${SOLUTION_NAME}.Web/public"

# Package.json
cat > "src/${SOLUTION_NAME}.Web/package.json" << EOF
{
  "name": "${SOLUTION_NAME,,}-web",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite --port ${WEB_PORT}",
    "build": "tsc && vite build",
    "lint": "eslint . --ext ts,tsx --report-unused-disable-directives --max-warnings 0",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "react-router-dom": "^7.0.0",
    "zustand": "^5.0.0",
    "@tanstack/react-query": "^5.0.0",
    "axios": "^1.7.0"
  },
  "devDependencies": {
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "@vitejs/plugin-react": "^4.0.0",
    "autoprefixer": "^10.4.0",
    "postcss": "^8.4.0",
    "tailwindcss": "^3.4.0",
    "typescript": "^5.5.0",
    "vite": "^6.0.0"
  }
}
EOF

# Vite config
cat > "src/${SOLUTION_NAME}.Web/vite.config.ts" << EOF
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: ${WEB_PORT},
    proxy: {
      '/api': {
        target: process.env.VITE_API_URL || 'https://localhost:${API_HTTPS_PORT}',
        changeOrigin: true,
        secure: false,
      },
    },
  },
})
EOF

# Tailwind config
cat > "src/${SOLUTION_NAME}.Web/tailwind.config.js" << 'EOF'
/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
EOF

# PostCSS config
cat > "src/${SOLUTION_NAME}.Web/postcss.config.js" << 'EOF'
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
EOF

# TypeScript config
cat > "src/${SOLUTION_NAME}.Web/tsconfig.json" << 'EOF'
{
  "compilerOptions": {
    "target": "ES2022",
    "useDefineForClassFields": true,
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true
  },
  "include": ["src"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
EOF

cat > "src/${SOLUTION_NAME}.Web/tsconfig.node.json" << 'EOF'
{
  "compilerOptions": {
    "composite": true,
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowSyntheticDefaultImports": true,
    "strict": true
  },
  "include": ["vite.config.ts"]
}
EOF

# Environment files
cat > "src/${SOLUTION_NAME}.Web/.env" << EOF
VITE_API_URL=https://localhost:${API_HTTPS_PORT}
EOF

cat > "src/${SOLUTION_NAME}.Web/.env.development" << EOF
VITE_API_URL=https://localhost:${API_HTTPS_PORT}
EOF

# Index HTML
cat > "src/${SOLUTION_NAME}.Web/index.html" << EOF
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>${SOLUTION_NAME}</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
EOF

# Vite SVG
cat > "src/${SOLUTION_NAME}.Web/public/vite.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" aria-hidden="true" role="img" class="iconify iconify--logos" width="31.88" height="32" preserveAspectRatio="xMidYMid meet" viewBox="0 0 256 257"><defs><linearGradient id="IconifyId1813088fe1fbc01fb466" x1="-.828%" x2="57.636%" y1="7.652%" y2="78.411%"><stop offset="0%" stop-color="#41D1FF"></stop><stop offset="100%" stop-color="#BD34FE"></stop></linearGradient><linearGradient id="IconifyId1813088fe1fbc01fb467" x1="43.376%" x2="50.316%" y1="2.242%" y2="89.03%"><stop offset="0%" stop-color="#FFBD4F"></stop><stop offset="100%" stop-color="#FF980E"></stop></linearGradient></defs><path fill="url(#IconifyId1813088fe1fbc01fb466)" d="M255.153 37.938L134.897 252.976c-2.483 4.44-8.862 4.466-11.382.048L.875 37.958c-2.746-4.814 1.371-10.646 6.827-9.67l120.385 21.517a6.537 6.537 0 0 0 2.322-.004l117.867-21.483c5.438-.991 9.574 4.796 6.877 9.62Z"></path><path fill="url(#IconifyId1813088fe1fbc01fb467)" d="M185.432.063L96.44 17.501a3.268 3.268 0 0 0-2.634 3.014l-5.474 92.456a3.268 3.268 0 0 0 3.997 3.378l24.777-5.718c2.318-.535 4.413 1.507 3.936 3.838l-7.361 36.047c-.495 2.426 1.782 4.5 4.151 3.78l15.304-4.649c2.372-.72 4.652 1.36 4.15 3.788l-11.698 56.621c-.732 3.542 3.979 5.473 5.943 2.437l1.313-2.028l72.516-144.72c1.215-2.423-.88-5.186-3.54-4.672l-25.505 4.922c-2.396.462-4.435-1.77-3.759-4.114l16.646-57.705c.677-2.35-1.37-4.583-3.769-4.113Z"></path></svg>
EOF

# Main entry point
cat > "src/${SOLUTION_NAME}.Web/src/main.tsx" << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import App from './App'
import './index.css'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5,
      retry: 1,
    },
  },
})

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </QueryClientProvider>
  </React.StrictMode>
)
EOF

# App component
cat > "src/${SOLUTION_NAME}.Web/src/App.tsx" << 'EOF'
import { Routes, Route } from 'react-router-dom'
import Layout from './components/Layout'
import Home from './pages/Home'
import Weather from './pages/Weather'

function App() {
  return (
    <Routes>
      <Route path="/" element={<Layout />}>
        <Route index element={<Home />} />
        <Route path="weather" element={<Weather />} />
      </Route>
    </Routes>
  )
}

export default App
EOF

# Index CSS
cat > "src/${SOLUTION_NAME}.Web/src/index.css" << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  font-family: Inter, system-ui, Avenir, Helvetica, Arial, sans-serif;
  line-height: 1.5;
  font-weight: 400;
}

body {
  @apply bg-gray-50 text-gray-900 min-h-screen;
}
EOF

# Vite env types
cat > "src/${SOLUTION_NAME}.Web/src/vite-env.d.ts" << 'EOF'
/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_URL: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
EOF

# Types
cat > "src/${SOLUTION_NAME}.Web/src/types/weather.ts" << 'EOF'
export interface WeatherForecast {
  date: string
  temperatureC: number
  temperatureF: number
  summary: string | null
}
EOF

# Store
cat > "src/${SOLUTION_NAME}.Web/src/store/weatherStore.ts" << 'EOF'
import { create } from 'zustand'
import { WeatherForecast } from '../types/weather'

interface WeatherState {
  forecasts: WeatherForecast[]
  isLoading: boolean
  error: string | null
  setForecasts: (forecasts: WeatherForecast[]) => void
  setLoading: (loading: boolean) => void
  setError: (error: string | null) => void
  clearForecasts: () => void
}

export const useWeatherStore = create<WeatherState>((set) => ({
  forecasts: [],
  isLoading: false,
  error: null,
  setForecasts: (forecasts) => set({ forecasts, error: null }),
  setLoading: (isLoading) => set({ isLoading }),
  setError: (error) => set({ error, isLoading: false }),
  clearForecasts: () => set({ forecasts: [], error: null }),
}))
EOF

cat > "src/${SOLUTION_NAME}.Web/src/store/index.ts" << 'EOF'
export { useWeatherStore } from './weatherStore'
EOF

# API
cat > "src/${SOLUTION_NAME}.Web/src/api/weatherApi.ts" << 'EOF'
import axios from 'axios'
import { WeatherForecast } from '../types/weather'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || '',
  headers: {
    'Content-Type': 'application/json',
  },
})

export const weatherApi = {
  getForecasts: async (): Promise<WeatherForecast[]> => {
    const response = await api.get<WeatherForecast[]>('/api/weather')
    return response.data
  },
}
EOF

# Components
cat > "src/${SOLUTION_NAME}.Web/src/components/Layout.tsx" << EOF
import { Outlet } from 'react-router-dom'
import Navbar from './Navbar'

export default function Layout() {
  return (
    <div className="min-h-screen flex flex-col">
      <Navbar />
      <main className="flex-1 container mx-auto px-4 py-8">
        <Outlet />
      </main>
      <footer className="bg-gray-800 text-white py-4 text-center">
        <p>&copy; {new Date().getFullYear()} ${SOLUTION_NAME}</p>
      </footer>
    </div>
  )
}
EOF

cat > "src/${SOLUTION_NAME}.Web/src/components/Navbar.tsx" << EOF
import { Link, NavLink } from 'react-router-dom'

export default function Navbar() {
  return (
    <nav className="bg-blue-600 text-white shadow-lg">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          <Link to="/" className="text-xl font-bold">
            ${SOLUTION_NAME}
          </Link>
          <div className="flex space-x-4">
            <NavLink
              to="/"
              className={({ isActive }) =>
                \`px-3 py-2 rounded-md text-sm font-medium \${
                  isActive ? 'bg-blue-700' : 'hover:bg-blue-500'
                }\`
              }
            >
              Home
            </NavLink>
            <NavLink
              to="/weather"
              className={({ isActive }) =>
                \`px-3 py-2 rounded-md text-sm font-medium \${
                  isActive ? 'bg-blue-700' : 'hover:bg-blue-500'
                }\`
              }
            >
              Weather
            </NavLink>
          </div>
        </div>
      </div>
    </nav>
  )
}
EOF

cat > "src/${SOLUTION_NAME}.Web/src/components/WeatherCard.tsx" << 'EOF'
import { WeatherForecast } from '../types/weather'

interface WeatherCardProps {
  forecast: WeatherForecast
}

export default function WeatherCard({ forecast }: WeatherCardProps) {
  return (
    <div className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
      <div className="text-sm text-gray-500 mb-2">
        {new Date(forecast.date).toLocaleDateString('en-US', {
          weekday: 'long',
          month: 'short',
          day: 'numeric',
        })}
      </div>
      <div className="text-3xl font-bold text-blue-600 mb-2">
        {forecast.temperatureC}°C
        <span className="text-lg text-gray-400 ml-2">
          / {forecast.temperatureF}°F
        </span>
      </div>
      <div className="text-gray-700">{forecast.summary}</div>
    </div>
  )
}
EOF

# Pages
cat > "src/${SOLUTION_NAME}.Web/src/pages/Home.tsx" << EOF
import { Link } from 'react-router-dom'

export default function Home() {
  return (
    <div className="text-center">
      <h1 className="text-4xl font-bold text-gray-800 mb-4">
        Welcome to ${SOLUTION_NAME}
      </h1>
      <p className="text-xl text-gray-600 mb-8">
        A modern microservices solution with .NET and React
      </p>
      <Link
        to="/weather"
        className="inline-block bg-blue-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-blue-700 transition-colors"
      >
        View Weather Forecast
      </Link>
    </div>
  )
}
EOF

cat > "src/${SOLUTION_NAME}.Web/src/pages/Weather.tsx" << 'EOF'
import { useQuery } from '@tanstack/react-query'
import { weatherApi } from '../api/weatherApi'
import { useWeatherStore } from '../store'
import WeatherCard from '../components/WeatherCard'
import { useEffect } from 'react'

export default function Weather() {
  const { setForecasts, setLoading, setError } = useWeatherStore()

  const { data, isLoading, error } = useQuery({
    queryKey: ['weather'],
    queryFn: weatherApi.getForecasts,
  })

  useEffect(() => {
    setLoading(isLoading)
    if (data) {
      setForecasts(data)
    }
    if (error) {
      setError(error instanceof Error ? error.message : 'Failed to fetch weather')
    }
  }, [data, isLoading, error, setForecasts, setLoading, setError])

  if (isLoading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
        <p>Error loading weather data. Make sure the API is running.</p>
        <p className="text-sm mt-2">API URL: {import.meta.env.VITE_API_URL}</p>
      </div>
    )
  }

  return (
    <div>
      <h1 className="text-3xl font-bold text-gray-800 mb-6">Weather Forecast</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-4">
        {data?.map((forecast, index) => (
          <WeatherCard key={index} forecast={forecast} />
        ))}
      </div>
    </div>
  )
}
EOF

# Add projects to solution
print_step "Adding projects to solution..."
dotnet sln add "src/${SOLUTION_NAME}.ServiceDefaults/${SOLUTION_NAME}.ServiceDefaults.csproj"
dotnet sln add "src/${SOLUTION_NAME}.Api/${SOLUTION_NAME}.Api.csproj"
dotnet sln add "src/${SOLUTION_NAME}.AppHost/${SOLUTION_NAME}.AppHost.csproj"

# Restore and build .NET projects
print_step "Restoring .NET packages..."
dotnet restore

print_step "Building solution..."
dotnet build

# Install npm dependencies
print_step "Installing frontend dependencies..."
cd "src/${SOLUTION_NAME}.Web"
npm install
cd ../..

# Create README
cat > "README.md" << EOF
# ${SOLUTION_NAME}

A modern microservices solution with .NET 10 + React + Aspire orchestration.

## Prerequisites

- .NET 10 SDK
- Node.js 20+
- Aspire CLI (\`aspire --version\` should show 13.x)
- Docker or Podman (for containers)

## Quick Start

\`\`\`bash
# Run with Aspire (recommended)
aspire run
\`\`\`

This starts:
- **API**: https://localhost:${API_HTTPS_PORT}/scalar/v1
- **Web**: http://localhost:${WEB_PORT}
- **Aspire Dashboard**: Shown in terminal output

## Manual Run

\`\`\`bash
# Terminal 1 - API
cd src/${SOLUTION_NAME}.Api
dotnet run

# Terminal 2 - Web
cd src/${SOLUTION_NAME}.Web
npm run dev
\`\`\`

## Project Structure

\`\`\`
${SOLUTION_NAME}/
├── src/
│   ├── ${SOLUTION_NAME}.AppHost/       # Aspire orchestrator
│   ├── ${SOLUTION_NAME}.ServiceDefaults/   # Shared service config
│   ├── ${SOLUTION_NAME}.Api/           # .NET 10 Minimal API
│   └── ${SOLUTION_NAME}.Web/           # Vite + React frontend
└── ${SOLUTION_NAME}.sln
\`\`\`

## Ports

- API HTTP: ${API_HTTP_PORT}
- API HTTPS: ${API_HTTPS_PORT}
- Web: ${WEB_PORT}
EOF

print_step "Solution created successfully!"
echo ""
echo "To run the solution:"
echo "  cd $ROOT_PATH/$SOLUTION_NAME"
echo "  aspire run"
echo ""
echo "Endpoints:"
echo "  API Docs:   https://localhost:${API_HTTPS_PORT}/scalar/v1"
echo "  OpenAPI:    https://localhost:${API_HTTPS_PORT}/openapi/v1.json"
echo "  Frontend:   http://localhost:${WEB_PORT}"
