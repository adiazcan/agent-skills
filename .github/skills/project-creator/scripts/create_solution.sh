#!/bin/bash

# Script para crear una solución de Visual Studio completa con Arquitectura de Microservicios
# Uso: ./create_solution.sh <nombre-solucion> <ruta-destino> [--microservices] [--aspire]

set -e

SOLUTION_NAME=${1:-"MyApp"}
TARGET_PATH=${2:-"./"}
MICROSERVICES_MODE=""
ASPIRE_MODE=""

# Parsear argumentos
for arg in "$@"; do
    if [ "$arg" = "--microservices" ]; then
        MICROSERVICES_MODE="--microservices"
    elif [ "$arg" = "--aspire" ]; then
        ASPIRE_MODE="--aspire"
    fi
done

FULL_PATH="$TARGET_PATH/$SOLUTION_NAME"

echo "🚀 Creando solución completa: $SOLUTION_NAME"
echo "📂 Ubicación: $FULL_PATH"

if [ "$MICROSERVICES_MODE" = "--microservices" ]; then
    if [ "$ASPIRE_MODE" = "--aspire" ]; then
        echo "🔄 Modo: Arquitectura de Microservicios con .NET Aspire"
    else
        echo "🔄 Modo: Arquitectura de Microservicios"
    fi
elif [ "$ASPIRE_MODE" = "--aspire" ]; then
    echo "🔄 Modo: Monolito con .NET Aspire"
else
    echo "🔄 Modo: Monolito (usa --microservices para microservicios o --aspire para .NET Aspire)"
fi

# Crear directorio principal
mkdir -p "$FULL_PATH"
cd "$FULL_PATH"

# Crear la solución
echo "📋 Creando solución de Visual Studio..."
dotnet new sln -n "$SOLUTION_NAME"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$MICROSERVICES_MODE" = "--microservices" ]; then
    # MODO MICROSERVICIOS
    echo "🏗️  Creando arquitectura de microservicios..."
    
    # Crear directorios para la arquitectura
    mkdir -p services
    mkdir -p gateway
    mkdir -p frontend
    mkdir -p dapr-config/components
    mkdir -p shared/contracts
    
    # 1. Crear API Gateway
    echo "🌐 Creando API Gateway..."
    mkdir -p gateway/ApiGateway
    cd gateway/ApiGateway
    
    dotnet new webapi -n "${SOLUTION_NAME}.Gateway" --use-minimal-apis --framework net10.0
    cd "${SOLUTION_NAME}.Gateway"
    
    dotnet add package Yarp.ReverseProxy
    dotnet add package Microsoft.AspNetCore.Cors
    
    # Crear configuración de YARP para el gateway
    cat > appsettings.json << 'GATEWAY_CONFIG'
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
            "Address": "http://localhost:5001"
          }
        }
      },
      "order-service": {
        "Destinations": {
          "destination1": {
            "Address": "http://localhost:5002"
          }
        }
      }
    }
  }
}
GATEWAY_CONFIG
    
    # Crear Program.cs del Gateway
    cat > Program.cs << 'GATEWAY_PROGRAM'
var builder = WebApplication.CreateBuilder(args);

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

// Configurar YARP Reverse Proxy
builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"));

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors();

// Health check del gateway
app.MapGet("/health", () => Results.Ok(new 
{ 
    service = "API Gateway",
    status = "healthy", 
    timestamp = DateTime.UtcNow 
}));

// Mapear el reverse proxy
app.MapReverseProxy();

app.Run();
GATEWAY_PROGRAM
    
    cd ../../..
    dotnet sln add "gateway/ApiGateway/${SOLUTION_NAME}.Gateway/${SOLUTION_NAME}.Gateway.csproj"
    
    # 2. Crear microservicios de ejemplo
    echo "📦 Creando microservicios de ejemplo..."
    
    # Microservicio Users
    bash "$SCRIPT_DIR/add_microservice.sh" "Users" "5001" "3501" "."
    
    # Microservicio Orders
    bash "$SCRIPT_DIR/add_microservice.sh" "Orders" "5002" "3502" "."
    
    # 3. Crear frontend
    echo "⚛️  Creando proyecto frontend (React + Vite + Zustand)..."
    cd frontend
    bash "$SCRIPT_DIR/create_react_app.sh" "${SOLUTION_NAME}.Frontend" "."
    cd ..
    
    # 4. Crear componentes Dapr compartidos
    echo "🔧 Configurando componentes Dapr..."
    
    # State Store (Redis)
    cat > dapr-config/components/statestore.yaml << 'DAPR_STATE'
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
DAPR_STATE
    
    # Pub/Sub (Redis)
    cat > dapr-config/components/pubsub.yaml << 'DAPR_PUBSUB'
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
DAPR_PUBSUB
    
    # Service Discovery
    cat > dapr-config/components/servicediscovery.yaml << 'DAPR_DISCOVERY'
