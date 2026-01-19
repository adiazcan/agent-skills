#!/bin/bash
#
# add-microservice.sh - Add a new microservice to an existing solution
#
# Usage: ./add-microservice.sh -n <ServiceName> [-s <SolutionPath>] [--http <port>] [--https <port>]
#

set -e

# Default values
SERVICE_NAME=""
SOLUTION_PATH="."
HTTP_PORT=""
HTTPS_PORT=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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
            SERVICE_NAME="$2"
            shift 2
            ;;
        -s|--solution)
            SOLUTION_PATH="$2"
            shift 2
            ;;
        --http)
            HTTP_PORT="$2"
            shift 2
            ;;
        --https)
            HTTPS_PORT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 -n <ServiceName> [-s <SolutionPath>] [--http <port>] [--https <port>]"
            echo ""
            echo "Options:"
            echo "  -n, --name       Service name (required, e.g., 'Orders', 'Products')"
            echo "  -s, --solution   Path to solution root (default: current directory)"
            echo "  --http           HTTP port (default: auto-assigned)"
            echo "  --https          HTTPS port (default: auto-assigned)"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$SERVICE_NAME" ]]; then
    print_error "Service name is required. Use -n <ServiceName>"
    exit 1
fi

# Find solution file
cd "$SOLUTION_PATH"
SOLUTION_FILE=$(find . -maxdepth 1 -name "*.sln" | head -1)

if [[ -z "$SOLUTION_FILE" ]]; then
    print_error "No .sln file found in $SOLUTION_PATH"
    exit 1
fi

SOLUTION_NAME=$(basename "$SOLUTION_FILE" .sln)
print_step "Adding microservice '$SERVICE_NAME' to solution '$SOLUTION_NAME'"

# Determine project name
PROJECT_NAME="${SOLUTION_NAME}.${SERVICE_NAME}"
PROJECT_PATH="src/${PROJECT_NAME}"

# Check if project already exists
if [[ -d "$PROJECT_PATH" ]]; then
    print_error "Project $PROJECT_NAME already exists at $PROJECT_PATH"
    exit 1
fi

# Set default ports if not provided
if [[ -z "$HTTP_PORT" ]]; then
    # Generate random port between 5100-5199
    HTTP_PORT=$((5100 + RANDOM % 100))
fi

if [[ -z "$HTTPS_PORT" ]]; then
    HTTPS_PORT=$((HTTP_PORT + 1000))
fi

# Create project directory with 4+1 architecture
print_step "Creating project with Kruchten 4+1 architecture..."
mkdir -p "$PROJECT_PATH/Properties"
mkdir -p "$PROJECT_PATH/Models"          # Logical View
mkdir -p "$PROJECT_PATH/Services"        # Process View
mkdir -p "$PROJECT_PATH/Endpoints"       # Scenario View
mkdir -p "$PROJECT_PATH/Infrastructure"  # Physical View

# Create project file
print_step "Creating project file..."
cat > "$PROJECT_PATH/${PROJECT_NAME}.csproj" << EOF
<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <RootNamespace>${PROJECT_NAME}</RootNamespace>
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

# Create architecture files
print_step "Creating 4+1 architecture files..."
SERVICE_NAME_LOWER=$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]')

# Models - Logical View
cat > "$PROJECT_PATH/Models/${SERVICE_NAME}Model.cs" << EOF
namespace ${PROJECT_NAME}.Models;

/// <summary>
/// ${SERVICE_NAME} domain model (Logical View)
/// </summary>
public record ${SERVICE_NAME}Item(
    Guid Id,
    string Name,
    DateTime CreatedAt)
{
    public static ${SERVICE_NAME}Item Create(string name) =>
        new(Guid.NewGuid(), name, DateTime.UtcNow);
}
EOF

# Services - Process View
cat > "$PROJECT_PATH/Services/I${SERVICE_NAME}Service.cs" << EOF
using ${PROJECT_NAME}.Models;

namespace ${PROJECT_NAME}.Services;

