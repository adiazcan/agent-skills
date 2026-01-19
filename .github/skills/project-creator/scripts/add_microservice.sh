#!/bin/bash

# Script para añadir un nuevo microservicio a la solución
# Uso: ./add_microservice.sh <nombre-microservicio> <puerto-app> <puerto-dapr> <ruta-solucion>

set -e

SERVICE_NAME=${1:-"NewService"}
APP_PORT=${2:-"5001"}
DAPR_PORT=${3:-"3501"}
SOLUTION_PATH=${4:-"./"}

echo "🚀 Añadiendo microservicio: $SERVICE_NAME"
echo "📂 Ubicación: $SOLUTION_PATH"
echo "🔌 Puerto App: $APP_PORT, Puerto Dapr: $DAPR_PORT"

cd "$SOLUTION_PATH"

# Verificar que existe el archivo de solución
SLN_FILE=$(find . -maxdepth 1 -name "*.sln" | head -n 1)
if [ -z "$SLN_FILE" ]; then
    echo "❌ No se encontró archivo .sln en $SOLUTION_PATH"
    exit 1
fi

SOLUTION_NAME=$(basename "$SLN_FILE" .sln)
PROJECT_NAME="${SOLUTION_NAME}.${SERVICE_NAME}"

echo "📋 Solución: $SOLUTION_NAME"
echo "📦 Proyecto: $PROJECT_NAME"

# Crear directorio del servicio
mkdir -p "services/$SERVICE_NAME"
cd "services/$SERVICE_NAME"

# Crear el proyecto .NET
echo "🔧 Creando proyecto .NET Minimal API..."
dotnet new webapi -n "$PROJECT_NAME" --use-minimal-apis --framework net10.0

cd "$PROJECT_NAME"

# Agregar paquetes necesarios
echo "📦 Instalando paquetes NuGet..."
dotnet add package Swashbuckle.AspNetCore
dotnet add package Microsoft.AspNetCore.OpenApi
dotnet add package Microsoft.AspNetCore.Cors
dotnet add package Dapr.AspNetCore
dotnet add package Dapr.Client

# Crear estructura basada en Modelo 4+1
echo "📐 Creando estructura basada en Modelo 4+1..."
mkdir -p Domain/Entities
mkdir -p Domain/ValueObjects
mkdir -p Domain/Interfaces
mkdir -p Application/Commands
mkdir -p Application/Queries
mkdir -p Application/DTOs
mkdir -p Application/Validators
mkdir -p Infrastructure/Persistence
mkdir -p Infrastructure/Messaging
mkdir -p Infrastructure/ExternalServices
mkdir -p Endpoints
mkdir -p Extensions

# Crear appsettings.json
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
  },
  "ServiceName": "SERVICE_NAME_PLACEHOLDER",
  "ServicePort": SERVICE_PORT_PLACEHOLDER
}
EOF

# Reemplazar placeholders
sed -i "s/SERVICE_NAME_PLACEHOLDER/$SERVICE_NAME/g" appsettings.json
sed -i "s/SERVICE_PORT_PLACEHOLDER/$APP_PORT/g" appsettings.json

# Crear Program.cs
cat > Program.cs << 'EOF'
using Microsoft.OpenApi.Models;
using Dapr.Client;

var builder = WebApplication.CreateBuilder(args);

builder.AddServiceDefaults();

var serviceName = builder.Configuration["ServiceName"] ?? "UnknownService";

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
        Title = $"{serviceName} API",
        Version = "v1",
        Description = $"Microservicio {serviceName} con .NET 10 y Dapr"
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
        c.SwaggerEndpoint("/swagger/v1/swagger.json", $"{serviceName} API v1");
        c.RoutePrefix = string.Empty;
    });
}

app.UseCors();
app.UseHttpsRedirection();

// Habilitar Dapr
app.UseCloudEvents();
app.MapSubscribeHandler();

// Endpoints del microservicio
app.MapGet("/api/health", () => Results.Ok(new 
{ 
    service = serviceName,
    status = "healthy", 
    timestamp = DateTime.UtcNow 
}))
    .WithName($"{serviceName}_HealthCheck")
    .WithTags("Health")
    .WithOpenApi();

