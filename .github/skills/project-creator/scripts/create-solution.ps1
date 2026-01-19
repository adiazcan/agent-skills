#Requires -Version 7.0
<#
.SYNOPSIS
    Create a microservices solution with .NET Aspire + React

.DESCRIPTION
    Creates a complete microservices solution with:
    - .NET 10 Minimal API with OpenAPI + Scalar and Dapr
    - Vite + React + Zustand + Tailwind CSS frontend
    - .NET Aspire orchestration

.PARAMETER Name
    The solution name. Default: MySolution

.PARAMETER Path
    Root path for the solution. Default: current directory

.PARAMETER ApiHttp
    API HTTP port. Default: 5080

.PARAMETER ApiHttps
    API HTTPS port. Default: 7080

.PARAMETER Web
    Web dev server port. Default: 5173

.EXAMPLE
    .\create-solution.ps1 -Name "MyApp" -Path "C:\Projects"

.EXAMPLE
    .\create-solution.ps1 -Name "MyApp" -ApiHttp 5000 -ApiHttps 5001 -Web 3000
#>

param(
    [Parameter(Position = 0)]
    [Alias("n")]
    [string]$Name = "MySolution",

    [Parameter()]
    [Alias("p")]
    [string]$Path = ".",

    [Parameter()]
    [int]$ApiHttp = 5080,

    [Parameter()]
    [int]$ApiHttps = 7080,

    [Parameter()]
    [int]$Web = 5173
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host "[STEP] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

# Check prerequisites
Write-Step "Checking prerequisites..."

$dotnetVersion = & dotnet --version 2>$null
if (-not $dotnetVersion) {
    Write-ErrorMessage "dotnet CLI not found. Please install .NET 10 SDK."
    exit 1
}

$majorVersion = [int]($dotnetVersion -split '\.')[0]
if ($majorVersion -lt 10) {
    Write-Warning "Recommended .NET version is 10.x. Found: $dotnetVersion"
}

$nodeVersion = & node --version 2>$null
if (-not $nodeVersion) {
    Write-ErrorMessage "Node.js not found. Please install Node.js 20+."
    exit 1
}

$npmVersion = & npm --version 2>$null
if (-not $npmVersion) {
    Write-ErrorMessage "npm not found. Please install Node.js with npm."
    exit 1
}

$aspireVersion = & aspire --version 2>$null
if (-not $aspireVersion) {
    Write-Warning "Aspire CLI not found. Installing..."
    Invoke-RestMethod https://aspire.dev/install.ps1 | Invoke-Expression
}

Write-Step "Creating solution: $Name in $Path"

# Create root directory
$solutionPath = Join-Path $Path $Name
New-Item -ItemType Directory -Force -Path "$solutionPath\src" | Out-Null
Set-Location $solutionPath

# Create solution file
Write-Step "Creating .NET solution..."
& dotnet new sln -n $Name

# Create ServiceDefaults project
Write-Step "Creating ServiceDefaults project..."
$serviceDefaultsPath = "src\$Name.ServiceDefaults"
New-Item -ItemType Directory -Force -Path $serviceDefaultsPath | Out-Null

@"
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
"@ | Set-Content "$serviceDefaultsPath\$Name.ServiceDefaults.csproj"

@'
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
'@ | Set-Content "$serviceDefaultsPath\Extensions.cs"

# Create API project with 4+1 architecture
Write-Step "Creating API project with 4+1 architecture..."
$apiPath = "src\$Name.Api"
New-Item -ItemType Directory -Force -Path "$apiPath\Properties" | Out-Null
New-Item -ItemType Directory -Force -Path "$apiPath\Models" | Out-Null
New-Item -ItemType Directory -Force -Path "$apiPath\Services" | Out-Null
New-Item -ItemType Directory -Force -Path "$apiPath\Endpoints" | Out-Null
New-Item -ItemType Directory -Force -Path "$apiPath\Infrastructure" | Out-Null

@"
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
    <ProjectReference Include="..\$Name.ServiceDefaults\$Name.ServiceDefaults.csproj" />
  </ItemGroup>

</Project>
"@ | Set-Content "$apiPath\$Name.Api.csproj"

# Create model (Logical View)
@"
namespace $Name.Api.Models;

/// <summary>
/// Weather forecast model - Logical View (Domain Model)
/// </summary>
public record WeatherForecast(DateOnly Date, int TemperatureC, string? Summary)
{
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}
"@ | Set-Content "$apiPath\Models\WeatherForecast.cs"

# Create service interface
@"
namespace $Name.Api.Services;

using $Name.Api.Models;

/// <summary>
/// Weather service interface - Process View (Abstraction)
/// </summary>
public interface IWeatherService
{
    Task<IEnumerable<WeatherForecast>> GetForecastAsync(int days = 5);
}
"@ | Set-Content "$apiPath\Services\IWeatherService.cs"

# Create service implementation (Process View)
@"
namespace $Name.Api.Services;

using Dapr.Client;
using $Name.Api.Models;

/// <summary>
/// Weather service implementation - Process View (Business Logic)
/// </summary>
public class WeatherService : IWeatherService
{
    private readonly DaprClient _daprClient;
    private readonly ILogger<WeatherService> _logger;
    private static readonly string[] Summaries = { "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching" };

    public WeatherService(DaprClient daprClient, ILogger<WeatherService> logger)
    {
        _daprClient = daprClient;
        _logger = logger;
    }

    public Task<IEnumerable<WeatherForecast>> GetForecastAsync(int days = 5)
    {
        _logger.LogInformation("Generating weather forecast for {Days} days", days);
        
        var forecast = Enumerable.Range(1, days).Select(index =>
            new WeatherForecast(
                DateOnly.FromDateTime(DateTime.Now.AddDays(index)),
                Random.Shared.Next(-20, 55),
                Summaries[Random.Shared.Next(Summaries.Length)]
            ));
        
        return Task.FromResult(forecast);
    }
}
"@ | Set-Content "$apiPath\Services\WeatherService.cs"

# Create endpoints (Scenario View)
@"
namespace $Name.Api.Endpoints;

using $Name.Api.Services;

/// <summary>
/// Weather endpoints - Scenario View (Use Cases/API)
/// </summary>
public static class WeatherEndpoints
{
    public static void MapWeatherEndpoints(this WebApplication app)
    {
        app.MapGet("/api/weather", async (IWeatherService weatherService) =>
        {
            var forecast = await weatherService.GetForecastAsync();
            return Results.Ok(forecast);
        })
        .WithName("GetWeatherForecast")
        .WithTags("Weather");

        app.MapGet("/api/weather/{days:int}", async (int days, IWeatherService weatherService) =>
        {
            if (days < 1 || days > 14)
                return Results.BadRequest("Days must be between 1 and 14");
            
            var forecast = await weatherService.GetForecastAsync(days);
            return Results.Ok(forecast);
        })
        .WithName("GetWeatherForecastByDays")
        .WithTags("Weather");
    }
}
"@ | Set-Content "$apiPath\Endpoints\WeatherEndpoints.cs"

# Create Dapr infrastructure (Physical View)
@"
namespace $Name.Api.Infrastructure;

/// <summary>
/// Dapr State Store configuration - Physical View (Infrastructure)
/// </summary>
public static class DaprStateStore
{
    public const string StoreName = "statestore";
    
    public static class Keys
    {
        public const string WeatherCache = "weather-cache";
    }
}
"@ | Set-Content "$apiPath\Infrastructure\DaprStateStore.cs"

# Create Program.cs
@"
using $Name.Api.Endpoints;
using $Name.Api.Services;
using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

// Add service defaults (OpenTelemetry, health checks, service discovery)
builder.AddServiceDefaults();

// Add OpenAPI (native .NET 10 support)
builder.Services.AddOpenApi("v1", options =>
{
    options.AddDocumentTransformer((document, context, cancellationToken) =>
    {
        document.Info.Title = "$Name API";
        document.Info.Version = "v1";
        document.Info.Description = "Microservices API following Kruchten 4+1 architecture";
        return Task.CompletedTask;
    });
});

// Add Dapr
builder.Services.AddDaprClient();

// Add Services (Process View - Dependency Injection)
builder.Services.AddScoped<IWeatherService, WeatherService>();

// Add CORS for frontend
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins("http://localhost:$Web")
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

var app = builder.Build();

// Configure pipeline
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference(options =>
    {
        options.WithTitle("$Name API")
               .WithDefaultHttpClient(ScalarTarget.CSharp, ScalarClient.HttpClient);
    });
}

