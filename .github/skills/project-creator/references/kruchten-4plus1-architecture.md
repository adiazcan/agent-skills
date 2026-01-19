# Modelo 4+1 de Kruchten para .NET Minimal API

## Introducción

El modelo 4+1 de Philippe Kruchten describe la arquitectura de un sistema software desde 5 vistas complementarias, cada una dirigida a diferentes stakeholders (usuarios finales, desarrolladores, integradores de sistemas, project managers). Este modelo es especialmente útil para documentar y comunicar la arquitectura de sistemas complejos.

## Las 5 Vistas

### 1. Vista Lógica (Logical View) 🧠
**Audiencia**: Usuarios finales, analistas de negocio
**Propósito**: Describe la funcionalidad del sistema desde la perspectiva del usuario

#### Implementación en .NET Minimal API

```
Api/
├── Domain/                     # Lógica de negocio pura
│   ├── Entities/               # Entidades del dominio
│   │   ├── User.cs
│   │   ├── Order.cs
│   │   └── Product.cs
│   ├── ValueObjects/           # Value objects (inmutables)
│   │   ├── Email.cs
│   │   ├── Money.cs
│   │   └── Address.cs
│   ├── Aggregates/             # Raíces de agregados (DDD)
│   │   └── OrderAggregate.cs
│   ├── Interfaces/             # Contratos del dominio
│   │   ├── IRepository.cs
│   │   └── IUnitOfWork.cs
│   └── Services/               # Servicios de dominio
│       └── OrderService.cs
├── Application/                # Casos de uso (Use Cases)
│   ├── Commands/               # Operaciones que modifican estado
│   │   ├── CreateOrderCommand.cs
│   │   └── UpdateUserCommand.cs
│   ├── Queries/                # Operaciones de lectura
│   │   ├── GetOrderQuery.cs
│   │   └── ListUsersQuery.cs
│   ├── DTOs/                   # Data Transfer Objects
│   │   ├── OrderDto.cs
│   │   └── UserDto.cs
│   └── Validators/             # Validación de entrada
│       └── CreateOrderValidator.cs
```

**Ejemplo - Entidad de Dominio:**

```csharp
// Domain/Entities/Order.cs
namespace Api.Domain.Entities;

public class Order
{
    public Guid Id { get; private set; }
    public string CustomerId { get; private set; }
    public DateTime CreatedAt { get; private set; }
    public OrderStatus Status { get; private set; }
    
    private readonly List<OrderItem> _items = new();
    public IReadOnlyCollection<OrderItem> Items => _items.AsReadOnly();

    private Order() { } // For EF Core

    public static Order Create(string customerId)
    {
        return new Order
        {
            Id = Guid.NewGuid(),
            CustomerId = customerId,
            CreatedAt = DateTime.UtcNow,
            Status = OrderStatus.Pending
        };
    }

    public void AddItem(string productId, int quantity, decimal price)
    {
        if (Status != OrderStatus.Pending)
            throw new InvalidOperationException("Cannot add items to non-pending order");

        var item = new OrderItem(productId, quantity, price);
        _items.Add(item);
    }

    public void MarkAsConfirmed()
    {
        if (Status != OrderStatus.Pending)
            throw new InvalidOperationException("Only pending orders can be confirmed");
            
        Status = OrderStatus.Confirmed;
    }
}

public enum OrderStatus
{
    Pending,
    Confirmed,
    Shipped,
    Delivered,
    Cancelled
}
```

**Ejemplo - Caso de Uso (Application Layer):**

