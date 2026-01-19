#!/bin/bash

# Script para crear una Minimal API de .NET 10 con Swagger y .NET Aspire
# Uso: ./create_dotnet_api.sh <nombre-proyecto> <ruta-destino>

set -e

PROJECT_NAME=${1:-"Api"}
TARGET_PATH=${2:-"./"}
FULL_PATH="$TARGET_PATH/$PROJECT_NAME"

echo "🚀 Creando proyecto .NET 10 Minimal API: $PROJECT_NAME"
echo "📂 Ubicación: $FULL_PATH"

# Crear directorio del proyecto
mkdir -p "$FULL_PATH"
cd "$FULL_PATH"

# Crear el proyecto de API
dotnet new webapi -n "$PROJECT_NAME" --use-minimal-apis --framework net10.0

cd "$PROJECT_NAME"

# Agregar paquetes necesarios para Swagger (OpenAPI)
dotnet add package Swashbuckle.AspNetCore
dotnet add package Microsoft.AspNetCore.OpenApi

# Agregar paquete para CORS
dotnet add package Microsoft.AspNetCore.Cors

# Agregar paquetes de Dapr
dotnet add package Dapr.AspNetCore
dotnet add package Dapr.Client

# Crear estructura de carpetas basada en el Modelo 4+1 de Kruchten
echo "📐 Creando estructura basada en Modelo 4+1..."

# Vista Lógica - Domain Layer
mkdir -p Domain/Entities
mkdir -p Domain/ValueObjects
mkdir -p Domain/Interfaces

# Vista Lógica - Application Layer
mkdir -p Application/Commands
mkdir -p Application/Queries
mkdir -p Application/DTOs
mkdir -p Application/Validators

# Vista de Desarrollo - Infrastructure Layer
mkdir -p Infrastructure/Persistence
mkdir -p Infrastructure/Messaging
mkdir -p Infrastructure/ExternalServices

# Vista de Desarrollo - Presentation Layer (Endpoints)
mkdir -p Endpoints

# Vista de Desarrollo - Extensions
mkdir -p Extensions

# Crear archivo de configuración appsettings.json actualizado
cat > appsettings.json << 'EOF'
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "Cors": {
    "AllowedOrigins": ["http://localhost:5173", "http://localhost:3000"]
  }
}
EOF

# Crear Program.cs con configuración de Swagger, CORS, Dapr y Aspire
cat > Program.cs << 'EOF'
using Microsoft.OpenApi.Models;
using Dapr.Client;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

// Configurar CORS
var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() 
    ?? new[] { "http://localhost:5173" };

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.WithOrigins(allowedOrigins)
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();
    });
});

// Agregar servicios de API Explorer y Swagger
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Minimal API",
        Version = "v1",
        Description = "API creada con .NET 10 Minimal API con Dapr",
        Contact = new OpenApiContact
        {
            Name = "Tu Nombre",
            Email = "tu-email@example.com"
        }
    });
});

// Configurar Dapr
builder.Services.AddControllers().AddDapr();
builder.Services.AddDaprClient();

var app = builder.Build();

// Configurar el pipeline de HTTP request
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "API v1");
        c.RoutePrefix = string.Empty; // Swagger en la raíz
    });
}

app.UseCors();
app.UseHttpsRedirection();

// Habilitar Dapr en los endpoints
app.UseCloudEvents();
app.MapSubscribeHandler();

// Endpoints de ejemplo
app.MapGet("/api/health", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow }))
    .WithName("HealthCheck")
    .WithTags("Health")
    .WithOpenApi();

app.MapGet("/api/version", () => Results.Ok(new { version = "1.0.0", framework = ".NET 10" }))
    .WithName("GetVersion")
    .WithTags("Info")
    .WithOpenApi();

// Endpoint de ejemplo con parámetros
app.MapGet("/api/greeting/{name}", (string name) => 
    Results.Ok(new { message = $"Hello, {name}!", timestamp = DateTime.UtcNow }))
    .WithName("GetGreeting")
    .WithTags("Greetings")
    .WithOpenApi();