/// <summary>
/// ${SERVICE_NAME} service interface (Process View - Service Contract)
/// </summary>
public interface I${SERVICE_NAME}Service
{
    Task<IEnumerable<${SERVICE_NAME}Item>> GetAllAsync();
    Task<${SERVICE_NAME}Item?> GetByIdAsync(Guid id);
    Task<${SERVICE_NAME}Item> CreateAsync(string name);
}
EOF

cat > "$PROJECT_PATH/Services/${SERVICE_NAME}Service.cs" << EOF
using ${PROJECT_NAME}.Models;

namespace ${PROJECT_NAME}.Services;

/// <summary>
/// ${SERVICE_NAME} service implementation (Process View - Business Logic)
/// </summary>
public class ${SERVICE_NAME}Service : I${SERVICE_NAME}Service
{
    private readonly List<${SERVICE_NAME}Item> _items = [];

    public Task<IEnumerable<${SERVICE_NAME}Item>> GetAllAsync()
    {
        return Task.FromResult<IEnumerable<${SERVICE_NAME}Item>>(_items);
    }

    public Task<${SERVICE_NAME}Item?> GetByIdAsync(Guid id)
    {
        var item = _items.FirstOrDefault(x => x.Id == id);
        return Task.FromResult(item);
    }

    public Task<${SERVICE_NAME}Item> CreateAsync(string name)
    {
        var item = ${SERVICE_NAME}Item.Create(name);
        _items.Add(item);
        return Task.FromResult(item);
    }
}
EOF

# Endpoints - Scenario View
cat > "$PROJECT_PATH/Endpoints/${SERVICE_NAME}Endpoints.cs" << EOF
using ${PROJECT_NAME}.Models;
using ${PROJECT_NAME}.Services;

namespace ${PROJECT_NAME}.Endpoints;

/// <summary>
/// ${SERVICE_NAME} API endpoints (Scenario View - Use Cases)
/// </summary>
public static class ${SERVICE_NAME}Endpoints
{
    public static void Map${SERVICE_NAME}Endpoints(this WebApplication app)
    {
        var group = app.MapGroup("/api/${SERVICE_NAME_LOWER}")
            .WithTags("${SERVICE_NAME}");

        group.MapGet("/", async (I${SERVICE_NAME}Service service) =>
        {
            var items = await service.GetAllAsync();
            return Results.Ok(items);
        })
        .WithName("GetAll${SERVICE_NAME}")
        .WithDescription("Get all ${SERVICE_NAME} items");

        group.MapGet("/{id:guid}", async (Guid id, I${SERVICE_NAME}Service service) =>
        {
            var item = await service.GetByIdAsync(id);
            return item is not null ? Results.Ok(item) : Results.NotFound();
        })
        .WithName("Get${SERVICE_NAME}ById")
        .WithDescription("Get ${SERVICE_NAME} item by ID");

        group.MapPost("/", async (Create${SERVICE_NAME}Request request, I${SERVICE_NAME}Service service) =>
        {
            var item = await service.CreateAsync(request.Name);
            return Results.Created(\$"/api/${SERVICE_NAME_LOWER}/{item.Id}", item);
        })
        .WithName("Create${SERVICE_NAME}")
        .WithDescription("Create a new ${SERVICE_NAME} item");
    }
}

public record Create${SERVICE_NAME}Request(string Name);
EOF

# Infrastructure - Physical View
cat > "$PROJECT_PATH/Infrastructure/DaprStateStore.cs" << EOF
using Dapr.Client;

namespace ${PROJECT_NAME}.Infrastructure;

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
cat > "$PROJECT_PATH/Program.cs" << EOF
using ${PROJECT_NAME}.Endpoints;
using ${PROJECT_NAME}.Services;
using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

// Add service defaults (OpenTelemetry, health checks, service discovery)
builder.AddServiceDefaults();

