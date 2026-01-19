---
name: project-creator
description: Create complete full-stack solutions with a .NET 10 Minimal API backend (with Swagger/OpenAPI, Dapr, and mandatory .NET Aspire orchestration) and a React frontend (Vite + Zustand + TailwindCSS + React Router). Supports monolithic and microservices architectures, always orchestrated by .NET Aspire with API Gateway (YARP) when applicable. Use when the user requests to create, scaffold, or initialize a new .NET API project, React application, Visual Studio solution, full-stack project, Dapr-enabled microservices, .NET Aspire application, or microservices architecture. Triggered by requests mentioning .NET, minimal API, React, Vite, Zustand, TailwindCSS, React Router, Visual Studio solution, Dapr, microservices, API Gateway, .NET Aspire, cloud-native, or full-stack development.
---

# .NET 10 + React Project Creator

## Overview

Create production-ready full-stack solutions with a .NET 10 Minimal API backend (with Dapr support, **mandatory .NET Aspire orchestration**, and Kruchten's 4+1 architectural model) and a modern React frontend using Vite, Zustand, TailwindCSS, and React Router. Supports **monolithic** and **microservices** architectures, **always orchestrated by .NET Aspire**. This skill provides automated scaffolding with clean architecture principles, Dapr integration for distributed systems, API Gateway with YARP, .NET Aspire for cloud-native orchestration, and ready-to-use templates with beautiful UI components for rapid development.

## Quick Start

### Create Complete Solution (Monolith)

Use the main solution script to create a full Visual Studio solution with both backend and frontend:

```bash
bash scripts/create_solution.sh <SolutionName> <target-path>
```

Example:
```bash
bash scripts/create_solution.sh MyApp ./projects
```

This creates:
- `MyApp.sln` - Visual Studio solution
- `MyApp.AppHost/` - **.NET Aspire AppHost** (orchestrator)
- `MyApp.ServiceDefaults/` - **Shared configuration** (telemetry, health checks, service discovery)
- `MyApp.Api/` - .NET 10 Minimal API with Swagger and Dapr
- `MyApp.Frontend/` - React app with Vite and Zustand

### .NET Aspire Orchestration (Always Included)

All solutions are orchestrated by .NET Aspire by default (no flags required).

```bash
bash scripts/create_solution.sh <SolutionName> <target-path>
```

Example:
```bash
bash scripts/create_solution.sh MyApp ./projects
```

This creates:
- `MyApp.sln` - Visual Studio solution
- `MyApp.AppHost/` - **.NET Aspire AppHost** (orchestrator)
- `MyApp.ServiceDefaults/` - **Shared configuration** (telemetry, health checks, service discovery)
- `MyApp.Api/` - .NET 10 Minimal API with Aspire integration
- `MyApp.Frontend/` - React app

**Run with Aspire:**
```bash
cd MyApp.AppHost
dotnet run
```
- Starts API, Frontend, Redis, SQL Server with one command
- Opens Aspire Dashboard at `http://localhost:15888` (telemetry, logs, traces)

### Create Microservices Architecture (Aspire Included)

To create a solution with microservices architecture including API Gateway:

```bash
bash scripts/create_solution.sh <SolutionName> <target-path> --microservices
```

Example:
```bash
bash scripts/create_solution.sh MyEcommerce ./projects --microservices
```

This creates:
- `MyEcommerce.sln` - Visual Studio solution
- `MyEcommerce.AppHost/` - **.NET Aspire AppHost** (orchestrator)
- `MyEcommerce.ServiceDefaults/` - **Shared configuration** (telemetry, health checks, service discovery)
- `gateway/ApiGateway/` - **YARP API Gateway** (reverse proxy)
- `services/Users/` - Users microservice with Dapr
- `services/Orders/` - Orders microservice with Dapr
- `frontend/MyEcommerce.Frontend/` - React app
- `dapr-config/components/` - Dapr configuration (state store, pub/sub)
- `docker-compose.yml` - Full infrastructure setup
- `run-all-services.sh` - Script to start all services

### Microservices + Aspire

Aspire orchestration is always included with microservices (no extra flags).

### Add New Microservice

Add a new microservice to an existing solution:

```bash
bash scripts/add_microservice.sh <ServiceName> <AppPort> <DaprPort> <SolutionPath>
```

Example:
```bash
bash scripts/add_microservice.sh Products 5003 3503 ./MyEcommerce
```

This creates a new microservice with:
- Complete .NET 10 Minimal API project
- Dapr integration
- 4+1 architecture structure
- Automatic addition to .sln
- Dockerfile and docker-compose integration
- Run script with Dapr

### Create Backend Only

For standalone API projects:

```bash
bash scripts/create_dotnet_api.sh <ProjectName> <target-path>
```

Creates a .NET 10 Minimal API with **.NET Aspire orchestration**:
- `MyApp.AppHost/` - **.NET Aspire AppHost** (orchestrator)
- `MyApp.ServiceDefaults/` - **Shared configuration** (telemetry, health checks, service discovery)
- Swagger/OpenAPI at root URL
- CORS configured for React development
- **Dapr integration** (State Management, Pub/Sub, Service Invocation)
- **Clean Architecture** following Kruchten's 4+1 model:
  - Vista Lógica: Domain and Application layers
  - Vista de Proceso: Dapr messaging and background services
  - Vista de Desarrollo: Modular folder structure
  - Vista Física: Docker and Kubernetes ready
- Example endpoints (health, version, greeting, echo)
- **Dapr-enabled endpoints** (state store, pub/sub, service invocation)
- Organized folder structure (Domain, Application, Infrastructure, Endpoints)

### Create Frontend Only

For standalone React projects:

```bash
bash scripts/create_react_app.sh <ProjectName> <target-path>
```

Creates a React application with:
- Vite build tool (fast HMR)
- Zustand for state management
- TailwindCSS for styling (utility-first)
- React Router for navigation (v6)
- Axios for API calls
- TypeScript configured
- Pre-configured folder structure

## Project Structure

### Microservices Architecture

```
MyEcommerce/
├── MyEcommerce.sln                      # Visual Studio solution
├── MyEcommerce.AppHost/                 # .NET Aspire AppHost (orchestrator)
├── MyEcommerce.ServiceDefaults/         # Shared configuration (telemetry, health checks)
├── gateway/                             # API Gateway
│   └── ApiGateway/
│       └── MyEcommerce.Gateway/
│           ├── Program.cs               # YARP configuration
│           └── appsettings.json         # Routes and clusters
├── services/                            # Microservices
│   ├── Users/
│   │   └── MyEcommerce.Users/
│   │       ├── Program.cs
│   │       ├── Domain/
│   │       ├── Application/
│   │       ├── Infrastructure/
│   │       └── Endpoints/
│   └── Orders/
│       └── MyEcommerce.Orders/
│           └── ... (same structure)
├── frontend/                            # React Frontend
│   └── MyEcommerce.Frontend/
│       ├── src/
│       ├── package.json
│       └── vite.config.ts
├── dapr-config/                         # Dapr configuration
│   └── components/
│       ├── statestore.yaml              # Redis state store
│       ├── pubsub.yaml                  # Redis pub/sub
│       └── servicediscovery.yaml        # Service discovery
├── shared/                              # Shared contracts
│   └── contracts/
├── docker-compose.yml                   # Full stack orchestration
├── run-all-services.sh                  # Start all services
└── stop-all-services.sh                 # Stop all services
```

### Backend Structure (.NET API / Microservice)

```
MyApp.Api/
├── Program.cs              # Entry point with Swagger & CORS config
├── appsettings.json        # Configuration with CORS origins
├── Architecture.md         # Documentation of 4+1 model
├── Domain/                 # Vista Lógica - Business logic
│   ├── Entities/           # Domain entities
│   ├── ValueObjects/       # Immutable value objects
│   └── Interfaces/         # Domain contracts
├── Application/            # Vista Lógica - Use cases
│   ├── Commands/           # Write operations (CQRS)
│   ├── Queries/            # Read operations (CQRS)
│   ├── DTOs/               # Data Transfer Objects
│   └── Validators/         # Input validation
├── Infrastructure/         # Vista Física - Technical implementations
│   ├── Persistence/        # Data access
│   ├── Messaging/          # Pub/Sub, events
│   └── ExternalServices/   # External APIs
├── Endpoints/              # Vista de Desarrollo - API endpoints
└── Extensions/             # Vista de Desarrollo - Modular configuration
```

Key features:
- **Swagger UI**: Available at root URL (`/`) in development
- **CORS**: Pre-configured for `http://localhost:5173` (Vite default)
- **Dapr SDK**: Integrated with state management, pub/sub, and service invocation
- **4+1 Architecture**: Clean separation of concerns following Kruchten's model
- **Domain-Driven Design**: Entities, Value Objects, Repository pattern
- **CQRS Pattern**: Separate Commands and Queries
- **Health endpoints**: `/api/health` and `/api/version`
- **Example endpoints**: Greeting and echo endpoints with OpenAPI tags
- **Dapr endpoints**: State store (`/api/state/{key}`), pub/sub (`/api/publish/{topic}`)
- **Service-to-Service**: Communication with other microservices via Dapr
- **Architecture.md**: Included documentation explaining the 4+1 model

### Frontend Structure (React)

```
MyApp.Frontend/
├── src/
│   ├── main.tsx           # Entry point
│   ├── App.tsx            # Main component with Router
│   ├── components/        # React components
│   ├── layouts/           # Layout components
│   ├── pages/             # Page components
│   ├── stores/            # Zustand stores
│   ├── services/          # API services
│   └── index.css          # Tailwind directives
├── tailwind.config.js     # Tailwind configuration
├── postcss.config.js      # PostCSS configuration
├── package.json
└── vite.config.ts
```

## Templates and Assets

### Zustand Store Template

Copy `assets/zustand-store-template.ts` for new stores:

```typescript
// Example usage
import { useAppStore } from './stores/appStore';

function Component() {
  const count = useAppStore(state => state.count);
  const increment = useAppStore(state => state.increment);
  // ...
}
```

Features:
- TypeScript typing
- Devtools integration
- Persistence with localStorage
- Optimized selectors

### API Service Template

Copy `assets/api-service-template.ts` for API integration:

```typescript
// Example usage
import { apiService, healthApi } from './services/api';

const health = await healthApi.check();
const data = await apiService.get('/api/endpoint');
```

Features:
- Axios interceptors for auth
- Global error handling
- TypeScript types
- Base URL configuration

### Environment Configuration

Copy `assets/.env.example` to `.env` in frontend:

```bash
cp assets/.env.example MyApp.Frontend/.env
```

Configure API URL and other settings.

### React Router Templates

Ready-to-use templates for routing:

- **`App-router-template.tsx`**: Main App component with React Router setup
- **`Layout-template.tsx`**: Layout component with navigation and responsive design
- **`Home-page-template.tsx`**: Home page example with Zustand integration and Tailwind styling

### TailwindCSS Components

Pre-built components with Tailwind:

- **`Button-component-template.tsx`**: Reusable button component with variants

Copy these templates to jumpstart your UI development:

```bash
cp assets/App-router-template.tsx MyApp.Frontend/src/App.tsx
cp assets/Layout-template.tsx MyApp.Frontend/src/layouts/Layout.tsx
cp assets/Home-page-template.tsx MyApp.Frontend/src/pages/Home.tsx
cp assets/Button-component-template.tsx MyApp.Frontend/src/components/Button.tsx
```

## Running the Projects

### .NET Aspire Orchestration

#### Start Everything with One Command

```bash
cd MyApp.AppHost
dotnet run
```

Aspire automatically starts:
- 🐳 **Infrastructure**: Redis, SQL Server (as Docker containers)
- 🔧 **Backend**: API with hot reload
- ⚛️  **Frontend**: React with Vite HMR
- 📊 **Dashboard**: Telemetry, logs, traces at `http://localhost:15888`

#### Aspire Dashboard Features

Access at `http://localhost:15888`:
- **Resources**: View status of all services and infrastructure
- **Logs**: Aggregated logs from all services with filtering
- **Traces**: Distributed tracing showing request flow across services
- **Metrics**: CPU, memory, HTTP requests per service
- **Endpoints**: All exposed URLs in one place

#### With Microservices

```bash
cd MyEcommerce.AppHost
dotnet run
```

Starts:
- API Gateway + all microservices
- Service discovery and observability
- Full distributed tracing

**Benefits:**
- ✅ One command to start everything
- ✅ Automatic dependency management
- ✅ Real-time observability
- ✅ Service discovery built-in
- ✅ Health monitoring

### Microservices Architecture

#### Start with Aspire (Recommended)

```bash
cd MyEcommerce.AppHost
dotnet run
```

#### Option 1: Automated Script (Development)

```bash
cd MyEcommerce
./run-all-services.sh
```

This starts:
- Redis infrastructure
- API Gateway on port 5000
- All microservices with Dapr sidecars
- Frontend on port 5173

#### Option 2: Docker Compose (Production)

```bash
cd MyEcommerce
docker-compose up --build
```

Orchestrates:
- Redis and SQL Server
- Dapr placement service
- API Gateway
- All microservices
- Frontend

#### Option 3: Manual (Step by Step)

1. **Start Infrastructure**:
   ```bash
   docker run -d -p 6379:6379 redis:alpine
   ```

2. **Start API Gateway**:
   ```bash
   cd gateway/ApiGateway/MyEcommerce.Gateway
   dotnet run
   ```

3. **Start Microservices with Dapr**:
   ```bash
   # Users Service
   cd services/Users
   ./run-with-dapr.sh
   
   # Orders Service (in another terminal)
   cd services/Orders
   ./run-with-dapr.sh
   ```

4. **Start Frontend**:
   ```bash
   cd frontend/MyEcommerce.Frontend
   npm run dev
   ```

**URLs**:
- Frontend: `http://localhost:5173`
- API Gateway: `http://localhost:5000`
- Users Service: `http://localhost:5001`
- Orders Service: `http://localhost:5002`

**Stop All Services**:
```bash
./stop-all-services.sh
```

### Monolithic Architecture

#### Start with Aspire (Recommended)

```bash
cd MyApp.AppHost
dotnet run
```

#### Start Backend (Standard)

```bash
cd MyApp.Api/MyApp.Api
dotnet run
```

API runs on HTTPS (typically `https://localhost:7000`)
Swagger UI available at root URL

#### Start Backend with Dapr

```bash
cd MyApp.Api/MyApp.Api
dapr run --app-id myapp-api --app-port 5000 --dapr-http-port 3500 -- dotnet run
```

This enables:
- Dapr sidecar for distributed capabilities
- State management with Redis
- Pub/Sub messaging
- Service invocation
- Distributed tracing with Zipkin

#### Start Frontend

```bash
cd MyApp.Frontend
npm run dev
```

React app runs on `http://localhost:5173`

## Advanced Configuration

For production-ready features and best practices, see:

### .NET Aspire Integration

Read `references/aspire-integration.md` for:
- AppHost configuration and orchestration
- Service Defaults (telemetry, health checks, service discovery)
- Service discovery and communication between services
- Resources and components (databases, caches, message brokers)
- Observability with Aspire Dashboard
  - Distributed tracing with OpenTelemetry
  - Metrics and health monitoring
  - Aggregated logs
- Deployment to Azure Container Apps and Kubernetes
- Custom telemetry and health checks
- Best practices for cloud-native applications

### Microservices Architecture

Read `references/microservices-architecture.md` for:
- Principles of microservices (Single Responsibility, Database per Service)
- API Gateway with YARP configuration
- Service Discovery with Dapr
- Communication patterns (Sync/Async, Pub/Sub, Event Sourcing)
- CQRS implementation
- Saga pattern for distributed transactions
- Outbox pattern for consistency
- Resiliency with Circuit Breaker and Retry policies
- Observability (Distributed Tracing, Metrics, Logging)
- Kubernetes deployment and scaling
- Best practices and anti-patterns

### Backend Best Practices

Read `references/dotnet-best-practices.md` for:
- Authentication & JWT configuration
- Entity Framework Core setup
- Rate limiting
- Global error handling
- Health checks
- API versioning
- Advanced logging with Serilog

### Kruchten's 4+1 Architectural Model

Read `references/kruchten-4plus1-architecture.md` for:
- Complete explanation of the 4+1 model
- **Vista Lógica** (Logical View): Domain entities, use cases, business logic
- **Vista de Proceso** (Process View): Concurrency, messaging, background services
- **Vista de Desarrollo** (Development View): Code organization, modules, layers
- **Vista Física** (Physical View): Deployment, containers, infrastructure
- **Vista de Escenarios** (+1): End-to-end use case examples
- Implementation patterns with .NET and Dapr
- Docker and Kubernetes deployment examples
- C4 and PlantUML diagrams

### Dapr Integration

Read `references/dapr-integration.md` for:
- Dapr installation and initialization
- State management patterns
- Pub/Sub messaging
- Service-to-service invocation
- Secrets management
- Input/Output bindings
- Actor pattern implementation
- Kubernetes deployment with Dapr

### Frontend Patterns

Read `references/react-zustand-patterns.md` for:
- Advanced Zustand patterns (slices, Immer)
- Custom hooks (forms, data fetching)
- React Router v6 configuration and patterns
- Protected routes and navigation
- TailwindCSS component patterns
- Responsive design with Tailwind
- Dark mode implementation
- Form handling with React Hook Form
- Optimized component patterns
- State management best practices

## Common Workflows

### 1. Create Microservices Architecture

Start a new project with microservices:

```bash
bash scripts/create_solution.sh ECommerceApp ./projects --microservices
```

Run with Aspire (recommended):
```bash
cd ECommerceApp.AppHost
dotnet run
```

Or run all services manually:
```bash
cd ECommerceApp
./run-all-services.sh
```

Access:
- Gateway Swagger: `http://localhost:5000/swagger`
- Frontend: `http://localhost:5173`
- Users Service: `http://localhost:5001/swagger`
- Orders Service: `http://localhost:5002/swagger`

### 2. Add New Microservice

Add a Products microservice:

```bash
cd ECommerceApp
bash ../scripts/add_microservice.sh Products 5003 3503 .
```

Update Gateway configuration in `gateway/ApiGateway/ECommerceApp.Gateway/appsettings.json`:

```json
{
  "ReverseProxy": {
    "Routes": {
      "product-service-route": {
        "ClusterId": "product-service",
        "Match": {
          "Path": "/api/products/{**catch-all}"
        },
        "Transforms": [
          { "PathPattern": "/api/{**catch-all}" }
        ]
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
  }
}
```

Start the new service:

```bash
cd services/Products
./run-with-dapr.sh
```

### 3. Service-to-Service Communication

In one microservice, call another using Dapr:

```csharp
// In Orders service, call Users service
app.MapPost("/api/orders", async (CreateOrderRequest request, DaprClient daprClient) =>
{
    // Get user info from Users service
    var user = await daprClient.InvokeMethodAsync<UserResponse>(
        HttpMethod.Get,
        "users",  // App ID of Users service
        $"api/users/{request.UserId}"
    );
    
    if (user == null)
        return Results.NotFound("User not found");
    
    // Create order logic...
    var order = new Order { /* ... */ };
    
    // Publish event
    await daprClient.PublishEventAsync("pubsub", "order-created", order);
    
    return Results.Created($"/api/orders/{order.Id}", order);
});
```

### 4. Subscribe to Events Across Services

In Notification service, listen to order events:

```csharp
// Subscribe to events from other services
app.MapPost("/api/events/order-created",
    [Topic("pubsub", "order-created")]
    async (OrderCreatedEvent evt, DaprClient daprClient) =>
{
    // Get user details
    var user = await daprClient.InvokeMethodAsync<UserResponse>(
        HttpMethod.Get,
        "users",
        $"api/users/{evt.UserId}"
    );
    
    // Send notification
    await SendEmailAsync(user.Email, "Order Created", $"Order {evt.OrderId} created");
    
    return Results.Ok();
});

// Enable Dapr pub/sub
app.MapSubscribeHandler();
```

### 5. Add New API Endpoint

Edit `MyApp.Api/MyApp.Api/Program.cs`:

```csharp
app.MapGet("/api/users", () => Results.Ok(users))
    .WithName("GetUsers")
    .WithTags("Users")
    .WithOpenApi();
```

### 6. Create Zustand Store

Copy template and customize:

```bash
cp assets/zustand-store-template.ts MyApp.Frontend/src/stores/userStore.ts
```

### 7. Set Up API Service

Copy template and add endpoints:

```bash
cp assets/api-service-template.ts MyApp.Frontend/src/services/api.ts
```

### 8. Configure CORS for Production

Update `appsettings.json` with production origins:

```json
{
  "Cors": {
    "AllowedOrigins": ["https://yourdomain.com"]
  }
}
```

### 9. Add New Route

Create page component and add to router:

```typescript
// src/pages/Products.tsx
export default function Products() {
  return <div className="container mx-auto px-4">Products</div>;
}

// Add to App.tsx
<Route path="products" element={<Products />} />
```

### 10. Create Tailwind Component

Build reusable UI components:

```typescript
function Card({ children }: { children: ReactNode }) {
  return (
    <div className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
      {children}
    </div>
  );
}
```

## Prerequisites

Verify required tools before project creation:

- **.NET 10 SDK**: Check with `dotnet --version`
- **Node.js 18+**: Check with `node --version`
- **npm**: Check with `npm --version`
- **Dapr CLI** (for microservices): Install with `wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash` then run `dapr init`
- **Docker** (for containerization): Check with `docker --version`
- **Docker Compose** (for orchestration): Check with `docker-compose --version`

## Troubleshooting

### Microservices Not Communicating

**Issue**: Services can't find each other

**Solutions**:
1. Verify Dapr is running: `dapr --version`
2. Check Dapr components: `ls dapr-config/components/`
3. Verify App IDs match in service calls
4. Check Dapr sidecar logs: `docker logs dapr_<app-id>`
5. Ensure Redis is running: `docker ps | grep redis`

### Gateway Not Routing

**Issue**: Gateway returns 503 or 404

**Solutions**:
1. Verify services are running on configured ports
2. Check `appsettings.json` routes and clusters configuration
3. Test services directly before going through gateway
4. Check gateway logs for routing errors

### Docker Compose Fails

**Issue**: Services fail to start with Docker Compose

**Solutions**:
1. Check Docker daemon is running: `docker info`
2. Verify no port conflicts: `docker ps`
3. Check logs: `docker-compose logs <service-name>`
4. Rebuild images: `docker-compose build --no-cache`
5. Clean Docker: `docker-compose down -v`

### Port Conflicts

If default ports are in use:

**Backend**: Edit `Properties/launchSettings.json` to change ports
**Frontend**: Vite will prompt for alternative port or set in `vite.config.ts`
**Microservices**: Pass different port when creating: `bash scripts/add_microservice.sh MyService 5010 3510 .`

### CORS Issues

Ensure frontend URL is in `appsettings.json`:

```json
"Cors": {
  "AllowedOrigins": ["http://localhost:5173"]
}
```

### Package Installation Fails

For frontend, try:
```bash
rm -rf node_modules package-lock.json
npm install
```

## Example Usage Scenarios

### .NET Aspire Applications (Always On)

**"Create a cloud-native app with Aspire"**
→ Run: `bash scripts/create_solution.sh MyApp .`

**"Start everything with one command"**
→ Run: `cd MyApp.AppHost && dotnet run`

**"View telemetry and logs from all services"**
→ Open Aspire Dashboard: `http://localhost:15888`

**"Add service discovery to my API"**
→ Always included; services communicate by name

**"Deploy to Azure Container Apps"**
→ Run: `azd init && azd up` (see `references/aspire-integration.md`)

**"Generate Kubernetes manifests from Aspire"**
→ Run: `cd MyApp.AppHost && dotnet publish /t:GenerateDeploymentManifest`

**"Create microservices orchestrated by Aspire"**
→ Run: `bash scripts/create_solution.sh ECommerce . --microservices`

**"Monitor distributed traces across services"**
→ Aspire Dashboard → Traces tab shows end-to-end request flow

**"Add custom metrics to my service"**
→ See Custom Telemetry in `references/aspire-integration.md`

**"Configure health checks for dependencies"**
→ See Health Checks in `references/aspire-integration.md`

### Monolithic Applications

**"Create a new full-stack app called TodoApp"**
→ Run: `bash scripts/create_solution.sh TodoApp .`

**"Set up a .NET API with Swagger"**
→ Run: `bash scripts/create_dotnet_api.sh MyApi .`

**"Initialize a React app with Zustand"**
→ Run: `bash scripts/create_react_app.sh MyReactApp .`

**"Add a Zustand store for user management"**
→ Copy `assets/zustand-store-template.ts` and customize

**"Configure the API service with authentication"**
→ Read `references/dotnet-best-practices.md` for JWT setup

**"Add Dapr state management to my API"**
→ Read `references/dapr-integration.md` for Dapr patterns

**"Set up pub/sub messaging with Dapr"**
→ Endpoints already included, see `references/dapr-integration.md` for configuration

**"Run the API with Dapr sidecar"**
→ Run: `dapr run --app-id myapi --app-port 5000 --dapr-http-port 3500 -- dotnet run`

**"Add a new route to my React app"**
→ Create page component in `src/pages/`, add route to App.tsx

**"Create a styled button component with Tailwind"**
→ Copy `assets/Button-component-template.tsx` and customize

**"Set up protected routes with authentication"**
→ See `references/react-zustand-patterns.md` for Protected Routes pattern

**"Implement clean architecture with 4+1 model"**
→ Structure already included, see `Architecture.md` in generated project

**"Create a domain entity following DDD principles"**
→ See `references/kruchten-4plus1-architecture.md` for examples

**"Organize endpoints by domain modules"**
→ Use endpoint grouping pattern in `references/kruchten-4plus1-architecture.md`

### Microservices Applications

**"Create a microservices e-commerce platform"**
→ Run: `bash scripts/create_solution.sh ECommerce . --microservices`

**"Add a Products microservice to my solution"**
→ Run: `bash scripts/add_microservice.sh Products 5003 3503 ./ECommerce`

**"Set up API Gateway with YARP"**
→ Already included with `--microservices` flag, see `gateway/ApiGateway/`

**"Configure service-to-service communication"**
→ Use Dapr InvokeMethodAsync, see `references/microservices-architecture.md`

**"Implement event-driven architecture with pub/sub"**
→ See Pub/Sub patterns in `references/microservices-architecture.md`

**"Create a distributed transaction with Saga pattern"**
→ See Saga implementation in `references/microservices-architecture.md`

**"Deploy microservices to Kubernetes"**
→ K8s manifests in `references/microservices-architecture.md`

**"Add circuit breaker for resilient service calls"**
→ See Circuit Breaker with Polly in `references/microservices-architecture.md`

**"Set up distributed tracing with Zipkin"**
→ Dapr tracing configured, see `references/dapr-integration.md`

**"Scale individual microservices independently"**
→ K8s HPA configuration in `references/microservices-architecture.md`

**"Start all microservices in development mode"**
→ Prefer: `cd MyEcommerce.AppHost && dotnet run` (Aspire)

**"Start all microservices with the legacy script"**
→ Run: `./run-all-services.sh`

**"Deploy full stack with Docker Compose"**
→ Run: `docker-compose up --build`
