# {{SOLUTION_NAME}}

A modern microservices solution with .NET 10 + React + Aspire orchestration.

## Prerequisites

- .NET 10 SDK
- Node.js 20+
- Aspire CLI (`aspire --version` should show 13.x)
- Docker or Podman (for containers)

## Quick Start

```bash
# Run with Aspire (recommended)
aspire run
```

This starts:
- **API**: https://localhost:{{API_HTTPS_PORT}}/scalar/v1
- **Web**: http://localhost:{{WEB_PORT}}
- **Aspire Dashboard**: Shown in terminal output

## Manual Run

```bash
# Terminal 1 - API
cd src/{{SOLUTION_NAME}}.Api
dotnet run

# Terminal 2 - Web
cd src/{{SOLUTION_NAME}}.Web
npm run dev
```

## Project Structure

```
{{SOLUTION_NAME}}/
├── src/
│   ├── {{SOLUTION_NAME}}.AppHost/       # Aspire orchestrator
│   ├── {{SOLUTION_NAME}}.ServiceDefaults/   # Shared service config
│   ├── {{SOLUTION_NAME}}.Api/           # .NET 10 Minimal API
│   └── {{SOLUTION_NAME}}.Web/           # Vite + React frontend
└── {{SOLUTION_NAME}}.sln
```

## Ports

- API HTTP: {{API_HTTP_PORT}}
- API HTTPS: {{API_HTTPS_PORT}}
- Web: {{WEB_PORT}}