```csharp
// Application/Commands/CreateOrderCommand.cs
namespace Api.Application.Commands;

public record CreateOrderCommand(string CustomerId, List<OrderItemDto> Items);

public record OrderItemDto(string ProductId, int Quantity, decimal Price);

public class CreateOrderCommandHandler
{
    private readonly IRepository<Order> _orderRepository;
    private readonly IUnitOfWork _unitOfWork;

    public CreateOrderCommandHandler(IRepository<Order> orderRepository, IUnitOfWork unitOfWork)
    {
        _orderRepository = orderRepository;
        _unitOfWork = unitOfWork;
    }

    public async Task<Guid> HandleAsync(CreateOrderCommand command)
    {
        var order = Order.Create(command.CustomerId);
        
        foreach (var item in command.Items)
        {
            order.AddItem(item.ProductId, item.Quantity, item.Price);
        }

        await _orderRepository.AddAsync(order);
        await _unitOfWork.CommitAsync();

        return order.Id;
    }
}
```

### 2. Vista de Proceso (Process View) ⚙️
**Audiencia**: Integradores de sistemas
**Propósito**: Describe concurrencia, distribución, performance, escalabilidad

#### Implementación con Dapr y Minimal API

```
Api/
├── Infrastructure/
│   ├── Messaging/              # Pub/Sub, mensajería asíncrona
│   │   ├── EventBus.cs
│   │   ├── Events/
│   │   │   ├── OrderCreatedEvent.cs
│   │   │   └── OrderConfirmedEvent.cs
│   │   └── Handlers/
│   │       ├── OrderCreatedHandler.cs
│   │       └── SendEmailHandler.cs
│   ├── BackgroundServices/     # Procesos en background
│   │   ├── OrderProcessingWorker.cs
│   │   └── NotificationWorker.cs
│   └── Workflows/              # Orquestación de procesos
│       └── OrderFulfillmentWorkflow.cs
```

**Ejemplo - Event Bus con Dapr:**

```csharp
// Infrastructure/Messaging/EventBus.cs
using Dapr.Client;

namespace Api.Infrastructure.Messaging;

public interface IEventBus
{
    Task PublishAsync<T>(string topic, T @event) where T : class;
}

public class DaprEventBus : IEventBus
{
    private readonly DaprClient _daprClient;
    private readonly ILogger<DaprEventBus> _logger;

    public DaprEventBus(DaprClient daprClient, ILogger<DaprEventBus> logger)
    {
        _daprClient = daprClient;
        _logger = logger;
    }

    public async Task PublishAsync<T>(string topic, T @event) where T : class
    {
        _logger.LogInformation("Publishing event {EventType} to topic {Topic}", 
            typeof(T).Name, topic);
            
        await _daprClient.PublishEventAsync("pubsub", topic, @event);
    }
}

// Infrastructure/Messaging/Events/OrderCreatedEvent.cs
public record OrderCreatedEvent(
    Guid OrderId,
    string CustomerId,
    DateTime CreatedAt,
    List<OrderItem> Items
);
```

**Ejemplo - Background Worker:**

```csharp
// Infrastructure/BackgroundServices/OrderProcessingWorker.cs
namespace Api.Infrastructure.BackgroundServices;

public class OrderProcessingWorker : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<OrderProcessingWorker> _logger;

    public OrderProcessingWorker(
        IServiceProvider serviceProvider, 
        ILogger<OrderProcessingWorker> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("Order Processing Worker starting");

        while (!stoppingToken.IsCancellationRequested)
        {
            using var scope = _serviceProvider.CreateScope();
            var orderService = scope.ServiceProvider.GetRequiredService<IOrderService>();

            try
            {
                await orderService.ProcessPendingOrdersAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing orders");
            }

            await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
        }
    }
}

// En Program.cs
builder.Services.AddHostedService<OrderProcessingWorker>();
```

### 3. Vista de Desarrollo (Development View) 👨‍💻
**Audiencia**: Desarrolladores, arquitectos de software
**Propósito**: Organización del código, gestión de módulos, reutilización

#### Estructura del Proyecto

