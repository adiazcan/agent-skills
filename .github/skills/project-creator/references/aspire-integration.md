# .NET Aspire Integration

Este documento describe cómo usar .NET Aspire para orquestar aplicaciones distribuidas tanto monolíticas como de microservicios.

## Tabla de Contenidos

1. [Introducción](#introducción)
2. [Conceptos Fundamentales](#conceptos-fundamentales)
3. [Estructura de Proyectos](#estructura-de-proyectos)
4. [AppHost Configuration](#apphost-configuration)
5. [Service Defaults](#service-defaults)
6. [Service Discovery](#service-discovery)
7. [Resources y Components](#resources-y-components)
8. [Observabilidad](#observabilidad)
9. [Deployment](#deployment)
10. [Best Practices](#best-practices)

## Introducción

**.NET Aspire** es un stack de desarrollo cloud-native que simplifica la construcción, ejecución, debug y deployment de aplicaciones distribuidas. Proporciona:

- **Orquestación local**: Inicia toda tu aplicación distribuida con un solo comando
- **Service Discovery automático**: Los servicios se encuentran entre sí sin configuración manual
- **Observabilidad integrada**: Dashboard con telemetría, logs y traces
- **Deploy flexible**: Despliega a Kubernetes, Azure Container Apps o tu propio servidor

### Ventajas sobre arquitecturas tradicionales

**Sin Aspire:**
```bash
# Terminal 1: Iniciar Redis
docker run -p 6379:6379 redis

# Terminal 2: Iniciar SQL Server
docker run -p 1433:1433 sql-server

# Terminal 3: Iniciar API
cd MyApp.Api && dotnet run

# Terminal 4: Iniciar Frontend
cd MyApp.Frontend && npm run dev

# Configurar manualmente: connection strings, URLs, env vars...
```

**Con Aspire:**
```bash
cd MyApp.AppHost
dotnet run  # ¡Todo inicia automáticamente! 🚀
```

## Conceptos Fundamentales

### AppHost

El **AppHost** es el orquestador central. Define toda la arquitectura de tu aplicación en código:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// Definir recursos (databases, caches, etc.)
var redis = builder.AddRedis("redis");
var postgres = builder.AddPostgres("db").AddDatabase("appdb");

// Definir servicios
var api = builder.AddProject<Projects.MyApp_Api>("api")
    .WithReference(redis)
    .WithReference(postgres);

var frontend = builder.AddNpmApp("frontend", "../MyApp.Frontend")
    .WithReference(api)
    .WithHttpEndpoint(port: 5173);

builder.Build().Run();
```

**Características clave:**
- Tipado fuerte (errores en compile-time)
- IntelliSense y autocompletado
- Control de versiones junto con el código
- Refactoring sencillo

### ServiceDefaults

El proyecto **ServiceDefaults** proporciona configuración compartida que se aplica automáticamente a todos los servicios:

```csharp
// Añadido automáticamente en Program.cs de cada servicio
builder.AddServiceDefaults();

// Configura:
// - OpenTelemetry (metrics + tracing)
// - Health checks (/health, /alive)
// - Service discovery
// - Resilient HttpClient (circuit breaker, retry)
```

### Dashboard

Aspire incluye un dashboard web que muestra:
- Estado de todos los servicios en tiempo real
- Logs agregados por servicio
- Distributed traces
- Métricas (CPU, memoria, requests)
- Endpoints expuestos

**URL**: `http://localhost:15888` (puerto por defecto)

## Estructura de Proyectos

### Aplicación Monolítica con Aspire

```
MyApp/
├── MyApp.sln
├── MyApp.AppHost/               # Orquestador
│   ├── Program.cs
│   └── MyApp.AppHost.csproj
├── MyApp.ServiceDefaults/       # Configuración compartida
│   ├── Extensions.cs
│   └── MyApp.ServiceDefaults.csproj
├── MyApp.Api/                   # Backend
│   ├── Program.cs               # Llama builder.AddServiceDefaults()
│   └── MyApp.Api.csproj
└── MyApp.Frontend/              # Frontend React
    ├── package.json
    └── vite.config.ts
```

### Microservicios con Aspire

```
MyEcommerce/
├── MyEcommerce.sln
├── MyEcommerce.AppHost/         # Orquestador
│   └── Program.cs               # Define todos los microservicios
├── MyEcommerce.ServiceDefaults/
├── gateway/
│   └── ApiGateway/
│       └── MyEcommerce.Gateway/ # Referencia ServiceDefaults
├── services/
│   ├── Users/
│   │   └── MyEcommerce.Users/   # Referencia ServiceDefaults
│   ├── Orders/
│   │   └── MyEcommerce.Orders/  # Referencia ServiceDefaults
│   └── Products/
│       └── MyEcommerce.Products/
└── frontend/
    └── MyEcommerce.Frontend/
```

## AppHost Configuration

### Monolito Básico

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// Bases de datos y caches
var redis = builder.AddRedis("redis")
    .WithDataVolume();  // Persistir datos

var sqlserver = builder.AddSqlServer("sqlserver")
    .WithDataVolume()
    .AddDatabase("appdb");

// API Backend
var api = builder.AddProject<Projects.MyApp_Api>("api")
    .WithReference(redis)
    .WithReference(sqlserver)
    .WithExternalHttpEndpoints();  // Accesible desde fuera

// Frontend
var frontend = builder.AddNpmApp("frontend", "../MyApp.Frontend")
    .WithReference(api)  // Inyecta URL de API automáticamente
    .WithHttpEndpoint(env: "PORT", port: 5173)
    .WithExternalHttpEndpoints()
    .PublishAsDockerFile();

builder.Build().Run();
```

### Microservicios con Dependencias

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// Infraestructura compartida
var redis = builder.AddRedis("redis")
    .WithDataVolume();

var sqlserver = builder.AddSqlServer("sqlserver")
    .WithDataVolume();

// Microservicios (orden importante)
var users = builder.AddProject<Projects.MyEcommerce_Users>("users")
    .WithReference(redis)
    .WithReference(sqlserver.AddDatabase("usersdb"));

var products = builder.AddProject<Projects.MyEcommerce_Products>("products")
    .WithReference(redis)
    .WithReference(sqlserver.AddDatabase("productsdb"));

// Orders depende de Users y Products
var orders = builder.AddProject<Projects.MyEcommerce_Orders>("orders")
    .WithReference(redis)
    .WithReference(sqlserver.AddDatabase("ordersdb"))
    .WithReference(users)     // Service-to-service communication
    .WithReference(products)
    .WaitFor(users)          // No iniciar hasta que users esté healthy
    .WaitFor(products);

// API Gateway
var gateway = builder.AddProject<Projects.MyEcommerce_Gateway>("gateway")
    .WithReference(users)
    .WithReference(orders)
    .WithReference(products)
    .WithExternalHttpEndpoints();

// Frontend
var frontend = builder.AddNpmApp("frontend", "../MyEcommerce.Frontend")
    .WithReference(gateway)
    .WithHttpEndpoint(env: "PORT", port: 5173)
    .WithExternalHttpEndpoints()
    .PublishAsDockerFile();

builder.Build().Run();
```

### Configuración Avanzada

#### Parámetros y Secretos

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// Parámetros configurables
var smtpHost = builder.AddParameter("smtp-host");
var smtpPort = builder.AddParameter("smtp-port", defaultValue: "587");

// Secretos (no se almacenan en código)
var apiKey = builder.AddParameter("api-key", secret: true);

var api = builder.AddProject<Projects.MyApp_Api>("api")
    .WithEnvironment("SmtpHost", smtpHost)
    .WithEnvironment("SmtpPort", smtpPort)
    .WithEnvironment("ApiKey", apiKey);
```

#### Variables de Entorno

```csharp
var api = builder.AddProject<Projects.MyApp_Api>("api")
    .WithEnvironment("ASPNETCORE_ENVIRONMENT", "Development")
    .WithEnvironment("LOG_LEVEL", "Information")
    .WithEnvironment("FEATURE_FLAGS__NewUI", "true");
```

#### Replicas para Escalado

```csharp
var api = builder.AddProject<Projects.MyApp_Api>("api")
    .WithReplicas(3);  // 3 instancias para balanceo de carga
```

## Service Defaults

### Configuración Automática

Cuando llamas a `builder.AddServiceDefaults()` en un servicio, se configura automáticamente:

#### 1. OpenTelemetry

```csharp
// Automático:
// - Metrics: ASP.NET Core, HttpClient, Runtime
// - Tracing: ASP.NET Core, HttpClient
// - Logging: OpenTelemetry format
// - Exporters: OTLP (para Aspire Dashboard)
```

#### 2. Health Checks

```csharp
// Endpoints automáticos:
// GET /health - Todos los health checks
// GET /alive - Solo checks tagged "live"
```

#### 3. Service Discovery

```csharp
// HttpClient configurado para resolver nombres de servicio:
var response = await httpClient.GetAsync("http://api/users");
// "api" se resuelve automáticamente a la URL real
```

#### 4. Resilient HttpClient

```csharp
// Circuit breaker y retry policies automáticos
// Sin configuración adicional
```

### Personalizar Service Defaults

Puedes extender `Extensions.cs` en el proyecto ServiceDefaults:

```csharp
public static class CustomExtensions
{
    public static IHostApplicationBuilder AddCustomDefaults(
        this IHostApplicationBuilder builder)
    {
        // Tus configuraciones personalizadas
        builder.Services.AddAuthentication(/* ... */);
        builder.Services.AddAuthorization(/* ... */);
        
        return builder;
    }
}
```

Usar en servicios:

```csharp
builder.AddServiceDefaults();
builder.AddCustomDefaults();  // Tu extensión personalizada
```

## Service Discovery

Aspire proporciona service discovery automático. Los servicios se comunican usando nombres lógicos en lugar de URLs hardcodeadas.

### En AppHost

```csharp
var users = builder.AddProject<Projects.Users>("users");
var orders = builder.AddProject<Projects.Orders>("orders")
    .WithReference(users);  // Inyecta conexión a "users"
```

### En el Servicio Consumidor (Orders)

#### Opción 1: HttpClient con Service Discovery

```csharp
// Program.cs
builder.AddServiceDefaults();  // Habilita service discovery

// En un endpoint
app.MapGet("/orders/{orderId}", async (string orderId, HttpClient httpClient) =>
{
    // Usa el nombre del servicio como host
    var user = await httpClient.GetFromJsonAsync<User>($"http://users/api/users/{userId}");
    
    // Aspire resuelve "http://users" a la URL real (ej: http://localhost:5001)
    return new Order { User = user, /* ... */ };
});
```

#### Opción 2: IHttpClientFactory

```csharp
// Program.cs
builder.Services.AddHttpClient<IUserService, UserService>(client =>
{
    client.BaseAddress = new Uri("http://users");  // Nombre del servicio
});

// UserService.cs
public class UserService : IUserService
{
    private readonly HttpClient _httpClient;
    
    public UserService(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }
    
    public async Task<User> GetUserAsync(string userId)
    {
        return await _httpClient.GetFromJsonAsync<User>($"/api/users/{userId}");
    }
}
```

### Configuración Inyectada

Aspire inyecta automáticamente la configuración necesaria:

```json
// appsettings.json generado automáticamente
{
  "ConnectionStrings": {
    "redis": "localhost:6379",
    "sqlserver": "Server=localhost,1433;Database=appdb;User=sa;Password=..."
  },
  "services": {
    "users": {
      "http": ["http://localhost:5001"],
      "https": ["https://localhost:7001"]
    }
  }
}
```

## Resources y Components

### Databases

#### PostgreSQL

```csharp
var postgres = builder.AddPostgres("postgres")
    .WithDataVolume()
    .WithPgAdmin();  // Incluir pgAdmin UI

var db = postgres.AddDatabase("mydb");

var api = builder.AddProject<Projects.Api>("api")
    .WithReference(db);  // Inyecta connection string
```

#### SQL Server

```csharp
var sqlserver = builder.AddSqlServer("sqlserver")
    .WithDataVolume();

var catalogDb = sqlserver.AddDatabase("catalog");
var ordersDb = sqlserver.AddDatabase("orders");

var catalogService = builder.AddProject<Projects.Catalog>("catalog")
    .WithReference(catalogDb);
```

#### MongoDB

```csharp
var mongo = builder.AddMongoDB("mongo")
    .WithDataVolume();

var db = mongo.AddDatabase("products");
```

### Caches

#### Redis

```csharp
var redis = builder.AddRedis("redis")
    .WithDataVolume()
    .WithRedisCommander();  // Redis UI
```

#### Valkey (Redis alternative)

```csharp
var valkey = builder.AddValkey("cache")
    .WithDataVolume();
```

### Message Brokers

#### RabbitMQ

```csharp
var rabbitmq = builder.AddRabbitMQ("messaging")
    .WithDataVolume()
    .WithManagementPlugin();  // Management UI

var api = builder.AddProject<Projects.Api>("api")
    .WithReference(rabbitmq);
```

#### Azure Service Bus

```csharp
var serviceBus = builder.AddAzureServiceBus("messaging");

var api = builder.AddProject<Projects.Api>("api")
    .WithReference(serviceBus);
```

### Storage

#### Azure Blob Storage

```csharp
var storage = builder.AddAzureStorage("storage")
    .RunAsEmulator();  // Azurite para desarrollo local

var blobs = storage.AddBlobs("images");

var api = builder.AddProject<Projects.Api>("api")
    .WithReference(blobs);
```

### Proyectos Externos

#### Containers Genéricos

```csharp
var prometheus = builder.AddContainer("prometheus", "prom/prometheus")
    .WithBindMount("./prometheus.yml", "/etc/prometheus/prometheus.yml")
    .WithHttpEndpoint(port: 9090, targetPort: 9090);
```

#### Executables

```csharp
var python = builder.AddExecutable("worker", "python", ".")
    .WithArgs("worker.py")
    .WithEnvironment("WORKER_ID", "1");
```

## Observabilidad

### Dashboard Features

El Aspire Dashboard (http://localhost:15888) proporciona:

#### 1. Resources View
- Estado de todos los servicios y recursos
- Estado de salud (healthy, unhealthy, starting)
- Endpoints expuestos
- Logs en tiempo real

#### 2. Traces View
- Distributed tracing con OpenTelemetry
- Visualización de request flow a través de servicios
- Tiempos de respuesta por operación
- Errores y excepciones

#### 3. Metrics View
- CPU y memoria por servicio
- Request rates y latencies
- Custom metrics de tu aplicación
- Dashboards con gráficos

#### 4. Logs View
- Logs agregados de todos los servicios
- Filtrado por servicio, level, timestamp
- Búsqueda full-text
- Export de logs

### Custom Telemetry

#### Metrics Personalizadas

```csharp
// Program.cs
var meter = new Meter("MyApp.Orders", "1.0.0");
var orderCounter = meter.CreateCounter<int>("orders_created");

app.MapPost("/orders", (Order order) =>
{
    // Lógica de negocio...
    
    orderCounter.Add(1, new KeyValuePair<string, object?>("status", "success"));
    
    return Results.Created($"/orders/{order.Id}", order);
});
```

#### Traces Personalizados

```csharp
using System.Diagnostics;

var activitySource = new ActivitySource("MyApp.Orders");

app.MapGet("/orders/{id}", async (string id) =>
{
    using var activity = activitySource.StartActivity("GetOrder");
    activity?.SetTag("order.id", id);
    
    // Lógica de negocio...
    
    activity?.SetTag("order.status", order.Status);
    
    return order;
});
```

#### Structured Logging

```csharp
app.MapPost("/orders", (Order order, ILogger<Program> logger) =>
{
    logger.LogInformation(
        "Creating order {OrderId} for user {UserId} with {ItemCount} items",
        order.Id,
        order.UserId,
        order.Items.Count
    );
    
    // Lógica...
    
    return Results.Created($"/orders/{order.Id}", order);
});
```

### Health Checks Personalizados

```csharp
// Program.cs
builder.Services.AddHealthChecks()
    .AddCheck("database", () =>
    {
        // Verificar conexión a DB
        var isHealthy = CheckDatabaseConnection();
        return isHealthy 
            ? HealthCheckResult.Healthy("Database is responsive")
            : HealthCheckResult.Unhealthy("Database is not responding");
    })
    .AddCheck("external-api", () =>
    {
        // Verificar API externa
        return HealthCheckResult.Healthy();
    }, tags: new[] { "external" });

// ServiceDefaults configura automáticamente:
// GET /health - Todos los checks
// GET /alive - Solo checks sin tag "external"
```

## Deployment

### Azure Container Apps

Aspire tiene integración nativa con Azure Container Apps usando Azure Developer CLI (azd).

#### 1. Inicializar

```bash
azd init
```

Esto crea archivos de configuración:
- `azure.yaml`: Define la aplicación
- `.azure/`: Configuración de deployment
- `infra/`: Bicep templates (opcional)

#### 2. Deploy

```bash
azd up
```

Automáticamente:
- Crea recursos de Azure (Container Apps, Redis, SQL, etc.)
- Construye contenedores
- Publica la aplicación
- Configura networking y service discovery

#### 3. Monitoreo

```bash
azd monitor --overview  # Logs y metrics en Azure
```

### Kubernetes

#### Generar Manifests

```bash
cd MyApp.AppHost
dotnet publish /t:GenerateDeploymentManifest
```

Genera `manifest.yaml` con:
- Deployments para cada servicio
- Services (ClusterIP, LoadBalancer)
- ConfigMaps y Secrets
- Persistent Volume Claims

#### Deploy

```bash
kubectl apply -f manifest.yaml
kubectl get pods
kubectl get services
```

### Docker Compose (Local Testing)

```bash
cd MyApp.AppHost
dotnet publish /t:GenerateDockerCompose

docker-compose -f docker-compose.yml up
```

## Best Practices

### 1. Organización del AppHost

**✅ Bueno:**
```csharp
// Agrupar por tipo
var builder = DistributedApplication.CreateBuilder(args);

// Infrastructure
var redis = builder.AddRedis("redis").WithDataVolume();
var postgres = builder.AddPostgres("db").WithDataVolume();

// Backend Services
var users = builder.AddProject<Projects.Users>("users")
    .WithReference(redis)
    .WithReference(postgres);

var orders = builder.AddProject<Projects.Orders>("orders")
    .WithReference(redis)
    .WithReference(users);

// Frontend
var web = builder.AddNpmApp("web", "../Web")
    .WithReference(orders);

builder.Build().Run();
```

**❌ Malo:**
```csharp
// Todo mezclado sin estructura
var redis = builder.AddRedis("redis");
var web = builder.AddNpmApp("web", "../Web");
var users = builder.AddProject<Projects.Users>("users");
// ...
```

### 2. Nombrar Recursos Consistentemente

**✅ Bueno:**
```csharp
var redis = builder.AddRedis("redis");
var users = builder.AddProject<Projects.Users>("users");
var orders = builder.AddProject<Projects.Orders>("orders");
```

**❌ Malo:**
```csharp
var redis = builder.AddRedis("cache-storage");  // Inconsistente
var users = builder.AddProject<Projects.Users>("user-svc");
var orders = builder.AddProject<Projects.Orders>("OrderService");
```

### 3. Usar WithReference para Dependencias

**✅ Bueno:**
```csharp
var orders = builder.AddProject<Projects.Orders>("orders")
    .WithReference(users)    // Dependencia explícita
    .WaitFor(users);         // Orden de inicio
```

**❌ Malo:**
```csharp
// Hardcodear URLs
var orders = builder.AddProject<Projects.Orders>("orders")
    .WithEnvironment("USERS_URL", "http://localhost:5001");
```

### 4. Volúmenes para Persistencia

```csharp
// Persistir datos entre reinicios
var postgres = builder.AddPostgres("db")
    .WithDataVolume();  // ✅ Datos persisten

// vs
var postgres = builder.AddPostgres("db");  // ❌ Datos se pierden
```

### 5. External Endpoints Solo Cuando Necesario

```csharp
// Gateway público
var gateway = builder.AddProject<Projects.Gateway>("gateway")
    .WithExternalHttpEndpoints();  // ✅ Accesible desde fuera

// Servicio interno
var orders = builder.AddProject<Projects.Orders>("orders");
// ❌ NO usar WithExternalHttpEndpoints() para servicios internos
```

### 6. Service Defaults en Todos los Proyectos

```csharp
// En CADA servicio:
var builder = WebApplication.CreateBuilder(args);
builder.AddServiceDefaults();  // ✅ Siempre

var app = builder.Build();
app.MapDefaultEndpoints();     // ✅ Health checks
app.Run();
```

### 7. Logging Estructurado

```csharp
// ✅ Bueno: Structured logging
logger.LogInformation(
    "Order {OrderId} created by {UserId}",
    order.Id,
    userId
);

// ❌ Malo: String interpolation
logger.LogInformation($"Order {order.Id} created by {userId}");
```

### 8. Health Checks Significativos

```csharp
// ✅ Bueno: Verificar dependencias críticas
builder.Services.AddHealthChecks()
    .AddCheck("database", () => CheckDatabase())
    .AddCheck("redis", () => CheckRedis())
    .AddCheck("external-api", () => CheckExternalApi(), tags: ["external"]);

// ❌ Malo: Solo self-check
builder.Services.AddHealthChecks()
    .AddCheck("self", () => HealthCheckResult.Healthy());
```

## Recursos Adicionales

- [Aspire Documentation](https://aspire.dev/)
- [Aspire GitHub](https://github.com/dotnet/aspire)
- [Aspire Samples](https://github.com/dotnet/aspire-samples)
- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [Aspire Dashboard](https://aspire.dev/dashboard/overview/)
- [Deployment Guide](https://aspire.dev/deployment/overview/)

## Troubleshooting

### Error: "Could not find project reference"

```bash
# Asegúrate de que el proyecto está en la solución
dotnet sln add MyApp.Api/MyApp.Api.csproj

# Rebuild AppHost
cd MyApp.AppHost
dotnet build
```

### Dashboard no aparece

```bash
# Verificar puerto
netstat -ano | findstr :15888

# Cambiar puerto si es necesario
set ASPIRE_DASHBOARD_PORT=15889
dotnet run
```

### Service Discovery no funciona

```csharp
// Verificar que AddServiceDefaults() está llamado
builder.AddServiceDefaults();  // ← Debe estar presente

// Verificar WithReference() en AppHost
var orders = builder.AddProject<Projects.Orders>("orders")
    .WithReference(users);  // ← Debe estar presente
```

### Contenedores no inician

```bash
# Verificar Docker está corriendo
docker ps

# Ver logs del contenedor
docker logs <container-id>

# Recrear volúmenes
docker volume prune
```
