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

## Architecture Overview

This skill uses a **single-source-of-truth template system** to eliminate code duplication:

- **Templates:** Stored in [`assets/templates/`](assets/templates/) with `{{PLACEHOLDER}}` syntax
- **Scripts:** Thin orchestrators in [`scripts/`](scripts/) that read templates and substitute placeholders
- **Documentation:** [`references/REFERENCE.md`](references/REFERENCE.md) references templates directly

**Benefits:**
- Update once in `assets/templates/` → changes propagate everywhere
- Scripts are ~80 lines vs ~1100+ in previous version
- Manual workflow and automation use identical templates
- Easy to maintain and extend

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

All templates are located in [`assets/templates/`](assets/templates/) organized by project type:
- `servicedefaults/` - Shared service configuration
- `microservice/` - Backend API with 4+1 architecture (used for initial API and added microservices)
- `apphost/` - Aspire orchestration
- `web/` - React frontend with Vite + Zustand

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

### Generated Solution Structure

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
│   │   ├── Models/                       # Logical View
│   │   ├── Services/                     # Process View
│   │   ├── Endpoints/                    # Scenario View
│   │   └── Infrastructure/               # Physical View
│   └── <SolutionName>.Web/               # Vite + React frontend
│       ├── src/
│       │   ├── App.tsx
│       │   ├── main.tsx
│       │   ├── store/
│       │   ├── components/
│       │   ├── pages/
│       │   └── api/
│       ├── package.json
│       ├── vite.config.ts
│       └── tailwind.config.js
└── README.md
```

### Skill Structure

```
project-creator/
├── SKILL.md                     # This file - skill documentation
├── assets/
│   └── templates/               # Single source of truth for all code
│       ├── servicedefaults/     # ServiceDefaults templates
│       ├── api/                 # API templates (4+1 architecture)
│       ├── apphost/             # AppHost templates
│       ├── web/                 # React frontend templates
│       └── README.md            # Solution README template
├── scripts/
│   ├── create-solution.sh       # Bash script (thin orchestrator)
│   ├── create-solution.ps1      # PowerShell script (thin orchestrator)
│   ├── add-microservice.sh      # Add service to existing solution
│   └── add-microservice.ps1
└── references/
    └── REFERENCE.md             # Manual workflow (references templates)
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

---

## Template System

The skill uses a **single-source-of-truth template system** to eliminate duplication:

### Template Organization

All templates are located in [`assets/templates/`](assets/templates/):

```
assets/templates/
├── servicedefaults/
│   ├── ServiceDefaults.csproj
│   └── Extensions.cs
├── microservice/                    # Used for both initial API and added services
│   ├── Microservice.csproj
│   ├── Program.cs
│   ├── appsettings.json
│   ├── appsettings.Development.json
│   ├── launchSettings.json
│   ├── Models/Model.cs
│   ├── Services/IService.cs
│   ├── Services/Service.cs
│   ├── Endpoints/Endpoints.cs
│   └── Infrastructure/DaprStateStore.cs
├── apphost/
│   ├── AppHost.csproj
│   ├── AppHost.cs
│   ├── appsettings.json
│   ├── appsettings.Development.json
│   └── launchSettings.json
├── web/
│   ├── package.json
│   ├── vite.config.ts
│   ├── src/App.tsx
│   ├── src/main.tsx
│   ├── src/components/...
│   ├── src/pages/...
│   └── ...
└── README.md
```

### Placeholder Convention

Templates use `{{PLACEHOLDER}}` syntax for variable substitution:

| Placeholder | Description | Example Value |
|-------------|-------------|---------------|
| `{{SOLUTION_NAME}}` | C# namespaces and project names | `MyCompany.Orders` |
| `{{SOLUTION_NAME_LOWER}}` | Lowercase for package names | `mycompany-orders` |
| `{{PROJECT_NAME}}` | Full project name (for microservices) | `MyCompany.Orders` |
| `{{SERVICE_NAME}}` | Service name (for microservices) | `Orders` |
| `{{SERVICE_NAME_LOWER}}` | Lowercase service name | `orders` |
| `{{API_HTTP_PORT}}` | HTTP port for API | `5080` |
| `{{API_HTTPS_PORT}}` | HTTPS port for API | `7080` |
| `{{HTTP_PORT}}` | HTTP port (microservices) | `5100` |
| `{{HTTPS_PORT}}` | HTTPS port (microservices) | `6100` |
| `{{WEB_PORT}}` | Frontend dev server port | `5173` |

### How It Works

1. **Scripts read templates** from `assets/templates/`
2. **Substitute placeholders** with user-provided or default values
3. **Write to destination** in the generated solution

**Shell script example:**
```bash
sed -e "s|{{SOLUTION_NAME}}|$SOLUTION_NAME|g" \
    -e "s|{{API_HTTPS_PORT}}|$API_HTTPS_PORT|g" \
    template.txt > output.txt
```

**PowerShell example:**
```powershell
(Get-Content template.txt) -replace '{{SOLUTION_NAME}}','MyApp' | 
    Set-Content output.txt
```

### Benefits

- ✅ **Single source of truth:** Update template once, changes propagate everywhere
- ✅ **Maintainability:** Scripts reduced from 1100+ lines to ~250 lines
- ✅ **Consistency:** Manual workflow and automation use identical templates
- ✅ **Extensibility:** Easy to add new project types or modify existing ones
- ✅ **Testability:** Templates can be validated independently of scripts

### Updating Templates

To modify the generated solution structure:

1. Edit files in `assets/templates/`
2. Test with `./scripts/create-solution.sh -n TestSolution`
3. Verify both automated and manual workflows work
4. Document changes in `REFERENCE.md` if needed

**No need to update:**
- Scripts (they read from templates automatically)
- Documentation (references templates directly)