app.MapGet("/api/info", () => Results.Ok(new 
{ 
    service = serviceName,
    version = "1.0.0",
    framework = ".NET 10",
    description = $"Microservicio {serviceName}"
}))
    .WithName($"{serviceName}_GetInfo")
    .WithTags("Info")
    .WithOpenApi();

// Ejemplo de comunicación entre servicios
app.MapGet("/api/call/{serviceId}/{method}", async (
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
        return Results.Ok(new { calledService = serviceId, response });
    }
    catch (Exception ex)
    {
        return Results.Problem($"Error calling service {serviceId}: {ex.Message}");
    }
})
.WithName($"{serviceName}_CallService")
.WithTags("Service-to-Service")
.WithOpenApi();

// State management
app.MapGet("/api/state/{key}", async (string key, DaprClient daprClient) =>
{
    try
    {
        var value = await daprClient.GetStateAsync<string>("statestore", key);
        return value != null 
            ? Results.Ok(new { service = serviceName, key, value })
            : Results.NotFound(new { message = "Key not found" });
    }
    catch (Exception ex)
    {
        return Results.Problem(ex.Message);
    }
})
.WithName($"{serviceName}_GetState")
.WithTags("State")
.WithOpenApi();

app.MapPost("/api/state/{key}", async (string key, StateValue request, DaprClient daprClient) =>
{
    try
    {
        await daprClient.SaveStateAsync("statestore", key, request.Value);
        return Results.Ok(new { service = serviceName, message = "State saved", key });
    }
    catch (Exception ex)
    {
        return Results.Problem(ex.Message);
    }
})
.WithName($"{serviceName}_SaveState")
.WithTags("State")
.WithOpenApi();

// Pub/Sub
app.MapPost("/api/publish/{topic}", async (string topic, EventData eventData, DaprClient daprClient) =>
{
    try
    {
        await daprClient.PublishEventAsync("pubsub", topic, eventData);
        return Results.Ok(new { service = serviceName, message = "Event published", topic });
    }
    catch (Exception ex)
    {
        return Results.Problem(ex.Message);
    }
})
.WithName($"{serviceName}_PublishEvent")
.WithTags("PubSub")
.WithOpenApi();

app.MapDefaultEndpoints();

app.Run();

// Modelos
public record StateValue(string Value);
public record EventData(string Message, DateTime Timestamp, string Source);
EOF

# Crear README del servicio
cat > README.md << EOF
# $SERVICE_NAME Microservice

Microservicio $SERVICE_NAME como parte de la arquitectura de microservicios $SOLUTION_NAME.

## Configuración

- **Puerto aplicación**: $APP_PORT
- **Puerto Dapr**: $DAPR_PORT
- **App ID Dapr**: ${SERVICE_NAME,,}

## Ejecutar

### Con .NET Aspire (recomendado)
Actualiza el AppHost para registrar el servicio y ejecuta:

