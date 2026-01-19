#Requires -Version 7.0
<#
.SYNOPSIS
    Add a new microservice to an existing solution

.DESCRIPTION
    Creates a new .NET 10 Minimal API microservice and registers it with the Aspire AppHost.

.PARAMETER Name
    The service name (required, e.g., 'Orders', 'Products')

.PARAMETER Solution
    Path to solution root. Default: current directory

.PARAMETER Http
    HTTP port. Default: auto-assigned

.PARAMETER Https
    HTTPS port. Default: auto-assigned

.EXAMPLE
    .\add-microservice.ps1 -Name "Orders"

.EXAMPLE
    .\add-microservice.ps1 -Name "Products" -Solution "C:\Projects\MySolution" -Http 5200 -Https 7200
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [Alias("n")]
    [string]$Name,

    [Parameter()]
    [Alias("s")]
    [string]$Solution = ".",

    [Parameter()]
    [int]$Http = 0,

    [Parameter()]
    [int]$Https = 0
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

# Find solution file
Set-Location $Solution
$solutionFile = Get-ChildItem -Filter "*.sln" | Select-Object -First 1

if (-not $solutionFile) {
    Write-ErrorMessage "No .sln file found in $Solution"
    exit 1
}

$solutionName = $solutionFile.BaseName
Write-Step "Adding microservice '$Name' to solution '$solutionName'"

# Determine project name
$projectName = "$solutionName.$Name"
$projectPath = "src\$projectName"

# Check if project already exists
if (Test-Path $projectPath) {
    Write-ErrorMessage "Project $projectName already exists at $projectPath"
    exit 1
}

# Set default ports if not provided
if ($Http -eq 0) {
    $Http = Get-Random -Minimum 5100 -Maximum 5199
}

if ($Https -eq 0) {
    $Https = $Http + 1000
}

# Create project directory with 4+1 architecture folders
Write-Step "Creating project directory with 4+1 architecture..."
New-Item -ItemType Directory -Force -Path "$projectPath\Properties" | Out-Null
New-Item -ItemType Directory -Force -Path "$projectPath\Models" | Out-Null
New-Item -ItemType Directory -Force -Path "$projectPath\Services" | Out-Null
New-Item -ItemType Directory -Force -Path "$projectPath\Endpoints" | Out-Null
New-Item -ItemType Directory -Force -Path "$projectPath\Infrastructure" | Out-Null

# Create project file
Write-Step "Creating project file..."
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
    <ProjectReference Include="..\$solutionName.ServiceDefaults\$solutionName.ServiceDefaults.csproj" />
  </ItemGroup>

</Project>
"@ | Set-Content "$projectPath\$projectName.csproj"

# Create model
Write-Step "Creating model (Logical View)..."
$serviceNameLower = $Name.ToLower()

@"
namespace $projectName.Models;

/// <summary>
/// $Name entity - Logical View (Domain Model)
/// </summary>
public record ${Name}Item
{
    public string Id { get; init; } = Guid.NewGuid().ToString();
    public string Name { get; init; } = string.Empty;
    public DateTime CreatedAt { get; init; } = DateTime.UtcNow;
}
"@ | Set-Content "$projectPath\Models\${Name}Item.cs"

# Create service interface
Write-Step "Creating service interface..."
@"
namespace $projectName.Services;

using $projectName.Models;

/// <summary>
/// $Name service interface - Process View (Abstraction)
/// </summary>
public interface I${Name}Service
{
    Task<IEnumerable<${Name}Item>> GetAllAsync();
    Task<${Name}Item?> GetByIdAsync(string id);
    Task<${Name}Item> CreateAsync(${Name}Item item);
    Task<bool> DeleteAsync(string id);
}
"@ | Set-Content "$projectPath\Services\I${Name}Service.cs"

# Create service implementation
Write-Step "Creating service implementation (Process View)..."
@"
namespace $projectName.Services;

using Dapr.Client;
using $projectName.Models;