apiVersion: dapr.io/v1alpha1
kind: Component
metadata:
  name: servicediscovery
spec:
  type: nameresolution.kubernetes
  version: v1
  metadata: []
DAPR_DISCOVERY
    
    # 5. Crear docker-compose para toda la arquitectura
    cat > docker-compose.yml << 'DOCKER_COMPOSE'
version: '3.8'

networks:
  microservices-network:
    driver: bridge

services:
  # Infrastructure
  redis:
    image: redis:alpine
    ports:
      - "6379:6379"
    networks:
      - microservices-network

  sqlserver:
    image: mcr.microsoft.com/mssql/server:2022-latest
    environment:
      - ACCEPT_EULA=Y
      - SA_PASSWORD=YourStrong@Passw0rd
      - MSSQL_PID=Express
    ports:
      - "1433:1433"
    networks:
      - microservices-network
    volumes:
      - sqlserver-data:/var/opt/mssql

  # Dapr Placement Service
  dapr-placement:
    image: daprio/dapr:latest
    command: ["./placement", "-port", "50006"]
    ports:
      - "50006:50006"
    networks:
      - microservices-network

  # API Gateway
  gateway:
    build:
      context: ./gateway/ApiGateway
      dockerfile: Dockerfile
    ports:
      - "5000:80"
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
    depends_on:
      - redis
    networks:
      - microservices-network

  # Frontend
  frontend:
    build:
      context: ./frontend/SOLUTION_NAME.Frontend
      dockerfile: Dockerfile
    ports:
      - "5173:80"
    environment:
      - VITE_API_BASE_URL=http://localhost:5000
    depends_on:
      - gateway
    networks:
      - microservices-network

volumes:
  sqlserver-data:
DOCKER_COMPOSE
    
    sed -i "s/SOLUTION_NAME/${SOLUTION_NAME}/g" docker-compose.yml
    
    # 6. Crear scripts de utilidad
    cat > run-all-services.sh << 'RUN_ALL'
#!/bin/bash

echo "🚀 Iniciando todos los servicios con Dapr..."

# Terminal para cada servicio
gnome-terminal --tab --title="Redis" -- bash -c "docker run --rm -p 6379:6379 redis:alpine; exec bash"
sleep 2

gnome-terminal --tab --title="Gateway" -- bash -c "cd gateway/ApiGateway/SOLUTION_NAME.Gateway && dotnet run; exec bash"
sleep 2

# Iniciar microservicios con Dapr
for service_dir in services/*/; do
    service_name=$(basename "$service_dir")
    echo "Starting $service_name..."
    gnome-terminal --tab --title="$service_name" -- bash -c "cd $service_dir && ./run-with-dapr.sh; exec bash"
    sleep 2
done

gnome-terminal --tab --title="Frontend" -- bash -c "cd frontend/SOLUTION_NAME.Frontend && npm run dev; exec bash"

echo "✅ Todos los servicios iniciados!"
echo "🌐 Gateway: http://localhost:5000"
echo "⚛️  Frontend: http://localhost:5173"
RUN_ALL
    
    sed -i "s/SOLUTION_NAME/${SOLUTION_NAME}/g" run-all-services.sh
    chmod +x run-all-services.sh
    
    cat > stop-all-services.sh << 'STOP_ALL'
#!/bin/bash

echo "🛑 Deteniendo todos los servicios..."

# Detener procesos dotnet
pkill -f "dotnet run"

# Detener Dapr
dapr stop --app-id users
dapr stop --app-id orders

# Detener frontend
pkill -f "vite"

echo "✅ Todos los servicios detenidos!"
STOP_ALL
    
    chmod +x stop-all-services.sh
    
else
    # MODO MONOLITO (comportamiento original)
    # Crear el proyecto backend (.NET API)
    echo "🔧 Creando proyecto backend (.NET 10 Minimal API)..."
    bash "$SCRIPT_DIR/create_dotnet_api.sh" "${SOLUTION_NAME}.Api" "."
    
    # Agregar el proyecto a la solución
    dotnet sln add "${SOLUTION_NAME}.Api/${SOLUTION_NAME}.Api/${SOLUTION_NAME}.Api.csproj"
    
    # Crear el proyecto frontend (React + Vite)
    echo "⚛️  Creando proyecto frontend (React + Vite + Zustand)..."
    bash "$SCRIPT_DIR/create_react_app.sh" "${SOLUTION_NAME}.Frontend" "."
fi

# Si se especificó --aspire, añadir proyectos de Aspire
if [ "$ASPIRE_MODE" = "--aspire" ]; then
    echo "☁️  Configurando .NET Aspire..."
    
    # Crear proyecto AppHost
    echo "📦 Creando proyecto AppHost..."
    dotnet new aspire-apphost -n "${SOLUTION_NAME}.AppHost" -o "${SOLUTION_NAME}.AppHost"
    dotnet sln add "${SOLUTION_NAME}.AppHost/${SOLUTION_NAME}.AppHost.csproj"
    
    # Crear proyecto ServiceDefaults
    echo "⚙️  Creando proyecto ServiceDefaults..."
    dotnet new aspire-servicedefaults -n "${SOLUTION_NAME}.ServiceDefaults" -o "${SOLUTION_NAME}.ServiceDefaults"
    dotnet sln add "${SOLUTION_NAME}.ServiceDefaults/${SOLUTION_NAME}.ServiceDefaults.csproj"
    
    # Configurar referencias según el modo
    if [ "$MICROSERVICES_MODE" = "--microservices" ]; then
        # Añadir referencias a ServiceDefaults en cada microservicio
        for service_dir in services/*/; do
            if [ -d "$service_dir" ]; then
                service_name=$(basename "$service_dir")
                project_file=$(find "$service_dir" -name "*.csproj" | head -n 1)
                if [ -n "$project_file" ]; then
                    echo "  → Añadiendo ServiceDefaults a $service_name"
                    dotnet add "$project_file" reference "${SOLUTION_NAME}.ServiceDefaults/${SOLUTION_NAME}.ServiceDefaults.csproj"
                fi
            fi
        done
        
        # Añadir referencia en Gateway
        dotnet add "gateway/ApiGateway/${SOLUTION_NAME}.Gateway/${SOLUTION_NAME}.Gateway.csproj" reference "${SOLUTION_NAME}.ServiceDefaults/${SOLUTION_NAME}.ServiceDefaults.csproj"
        
        # Configurar AppHost para microservicios
        cat > "${SOLUTION_NAME}.AppHost/Program.cs" << 'ASPIRE_APPHOST'