```
Solution/
├── src/
│   ├── Api/                            # API principal
│   │   ├── Endpoints/                  # Minimal API endpoints
│   │   │   ├── Orders/
│   │   │   │   ├── CreateOrder.cs
│   │   │   │   ├── GetOrder.cs
│   │   │   │   └── OrderEndpoints.cs
│   │   │   ├── Users/
│   │   │   └── Products/
│   │   ├── Extensions/                 # Extension methods
│   │   │   ├── ServiceCollectionExtensions.cs
│   │   │   └── WebApplicationExtensions.cs
│   │   └── Program.cs
│   ├── Api.Domain/                     # Class Library
│   │   ├── Entities/
│   │   ├── ValueObjects/
│   │   └── Interfaces/
│   ├── Api.Application/                # Class Library
│   │   ├── Commands/
│   │   ├── Queries/
│   │   └── DTOs/
│   └── Api.Infrastructure/             # Class Library
│       ├── Persistence/
│       ├── Messaging/
│       └── ExternalServices/
├── tests/
│   ├── Api.UnitTests/
│   ├── Api.IntegrationTests/
│   └── Api.ArchitectureTests/
└── docs/
    ├── architecture/
    └── diagrams/
```

**Ejemplo - Configuración Modular:**

```csharp
// Api/Extensions/ServiceCollectionExtensions.cs
namespace Api.Extensions;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddApplicationServices(
        this IServiceCollection services)
    {
        // Registrar handlers de comandos y queries
        services.AddScoped<CreateOrderCommandHandler>();
        services.AddScoped<GetOrderQueryHandler>();
        return services;
    }

    public static IServiceCollection AddInfrastructureServices(
        this IServiceCollection services, IConfiguration configuration)
    {
        // Configurar base de datos
        services.AddDbContext<AppDbContext>(options =>
            options.UseSqlServer(configuration.GetConnectionString("DefaultConnection")));

        // Registrar repositorios
        services.AddScoped(typeof(IRepository<>), typeof(Repository<>));
        services.AddScoped<IUnitOfWork, UnitOfWork>();
        
        // Event Bus
        services.AddScoped<IEventBus, DaprEventBus>();
        
        return services;
    }

    public static IServiceCollection AddDomainServices(
        this IServiceCollection services)
    {
        services.AddScoped<OrderService>();
        return services;
    }
}

// En Program.cs - Configuración limpia
builder.Services
    .AddDomainServices()
    .AddApplicationServices()
    .AddInfrastructureServices(builder.Configuration);
```

**Ejemplo - Endpoints Organizados:**

```csharp
// Api/Endpoints/Orders/OrderEndpoints.cs
namespace Api.Endpoints.Orders;

public static class OrderEndpoints
{
    public static void MapOrderEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/api/orders")
            .WithTags("Orders")
            .WithOpenApi();

        group.MapPost("/", CreateOrder.Handle)
            .WithName("CreateOrder")
            .Produces<Guid>(StatusCodes.Status201Created);

        group.MapGet("/{id}", GetOrder.Handle)
            .WithName("GetOrder")
            .Produces<OrderDto>();

        group.MapPut("/{id}/confirm", ConfirmOrder.Handle)
            .WithName("ConfirmOrder")
            .Produces(StatusCodes.Status204NoContent);
    }
}

// En Program.cs
app.MapOrderEndpoints();
app.MapUserEndpoints();
app.MapProductEndpoints();
```

### 4. Vista Física (Physical View) 🖥️
**Audiencia**: Ingenieros de sistemas, DevOps
**Propósito**: Mapeo de componentes a nodos físicos, deployment

#### Configuración de Deployment

**Docker Compose para desarrollo:**