app.UseHttpsRedirection();
app.UseCors();

// Map default health endpoints
app.MapDefaultEndpoints();

// Map Weather endpoints (Scenario View)
app.MapWeatherEndpoints();

app.Run();
"@ | Set-Content "$apiPath\Program.cs"

@'
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
'@ | Set-Content "$apiPath\appsettings.json"

@'
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  }
}
'@ | Set-Content "$apiPath\appsettings.Development.json"

@"
{
  "`$schema": "https://json.schemastore.org/launchsettings.json",
  "profiles": {
    "http": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "launchUrl": "scalar/v1",
      "applicationUrl": "http://localhost:$ApiHttp",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    },
    "https": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "launchUrl": "scalar/v1",
      "applicationUrl": "https://localhost:$ApiHttps;http://localhost:$ApiHttp",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    }
  }
}
"@ | Set-Content "$apiPath\Properties\launchSettings.json"

# Create AppHost project
Write-Step "Creating AppHost project..."
$appHostPath = "src\$Name.AppHost"
New-Item -ItemType Directory -Force -Path "$appHostPath\Properties" | Out-Null

@"
<Project Sdk="Microsoft.NET.Sdk">

  <Sdk Name="Aspire.AppHost.Sdk" Version="13.0.0" />

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <UserSecretsId>$Name-apphost</UserSecretsId>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Aspire.Hosting.AppHost" Version="13.*" />
    <PackageReference Include="Aspire.Hosting.JavaScript" Version="13.*" />
    <PackageReference Include="CommunityToolkit.Aspire.Hosting.Dapr" Version="9.*" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\$Name.Api\$Name.Api.csproj" />
  </ItemGroup>