// Endpoint POST de ejemplo
app.MapPost("/api/echo", (EchoRequest request) => 
    Results.Ok(new { echo = request.Message, receivedAt = DateTime.UtcNow }))
    .WithName("Echo")
    .WithTags("Echo")
    .WithOpenApi();

// Ejemplo de endpoint con Dapr State Store
app.MapGet("/api/state/{key}", async (string key, DaprClient daprClient) =>
{
    try
    {
        var value = await daprClient.GetStateAsync<string>("statestore", key);
        return value != null 
            ? Results.Ok(new { key, value })
            : Results.NotFound(new { message = "Key not found" });
    }
    catch (Exception ex)
    {
        return Results.Problem(ex.Message);
    }
})
.WithName("GetState")
.WithTags("Dapr")
.WithOpenApi();

app.MapPost("/api/state/{key}", async (string key, StateValue request, DaprClient daprClient) =>
{
    try
    {
        await daprClient.SaveStateAsync("statestore", key, request.Value);
        return Results.Ok(new { message = "State saved successfully", key });
    }
    catch (Exception ex)
    {
        return Results.Problem(ex.Message);
    }
})
.WithName("SaveState")
.WithTags("Dapr")
.WithOpenApi();

// Ejemplo de endpoint con Dapr Pub/Sub
app.MapPost("/api/publish/{topic}", async (string topic, EventData eventData, DaprClient daprClient) =>
{
    try
    {
        await daprClient.PublishEventAsync("pubsub", topic, eventData);
        return Results.Ok(new { message = "Event published successfully", topic });
    }
    catch (Exception ex)
    {
        return Results.Problem(ex.Message);
    }
})
.WithName("PublishEvent")
.WithTags("Dapr")
.WithOpenApi();

app.MapDefaultEndpoints();

app.Run();

// Modelos de ejemplo
public record EchoRequest(string Message);
public record StateValue(string Value);
public record EventData(string Message, DateTime Timestamp);
EOF

# Configurar .NET Aspire (obligatorio)
echo "☁️  Configurando .NET Aspire..."
cd ..

# Crear proyecto AppHost
dotnet new aspire-apphost -n "${PROJECT_NAME}.AppHost" -o "${PROJECT_NAME}.AppHost"

# Crear proyecto ServiceDefaults
dotnet new aspire-servicedefaults -n "${PROJECT_NAME}.ServiceDefaults" -o "${PROJECT_NAME}.ServiceDefaults"

# Referencias
dotnet add "${PROJECT_NAME}/${PROJECT_NAME}.csproj" reference "${PROJECT_NAME}.ServiceDefaults/${PROJECT_NAME}.ServiceDefaults.csproj"
dotnet add "${PROJECT_NAME}.AppHost/${PROJECT_NAME}.AppHost.csproj" reference "${PROJECT_NAME}/${PROJECT_NAME}.csproj"

# Configurar AppHost
cat > "${PROJECT_NAME}.AppHost/Program.cs" << 'ASPIRE_APPHOST'
var builder = DistributedApplication.CreateBuilder(args);

// Redis para Dapr
var redis = builder.AddRedis("redis")
    .WithDataVolume();

// SQL Server (opcional)
var sqlserver = builder.AddSqlServer("sqlserver")
    .WithDataVolume()
    .AddDatabase("appdb");

// API Backend
var api = builder.AddProject<Projects.PROJECT_NAME>("api")
    .WithReference(redis)
    .WithReference(sqlserver)
    .WithExternalHttpEndpoints();

builder.Build().Run();
ASPIRE_APPHOST

sed -i "s/PROJECT_NAME/${PROJECT_NAME}/g" "${PROJECT_NAME}.AppHost/Program.cs"

cd "${PROJECT_NAME}"

# Crear archivos de ejemplo para el modelo 4+1
echo "📝 Creando archivos de ejemplo del modelo 4+1..."