var builder = DistributedApplication.CreateBuilder(args);

// Redis para Dapr
var redis = builder.AddRedis("redis")
    .WithDataVolume();

// SQL Server
var sqlserver = builder.AddSqlServer("sqlserver")
    .WithDataVolume();

// Microservicios
var users = builder.AddProject<Projects.SOLUTION_Users>("users")
    .WithReference(redis)
    .WithReference(sqlserver);

var orders = builder.AddProject<Projects.SOLUTION_Orders>("orders")
    .WithReference(redis)
    .WithReference(sqlserver)
    .WithReference(users);

// API Gateway
var gateway = builder.AddProject<Projects.SOLUTION_Gateway>("gateway")
    .WithReference(users)
    .WithReference(orders)
    .WithExternalHttpEndpoints();

// Frontend
var frontend = builder.AddNpmApp("frontend", "../SOLUTION.Frontend")
    .WithReference(gateway)
    .WithHttpEndpoint(env: "PORT", port: 5173)
    .WithExternalHttpEndpoints()
    .PublishAsDockerFile();

builder.Build().Run();
ASPIRE_APPHOST
        
        # Reemplazar SOLUTION con el nombre real
        sed -i "s/SOLUTION/${SOLUTION_NAME}/g" "${SOLUTION_NAME}.AppHost/Program.cs"
        
    else
        # MONOLITO: Añadir referencia a ServiceDefaults en API
        dotnet add "${SOLUTION_NAME}.Api/${SOLUTION_NAME}.Api/${SOLUTION_NAME}.Api.csproj" reference "${SOLUTION_NAME}.ServiceDefaults/${SOLUTION_NAME}.ServiceDefaults.csproj"
        
        # Configurar AppHost para monolito
        cat > "${SOLUTION_NAME}.AppHost/Program.cs" << 'ASPIRE_APPHOST_MONO'
var builder = DistributedApplication.CreateBuilder(args);

// Redis para Dapr
var redis = builder.AddRedis("redis")
    .WithDataVolume();

// SQL Server (opcional)
var sqlserver = builder.AddSqlServer("sqlserver")
    .WithDataVolume()
    .AddDatabase("appdb");

// API Backend
var api = builder.AddProject<Projects.SOLUTION_Api>("api")
    .WithReference(redis)
    .WithReference(sqlserver)
    .WithExternalHttpEndpoints();

// Frontend React
var frontend = builder.AddNpmApp("frontend", "../SOLUTION.Frontend")
    .WithReference(api)
    .WithHttpEndpoint(env: "PORT", port: 5173)
    .WithExternalHttpEndpoints()
    .PublishAsDockerFile();