</Project>
"@ | Set-Content "$appHostPath\$Name.AppHost.csproj"

$appHostContent = @"
var builder = DistributedApplication.CreateBuilder(args);

// Add the API service with Dapr sidecar
var api = builder.AddProject<Projects.${Name}_Api>("api")
    .WithDaprSidecar()
    .WithHttpHealthCheck("/health");

// Add the web frontend (Vite + React)
var web = builder.AddViteApp("web", "../$Name.Web")
    .WithReference(api)
    .WaitFor(api);

builder.Build().Run();
"@
$appHostContent | Set-Content "$appHostPath\AppHost.cs"

@'
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Aspire.Hosting.Dcp": "Warning"
    }
  }
}
'@ | Set-Content "$appHostPath\appsettings.json"

@'
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Aspire.Hosting.Dcp": "Warning"
    }
  }
}
'@ | Set-Content "$appHostPath\appsettings.Development.json"

@'
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
'@ | Set-Content "$appHostPath\Properties\launchSettings.json"

# Create Web (React) project
Write-Step "Creating React frontend..."
$webPath = "src\$Name.Web"
$webDirs = @(
    "$webPath\src\api",
    "$webPath\src\store",
    "$webPath\src\components",
    "$webPath\src\pages",
    "$webPath\src\types",
    "$webPath\public"
)
foreach ($dir in $webDirs) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