```yaml
# docker-compose.yml
version: '3.8'

services:
  api:
    build: 
      context: .
      dockerfile: Dockerfile
    ports:
      - "5000:80"
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ConnectionStrings__DefaultConnection=Server=sqlserver;Database=AppDb;User=sa;Password=YourPass123!
    depends_on:
      - sqlserver
      - redis
    networks:
      - app-network

  sqlserver:
    image: mcr.microsoft.com/mssql/server:2022-latest
    environment:
      - ACCEPT_EULA=Y
      - SA_PASSWORD=YourPass123!
    ports:
      - "1433:1433"
    volumes:
      - sqldata:/var/opt/mssql
    networks:
      - app-network

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    networks:
      - app-network

  dapr-placement:
    image: daprio/dapr:latest
    command: ["./placement", "-port", "50006"]
    ports:
      - "50006:50006"
    networks:
      - app-network

volumes:
  sqldata:

networks:
  app-network:
    driver: bridge
```

**Kubernetes Deployment:**

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "api"
        dapr.io/app-port: "80"
        dapr.io/enable-api-logging: "true"
    spec:
      containers:
      - name: api
        image: myregistry.azurecr.io/api:latest
        ports:
        - containerPort: 80
        env:
        - name: ASPNETCORE_ENVIRONMENT
          value: "Production"
        - name: ConnectionStrings__DefaultConnection
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: connection-string
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  selector:
    app: api
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
```

### 5. Vista de Escenarios (+1) 📋
**Audiencia**: Todos los stakeholders
**Propósito**: Casos de uso que ilustran cómo las 4 vistas trabajan juntas

#### Escenario 1: Crear y Procesar Pedido

**Flujo:**
1. Usuario envía petición HTTP POST a `/api/orders`
2. Endpoint llama a `CreateOrderCommandHandler` (Vista Lógica)
3. Handler crea entidad `Order` en el dominio (Vista Lógica)
4. Order se persiste en la base de datos (Vista Física)
5. Se publica evento `OrderCreatedEvent` vía Dapr (Vista de Proceso)
6. Background Worker procesa el pedido (Vista de Proceso)
7. Se envía notificación al cliente

**Implementación Completa:**

```csharp
// 1. Endpoint (Vista de Desarrollo)
// Api/Endpoints/Orders/CreateOrder.cs
public static class CreateOrder
{
    public record Request(string CustomerId, List<ItemDto> Items);
    public record ItemDto(string ProductId, int Quantity);

    public static async Task<IResult> Handle(
        Request request,
        CreateOrderCommandHandler handler,
        IEventBus eventBus)
    {
        // Vista Lógica - Ejecutar caso de uso
        var orderId = await handler.HandleAsync(
            new CreateOrderCommand(request.CustomerId, request.Items));

        // Vista de Proceso - Publicar evento
        await eventBus.PublishAsync("orders", new OrderCreatedEvent(
            orderId, 
            request.CustomerId, 
            DateTime.UtcNow));

        return Results.Created($"/api/orders/{orderId}", new { orderId });
    }
}

// 2. Suscriptor del evento
// Api/Endpoints/Orders/OrderEventHandlers.cs
public static void MapOrderEventHandlers(this IEndpointRouteBuilder app)
{
    app.MapPost("/api/events/order-created", async (
        [FromBody] OrderCreatedEvent @event,
        IOrderService orderService,
        INotificationService notificationService) =>
    {
        // Procesar el pedido
        await orderService.ProcessOrderAsync(@event.OrderId);
        
        // Enviar notificación
        await notificationService.SendOrderConfirmationAsync(
            @event.CustomerId, 
            @event.OrderId);

        return Results.Ok();
    })
    .WithTopic("pubsub", "orders")
    .WithName("HandleOrderCreated")
    .ExcludeFromDescription();
}
```

#### Escenario 2: Consultar Estado de Pedido

**Flujo:**
1. Usuario envía GET a `/api/orders/{id}`
2. Query handler recupera datos (Vista Lógica)
3. Datos se obtienen de cache (Redis) o DB (Vista Física)
4. Se retorna DTO al cliente

```csharp
// Api/Endpoints/Orders/GetOrder.cs
public static class GetOrder
{
    public static async Task<IResult> Handle(
        Guid id,
        IRepository<Order> repository,
        DaprClient daprClient)
    {
        // Intentar obtener de cache (Vista Física - Redis via Dapr)
        var cachedOrder = await daprClient.GetStateAsync<OrderDto>(
            "statestore", 
            $"order-{id}");

        if (cachedOrder != null)
            return Results.Ok(cachedOrder);

        // Si no está en cache, obtener de DB (Vista Lógica)
        var order = await repository.GetByIdAsync(id);
        if (order == null)
            return Results.NotFound();

        var dto = new OrderDto(
            order.Id,
            order.CustomerId,
            order.Status.ToString(),
            order.Items.Select(i => new OrderItemDto(
                i.ProductId, 
                i.Quantity, 
                i.Price)).ToList());

        // Guardar en cache para próximas consultas
        await daprClient.SaveStateAsync("statestore", $"order-{id}", dto);

        return Results.Ok(dto);
    }
}
```

## Integración con la Solución

### Program.cs Completo siguiendo 4+1

```csharp
using Api.Extensions;
using Api.Endpoints.Orders;
using Api.Endpoints.Users;

