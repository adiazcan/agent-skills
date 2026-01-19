---
name: project-creator
description: Create complete microservices project solutions using .NET 10 Minimal API backend with Dapr integration and Vite + React + Zustand frontend, orchestrated with .NET Aspire 13. Use this skill when the user wants to scaffold a new microservices solution, create a distributed application with API and frontend, set up a full-stack .NET + React project, or generate a modern cloud-native solution with orchestration. Triggers on requests involving microservices project, full-stack solution, .NET Aspire setup, API + frontend scaffold, distributed app creation.
---

# Microservices Creator

Create modern microservices solutions with .NET 10 + React + Aspire orchestration following Kruchten's 4+1 architectural model.

## Solution Architecture

The generated solution includes:

- **Backend**: .NET 10 Minimal API with OpenAPI + Scalar UI, Dapr integration
- **Frontend**: Vite + React + Zustand + Tailwind CSS + React Router  
- **Orchestration**: .NET Aspire 13 AppHost for dev-time orchestration

## Workflow

1. Gather user requirements (or use defaults)
2. Check prerequisites
3. Run automation script or follow manual workflow
4. Verify the solution works

## Step 1: Gather Requirements

Ask only what is strictly necessary. Propose defaults and proceed if user accepts or doesn't respond:

| Parameter | Default | Description |
|-----------|---------|-------------|
| Solution name | `MySolution` | Name for solution and project folders |
| Root folder | Current directory | Where to create the solution |
| API HTTP port | `5080` | Backend HTTP port |
| API HTTPS port | `7080` | Backend HTTPS port |
| Web port | `5173` | Frontend dev server port |

**If user does not specify or says "use defaults", proceed automatically with defaults.**

## Step 2: Check Prerequisites

Before proceeding, verify:

- [ ] .NET 10 SDK installed (`dotnet --version` should show 10.x)
- [ ] Node.js 20+ installed (`node --version`)
- [ ] Aspire CLI installed (`aspire --version` should show 13.x)
- [ ] Docker or Podman running (for Aspire containers)
- [ ] Dapr CLI installed (`dapr --version`)
- [ ] Dapr initialized (`dapr init` must have been run)

### Install Aspire CLI

**Linux/macOS:**
```bash
curl -fsSL https://aspire.dev/install.sh | bash
```

**Windows PowerShell:**
```powershell
irm https://aspire.dev/install.ps1 | iex
```

### Install Dapr CLI

**Linux/macOS:**
```bash
wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
dapr init
```

**Windows PowerShell:**
```powershell
powershell -Command "iwr -useb https://raw.githubusercontent.com/dapr/cli/master/install/install.ps1 | iex"
dapr init
```

## Step 3: Generate Solution

**Preferred approach**: Run the automation script from `scripts/` folder.

**If scripts cannot run**: Follow manual workflow in [REFERENCE.md](references/REFERENCE.md).

### Using Scripts

**Linux/macOS:**
```bash
./scripts/create-solution.sh -n <SolutionName> -p <RootPath> --api-http 5080 --api-https 7080 --web 5173
```

**Windows PowerShell:**
```powershell
.\scripts\create-solution.ps1 -Name <SolutionName> -Path <RootPath> -ApiHttp 5080 -ApiHttps 7080 -Web 5173
```

### Manual Workflow

If scripts cannot be used, follow [REFERENCE.md](references/REFERENCE.md) for step-by-step commands.

Template details:
- API template: [TEMPLATE_API.md](references/TEMPLATE_API.md)
- Web template: [TEMPLATE_WEB.md](references/TEMPLATE_WEB.md)

## Step 4: Verify Solution (Definition of Done)

Run this checklist after generation:

- [ ] `dotnet build` completes successfully in solution root
- [ ] `aspire run` starts the AppHost
- [ ] Backend API runs and Scalar UI loads at `https://localhost:7080/scalar/v1`
- [ ] Frontend runs at `http://localhost:5173` and can call the API (or has API endpoint wired via environment variables)

## Quick Run Commands

After generation:

```bash
cd <SolutionName>
aspire run
```

This starts all services via the Aspire dashboard.

## Project Structure

```
<SolutionName>/
├── <SolutionName>.sln
├── src/
│   ├── <SolutionName>.AppHost/           # Aspire orchestrator
│   │   ├── AppHost.cs
│   │   └── <SolutionName>.AppHost.csproj
│   ├── <SolutionName>.ServiceDefaults/   # Shared service config
│   │   ├── Extensions.cs
│   │   └── <SolutionName>.ServiceDefaults.csproj
│   ├── <SolutionName>.Api/               # .NET 10 Minimal API
│   │   ├── Program.cs
│   │   ├── appsettings.json
│   │   └── <SolutionName>.Api.csproj
│   └── <SolutionName>.Web/               # Vite + React frontend
│       ├── src/
│       │   ├── App.tsx
│       │   ├── main.tsx
│       │   ├── store/
│       │   └── components/
│       ├── package.json
│       ├── vite.config.ts
│       └── tailwind.config.js
└── README.md
```

## Adding New Microservices

To add a new microservice to an existing solution:

### Using Scripts

**Linux/macOS:**
```bash
./scripts/add-microservice.sh -n <ServiceName> -s <SolutionPath>
```

**Windows PowerShell:**
```powershell
.\scripts\add-microservice.ps1 -Name <ServiceName> -Solution <SolutionPath>
```

**Options:**
| Parameter | Description |
|-----------|-------------|
| `-n, --name` | Service name (required, e.g., 'Orders', 'Products') |
| `-s, --solution` | Path to solution root (default: current directory) |
| `--http` | HTTP port (default: auto-assigned) |
| `--https` | HTTPS port (default: auto-assigned) |

### What the Script Does

1. Creates a new .NET 10 Minimal API project
2. Adds it to the solution
3. Registers it in the AppHost for Aspire orchestration
4. Configures health checks and OpenAPI with Scalar UI

### After Adding a Service

1. Update `AppHost.cs` to add `.WithReference()` if the new service needs to call other services
2. Implement your domain logic and endpoints in the new service's `Program.cs`
3. Run `aspire run` to test

### Manual Workflow

See [REFERENCE.md](references/REFERENCE.md#adding-a-new-microservice) for manual steps.

## Architecture (Kruchten 4+1 View Model)

The solution follows Kruchten's 4+1 architectural views:

- **Logical View**: Domain models and business logic in API layer
- **Process View**: Async communication via Dapr pub/sub
- **Development View**: Modular project structure with clear separation
- **Physical View**: Container-ready services orchestrated by Aspire
- **Scenarios**: API endpoints as use case implementations
