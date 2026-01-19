# Integración de Dapr con .NET 10 Minimal API

## Introducción a Dapr

Dapr (Distributed Application Runtime) es un runtime portable para construir aplicaciones distribuidas resilientes, con estado y sin estado. Simplifica la construcción de microservicios proporcionando bloques de construcción como:

- **State Management**: Almacenamiento de estado persistente
- **Pub/Sub**: Mensajería asíncrona
- **Service Invocation**: Invocación de servicios con descubrimiento
- **Bindings**: Integración con sistemas externos
- **Secrets**: Gestión segura de secretos
- **Actors**: Modelo de actores para estado distribuido

## Instalación de Dapr

### Instalar Dapr CLI

```bash
# Linux/macOS
wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash

# Windows (PowerShell)
powershell -Command "iwr -useb https://raw.githubusercontent.com/dapr/cli/master/install/install.ps1 | iex"
```

### Inicializar Dapr

```bash
dapr init
```

Esto instala:
- Dapr sidecar binaries
- Redis (para state store y pub/sub)
- Zipkin (para distributed tracing)

## Configuración Básica

### 1. State Management (Gestión de Estado)

El proyecto ya incluye endpoints de ejemplo para state management:

```csharp
// Guardar estado
app.MapPost("/api/state/{key}", async (string key, StateValue request, DaprClient daprClient) =>
{
    await daprClient.SaveStateAsync("statestore", key, request.Value);
    return Results.Ok(new { message = "State saved successfully", key });
})
.WithName("SaveState")
.WithTags("Dapr")
.WithOpenApi();

// Obtener estado
app.MapGet("/api/state/{key}", async (string key, DaprClient daprClient) =>
{
    var value = await daprClient.GetStateAsync<string>("statestore", key);
    return value != null 
        ? Results.Ok(new { key, value })
        : Results.NotFound(new { message = "Key not found" });
})
.WithName("GetState")
.WithTags("Dapr")
.WithOpenApi();
```

### 2. Pub/Sub (Publicación/Suscripción)

#### Publicar Eventos

```csharp
app.MapPost("/api/publish/{topic}", async (string topic, EventData eventData, DaprClient daprClient) =>
{
    await daprClient.PublishEventAsync("pubsub", topic, eventData);
    return Results.Ok(new { message = "Event published successfully", topic });
})
.WithName("PublishEvent")
.WithTags("Dapr")
.WithOpenApi();
```

#### Suscribirse a Eventos

```csharp
// Endpoint que recibe eventos
app.MapPost("/api/subscribe/orders", async (OrderEvent orderEvent, ILogger<Program> logger) =>
{
    logger.LogInformation("Received order event: {OrderId}", orderEvent.OrderId);
    // Procesar el evento
    return Results.Ok();
})
.WithTopic("pubsub", "orders")
.WithName("SubscribeToOrders")
.WithTags("Dapr");

public record OrderEvent(string OrderId, string CustomerId, decimal Amount);
```

### 3. Service Invocation (Invocación de Servicios)

```csharp
// Invocar otro servicio Dapr
app.MapGet("/api/invoke/{serviceId}/{method}", async (
    string serviceId, 
    string method, 
    DaprClient daprClient) =>
{
    try
    {
        var response = await daprClient.InvokeMethodAsync<object>(
            HttpMethod.Get,
            serviceId,
            method
        );
        return Results.Ok(response);
    }
    catch (Exception ex)
    {
        return Results.Problem(ex.Message);
    }
})
.WithName("InvokeService")
.WithTags("Dapr")
.WithOpenApi();
```

### 4. Secrets Management

```csharp
// Obtener secreto de Dapr secret store
app.MapGet("/api/secrets/{secretName}", async (string secretName, DaprClient daprClient) =>
{
    try
    {
        var secrets = await daprClient.GetSecretAsync("localsecretstore", secretName);
        return Results.Ok(new { exists = secrets.Any() });
    }
    catch (Exception ex)
    {
        return Results.Problem(ex.Message);
    }
})
.WithName("GetSecret")
.WithTags("Dapr")
.WithOpenApi();
```