var builder = WebApplication.CreateBuilder(args);

// Configuración por capas (Vista de Desarrollo)
builder.Services
    .AddDomainServices()
    .AddApplicationServices()
    .AddInfrastructureServices(builder.Configuration);

// Dapr para procesamiento distribuido (Vista de Proceso)
builder.Services.AddControllers().AddDapr();
builder.Services.AddDaprClient();

// Background services (Vista de Proceso)
builder.Services.AddHostedService<OrderProcessingWorker>();

// API Documentation (Vista Lógica)
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// CORS (Vista Física)
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
        policy.WithOrigins("http://localhost:5173")
              .AllowAnyHeader()
              .AllowAnyMethod());
});

var app = builder.Build();

// Middleware pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors();
app.UseHttpsRedirection();

// Dapr middleware (Vista de Proceso)
app.UseCloudEvents();
app.MapSubscribeHandler();

// Endpoints organizados por módulo (Vista de Desarrollo)
app.MapOrderEndpoints();
app.MapOrderEventHandlers();
app.MapUserEndpoints();

// Health checks (Vista Física)
app.MapHealthChecks("/health");

app.Run();
```

## Beneficios del Modelo 4+1

1. **Separación de Concerns**: Cada vista aborda preocupaciones específicas
2. **Comunicación Efectiva**: Diferentes stakeholders entienden la arquitectura desde su perspectiva
3. **Documentación Clara**: La arquitectura está bien documentada y es fácil de mantener
4. **Flexibilidad**: Las vistas son independientes pero coherentes
5. **Escalabilidad**: Facilita el crecimiento del sistema

## Herramientas de Documentación

### C4 Model con PlantUML

```plantuml
@startuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Container.puml

Person(user, "Usuario", "Cliente que usa la aplicación")
System_Boundary(api, "API System") {
    Container(webapp, "Web API", ".NET 10", "Proporciona endpoints REST")
    Container(worker, "Background Worker", ".NET 10", "Procesa pedidos")
    ContainerDb(db, "Database", "SQL Server", "Almacena datos")
    Container(cache, "Cache", "Redis", "Cache de datos")
}

Rel(user, webapp, "Usa", "HTTPS")
Rel(webapp, db, "Lee/Escribe", "EF Core")
Rel(webapp, cache, "Usa", "Dapr")
Rel(worker, db, "Lee/Escribe")
Rel(webapp, worker, "Publica eventos", "Dapr Pub/Sub")

@enduml
```

## Referencias

- [4+1 Architectural View Model - Philippe Kruchten](https://www.cs.ubc.ca/~gregor/teaching/papers/4+1view-architecture.pdf)
- [C4 Model](https://c4model.com/)
- [Clean Architecture - Robert C. Martin](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Vertical Slice Architecture](https://www.jimmybogard.com/vertical-slice-architecture/)
