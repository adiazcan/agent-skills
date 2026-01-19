# Arquitectura de Microservicios con .NET 10 y Dapr

Este documento describe los patrones y prácticas recomendadas para construir una arquitectura de microservicios utilizando .NET 10, Dapr y React.

## Tabla de Contenidos

1. [Introducción](#introducción)
2. [Principios Fundamentales](#principios-fundamentales)
3. [Componentes de la Arquitectura](#componentes-de-la-arquitectura)
4. [Patrones de Comunicación](#patrones-de-comunicación)
5. [Data Management](#data-management)
6. [API Gateway con YARP](#api-gateway-con-yarp)
7. [Service Discovery](#service-discovery)
8. [Resiliencia y Fault Tolerance](#resiliencia-y-fault-tolerance)
9. [Observabilidad](#observabilidad)
10. [Deployment](#deployment)

## Introducción

Una arquitectura de microservicios divide una aplicación en servicios pequeños, independientes y desplegables que se comunican entre sí. Esta arquitectura proporciona:

- **Escalabilidad independiente**: Cada servicio puede escalar según sus necesidades
- **Despliegue independiente**: Los servicios se pueden actualizar sin afectar a otros
- **Aislamiento de fallos**: Un fallo en un servicio no colapsa toda la aplicación
- **Flexibilidad tecnológica**: Cada servicio puede usar diferentes tecnologías
- **Equipos autónomos**: Los equipos pueden trabajar en servicios de forma independiente

## Principios Fundamentales

### 1. Single Responsibility

Cada microservicio debe tener una única responsabilidad de negocio bien definida.

```csharp
// ❌ MAL - Servicio que hace demasiado
public class MonolithService
{
    public void CreateUser() { }
    public void CreateOrder() { }
    public void ProcessPayment() { }
    public void SendEmail() { }
}

// ✅ BIEN - Servicios con responsabilidades únicas
// UserService
public class UserService
{
    public Task<User> CreateUserAsync(CreateUserCommand command) { }
    public Task<User> GetUserAsync(Guid userId) { }
}

// OrderService
public class OrderService
{
    public Task<Order> CreateOrderAsync(CreateOrderCommand command) { }
    public Task<Order> GetOrderAsync(Guid orderId) { }
}
```

### 2. Database per Service

Cada microservicio debe tener su propia base de datos para garantizar el desacoplamiento.

```yaml
services:
  user-service:
    image: user-service:latest
    environment:
      - ConnectionString=Server=userdb;Database=Users;
    depends_on:
      - userdb
      
  order-service:
    image: order-service:latest
    environment:
      - ConnectionString=Server=orderdb;Database=Orders;
    depends_on:
      - orderdb
      
  userdb:
    image: postgres:15
    
  orderdb:
    image: postgres:15
```

### 3. API First

Diseñar las APIs antes de la implementación usando OpenAPI/Swagger.

```csharp
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "User Service API",
        Version = "v1",
        Description = "Gestión de usuarios",
        Contact = new OpenApiContact
        {
            Name = "Team Users",
            Email = "team-users@company.com"
        }
    });
    
    // Incluir comentarios XML
    var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    c.IncludeXmlComments(xmlPath);
});
```

## Componentes de la Arquitectura

### API Gateway

El API Gateway es el punto de entrada único para todos los clientes. En nuestra arquitectura usamos **YARP (Yet Another Reverse Proxy)**.

```csharp
// Program.cs del Gateway
var builder = WebApplication.CreateBuilder(args);

// Configurar YARP
builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"));

// Rate Limiting
builder.Services.AddRateLimiter(options =>
{
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: context.User.Identity?.Name ?? context.Request.Headers.Host.ToString(),
            factory: partition => new FixedWindowRateLimiterOptions
            {
                AutoReplenishment = true,
                PermitLimit = 100,
                QueueLimit = 0,
                Window = TimeSpan.FromMinutes(1)
            }));
});

var app = builder.Build();

app.UseRateLimiter();
app.MapReverseProxy();

app.Run();
```

Configuración en `appsettings.json`:

```json
{
  "ReverseProxy": {
    "Routes": {
      "user-service-route": {
        "ClusterId": "user-service",
        "Match": {
          "Path": "/api/users/{**catch-all}"
        },
        "Transforms": [
          { "PathPattern": "/api/{**catch-all}" }
        ]
      },
      "order-service-route": {
        "ClusterId": "order-service",
        "Match": {
          "Path": "/api/orders/{**catch-all}"
        },
        "Transforms": [
          { "PathPattern": "/api/{**catch-all}" }
        ]
      }
    },
    "Clusters": {
      "user-service": {
        "Destinations": {
          "destination1": {
            "Address": "http://user-service:80"
          },
          "destination2": {
            "Address": "http://user-service-2:80"
          }
        },
        "LoadBalancingPolicy": "RoundRobin"
      },
      "order-service": {
        "Destinations": {
          "destination1": {
            "Address": "http://order-service:80"
          }
        }
      }
    }
  }
}
```

### Service Registry & Discovery

Con Dapr, el service discovery es automático. Los servicios se comunican usando App IDs:

```csharp
// Llamar a otro servicio por su App ID
var orderData = await daprClient.InvokeMethodAsync<OrderResponse>(
    HttpMethod.Get,
    "order-service",  // App ID del servicio
    "api/orders/12345"
);
```

## Patrones de Comunicación

### 1. Comunicación Síncrona (HTTP)

Usar para operaciones que requieren respuesta inmediata.

```csharp
// Service-to-Service con Dapr
app.MapPost("/api/orders", async (CreateOrderRequest request, DaprClient daprClient) =>
{
    // 1. Verificar usuario
    var user = await daprClient.InvokeMethodAsync<UserResponse>(
        HttpMethod.Get,
        "user-service",
        $"api/users/{request.UserId}"
    );
    
    if (user == null)
        return Results.NotFound("User not found");
    
    // 2. Crear orden
    var order = new Order
    {
        Id = Guid.NewGuid(),
        UserId = request.UserId,
        Items = request.Items,
        Total = request.Items.Sum(i => i.Price * i.Quantity)
    };
    
    // 3. Guardar en state store
    await daprClient.SaveStateAsync("statestore", order.Id.ToString(), order);
    
    return Results.Created($"/api/orders/{order.Id}", order);
});
```

### 2. Comunicación Asíncrona (Pub/Sub)

Usar para eventos y operaciones que no requieren respuesta inmediata.

**Publicar evento:**

```csharp
// OrderService - Publicar evento cuando se crea una orden
app.MapPost("/api/orders", async (CreateOrderRequest request, DaprClient daprClient) =>
{
    var order = new Order { /* ... */ };
    
    // Guardar orden
    await daprClient.SaveStateAsync("statestore", order.Id.ToString(), order);
    
    // Publicar evento
    var orderCreatedEvent = new OrderCreatedEvent
    {
        OrderId = order.Id,
        UserId = order.UserId,
        Total = order.Total,
        Timestamp = DateTime.UtcNow
    };
    
    await daprClient.PublishEventAsync("pubsub", "order-created", orderCreatedEvent);
    
    return Results.Created($"/api/orders/{order.Id}", order);
});
```

**Suscribirse a evento:**

```csharp
// NotificationService - Escuchar evento y enviar notificación
app.MapPost("/api/events/order-created", 
    [Topic("pubsub", "order-created")] 
    async (OrderCreatedEvent evt, DaprClient daprClient) =>
{
    // Obtener información del usuario
    var user = await daprClient.InvokeMethodAsync<UserResponse>(
        HttpMethod.Get,
        "user-service",
        $"api/users/{evt.UserId}"
    );
    
    // Enviar notificación
    await SendEmailAsync(user.Email, "Order Created", 
        $"Your order {evt.OrderId} has been created. Total: ${evt.Total}");
    
    return Results.Ok();
});

// Registrar suscripciones
app.MapSubscribeHandler();
```

### 3. Event Sourcing

Almacenar todos los cambios como una secuencia de eventos.

```csharp
public class OrderAggregate
{
    public Guid Id { get; private set; }
    public OrderStatus Status { get; private set; }
    private readonly List<IEvent> _events = new();
    
    public void Create(CreateOrderCommand command)
    {
        ApplyEvent(new OrderCreatedEvent
        {
            OrderId = Guid.NewGuid(),
            UserId = command.UserId,
            Items = command.Items,
            Timestamp = DateTime.UtcNow
        });
    }
    
    public void ConfirmPayment(Guid paymentId)
    {
        ApplyEvent(new PaymentConfirmedEvent
        {
            OrderId = Id,
            PaymentId = paymentId,
            Timestamp = DateTime.UtcNow
        });
    }
    
    private void ApplyEvent(IEvent evt)
    {
        _events.Add(evt);
        
        switch (evt)
        {
            case OrderCreatedEvent e:
                Id = e.OrderId;
                Status = OrderStatus.Created;
                break;
            case PaymentConfirmedEvent e:
                Status = OrderStatus.Paid;
                break;
        }
    }
    
    public IEnumerable<IEvent> GetUncommittedEvents() => _events;
}
```

### 4. CQRS (Command Query Responsibility Segregation)

Separar operaciones de lectura y escritura.

```csharp
// Commands (escritura)
public record CreateOrderCommand(Guid UserId, List<OrderItem> Items);
public record CancelOrderCommand(Guid OrderId);

// Queries (lectura)
public record GetOrderQuery(Guid OrderId);
public record GetUserOrdersQuery(Guid UserId);

// Command Handler
public class CreateOrderCommandHandler
{
    private readonly DaprClient _daprClient;
    
    public async Task<Order> HandleAsync(CreateOrderCommand command)
    {
        var order = new Order { /* ... */ };
        await _daprClient.SaveStateAsync("statestore", order.Id.ToString(), order);
        await _daprClient.PublishEventAsync("pubsub", "order-created", order);
        return order;
    }
}

// Query Handler (podría leer de una DB de solo lectura optimizada)
public class GetOrderQueryHandler
{
    private readonly DaprClient _daprClient;
    
    public async Task<Order?> HandleAsync(GetOrderQuery query)
    {
        return await _daprClient.GetStateAsync<Order>("statestore", query.OrderId.ToString());
    }
}
```

## Data Management

### Saga Pattern

Para transacciones distribuidas que involucran múltiples servicios.

```csharp
// Saga Orchestrator
public class CreateOrderSaga
{
    private readonly DaprClient _daprClient;
    
    public async Task<SagaResult> ExecuteAsync(CreateOrderCommand command)
    {
        var sagaId = Guid.NewGuid();
        var compensations = new Stack<Func<Task>>();
        
        try
        {
            // Paso 1: Reservar inventario
            var inventory = await _daprClient.InvokeMethodAsync<ReserveInventoryResponse>(
                HttpMethod.Post,
                "inventory-service",
                "api/inventory/reserve",
                command.Items
            );
            
            compensations.Push(async () => 
                await _daprClient.InvokeMethodAsync(
                    HttpMethod.Post,
                    "inventory-service",
                    $"api/inventory/release/{inventory.ReservationId}"
                ));
            
            // Paso 2: Procesar pago
            var payment = await _daprClient.InvokeMethodAsync<ProcessPaymentResponse>(
                HttpMethod.Post,
                "payment-service",
                "api/payments/process",
                new { Amount = command.TotalAmount, UserId = command.UserId }
            );
            
            compensations.Push(async () => 
                await _daprClient.InvokeMethodAsync(
                    HttpMethod.Post,
                    "payment-service",
                    $"api/payments/refund/{payment.PaymentId}"
                ));
            
            // Paso 3: Crear orden
            var order = await _daprClient.InvokeMethodAsync<Order>(
                HttpMethod.Post,
                "order-service",
                "api/orders",
                command
            );
            
            return SagaResult.Success(order);
        }
        catch (Exception ex)
        {
            // Ejecutar compensaciones en orden inverso
            while (compensations.Count > 0)
            {
                var compensation = compensations.Pop();
                try
                {
                    await compensation();
                }
                catch (Exception compensationEx)
                {
                    // Log error de compensación
                }
            }
            
            return SagaResult.Failed(ex.Message);
        }
    }
}
```

### Outbox Pattern

Garantizar consistencia entre base de datos y mensajería.

```csharp
public class OrderRepository
{
    private readonly DbContext _context;
    
    public async Task CreateOrderAsync(Order order, OrderCreatedEvent evt)
    {
        using var transaction = await _context.Database.BeginTransactionAsync();
        
        try
        {
            // 1. Guardar orden en DB
            _context.Orders.Add(order);
            
            // 2. Guardar evento en tabla Outbox
            _context.OutboxMessages.Add(new OutboxMessage
            {
                Id = Guid.NewGuid(),
                Type = nameof(OrderCreatedEvent),
                Payload = JsonSerializer.Serialize(evt),
                CreatedAt = DateTime.UtcNow
            });
            
            await _context.SaveChangesAsync();
            await transaction.CommitAsync();
        }
        catch
        {
            await transaction.RollbackAsync();
            throw;
        }
    }
}

// Background service para procesar mensajes Outbox
public class OutboxProcessor : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly DaprClient _daprClient;
    
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            using var scope = _serviceProvider.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<DbContext>();
            
            var messages = await context.OutboxMessages
                .Where(m => !m.Processed)
                .OrderBy(m => m.CreatedAt)
                .Take(10)
                .ToListAsync(stoppingToken);
            
            foreach (var message in messages)
            {
                try
                {
                    // Publicar evento
                    await _daprClient.PublishEventAsync(
                        "pubsub",
                        message.Type.ToLower(),
                        message.Payload,
                        stoppingToken
                    );
                    
                    // Marcar como procesado
                    message.Processed = true;
                    message.ProcessedAt = DateTime.UtcNow;
                }
                catch
                {
                    message.RetryCount++;
                    message.LastError = DateTime.UtcNow;
                }
            }
            
            await context.SaveChangesAsync(stoppingToken);
            await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken);
        }
    }
}
```

## API Gateway con YARP

### Transformaciones

```json
{
  "Routes": {
    "user-route": {
      "ClusterId": "user-service",
      "Match": {
        "Path": "/api/users/{**catch-all}"
      },
      "Transforms": [
        // Reescribir path
        { "PathPattern": "/api/{**catch-all}" },
        // Agregar header
        { "RequestHeader": "X-Gateway", "Set": "YARP" },
        // Remover header de respuesta
        { "ResponseHeader": "Server", "Set": "" }
      ]
    }
  }
}
```

### Health Checks

```csharp
builder.Services.AddHealthChecks()
    .AddCheck("user-service", () =>
    {
        // Check user service
        return HealthCheckResult.Healthy();
    })
    .AddCheck("order-service", () =>
    {
        // Check order service
        return HealthCheckResult.Healthy();
    });

app.MapHealthChecks("/health");
```

## Resiliencia y Fault Tolerance

### Circuit Breaker con Polly

```csharp
builder.Services.AddHttpClient("user-service")
    .AddTransientHttpErrorPolicy(policy =>
        policy.CircuitBreakerAsync(
            handledEventsAllowedBeforeBreaking: 3,
            durationOfBreak: TimeSpan.FromSeconds(30)
        ));

builder.Services.AddHttpClient("order-service")
    .AddTransientHttpErrorPolicy(policy =>
        policy.WaitAndRetryAsync(
            retryCount: 3,
            sleepDurationProvider: retryAttempt => 
                TimeSpan.FromSeconds(Math.Pow(2, retryAttempt))
        ));
```

### Timeout

```csharp
var response = await daprClient.InvokeMethodAsync<OrderResponse>(
    HttpMethod.Get,
    "order-service",
    "api/orders/123",
    cancellationToken: new CancellationTokenSource(TimeSpan.FromSeconds(5)).Token
);
```

## Observabilidad

### Distributed Tracing

Dapr proporciona tracing automático. Configurar Zipkin:

```yaml
# dapr-config/tracing.yaml
apiVersion: dapr.io/v1alpha1
kind: Configuration
metadata:
  name: tracing
spec:
  tracing:
    samplingRate: "1"
    zipkin:
      endpointAddress: "http://zipkin:9411/api/v2/spans"
```

### Metrics

```csharp
builder.Services.AddOpenTelemetry()
    .WithMetrics(metrics =>
    {
        metrics
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddRuntimeInstrumentation()
            .AddPrometheusExporter();
    });

app.UseOpenTelemetryPrometheusScrapingEndpoint();
```

### Structured Logging

```csharp
builder.Services.AddLogging(logging =>
{
    logging.AddConsole();
    logging.AddDebug();
});

// En el código
logger.LogInformation("Order {OrderId} created by user {UserId}", 
    order.Id, order.UserId);
```

## Deployment

### Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "user-service"
        dapr.io/app-port: "80"
        dapr.io/enable-api-logging: "true"
    spec:
      containers:
      - name: user-service
        image: user-service:latest
        ports:
        - containerPort: 80
        env:
        - name: ASPNETCORE_ENVIRONMENT
          value: "Production"
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
  name: user-service
spec:
  selector:
    app: user-service
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
```

### Scaling

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: user-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: user-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## Best Practices

1. **Versionado de APIs**: Usar versionado semántico (v1, v2, etc.)
2. **Idempotencia**: Operaciones deben ser idempotentes
3. **Timeouts**: Siempre establecer timeouts en llamadas entre servicios
4. **Circuit Breakers**: Implementar para evitar cascadas de fallos
5. **Health Checks**: Cada servicio debe exponer endpoints de health
6. **Logging**: Usar logging estructurado con correlation IDs
7. **Secrets**: Nunca hardcodear secretos, usar Dapr Secrets
8. **Testing**: Unit tests, integration tests y contract tests
9. **Documentation**: Mantener Swagger actualizado
10. **Monitoring**: Implementar alertas proactivas

## Recursos

- [Dapr Documentation](https://docs.dapr.io/)
- [YARP Documentation](https://microsoft.github.io/reverse-proxy/)
- [.NET Microservices Architecture](https://docs.microsoft.com/en-us/dotnet/architecture/microservices/)
- [Building Microservices by Sam Newman](https://www.oreilly.com/library/view/building-microservices-2nd/9781492034018/)