### 5. Input/Output Bindings

```csharp
// Invocar binding de salida
app.MapPost("/api/bindings/send", async (BindingRequest request, DaprClient daprClient) =>
{
    try
    {
        await daprClient.InvokeBindingAsync("outputbinding", "create", request.Data);
        return Results.Ok(new { message = "Binding invoked successfully" });
    }
    catch (Exception ex)
    {
        return Results.Problem(ex.Message);
    }
})
.WithName("InvokeBinding")
.WithTags("Dapr")
.WithOpenApi();

public record BindingRequest(object Data);
```

## Archivos de Componentes Dapr

Crea una carpeta `components` en la raíz del proyecto:

### State Store (Redis)

`components/statestore.yaml`:
```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: statestore
spec:
  type: state.redis
  version: v1
  metadata:
  - name: redisHost
    value: localhost:6379
  - name: redisPassword
    value: ""
  - name: actorStateStore
    value: "true"
```

### Pub/Sub (Redis)

`components/pubsub.yaml`:
```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: pubsub
spec:
  type: pubsub.redis
  version: v1
  metadata:
  - name: redisHost
    value: localhost:6379
  - name: redisPassword
    value: ""
```

### Secret Store (Local)

`components/localsecretstore.yaml`:
```yaml
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: localsecretstore
spec:
  type: secretstores.local.file
  version: v1
  metadata:
  - name: secretsFile
    value: ./secrets.json
  - name: nestedSeparator
    value: ":"
```

## Ejecutar con Dapr

### Modo Desarrollo Local

```bash
# Ejecutar la aplicación con Dapr
dapr run --app-id myapi --app-port 5000 --dapr-http-port 3500 --components-path ./components -- dotnet run

# Parámetros:
# --app-id: Identificador único de la aplicación
# --app-port: Puerto donde corre tu aplicación .NET
# --dapr-http-port: Puerto para la API HTTP de Dapr
# --components-path: Ruta a los componentes de Dapr
```

### Múltiples Servicios

Para ejecutar múltiples servicios simultáneamente, usa `dapr run` con diferentes app-id y puertos:

```bash
# Terminal 1 - API Backend
dapr run --app-id backend-api --app-port 5000 --dapr-http-port 3500 --components-path ./components -- dotnet run

# Terminal 2 - Otro servicio
dapr run --app-id order-service --app-port 5001 --dapr-http-port 3501 --components-path ./components -- dotnet run
```

## Patrones Avanzados

### 1. Resiliencia con Retry

```csharp
builder.Services.AddDaprClient(client =>
{
    client.UseJsonSerializationOptions(new JsonSerializerOptions
    {
        PropertyNameCaseInsensitive = true
    });
});

// Configurar política de retry
var retryPolicy = Policy
    .Handle<DaprException>()
    .WaitAndRetryAsync(3, retryAttempt => 
        TimeSpan.FromSeconds(Math.Pow(2, retryAttempt)));

// Usar en endpoint
app.MapPost("/api/reliable-publish", async (EventData data, DaprClient daprClient) =>
{
    await retryPolicy.ExecuteAsync(async () =>
    {
        await daprClient.PublishEventAsync("pubsub", "events", data);
    });
    return Results.Ok();
});
```

### 2. State Store con TTL

```csharp
app.MapPost("/api/state/ttl/{key}", async (
    string key, 
    StateValue value, 
    DaprClient daprClient,
    [FromQuery] int ttlSeconds = 60) =>
{
    var metadata = new Dictionary<string, string>
    {
        { "ttlInSeconds", ttlSeconds.ToString() }
    };
    
    await daprClient.SaveStateAsync("statestore", key, value.Value, metadata: metadata);
    return Results.Ok(new { message = "State saved with TTL", expiresIn = ttlSeconds });
});
```

### 3. Transacciones de Estado