$nameLower = $Name.ToLower()

@"
{
  "name": "$nameLower-web",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite --port $Web",
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
"@ | Set-Content "$webPath\package.json"

@"
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: $Web,
    proxy: {
      '/api': {
        target: process.env.VITE_API_URL || 'https://localhost:$ApiHttps',
        changeOrigin: true,
        secure: false,
      },
    },
  },
})
"@ | Set-Content "$webPath\vite.config.ts"

@'
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
'@ | Set-Content "$webPath\tailwind.config.js"

@'
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
'@ | Set-Content "$webPath\postcss.config.js"

@'
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
'@ | Set-Content "$webPath\tsconfig.json"

@'
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
'@ | Set-Content "$webPath\tsconfig.node.json"

"VITE_API_URL=https://localhost:$ApiHttps" | Set-Content "$webPath\.env"
"VITE_API_URL=https://localhost:$ApiHttps" | Set-Content "$webPath\.env.development"

@"
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>$Name</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
"@ | Set-Content "$webPath\index.html"

@'
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" aria-hidden="true" role="img" class="iconify iconify--logos" width="31.88" height="32" preserveAspectRatio="xMidYMid meet" viewBox="0 0 256 257"><defs><linearGradient id="IconifyId1813088fe1fbc01fb466" x1="-.828%" x2="57.636%" y1="7.652%" y2="78.411%"><stop offset="0%" stop-color="#41D1FF"></stop><stop offset="100%" stop-color="#BD34FE"></stop></linearGradient><linearGradient id="IconifyId1813088fe1fbc01fb467" x1="43.376%" x2="50.316%" y1="2.242%" y2="89.03%"><stop offset="0%" stop-color="#FFBD4F"></stop><stop offset="100%" stop-color="#FF980E"></stop></linearGradient></defs><path fill="url(#IconifyId1813088fe1fbc01fb466)" d="M255.153 37.938L134.897 252.976c-2.483 4.44-8.862 4.466-11.382.048L.875 37.958c-2.746-4.814 1.371-10.646 6.827-9.67l120.385 21.517a6.537 6.537 0 0 0 2.322-.004l117.867-21.483c5.438-.991 9.574 4.796 6.877 9.62Z"></path><path fill="url(#IconifyId1813088fe1fbc01fb467)" d="M185.432.063L96.44 17.501a3.268 3.268 0 0 0-2.634 3.014l-5.474 92.456a3.268 3.268 0 0 0 3.997 3.378l24.777-5.718c2.318-.535 4.413 1.507 3.936 3.838l-7.361 36.047c-.495 2.426 1.782 4.5 4.151 3.78l15.304-4.649c2.372-.72 4.652 1.36 4.15 3.788l-11.698 56.621c-.732 3.542 3.979 5.473 5.943 2.437l1.313-2.028l72.516-144.72c1.215-2.423-.88-5.186-3.54-4.672l-25.505 4.922c-2.396.462-4.435-1.77-3.759-4.114l16.646-57.705c.677-2.35-1.37-4.583-3.769-4.113Z"></path></svg>
'@ | Set-Content "$webPath\public\vite.svg"

# Source files
@'
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
'@ | Set-Content "$webPath\src\main.tsx"

@'
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
'@ | Set-Content "$webPath\src\App.tsx"

@'
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
'@ | Set-Content "$webPath\src\index.css"

@'
/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_URL: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
'@ | Set-Content "$webPath\src\vite-env.d.ts"

# Types
@'
export interface WeatherForecast {
  date: string
  temperatureC: number
  temperatureF: number
  summary: string | null
}
'@ | Set-Content "$webPath\src\types\weather.ts"

# Store
@'
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
'@ | Set-Content "$webPath\src\store\weatherStore.ts"

@'
export { useWeatherStore } from './weatherStore'
'@ | Set-Content "$webPath\src\store\index.ts"