/// <summary>
/// $Name service implementation - Process View (Business Logic)
/// </summary>
public class ${Name}Service : I${Name}Service
{
    private readonly DaprClient _daprClient;
    private readonly ILogger<${Name}Service> _logger;
    private const string StateStoreName = "statestore";
    private const string StateKey = "${serviceNameLower}-items";

    public ${Name}Service(DaprClient daprClient, ILogger<${Name}Service> logger)
    {
        _daprClient = daprClient;
        _logger = logger;
    }

    public async Task<IEnumerable<${Name}Item>> GetAllAsync()
    {
        try
        {
            var items = await _daprClient.GetStateAsync<List<${Name}Item>>(StateStoreName, StateKey);
            return items ?? new List<${Name}Item>();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error getting all $Name items");
            return new List<${Name}Item>();
        }
    }

    public async Task<${Name}Item?> GetByIdAsync(string id)
    {
        var items = await GetAllAsync();
        return items.FirstOrDefault(x => x.Id == id);
    }

    public async Task<${Name}Item> CreateAsync(${Name}Item item)
    {
        var items = (await GetAllAsync()).ToList();
        items.Add(item);
        await _daprClient.SaveStateAsync(StateStoreName, StateKey, items);
        _logger.LogInformation("Created $Name item {Id}", item.Id);
        return item;
    }

    public async Task<bool> DeleteAsync(string id)
    {
        var items = (await GetAllAsync()).ToList();
        var item = items.FirstOrDefault(x => x.Id == id);
        if (item == null) return false;
        
        items.Remove(item);
        await _daprClient.SaveStateAsync(StateStoreName, StateKey, items);
        _logger.LogInformation("Deleted $Name item {Id}", id);
        return true;
    }
}
"@ | Set-Content "$projectPath\Services\${Name}Service.cs"

# Create endpoints
Write-Step "Creating endpoints (Scenario View)..."
@"
namespace $projectName.Endpoints;

using $projectName.Models;
using $projectName.Services;

/// <summary>
/// $Name endpoints - Scenario View (Use Cases/API)
/// </summary>
public static class ${Name}Endpoints
{
    public static void Map${Name}Endpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/$serviceNameLower")
            .WithTags("$Name");

        group.MapGet("/", async (I${Name}Service service) =>
        {
            var items = await service.GetAllAsync();
            return Results.Ok(items);
        })
        .WithName("GetAll${Name}s")
        .WithDescription("Get all $Name items");

        group.MapGet("/{id}", async (string id, I${Name}Service service) =>
        {
            var item = await service.GetByIdAsync(id);
            return item is not null ? Results.Ok(item) : Results.NotFound();
        })
        .WithName("Get${Name}ById")
        .WithDescription("Get a $Name item by ID");

        group.MapPost("/", async (${Name}Item item, I${Name}Service service) =>
        {
            var created = await service.CreateAsync(item);
            return Results.Created($"/api/$serviceNameLower/{created.Id}", created);
        })
        .WithName("Create${Name}")
        .WithDescription("Create a new $Name item");

        group.MapDelete("/{id}", async (string id, I${Name}Service service) =>
        {
            var deleted = await service.DeleteAsync(id);
            return deleted ? Results.NoContent() : Results.NotFound();
        })
        .WithName("Delete${Name}")
        .WithDescription("Delete a $Name item");
    }
}
"@ | Set-Content "$projectPath\Endpoints\${Name}Endpoints.cs"

# Create Dapr state store helper (Physical/Infrastructure View)
Write-Step "Creating infrastructure (Physical View)..."
@"
namespace $projectName.Infrastructure;

/// <summary>
/// Dapr State Store configuration - Physical View (Infrastructure)
/// </summary>
public static class DaprStateStore
{
    public const string StoreName = "statestore";
    
    public static class Keys
    {
        public const string ${Name}Items = "${serviceNameLower}-items";
    }
}
"@ | Set-Content "$projectPath\Infrastructure\DaprStateStore.cs"

# Create Program.cs
Write-Step "Creating Program.cs..."
@"
using $projectName.Endpoints;
using $projectName.Services;

var builder = WebApplication.CreateBuilder(args);