\`\`\`bash
cd ../../${SOLUTION_NAME}.AppHost
dotnet run
\`\`\`

### Sin Dapr
\`\`\`bash
dotnet run
\`\`\`

### Con Dapr
\`\`\`bash
dapr run --app-id ${SERVICE_NAME,,} --app-port $APP_PORT --dapr-http-port $DAPR_PORT -- dotnet run
\`\`\`

## Endpoints

- \`GET /api/health\` - Health check
- \`GET /api/info\` - Información del servicio
- \`GET /api/call/{serviceId}/{method}\` - Llamar otro servicio
- \`GET /api/state/{key}\` - Obtener estado
- \`POST /api/state/{key}\` - Guardar estado
- \`POST /api/publish/{topic}\` - Publicar evento

## Swagger

Disponible en: \`http://localhost:$APP_PORT/\`

## Arquitectura

Este microservicio sigue el Modelo 4+1 de Kruchten:
- **Domain/**: Lógica de negocio
- **Application/**: Casos de uso (Commands/Queries)
- **Infrastructure/**: Implementaciones técnicas
- **Endpoints/**: API endpoints
- **Extensions/**: Configuración modular
EOF

# Volver a la raíz de la solución
cd ../../..

# Agregar el proyecto a la solución
echo "➕ Agregando proyecto a la solución..."
dotnet sln "$SLN_FILE" add "services/$SERVICE_NAME/$PROJECT_NAME/$PROJECT_NAME.csproj"

# Integración con .NET Aspire (ServiceDefaults + AppHost)
SERVICE_DEFAULTS_PROJECT="${SOLUTION_NAME}.ServiceDefaults/${SOLUTION_NAME}.ServiceDefaults.csproj"
APPHOST_PROJECT="${SOLUTION_NAME}.AppHost/${SOLUTION_NAME}.AppHost.csproj"

if [ -f "$SERVICE_DEFAULTS_PROJECT" ]; then
    echo "☁️  Añadiendo referencia a ServiceDefaults..."
    dotnet add "services/$SERVICE_NAME/$PROJECT_NAME/$PROJECT_NAME.csproj" reference "$SERVICE_DEFAULTS_PROJECT"
fi

if [ -f "$APPHOST_PROJECT" ]; then
    echo "☁️  Añadiendo referencia del microservicio al AppHost..."
    dotnet add "$APPHOST_PROJECT" reference "services/$SERVICE_NAME/$PROJECT_NAME/$PROJECT_NAME.csproj"
    echo "ℹ️  Actualiza ${SOLUTION_NAME}.AppHost/Program.cs para registrar el nuevo servicio en Aspire."
fi

# Crear archivo de configuración Dapr para el servicio
echo "📝 Creando configuración Dapr..."
mkdir -p dapr-config/components

# Actualizar docker-compose si existe
if [ -f "docker-compose.yml" ]; then
    echo "🐳 Actualizando docker-compose.yml..."
    
    # Crear entrada para el nuevo servicio
    cat >> docker-compose.yml << EOF

  ${SERVICE_NAME,,}:
    build:
      context: ./services/$SERVICE_NAME
      dockerfile: Dockerfile
    ports:
      - "$APP_PORT:80"
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ServiceName=$SERVICE_NAME
    depends_on:
      - redis
      - sqlserver
    networks:
      - microservices-network
EOF
fi

# Crear Dockerfile para el servicio
cat > "services/$SERVICE_NAME/Dockerfile" << EOF
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS base
WORKDIR /app
EXPOSE 80

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY ["$PROJECT_NAME/$PROJECT_NAME.csproj", "$PROJECT_NAME/"]
RUN dotnet restore "$PROJECT_NAME/$PROJECT_NAME.csproj"
COPY . .
WORKDIR "/src/$PROJECT_NAME"
RUN dotnet build "$PROJECT_NAME.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "$PROJECT_NAME.csproj" -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "$PROJECT_NAME.dll"]
EOF

# Crear script de ejecución con Dapr
cat > "services/$SERVICE_NAME/run-with-dapr.sh" << EOF
#!/bin/bash
cd $PROJECT_NAME
dapr run --app-id ${SERVICE_NAME,,} --app-port $APP_PORT --dapr-http-port $DAPR_PORT --components-path ../../dapr-config/components -- dotnet run
EOF

chmod +x "services/$SERVICE_NAME/run-with-dapr.sh"

echo ""
echo "✅ ¡Microservicio $SERVICE_NAME creado exitosamente!"
echo ""
echo "📁 Ubicación: services/$SERVICE_NAME/$PROJECT_NAME"
echo ""
echo "🚀 Para ejecutar el servicio:"
echo ""
echo "   Opción 1 - Sin Dapr:"
echo "   cd services/$SERVICE_NAME/$PROJECT_NAME"
echo "   dotnet run"
echo ""
echo "   Opción 2 - Con Dapr:"
echo "   cd services/$SERVICE_NAME"
echo "   ./run-with-dapr.sh"
echo ""
echo "   Opción 3 - Con Dapr (manual):"
echo "   cd services/$SERVICE_NAME/$PROJECT_NAME"
echo "   dapr run --app-id ${SERVICE_NAME,,} --app-port $APP_PORT --dapr-http-port $DAPR_PORT -- dotnet run"
echo ""
echo "🌐 Swagger UI: http://localhost:$APP_PORT/"
echo "📖 Health Check: http://localhost:$APP_PORT/api/health"
echo ""
echo "💡 Tip: El servicio ya está agregado a la solución $SOLUTION_NAME.sln"