```csharp
app.MapPost("/api/state/transaction", async (
    StateTransaction transaction,
    DaprClient daprClient) =>
{
    var operations = new List<StateTransactionRequest>
    {
        new StateTransactionRequest(
            transaction.Key1,
            JsonSerializer.SerializeToUtf8Bytes(transaction.Value1),
            StateOperationType.Upsert
        ),
        new StateTransactionRequest(
            transaction.Key2,
            JsonSerializer.SerializeToUtf8Bytes(transaction.Value2),
            StateOperationType.Upsert
        )
    };

    await daprClient.ExecuteStateTransactionAsync("statestore", operations);
    return Results.Ok(new { message = "Transaction completed" });
});

public record StateTransaction(string Key1, string Value1, string Key2, string Value2);
```

### 4. Actor Pattern

```csharp
// Instalar: dotnet add package Dapr.Actors
// Instalar: dotnet add package Dapr.Actors.AspNetCore

using Dapr.Actors;
using Dapr.Actors.Runtime;

// Definir interfaz del actor
public interface IUserActor : IActor
{
    Task<string> GetUserNameAsync();
    Task SetUserNameAsync(string name);
}

// Implementar actor
public class UserActor : Actor, IUserActor
{
    private const string UserNameKey = "username";

    public UserActor(ActorHost host) : base(host) { }

    public async Task<string> GetUserNameAsync()
    {
        return await StateManager.GetStateAsync<string>(UserNameKey);
    }

    public async Task SetUserNameAsync(string name)
    {
        await StateManager.SetStateAsync(UserNameKey, name);
    }
}

// En Program.cs, registrar actors
builder.Services.AddActors(options =>
{
    options.Actors.RegisterActor<UserActor>();
});

app.MapActorsHandlers();
```

## Observabilidad

### 1. Distributed Tracing

Dapr automáticamente propaga contextos de rastreo. Para visualizar:

```bash
# Abrir Zipkin (instalado con dapr init)
open http://localhost:9411
```

### 2. Métricas

```csharp
// Las métricas de Dapr están disponibles en
// http://localhost:9090/metrics (cuando se ejecuta con Dapr)
```

### 3. Logging

```csharp
app.MapGet("/api/test-logging", (ILogger<Program> logger) =>
{
    logger.LogInformation("Processing request with Dapr");
    return Results.Ok(new { message = "Check logs for Dapr context" });
});
```

## Despliegue en Kubernetes

### 1. Anotaciones de Dapr

`deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapi
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapi
  template:
    metadata:
      labels:
        app: myapi
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "myapi"
        dapr.io/app-port: "80"
        dapr.io/enable-api-logging: "true"
    spec:
      containers:
      - name: myapi
        image: myapi:latest
        ports:
        - containerPort: 80
```

### 2. Componentes en Kubernetes

Los archivos de componentes se aplican como recursos de Kubernetes:

```bash
kubectl apply -f components/statestore.yaml
kubectl apply -f components/pubsub.yaml
```

## Mejores Prácticas

1. **Usar DaprClient como Singleton**: Ya está configurado con `AddDaprClient()`
2. **Manejar errores de Dapr**: Usar try-catch para `DaprException`
3. **Configurar timeouts apropiados**: Para evitar bloqueos en llamadas a Dapr
4. **Usar componentes separados por ambiente**: Desarrollo, staging, producción
5. **Implementar circuit breakers**: Para llamadas entre servicios
6. **Aprovechar el sidecar**: Dejar que Dapr maneje retry, timeout, y circuit breaking
7. **Monitorear métricas de Dapr**: Para entender el comportamiento del sistema

## Recursos Adicionales

- [Documentación oficial de Dapr](https://docs.dapr.io/)
- [Dapr .NET SDK](https://github.com/dapr/dotnet-sdk)
- [Ejemplos de Dapr](https://github.com/dapr/samples)
- [Componentes disponibles](https://docs.dapr.io/reference/components-reference/)
