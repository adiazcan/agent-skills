# Reference: Manual Workflow

Complete step-by-step commands when automation scripts cannot be used.

## Table of Contents

1. [Create Solution Structure](#1-create-solution-structure)
2. [Create Service Defaults](#2-create-service-defaults)
3. [Create Backend API](#3-create-backend-api)
4. [Create AppHost](#4-create-apphost)
5. [Create Frontend Web](#5-create-frontend-web)
6. [Add Projects to Solution](#6-add-projects-to-solution)
7. [Build and Run](#7-build-and-run)

---

## Overview

This document provides a manual workflow for creating a microservices solution when automation scripts cannot be used. All code templates are stored in `../assets/templates/` and referenced throughout this guide.

Replace `{SolutionName}` with your actual solution name and `{ports}` with your chosen port numbers throughout.

---

## 1. Create Solution Structure

```bash
# Create root directory and solution
mkdir -p {SolutionName}/src
cd {SolutionName}
dotnet new sln -n {SolutionName}
```

---

## 2. Create Service Defaults

The ServiceDefaults project provides shared configuration for OpenTelemetry, health checks, and service discovery.

```bash
# Create project directory
mkdir -p src/{SolutionName}.ServiceDefaults
cd src/{SolutionName}.ServiceDefaults

# Copy template files from assets/templates/servicedefaults/
# - ServiceDefaults.csproj (update solution name)
# - Extensions.cs (no changes needed)

cd ../..
```

**Template files:** See [`assets/templates/servicedefaults/`](../assets/templates/servicedefaults/)
- `ServiceDefaults.csproj` - Project file with OpenTelemetry packages
- `Extensions.cs` - Extension methods for service configuration

**Placeholders to replace:**
- None (Extensions.cs is generic)
- Update project name in .csproj references if needed

---

## 3. Create Backend API

The API project follows Kruchten's 4+1 architecture with:
- **Models/** - Logical View (domain models)
- **Services/** - Process View (business logic)
- **Endpoints/** - Scenario View (use cases/API endpoints)
- **Infrastructure/** - Physical View (Dapr, state stores, etc.)

```bash
# Create project structure
mkdir -p src/{SolutionName}.Api/Properties
mkdir -p src/{SolutionName}.Api/Models
mkdir -p src/{SolutionName}.Api/Services
mkdir -p src/{SolutionName}.Api/Endpoints
mkdir -p src/{SolutionName}.Api/Infrastructure

cd src/{SolutionName}.Api

# Copy template files from assets/templates/microservice/
# Update {{SOLUTION_NAME}}, {{PROJECT_NAME}}, {{SERVICE_NAME}}, and {{PORTS}} placeholders

cd ../..
```

**Template files:** See [`assets/templates/microservice/`](../assets/templates/microservice/)

| File | Description | Placeholders |
|------|-------------|--------------|
| `Microservice.csproj` | Project file with Dapr, OpenAPI, Scalar | `{{SOLUTION_NAME}}`, `{{PROJECT_NAME}}` |
| `Program.cs` | Application entry point and configuration | `{{PROJECT_NAME}}`, `{{SERVICE_NAME}}` |
| `appsettings.json` | Configuration settings | None |
| `appsettings.Development.json` | Development settings | None |
| `launchSettings.json` | Launch profiles with ports | `{{HTTP_PORT}}`, `{{HTTPS_PORT}}` |
| `Models/Model.cs` | Sample domain model | `{{PROJECT_NAME}}`, `{{SERVICE_NAME}}` |
| `Services/IService.cs` | Service interface | `{{PROJECT_NAME}}`, `{{SERVICE_NAME}}` |
| `Services/Service.cs` | Service implementation | `{{PROJECT_NAME}}`, `{{SERVICE_NAME}}` |
| `Endpoints/Endpoints.cs` | API endpoint definitions | `{{PROJECT_NAME}}`, `{{SERVICE_NAME}}`, `{{SERVICE_NAME_LOWER}}` |
| `Infrastructure/DaprStateStore.cs` | Dapr state management | `{{PROJECT_NAME}}` |

**Steps:**
1. Copy each template file to the appropriate location (rename to match your API)
2. Replace all placeholders:
   - `{{SOLUTION_NAME}}` → Your solution name (e.g., `MyApp`)
   - `{{PROJECT_NAME}}` → `{SolutionName}.Api` (e.g., `MyApp.Api`)
   - `{{SERVICE_NAME}}` → `Weather` (for initial API)
   - `{{SERVICE_NAME_LOWER}}` → `weather`
   - `{{HTTP_PORT}}` → e.g., 5080
   - `{{HTTPS_PORT}}` → e.g., 7080

---

## 4. Create AppHost

The AppHost orchestrates all services using .NET Aspire 13.

```bash
# Create project structure
mkdir -p src/{SolutionName}.AppHost/Properties

cd src/{SolutionName}.AppHost

# Copy template files from assets/templates/apphost/
# Update {{SOLUTION_NAME}} placeholder

cd ../..
```

**Template files:** See [`assets/templates/apphost/`](../assets/templates/apphost/)

| File | Description | Placeholders |
|------|-------------|--------------|
| `AppHost.csproj` | Project file with Aspire packages | `{{SOLUTION_NAME}}` |
| `AppHost.cs` | Service orchestration configuration | `{{SOLUTION_NAME}}` |
| `appsettings.json` | Aspire configuration | None |
| `appsettings.Development.json` | Development configuration | None |
| `launchSettings.json` | Launch settings for Aspire dashboard | None |

**Steps:**
1. Copy template files to `src/{SolutionName}.AppHost/`
2. Replace `{{SOLUTION_NAME}}` with your solution name
3. Update `AppHost.cs` to reference your projects

---

## 5. Create Frontend Web

The frontend is a Vite + React + Zustand application with Tailwind CSS.

```bash
# Create project structure
mkdir -p src/{SolutionName}.Web/src/api
mkdir -p src/{SolutionName}.Web/src/store
mkdir -p src/{SolutionName}.Web/src/components
mkdir -p src/{SolutionName}.Web/src/pages
mkdir -p src/{SolutionName}.Web/src/types
mkdir -p src/{SolutionName}.Web/public

cd src/{SolutionName}.Web

# Copy template files from assets/templates/web/
# Update {{SOLUTION_NAME}}, {{SOLUTION_NAME_LOWER}}, and {{PORTS}} placeholders

cd ../..
```

**Template files:** See [`assets/templates/web/`](../assets/templates/web/)

### Root Configuration Files

| File | Description | Placeholders |
|------|-------------|--------------|
| `package.json` | NPM dependencies and scripts | `{{SOLUTION_NAME_LOWER}}`, `{{WEB_PORT}}` |
| `vite.config.ts` | Vite configuration with proxy | `{{WEB_PORT}}`, `{{API_HTTPS_PORT}}` |
| `tailwind.config.js` | Tailwind CSS configuration | None |
| `postcss.config.js` | PostCSS configuration | None |
| `tsconfig.json` | TypeScript configuration | None |
| `tsconfig.node.json` | TypeScript config for Vite | None |
| `.env` | Environment variables | `{{API_HTTPS_PORT}}` |
| `index.html` | HTML entry point | `{{SOLUTION_NAME}}` |

### Source Files

| File | Description | Placeholders |
|------|-------------|--------------|
| `src/main.tsx` | React entry point | None |
| `src/App.tsx` | Main App component with routing | None |
| `src/index.css` | Global styles with Tailwind | None |
| `src/vite-env.d.ts` | TypeScript environment types | None |
| `src/types/weather.ts` | TypeScript type definitions | None |
| `src/store/weatherStore.ts` | Zustand state management | None |
| `src/store/index.ts` | Store exports | None |
| `src/api/weatherApi.ts` | API client with axios | None |
| `src/components/Layout.tsx` | Layout component | `{{SOLUTION_NAME}}` |
| `src/components/Navbar.tsx` | Navigation component | `{{SOLUTION_NAME}}` |
| `src/components/WeatherCard.tsx` | Weather card component | None |
| `src/pages/Home.tsx` | Home page | `{{SOLUTION_NAME}}` |
| `src/pages/Weather.tsx` | Weather forecast page | None |

**Steps:**
1. Copy all template files to the appropriate locations
2. Replace placeholders:
   - `{{SOLUTION_NAME}}` → Your solution name
   - `{{SOLUTION_NAME_LOWER}}` → Lowercase version (for package.json)
   - `{{WEB_PORT}}` → e.g., 5173
   - `{{API_HTTPS_PORT}}` → e.g., 7080
3. Copy `public/vite.svg` for the favicon

---

## 6. Add Projects to Solution

```bash
# From solution root directory
dotnet sln add src/{SolutionName}.ServiceDefaults/{SolutionName}.ServiceDefaults.csproj
dotnet sln add src/{SolutionName}.Api/{SolutionName}.Api.csproj
dotnet sln add src/{SolutionName}.AppHost/{SolutionName}.AppHost.csproj
```

---

## 7. Build and Run

```bash
# Restore .NET packages
dotnet restore

# Build solution
dotnet build

# Install Node.js dependencies
cd src/{SolutionName}.Web
npm install
cd ../..

# Run with Aspire (recommended)
aspire run

# OR run manually:
# Terminal 1 - API
cd src/{SolutionName}.Api
dotnet run

# Terminal 2 - Web
cd src/{SolutionName}.Web
npm run dev
```

---

## Adding a New Microservice

To add a new microservice to an existing solution:

1. **Create new API project** using the microservice templates:
   ```bash
   mkdir -p src/{SolutionName}.{ServiceName}/Properties
   mkdir -p src/{SolutionName}.{ServiceName}/Models
   mkdir -p src/{SolutionName}.{ServiceName}/Services
   mkdir -p src/{SolutionName}.{ServiceName}/Endpoints
   mkdir -p src/{SolutionName}.{ServiceName}/Infrastructure
   
   # Copy and adapt templates from assets/templates/microservice/
   # Replace {{SERVICE_NAME}} with your service name (e.g., Orders)
   ```

2. **Add to solution:**
   ```bash
   dotnet sln add src/{SolutionName}.{ServiceName}/{SolutionName}.{ServiceName}.csproj
   ```

3. **Register in AppHost:**
   Edit `src/{SolutionName}.AppHost/AppHost.cs`:
   ```csharp
   var newService = builder.AddProject<Projects.{SolutionName}_{ServiceName}>("{servicename}")
       .WithDaprSidecar()
       .WithHttpHealthCheck("/health");
   ```

4. **Add project reference if services need to communicate:**
   ```bash
   cd src/{SolutionName}.{ServiceName}
   dotnet add reference ../{SolutionName}.ServiceDefaults/{SolutionName}.ServiceDefaults.csproj
   ```

---

## Template System

All templates use the following placeholder convention:

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{{SOLUTION_NAME}}` | C# namespace and project names | `MyCompany.Orders` |
| `{{SOLUTION_NAME_LOWER}}` | Lowercase for package names | `mycompany-orders` |
| `{{PROJECT_NAME}}` | Full project name (for microservices) | `MyCompany.Api` |
| `{{SERVICE_NAME}}` | Service name (for microservices) | `Weather`, `Orders` |
| `{{SERVICE_NAME_LOWER}}` | Lowercase service name | `weather`, `orders` |
| `{{HTTP_PORT}}` | HTTP port for microservice | `5080` |
| `{{HTTPS_PORT}}` | HTTPS port for microservice | `7080` |
| `{{API_HTTP_PORT}}` | HTTP port for API (legacy) | `5080` |
| `{{API_HTTPS_PORT}}` | HTTPS port for API (legacy) | `7080` |
| `{{WEB_PORT}}` | Frontend dev server port | `5173` |

### Substitution Methods

**Bash (Linux/macOS):**
```bash
sed -e 's/{{SOLUTION_NAME}}/MyApp/g' \
    -e 's/{{API_HTTPS_PORT}}/7080/g' \
    template.txt > output.txt
```

**PowerShell (Windows):**
```powershell
(Get-Content template.txt) -replace '{{SOLUTION_NAME}}','MyApp' `
    -replace '{{API_HTTPS_PORT}}','7080' | Set-Content output.txt
```

---

## Project Structure Reference

```
{SolutionName}/
├── {SolutionName}.sln
├── README.md
└── src/
    ├── {SolutionName}.AppHost/           # Aspire orchestrator
    │   ├── AppHost.cs
    │   ├── {SolutionName}.AppHost.csproj
    │   ├── appsettings.json
    │   ├── appsettings.Development.json
    │   └── Properties/
    │       └── launchSettings.json
    ├── {SolutionName}.ServiceDefaults/   # Shared service config
    │   ├── Extensions.cs
    │   └── {SolutionName}.ServiceDefaults.csproj
    ├── {SolutionName}.Api/               # .NET 10 Minimal API
    │   ├── Program.cs
    │   ├── {SolutionName}.Api.csproj
    │   ├── appsettings.json
    │   ├── appsettings.Development.json
    │   ├── Properties/
    │   │   └── launchSettings.json
    │   ├── Models/                       # Logical View
    │   │   └── WeatherForecast.cs
    │   ├── Services/                     # Process View
    │   │   ├── IWeatherService.cs
    │   │   └── WeatherService.cs
    │   ├── Endpoints/                    # Scenario View
    │   │   └── WeatherEndpoints.cs
    │   └── Infrastructure/               # Physical View
    │       └── DaprStateStore.cs
    └── {SolutionName}.Web/               # Vite + React frontend
        ├── package.json
        ├── vite.config.ts
        ├── tsconfig.json
        ├── tsconfig.node.json
        ├── tailwind.config.js
        ├── postcss.config.js
        ├── .env
        ├── index.html
        ├── public/
        │   └── vite.svg
        └── src/
            ├── main.tsx
            ├── App.tsx
            ├── index.css
            ├── vite-env.d.ts
            ├── types/
            │   └── weather.ts
            ├── store/
            │   ├── index.ts
            │   └── weatherStore.ts
            ├── api/
            │   └── weatherApi.ts
            ├── components/
            │   ├── Layout.tsx
            │   ├── Navbar.tsx
            │   └── WeatherCard.tsx
            └── pages/
                ├── Home.tsx
                └── Weather.tsx
```

---

## Troubleshooting

### .NET Build Issues

**Missing project references:**
```bash
dotnet add src/{SolutionName}.Api/{SolutionName}.Api.csproj reference \
    src/{SolutionName}.ServiceDefaults/{SolutionName}.ServiceDefaults.csproj
```

**Restore failures:**
```bash
dotnet nuget locals all --clear
dotnet restore --force
```

### Node.js / NPM Issues

**Dependency conflicts:**
```bash
cd src/{SolutionName}.Web
rm -rf node_modules package-lock.json
npm install
```

**Port already in use:**
Update `vite.config.ts` and `.env` with different port numbers.

### Aspire Issues

**CLI not found:**
```bash
# Linux/macOS
curl -fsSL https://aspire.dev/install.sh | bash

# Windows
irm https://aspire.dev/install.ps1 | iex
```

**Dapr not initialized:**
```bash
dapr init
```

---

## Additional Resources

- **Templates:** [`../assets/templates/`](../assets/templates/)
- **Automation Scripts:** [`../scripts/`](../scripts/)
- **Skill Documentation:** [`../SKILL.md`](../SKILL.md)
- **.NET Aspire:** https://learn.microsoft.com/en-us/dotnet/aspire/
- **Dapr:** https://docs.dapr.io/
- **React + Vite:** https://vitejs.dev/guide/