# Domain Entity Example
cat > Domain/Entities/Entity.cs << 'EOF'
namespace $PROJECT_NAME.Domain.Entities;

/// <summary>
/// Base class for domain entities following DDD principles
/// </summary>
public abstract class Entity
{
    public Guid Id { get; protected set; }
    public DateTime CreatedAt { get; protected set; }
    public DateTime? UpdatedAt { get; protected set; }

    protected Entity()
    {
        Id = Guid.NewGuid();
        CreatedAt = DateTime.UtcNow;
    }

    public override bool Equals(object? obj)
    {
        if (obj is not Entity other)
            return false;

        if (ReferenceEquals(this, other))
            return true;

        if (GetType() != other.GetType())
            return false;

        return Id == other.Id;
    }

    public override int GetHashCode()
    {
        return Id.GetHashCode();
    }
}
EOF

# Repository Interface
cat > Domain/Interfaces/IRepository.cs << 'EOF'
namespace $PROJECT_NAME.Domain.Interfaces;

/// <summary>
/// Generic repository interface for domain entities
/// </summary>
public interface IRepository<T> where T : class
{
    Task<T?> GetByIdAsync(Guid id, CancellationToken cancellationToken = default);
    Task<IEnumerable<T>> GetAllAsync(CancellationToken cancellationToken = default);
    Task AddAsync(T entity, CancellationToken cancellationToken = default);
    Task UpdateAsync(T entity, CancellationToken cancellationToken = default);
    Task DeleteAsync(Guid id, CancellationToken cancellationToken = default);
}
EOF

# Service Collection Extensions
cat > Extensions/ServiceCollectionExtensions.cs << 'EOF'
namespace $PROJECT_NAME.Extensions;

/// <summary>
/// Extension methods for configuring services following 4+1 model
/// </summary>
public static class ServiceCollectionExtensions
{
    /// <summary>
    /// Add Domain services (Vista Lógica)
    /// </summary>
    public static IServiceCollection AddDomainServices(this IServiceCollection services)
    {
        // Register domain services here
        return services;
    }

    /// <summary>
    /// Add Application services (Vista Lógica - Use Cases)
    /// </summary>
    public static IServiceCollection AddApplicationServices(this IServiceCollection services)
    {
        // Register command handlers, query handlers, validators
        return services;
    }

    /// <summary>
    /// Add Infrastructure services (Vista Física)
    /// </summary>
    public static IServiceCollection AddInfrastructureServices(
        this IServiceCollection services, 
        IConfiguration configuration)
    {
        // Register repositories, external services, messaging
        return services;
    }
}
EOF

# Architecture Documentation
cat > Architecture.md << 'EOF'
# Arquitectura del Proyecto - Modelo 4+1 de Kruchten

Este proyecto sigue el **Modelo 4+1 de Philippe Kruchten**, que describe la arquitectura desde 5 vistas complementarias.

## Estructura del Proyecto