# API
@'
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
'@ | Set-Content "$webPath\src\api\weatherApi.ts"

# Components
@"
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
        <p>&copy; {new Date().getFullYear()} $Name</p>
      </footer>
    </div>
  )
}
"@ | Set-Content "$webPath\src\components\Layout.tsx"

@"
import { Link, NavLink } from 'react-router-dom'

export default function Navbar() {
  return (
    <nav className="bg-blue-600 text-white shadow-lg">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          <Link to="/" className="text-xl font-bold">
            $Name
          </Link>
          <div className="flex space-x-4">
            <NavLink
              to="/"
              className={({ isActive }) =>
                ``px-3 py-2 rounded-md text-sm font-medium `${
                  isActive ? 'bg-blue-700' : 'hover:bg-blue-500'
                }``
              }
            >
              Home
            </NavLink>
            <NavLink
              to="/weather"
              className={({ isActive }) =>
                ``px-3 py-2 rounded-md text-sm font-medium `${
                  isActive ? 'bg-blue-700' : 'hover:bg-blue-500'
                }``
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
"@ | Set-Content "$webPath\src\components\Navbar.tsx"

@'
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
'@ | Set-Content "$webPath\src\components\WeatherCard.tsx"

# Pages
@"
import { Link } from 'react-router-dom'

export default function Home() {
  return (
    <div className="text-center">
      <h1 className="text-4xl font-bold text-gray-800 mb-4">
        Welcome to $Name
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
"@ | Set-Content "$webPath\src\pages\Home.tsx"

@'
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
'@ | Set-Content "$webPath\src\pages\Weather.tsx"

# Add projects to solution
Write-Step "Adding projects to solution..."
& dotnet sln add "src\$Name.ServiceDefaults\$Name.ServiceDefaults.csproj"
& dotnet sln add "src\$Name.Api\$Name.Api.csproj"
& dotnet sln add "src\$Name.AppHost\$Name.AppHost.csproj"

# Restore and build
Write-Step "Restoring .NET packages..."
& dotnet restore

Write-Step "Building solution..."
& dotnet build

# Install npm dependencies
Write-Step "Installing frontend dependencies..."
Push-Location "src\$Name.Web"
& npm install
Pop-Location

# Create README
@"
# $Name

A modern microservices solution with .NET 10 + React + Aspire orchestration.

## Prerequisites

- .NET 10 SDK
- Node.js 20+
- Aspire CLI (``aspire --version`` should show 13.x)
- Docker or Podman (for containers)

## Quick Start

``````powershell
# Run with Aspire (recommended)
aspire run
``````

This starts:
- **API**: https://localhost:$ApiHttps/scalar/v1
- **Web**: http://localhost:$Web
- **Aspire Dashboard**: Shown in terminal output

## Manual Run

``````powershell
# Terminal 1 - API
cd src\$Name.Api
dotnet run

# Terminal 2 - Web
cd src\$Name.Web
npm run dev
``````

## Project Structure

``````
$Name/
├── src/
│   ├── $Name.AppHost/       # Aspire orchestrator
│   ├── $Name.ServiceDefaults/   # Shared service config
│   ├── $Name.Api/           # .NET 10 Minimal API
│   └── $Name.Web/           # Vite + React frontend
└── $Name.sln
``````

## Ports

- API HTTP: $ApiHttp
- API HTTPS: $ApiHttps
- Web: $Web
"@ | Set-Content "README.md"

Write-Step "Solution created successfully!"
Write-Host ""
Write-Host "To run the solution:"
Write-Host "  cd $solutionPath"
Write-Host "  aspire run"
Write-Host ""
Write-Host "Endpoints:"
Write-Host "  API Docs:   https://localhost:$ApiHttps/scalar/v1"
Write-Host "  OpenAPI:    https://localhost:$ApiHttps/openapi/v1.json"
Write-Host "  Frontend:   http://localhost:$Web"