// Add OpenAPI (native .NET 10 support)
builder.Services.AddOpenApi("v1", options =>
{
    options.AddDocumentTransformer((document, context, cancellationToken) =>
    {
        document.Info.Title = "${SERVICE_NAME} Service API";
        document.Info.Version = "v1";
        document.Info.Description = "${SERVICE_NAME} microservice following Kruchten 4+1 architecture";
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
builder.Services.AddSingleton<I${SERVICE_NAME}Service, ${SERVICE_NAME}Service>();

var app = builder.Build();

// Configure pipeline
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference(options =>
    {
        options.WithTitle("${SERVICE_NAME} Service API")
               .WithDefaultHttpClient(ScalarTarget.CSharp, ScalarClient.HttpClient);
    });
}

app.UseHttpsRedirection();
app.UseCors();

// Map default health endpoints
app.MapDefaultEndpoints();

// Map API endpoints (Scenario View)
app.Map${SERVICE_NAME}Endpoints();

app.Run();
EOF

# Create appsettings.json
cat > "$PROJECT_PATH/appsettings.json" << EOF
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
EOF

# Create appsettings.Development.json
cat > "$PROJECT_PATH/appsettings.Development.json" << 'EOF'
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  }
}
EOF

# Create launchSettings.json
cat > "$PROJECT_PATH/Properties/launchSettings.json" << EOF
{
  "\$schema": "https://json.schemastore.org/launchsettings.json",
  "profiles": {
    "http": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "launchUrl": "scalar/v1",
      "applicationUrl": "http://localhost:${HTTP_PORT}",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    },
    "https": {
      "commandName": "Project",
      "dotnetRunMessages": true,
      "launchBrowser": true,
      "launchUrl": "scalar/v1",
      "applicationUrl": "https://localhost:${HTTPS_PORT};http://localhost:${HTTP_PORT}",
      "environmentVariables": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    }
  }
}
EOF

# Add project to solution
print_step "Adding project to solution..."
dotnet sln add "$PROJECT_PATH/${PROJECT_NAME}.csproj"

# Add project reference to AppHost
print_step "Adding project reference to AppHost..."
APPHOST_CSPROJ="src/${SOLUTION_NAME}.AppHost/${SOLUTION_NAME}.AppHost.csproj"

if [[ -f "$APPHOST_CSPROJ" ]]; then
    # Add ProjectReference to AppHost csproj
    sed -i "/<\/ItemGroup>/i\\    <ProjectReference Include=\"..\\\\${PROJECT_NAME}\\\\${PROJECT_NAME}.csproj\" />" "$APPHOST_CSPROJ"
    
    print_step "Updating AppHost.cs..."
    APPHOST_CS="src/${SOLUTION_NAME}.AppHost/AppHost.cs"
    
    # Create variable name for the service
    SERVICE_VAR=$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]')
    PROJECT_CLASS="${SOLUTION_NAME}_${SERVICE_NAME}"
    
    # Insert the new service registration before builder.Build().Run();
    sed -i "/builder.Build().Run();/i\\\\n// Add ${SERVICE_NAME} service with Dapr sidecar\\nvar ${SERVICE_VAR} = builder.AddProject<Projects.${PROJECT_CLASS}>(\"${SERVICE_VAR}\")\\n    .WithDaprSidecar()\\n    .WithHttpHealthCheck(\"/health\");\\n" "$APPHOST_CS"
    
    print_warning "Please review AppHost.cs and add .WithReference() calls if this service needs to communicate with others."
fi

# Build the new project
print_step "Building new project..."
dotnet build "$PROJECT_PATH/${PROJECT_NAME}.csproj"

print_step "Microservice '${SERVICE_NAME}' added successfully!"
echo ""
echo "Project location: $PROJECT_PATH"
echo "HTTP port: $HTTP_PORT"
echo "HTTPS port: $HTTPS_PORT"
echo ""
echo "Next steps:"
echo "  1. Add your domain models and endpoints to Program.cs"
echo "  2. Update AppHost.cs if this service needs references to other services"
echo "  3. Run 'aspire run' to test the new service"