builder.Build().Run();
ASPIRE_APPHOST_MONO
        
        # Reemplazar SOLUTION con el nombre real
        sed -i "s/SOLUTION/${SOLUTION_NAME}/g" "${SOLUTION_NAME}.AppHost/Program.cs"
    fi
    
    # Añadir referencias de proyectos al AppHost
    if [ "$MICROSERVICES_MODE" = "--microservices" ]; then
        for service_dir in services/*/; do
            if [ -d "$service_dir" ]; then
                project_file=$(find "$service_dir" -name "*.csproj" | head -n 1)
                if [ -n "$project_file" ]; then
                    dotnet add "${SOLUTION_NAME}.AppHost/${SOLUTION_NAME}.AppHost.csproj" reference "$project_file"
                fi
            fi
        done
        dotnet add "${SOLUTION_NAME}.AppHost/${SOLUTION_NAME}.AppHost.csproj" reference "gateway/ApiGateway/${SOLUTION_NAME}.Gateway/${SOLUTION_NAME}.Gateway.csproj"
    else
        dotnet add "${SOLUTION_NAME}.AppHost/${SOLUTION_NAME}.AppHost.csproj" reference "${SOLUTION_NAME}.Api/${SOLUTION_NAME}.Api/${SOLUTION_NAME}.Api.csproj"
    fi
    
    # Actualizar Program.cs de los servicios para usar ServiceDefaults
    if [ "$MICROSERVICES_MODE" = "--microservices" ]; then
        for service_dir in services/*/; do
            if [ -d "$service_dir" ]; then
                program_file=$(find "$service_dir" -name "Program.cs" | head -n 1)
                if [ -n "$program_file" ]; then
                    # Insertar AddServiceDefaults después de CreateBuilder
                    sed -i '/var builder = WebApplication.CreateBuilder(args);/a builder.AddServiceDefaults();' "$program_file"
                    # Insertar MapDefaultEndpoints antes de Run
                    sed -i '/app.Run();/i app.MapDefaultEndpoints();' "$program_file"
                fi
            fi
        done
        
        # Actualizar Gateway
        gateway_program="gateway/ApiGateway/${SOLUTION_NAME}.Gateway/Program.cs"
        if [ -f "$gateway_program" ]; then
            sed -i '/var builder = WebApplication.CreateBuilder(args);/a builder.AddServiceDefaults();' "$gateway_program"
            sed -i '/app.Run();/i app.MapDefaultEndpoints();' "$gateway_program"
        fi
    else
        # Actualizar API monolito
        api_program="${SOLUTION_NAME}.Api/${SOLUTION_NAME}.Api/Program.cs"
        if [ -f "$api_program" ]; then
            sed -i '/var builder = WebApplication.CreateBuilder(args);/a builder.AddServiceDefaults();' "$api_program"
            sed -i '/app.Run();/i app.MapDefaultEndpoints();' "$api_program"
        fi
    fi
fi

# Crear README según el modo
if [ "$ASPIRE_MODE" = "--aspire" ] && [ "$MICROSERVICES_MODE" = "--microservices" ]; then
    # README para Microservicios con Aspire
    cat > README.md << EOF
# $SOLUTION_NAME - Arquitectura de Microservicios con .NET Aspire

Solución completa con arquitectura de microservicios orquestada por .NET Aspire.

## 🏗️ Arquitectura