\`\`\`
$PROJECT_NAME/
├── Domain/                     # Vista Lógica - Lógica de negocio pura
│   ├── Entities/              # Entidades del dominio
│   ├── ValueObjects/          # Value objects inmutables
│   └── Interfaces/            # Contratos del dominio
├── Application/               # Vista Lógica - Casos de uso
│   ├── Commands/              # Operaciones que modifican estado (CQRS)
│   ├── Queries/               # Operaciones de lectura (CQRS)
│   ├── DTOs/                  # Data Transfer Objects
│   └── Validators/            # Validación de entrada
├── Infrastructure/            # Vista Física - Implementaciones técnicas
│   ├── Persistence/           # Acceso a datos
│   ├── Messaging/             # Pub/Sub, eventos
│   └── ExternalServices/      # APIs externas
├── Endpoints/                 # Vista de Desarrollo - API endpoints
└── Extensions/                # Vista de Desarrollo - Configuración modular
\`\`\`

## Las 5 Vistas

### 1. Vista Lógica 🧠
**Ubicación**: `Domain/`, `Application/`
**Propósito**: Funcionalidad del sistema desde la perspectiva del usuario

- **Entities**: Objetos de negocio con identidad
- **Value Objects**: Objetos inmutables definidos por sus atributos
- **Commands/Queries**: Casos de uso siguiendo CQRS

### 2. Vista de Proceso ⚙️
**Ubicación**: `Infrastructure/Messaging/`, Background Services
**Propósito**: Concurrencia, distribución, performance

- **Dapr Pub/Sub**: Mensajería asíncrona
- **State Management**: Gestión de estado distribuido
- **Background Workers**: Procesamiento en background

### 3. Vista de Desarrollo 👨‍💻
**Ubicación**: Toda la estructura de carpetas
**Propósito**: Organización del código

- **Separación en capas**: Domain, Application, Infrastructure
- **Endpoints modulares**: Organizados por dominio
- **Extensions**: Configuración modular y reutilizable

### 4. Vista Física 🖥️
**Ubicación**: `Infrastructure/`, Docker, Kubernetes
**Propósito**: Deployment y topología física

- **Dapr sidecar**: Runtime distribuido
- **Docker/K8s**: Contenedorización y orquestación
- **Base de datos**: SQL Server, Redis

### 5. Vista de Escenarios (+1) 📋
**Ubicación**: Casos de uso end-to-end
**Propósito**: Ilustrar cómo las 4 vistas trabajan juntas

## Patrones Arquitectónicos Aplicados

- **Clean Architecture**: Separación de concerns, dependencias hacia adentro
- **CQRS**: Separación de Commands y Queries
- **Domain-Driven Design (DDD)**: Entidades, Value Objects, Aggregates
- **Repository Pattern**: Abstracción del acceso a datos

## Próximos Pasos

1. Implementar entidades de dominio en `Domain/Entities/`
2. Crear casos de uso en `Application/Commands/` y `Application/Queries/`
3. Implementar repositorios en `Infrastructure/Persistence/`
4. Configurar endpoints en `Endpoints/`

## Referencias

- Ver `references/kruchten-4plus1-architecture.md` para documentación completa
- [4+1 Architectural View Model](https://www.cs.ubc.ca/~gregor/teaching/papers/4+1view-architecture.pdf)
EOF
echo "✅ Proyecto .NET 10 Minimal API creado exitosamente"
echo ""
echo "📦 Incluye:"
echo "   ✓ Minimal API con Swagger"
echo "   ✓ Dapr integration (State, Pub/Sub)"
echo "   ✓ .NET Aspire (AppHost + ServiceDefaults)"
echo "   ✓ Arquitectura Modelo 4+1 de Kruchten"
echo "   ✓ Clean Architecture structure"
echo ""
echo "📐 Estructura basada en:"
echo "   • Vista Lógica: Domain/ y Application/"
echo "   • Vista de Proceso: Infrastructure/Messaging/"
echo "   • Vista de Desarrollo: Endpoints/, Extensions/"
echo "   • Vista Física: Configuración Dapr"
echo ""
echo "📝 Para ejecutar con Aspire (recomendado):"
echo "   cd $FULL_PATH/${PROJECT_NAME}.AppHost"
echo "   dotnet run"
echo ""
echo "📝 Para ejecutar solo la API:"
echo "   cd $FULL_PATH/$PROJECT_NAME"
echo "   dotnet run"
echo ""
echo "🌐 Swagger estará disponible en: https://localhost:<puerto>/"
echo ""
echo "🚀 Para ejecutar con Dapr:"
echo "   dapr run --app-id ${PROJECT_NAME,,} --app-port <puerto> --dapr-http-port 3500 -- dotnet run"
echo ""
echo "📖 Endpoints de Dapr incluidos:"
echo "   GET  /api/state/{key}      - Obtener estado"
echo "   POST /api/state/{key}      - Guardar estado"
echo "   POST /api/publish/{topic}  - Publicar evento"
echo ""
echo "📐 Consulta Architecture.md para detalles del modelo 4+1"