// Add service defaults (OpenTelemetry, health checks, service discovery)
builder.AddServiceDefaults();

// Add OpenAPI
builder.Services.AddOpenApi("v1", options =>
{
    options.AddDocumentTransformer((document, context, cancellationToken) =>
    {
        document.Info.Title = "$Name Service API";
        document.Info.Version = "v1";
        return Task.CompletedTask;
    });
});

// Add Dapr
builder.Services.AddDaprClient();

// Add Services (Process View - Dependency Injection)
builder.Services.AddScoped<I${Name}Service, ${Name}Service>();

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

var app = builder.Build();

// Configure pipeline
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference();
}

app.UseHttpsRedirection();
app.UseCors();

// Map default health endpoints
app.MapDefaultEndpoints();

// Map $Name endpoints (Scenario View)
app.Map${Name}Endpoints();

app.Run();
"@ | Set-Content "$projectPath\Program.cs"

# Create appsettings.json
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
'@ | Set-Content "$projectPath\appsettings.json"

# Create appsettings.Development.json
@'
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  }
}
'@ | Set-Content "$projectPath\appsettings.Development.json"

# Create launchSettings.json
@"
{
  "`$schema": "https://json.schemastore.org/launchsettings.json",
  "profiles": {
    "http": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "launchUrl": "scalar/v1",
      "applicationUrl": "http://localhost:$Http",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    },
    "https": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "launchUrl": "scalar/v1",
      "applicationUrl": "https://localhost:$Https;http://localhost:$Http",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    }
  }
}
"@ | Set-Content "$projectPath\Properties\launchSettings.json"

# Add project to solution
Write-Step "Adding project to solution..."
& dotnet sln add "$projectPath\$projectName.csproj"

# Add project reference to AppHost
Write-Step "Adding project reference to AppHost..."
$appHostCsproj = "src\$solutionName.AppHost\$solutionName.AppHost.csproj"

if (Test-Path $appHostCsproj) {
    # Read and update AppHost csproj
    $csprojContent = Get-Content $appHostCsproj -Raw
    $newReference = "    <ProjectReference Include=`"..\$projectName\$projectName.csproj`" />"
    
    # Find the last ProjectReference and add after it
    if ($csprojContent -match '(<ProjectReference[^>]+/>)\s*(</ItemGroup>)') {
        $csprojContent = $csprojContent -replace '(<ProjectReference[^>]+/>)(\s*)(</ItemGroup>)', "`$1`$2$newReference`$2`$3"
        $csprojContent | Set-Content $appHostCsproj -NoNewline
    }
    
    Write-Step "Updating AppHost.cs..."
    $appHostCs = "src\$solutionName.AppHost\AppHost.cs"
    
    if (Test-Path $appHostCs) {
        $appHostContent = Get-Content $appHostCs -Raw
        $serviceVar = $Name.ToLower()
        $projectClass = "${solutionName}_$Name"
        
        $newServiceCode = @"

// Add $Name service with Dapr sidecar
var $serviceVar = builder.AddProject<Projects.$projectClass>("$serviceVar")
    .WithDaprSidecar()
    .WithHttpHealthCheck("/health");

"@
        
        # Insert before builder.Build().Run();
        $appHostContent = $appHostContent -replace '(builder\.Build\(\)\.Run\(\);)', "$newServiceCode`$1"
        $appHostContent | Set-Content $appHostCs -NoNewline
    }
    
    Write-Warning "Please review AppHost.cs and add .WithReference() calls if this service needs to communicate with others."
}

# Build the new project
Write-Step "Building new project..."
& dotnet build "$projectPath\$projectName.csproj"

Write-Step "Microservice '$Name' added successfully!"
Write-Host ""
Write-Host "Project location: $projectPath"
Write-Host "HTTP port: $Http"
Write-Host "HTTPS port: $Https"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Add your domain models and endpoints to Program.cs"
Write-Host "  2. Update AppHost.cs if this service needs references to other services"
Write-Host "  3. Run 'aspire run' to test the new service"