\`\`\`
$SOLUTION_NAME/
├── $SOLUTION_NAME.sln                        # Solución de Visual Studio
├── $SOLUTION_NAME.AppHost/                   # .NET Aspire AppHost (Orquestador)
├── $SOLUTION_NAME.ServiceDefaults/           # Configuración compartida (telemetry, health checks)
├── gateway/                                   # API Gateway (YARP)
│   └── ApiGateway/
│       └── ${SOLUTION_NAME}.Gateway/
├── services/                                  # Microservicios
│   ├── Users/
│   │   └── ${SOLUTION_NAME}.Users/
│   └── Orders/
│       └── ${SOLUTION_NAME}.Orders/
├── frontend/                                  # Frontend React
│   └── ${SOLUTION_NAME}.Frontend/
└── dapr-config/                              # Configuración Dapr
    └── components/
\`\`\`

## 📋 Requisitos

- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)
- [.NET Aspire Workload](https://learn.microsoft.com/dotnet/aspire/fundamentals/setup-tooling): \`dotnet workload install aspire\`
- [Node.js 18+](https://nodejs.org/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Visual Studio 2025](https://visualstudio.microsoft.com/) o [Visual Studio Code](https://code.visualstudio.com/)

## 🚀 Inicio Rápido

### Con .NET Aspire (Recomendado)

\`\`\`bash
cd $SOLUTION_NAME.AppHost
dotnet run
\`\`\`

Aspire iniciará:
- 🐳 Redis y SQL Server (contenedores)
- 🌐 API Gateway
- 📦 Todos los microservicios
- ⚛️  Frontend React
- 📊 Aspire Dashboard en \`http://localhost:15888\`

### Manual (Desarrollo)

\`\`\`bash
./run-all-services.sh
\`\`\`

## 🌐 Endpoints

- **Aspire Dashboard**: http://localhost:15888 (telemetry, logs, traces)
- **Frontend**: http://localhost:5173
- **API Gateway**: http://localhost:5000
- **Users Service**: http://localhost:5001
- **Orders Service**: http://localhost:5002

## ☁️  .NET Aspire Features

### Orquestación Local
- Inicio con un solo comando (\`dotnet run\` en AppHost)
- Gestión automática de dependencias
- Service discovery integrado
- Variables de entorno inyectadas automáticamente

### Observabilidad
- **Dashboard**: Visualización en tiempo real de todos los servicios
- **Distributed Tracing**: OpenTelemetry integrado
- **Métricas**: CPU, memoria, requests
- **Logs estructurados**: Agregados por servicio

### Service Defaults
Cada servicio incluye automáticamente:
- Health checks en \`/health\` y \`/alive\`
- OpenTelemetry (metrics + tracing)
- Service discovery
- Resilient HTTP client (circuit breaker, retry)

## 📦 Añadir Nuevo Microservicio

\`\`\`bash
bash scripts/add_microservice.sh Products 5003 3503 .

# Actualizar AppHost/Program.cs
var products = builder.AddProject<Projects.${SOLUTION_NAME}_Products>("products")
    .WithReference(redis)
    .WithReference(sqlserver);
\`\`\`

## 🐳 Deployment

### Kubernetes con Aspire
\`\`\`bash
cd $SOLUTION_NAME.AppHost
dotnet publish /t:GenerateDeploymentManifest
\`\`\`

### Azure Container Apps
\`\`\`bash
azd init
azd up
\`\`\`

## 📚 Documentación

- [.NET Aspire](https://aspire.dev/)
- [Aspire Dashboard](https://aspire.dev/dashboard/overview/)
- [Aspire Deployment](https://aspire.dev/deployment/overview/)
- [Microservices Architecture](./docs/microservices-architecture.md)

EOF

elif [ "$ASPIRE_MODE" = "--aspire" ]; then
    # README para Monolito con Aspire
    cat > README.md << EOF
# $SOLUTION_NAME - .NET Aspire Application

Aplicación full-stack con .NET 10 API y React, orquestada por .NET Aspire.

## 🏗️ Arquitectura

\`\`\`
$SOLUTION_NAME/
├── $SOLUTION_NAME.sln                        # Solución de Visual Studio
├── $SOLUTION_NAME.AppHost/                   # .NET Aspire AppHost (Orquestador)
├── $SOLUTION_NAME.ServiceDefaults/           # Configuración compartida
├── ${SOLUTION_NAME}.Api/                     # Backend .NET 10 Minimal API
│   └── ${SOLUTION_NAME}.Api/
└── ${SOLUTION_NAME}.Frontend/                # Frontend React + Vite
\`\`\`

## 📋 Requisitos

- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)
- [.NET Aspire Workload](https://learn.microsoft.com/dotnet/aspire/fundamentals/setup-tooling): \`dotnet workload install aspire\`
- [Node.js 18+](https://nodejs.org/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)

## 🚀 Inicio Rápido

### Con .NET Aspire (Recomendado)

\`\`\`bash
cd $SOLUTION_NAME.AppHost
dotnet run
\`\`\`

Aspire iniciará:
- 🐳 Redis y SQL Server (contenedores)
- 🔧 API Backend con hot reload
- ⚛️  Frontend React con Vite HMR
- 📊 Aspire Dashboard en \`http://localhost:15888\`

### Manual (Desarrollo)

Backend:
\`\`\`bash
cd ${SOLUTION_NAME}.Api/${SOLUTION_NAME}.Api
dotnet run
\`\`\`

Frontend:
\`\`\`bash
cd ${SOLUTION_NAME}.Frontend
npm run dev
\`\`\`

## 🌐 Endpoints

- **Aspire Dashboard**: http://localhost:15888
- **API**: https://localhost:7000 (Swagger en raíz)
- **Frontend**: http://localhost:5173

## ☁️  .NET Aspire Benefits

### Development Experience
- **Un solo comando**: \`dotnet run\` inicia todo
- **Hot Reload**: Cambios reflejados instantáneamente
- **Service Discovery**: Frontend encuentra API automáticamente
- **Dependency Management**: Redis y SQL Server se inician automáticamente

### Observability Out-of-the-Box
- **Dashboard**: Visualización en tiempo real
- **Distributed Tracing**: Seguimiento de requests end-to-end
- **Metrics**: Rendimiento de API y base de datos
- **Logs Aggregation**: Todos los logs en un solo lugar

### Service Defaults
La API incluye automáticamente:
- Health checks (\`/health\`, \`/alive\`)
- OpenTelemetry (metrics + distributed tracing)
- Service discovery
- Resilient HttpClient

## 🐳 Deployment

### Azure Container Apps
\`\`\`bash
azd init
azd up
\`\`\`

### Kubernetes
\`\`\`bash
cd $SOLUTION_NAME.AppHost
dotnet publish /t:GenerateDeploymentManifest
kubectl apply -f manifest.yaml
\`\`\`

## 📚 Más Información

- [.NET Aspire Documentation](https://aspire.dev/)
- [Service Defaults](https://aspire.dev/fundamentals/service-defaults/)
- [Aspire Dashboard](https://aspire.dev/dashboard/overview/)

EOF

elif [ "$MICROSERVICES_MODE" = "--microservices" ]; then
    cat > README.md << EOF
# $SOLUTION_NAME - Arquitectura de Microservicios

Solución completa con arquitectura de microservicios, API Gateway, Dapr y frontend React.

## 🏗️ Arquitectura

\`\`\`
$SOLUTION_NAME/
├── $SOLUTION_NAME.sln                        # Solución de Visual Studio
├── gateway/                                   # API Gateway (YARP)
│   └── ApiGateway/
│       └── ${SOLUTION_NAME}.Gateway/
├── services/                                  # Microservicios
│   ├── Users/
│   │   └── ${SOLUTION_NAME}.Users/
│   └── Orders/
│       └── ${SOLUTION_NAME}.Orders/
├── frontend/                                  # Frontend React
│   └── ${SOLUTION_NAME}.Frontend/
├── dapr-config/                              # Configuración Dapr
│   └── components/
│       ├── statestore.yaml
│       ├── pubsub.yaml
│       └── servicediscovery.yaml
├── shared/                                   # Contratos compartidos
│   └── contracts/
├── docker-compose.yml                        # Orquestación Docker
└── run-all-services.sh                       # Script para iniciar todo
\`\`\`

## 📋 Requisitos

- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)
- [Node.js 18+](https://nodejs.org/)
- [Dapr CLI](https://docs.dapr.io/getting-started/install-dapr-cli/)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Visual Studio 2025](https://visualstudio.microsoft.com/) o [Visual Studio Code](https://code.visualstudio.com/)

## 🚀 Inicio Rápido

### Opción 1: Todos los servicios con script (recomendado para desarrollo)

\`\`\`bash
./run-all-services.sh
\`\`\`

### Opción 2: Con Docker Compose (recomendado para producción)

\`\`\`bash
docker-compose up --build
\`\`\`

### Opción 3: Manual (paso a paso)

1. **Iniciar infraestructura**:
   \`\`\`bash
   docker run -d -p 6379:6379 redis:alpine
   \`\`\`

2. **Iniciar API Gateway**:
   \`\`\`bash
   cd gateway/ApiGateway/${SOLUTION_NAME}.Gateway
   dotnet run
   \`\`\`

3. **Iniciar Microservicios con Dapr**:
   \`\`\`bash
   # Users Service
   cd services/Users
   ./run-with-dapr.sh
   
   # Orders Service (en otra terminal)
   cd services/Orders
   ./run-with-dapr.sh
   \`\`\`

4. **Iniciar Frontend**:
   \`\`\`bash
   cd frontend/${SOLUTION_NAME}.Frontend
   npm run dev
   \`\`\`

## 🌐 Endpoints

- **Frontend**: http://localhost:5173
- **API Gateway**: http://localhost:5000
- **Users Service**: http://localhost:5001
- **Orders Service**: http://localhost:5002

### Rutas del Gateway

- \`GET /api/users/*\` → Users Service
- \`GET /api/orders/*\` → Orders Service
- \`GET /health\` → Gateway Health

## 📦 Añadir un Nuevo Microservicio

\`\`\`bash
bash scripts/add_microservice.sh <NombreServicio> <Puerto> <PuertoDapr> <RutaSolucion>
\`\`\`

Ejemplo:
\`\`\`bash
bash scripts/add_microservice.sh Products 5003 3503 .
\`\`\`

Después, actualiza el \`appsettings.json\` del Gateway para añadir la ruta:

\`\`\`json
"product-service-route": {
  "ClusterId": "product-service",
  "Match": {
    "Path": "/api/products/{**catch-all}"
  }
},
"Clusters": {
  "product-service": {
    "Destinations": {
      "destination1": {
        "Address": "http://localhost:5003"
      }
    }
  }
}
\`\`\`

## 🔧 Características

### Microservicios
- Arquitectura distribuida con separación de responsabilidades
- Cada servicio tiene su propio dominio y base de datos (Database per Service)
- Comunicación asíncrona con Dapr Pub/Sub
- Comunicación síncrona con Dapr Service Invocation
- State Management con Dapr State Store

### API Gateway
- YARP Reverse Proxy para enrutamiento
- CORS configurado
- Health checks
- Balanceo de carga
- Rate limiting (configurable)

### Frontend
- React 18+ con Vite
- Zustand para estado global
- React Router para navegación
- TailwindCSS para estilos
- Axios para peticiones HTTP

## 🐳 Docker

Cada servicio tiene su propio Dockerfile. Para construir:

\`\`\`bash
docker-compose build
docker-compose up
\`\`\`

## 📚 Documentación

- [Dapr Documentation](https://docs.dapr.io/)
- [YARP Documentation](https://microsoft.github.io/reverse-proxy/)
- [Microservices Architecture Guide](./docs/microservices-architecture.md)
- [Kruchten 4+1 Architecture](./docs/kruchten-4plus1-architecture.md)

## 🛠️ Desarrollo

### Agregar endpoint a un microservicio

Edita \`Program.cs\` del microservicio correspondiente y añade tu endpoint.

### Comunicación entre servicios

Usa Dapr Service Invocation:
\`\`\`csharp
var result = await daprClient.InvokeMethodAsync<OrderResponse>(
    HttpMethod.Get,
    "orders",  // App ID del servicio destino
    "api/orders/123"
);
\`\`\`

### Pub/Sub

Publicar evento:
\`\`\`csharp
await daprClient.PublishEventAsync("pubsub", "order-created", orderData);
\`\`\`

Suscribirse:
\`\`\`csharp
app.MapPost("/orders/created", [Topic("pubsub", "order-created")] 
    (OrderEvent evt) => {
    // Manejar evento
});
\`\`\`

## 🧪 Testing

\`\`\`bash
dotnet test
\`\`\`

## 📈 Monitoreo

Dapr proporciona observabilidad out-of-the-box:
- Métricas: Prometheus en http://localhost:9090
- Tracing: Zipkin en http://localhost:9411
- Logging: Salida estándar de cada servicio

## 🚦 Detener servicios

\`\`\`bash
./stop-all-services.sh
\`\`\`

O con Docker:
\`\`\`bash
docker-compose down
\`\`\`

EOF
else
    cat > README.md << EOF
# $SOLUTION_NAME

Solución completa con backend .NET 10 Minimal API y frontend React + Vite.

## Estructura del proyecto

\`\`\`
$SOLUTION_NAME/
├── $SOLUTION_NAME.sln                    # Solución de Visual Studio
├── ${SOLUTION_NAME}.Api/                 # Proyecto backend
│   └── ${SOLUTION_NAME}.Api/
│       ├── Program.cs                    # Punto de entrada de la API
│       ├── appsettings.json              # Configuración
│       └── ...
└── ${SOLUTION_NAME}.Frontend/            # Proyecto frontend
    ├── src/
    ├── package.json
    └── ...
\`\`\`

## Requisitos

- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)
- [Node.js 18+](https://nodejs.org/)
- [Visual Studio 2025](https://visualstudio.microsoft.com/) o [Visual Studio Code](https://code.visualstudio.com/)

## Ejecutar el proyecto

### Backend (.NET API)

\`\`\`bash
cd ${SOLUTION_NAME}.Api/${SOLUTION_NAME}.Api
dotnet run
\`\`\`

La API estará disponible en \`https://localhost:<puerto>\` con Swagger en la raíz.

### Frontend (React)

\`\`\`bash
cd ${SOLUTION_NAME}.Frontend
npm run dev
\`\`\`

La aplicación estará disponible en \`http://localhost:5173\`.

## Desarrollo

### Backend

- La API usa Minimal APIs de .NET 10
- Swagger/OpenAPI configurado en la raíz
- CORS configurado para localhost:5173 y localhost:3000
- Estructura organizada siguiendo el Modelo 4+1 de Kruchten
- Dapr para state management y pub/sub

### Frontend

- React 18+ con Vite
- Zustand para gestión de estado
- Axios para peticiones HTTP
- React Router para navegación
- TailwindCSS para estilos

## Endpoints de ejemplo

- \`GET /api/health\` - Health check
- \`GET /api/version\` - Información de versión
- \`GET /api/greeting/{name}\` - Saludo personalizado
- \`POST /api/echo\` - Echo de mensajes

## Migrar a Microservicios

Para convertir esta solución en una arquitectura de microservicios:

\`\`\`bash
bash scripts/create_solution.sh $SOLUTION_NAME . --microservices
\`\`\`

## Siguiente pasos

1. Personalizar los endpoints de la API
2. Implementar los stores de Zustand
3. Crear componentes de React
4. Configurar variables de entorno
5. Implementar autenticación si es necesario

EOF
fi

# Crear archivo .gitignore general
cat > .gitignore << 'EOF'
# .NET
bin/
obj/
*.user
*.suo
*.cache
*.log

# React/Node
node_modules/
dist/
*.local

# IDE
.vs/
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Dapr
.dapr/
EOF

echo ""
echo "✅ ¡Solución creada exitosamente!"
echo ""

if [ "$ASPIRE_MODE" = "--aspire" ] && [ "$MICROSERVICES_MODE" = "--microservices" ]; then
    echo "📁 Arquitectura de Microservicios con .NET Aspire creada:"
    echo "   $FULL_PATH/"
    echo "   ├── $SOLUTION_NAME.sln"
    echo "   ├── $SOLUTION_NAME.AppHost/ (Orquestador Aspire)"
    echo "   ├── $SOLUTION_NAME.ServiceDefaults/ (Configuración compartida)"
    echo "   ├── gateway/ApiGateway/${SOLUTION_NAME}.Gateway/"
    echo "   ├── services/Users/${SOLUTION_NAME}.Users/"
    echo "   ├── services/Orders/${SOLUTION_NAME}.Orders/"
    echo "   └── frontend/${SOLUTION_NAME}.Frontend/"
    echo ""
    echo "🚀 Para comenzar con Aspire:"
    echo "   cd $FULL_PATH/${SOLUTION_NAME}.AppHost"
    echo "   dotnet run"
    echo ""
    echo "📊 Aspire Dashboard: http://localhost:15888"
    echo "🌐 Frontend: http://localhost:5173"
    echo "🔧 Gateway: http://localhost:5000"
    
elif [ "$ASPIRE_MODE" = "--aspire" ]; then
    echo "📁 Aplicación con .NET Aspire creada:"
    echo "   $FULL_PATH/"
    echo "   ├── $SOLUTION_NAME.sln"
    echo "   ├── $SOLUTION_NAME.AppHost/ (Orquestador Aspire)"
    echo "   ├── $SOLUTION_NAME.ServiceDefaults/ (Configuración compartida)"
    echo "   ├── ${SOLUTION_NAME}.Api/"
    echo "   └── ${SOLUTION_NAME}.Frontend/"
    echo ""
    echo "🚀 Para comenzar con Aspire:"
    echo "   cd $FULL_PATH/${SOLUTION_NAME}.AppHost"
    echo "   dotnet run"
    echo ""
    echo "📊 Aspire Dashboard: http://localhost:15888"
    echo "⚛️  Frontend: http://localhost:5173"
    echo "🔧 API: https://localhost:7000"
    
elif [ "$MICROSERVICES_MODE" = "--microservices" ]; then
    echo "📁 Arquitectura de Microservicios creada:"
    echo "   $FULL_PATH/"
    echo "   ├── $SOLUTION_NAME.sln"
    echo "   ├── gateway/ApiGateway/${SOLUTION_NAME}.Gateway/"
    echo "   ├── services/Users/${SOLUTION_NAME}.Users/"
    echo "   ├── services/Orders/${SOLUTION_NAME}.Orders/"
    echo "   ├── frontend/${SOLUTION_NAME}.Frontend/"
    echo "   ├── dapr-config/components/"
    echo "   └── docker-compose.yml"
    echo ""
    echo "🚀 Para comenzar:"
    echo ""
    echo "   Opción 1 - Script automatizado:"
    echo "   cd $FULL_PATH"
    echo "   ./run-all-services.sh"
    echo ""
    echo "   Opción 2 - Docker Compose:"
    echo "   cd $FULL_PATH"
    echo "   docker-compose up --build"
    echo ""
    echo "   Opción 3 - Manual:"
    echo "   1. Iniciar Redis: docker run -d -p 6379:6379 redis:alpine"
    echo "   2. Gateway: cd gateway/ApiGateway/${SOLUTION_NAME}.Gateway && dotnet run"
    echo "   3. Servicios: cd services/Users && ./run-with-dapr.sh"
    echo "   4. Frontend: cd frontend/${SOLUTION_NAME}.Frontend && npm run dev"
    echo ""
    echo "🌐 URLs:"
    echo "   Frontend: http://localhost:5173"
    echo "   Gateway: http://localhost:5000"
    echo "   Users: http://localhost:5001"
    echo "   Orders: http://localhost:5002"
    echo ""
    echo "📦 Añadir más microservicios:"
    echo "   bash scripts/add_microservice.sh <NombreServicio> <Puerto> <PuertoDapr> ."
else
    echo "📁 Estructura creada:"
    echo "   $FULL_PATH/"
    echo "   ├── $SOLUTION_NAME.sln"
    echo "   ├── ${SOLUTION_NAME}.Api/"
    echo "   └── ${SOLUTION_NAME}.Frontend/"
    echo ""
    echo "🚀 Para comenzar:"
    echo ""
    echo "   Backend:"
    echo "   cd $FULL_PATH/${SOLUTION_NAME}.Api/${SOLUTION_NAME}.Api"
    echo "   dotnet run"
    echo ""
    echo "   Frontend:"
    echo "   cd $FULL_PATH/${SOLUTION_NAME}.Frontend"
    echo "   npm run dev"
    echo ""
    echo "💡 Para .NET Aspire, usa:"
    echo "   bash scripts/create_solution.sh $SOLUTION_NAME . --aspire"
fi

if [ -z "$ASPIRE_MODE" ] && [ "$MICROSERVICES_MODE" != "--microservices" ]; then
    echo "💡 Para arquitectura de microservicios, usa:"
    echo "   bash scripts/create_solution.sh $SOLUTION_NAME . --microservices"
fi

echo ""
echo "📖 Consulta README.md para más información"
