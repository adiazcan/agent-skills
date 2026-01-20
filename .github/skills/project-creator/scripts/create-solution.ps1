#Requires -Version 7.0
<#
.SYNOPSIS
    Create a microservices solution with .NET Aspire + React

.DESCRIPTION
    Creates a complete microservices solution with:
    - .NET 10 Minimal API with OpenAPI + Scalar and Dapr
    - Vite + React + Zustand + Tailwind CSS frontend
    - .NET Aspire orchestration

.PARAMETER Name
    The solution name. Default: MySolution

.PARAMETER Path
    Root path for the solution. Default: current directory

.PARAMETER ApiHttp
    API HTTP port. Default: 5080

.PARAMETER ApiHttps
    API HTTPS port. Default: 7080

.PARAMETER Web
    Web dev server port. Default: 5173

.EXAMPLE
    .\create-solution.ps1 -Name "MyApp" -Path "C:\Projects"

.EXAMPLE
    .\create-solution.ps1 -Name "MyApp" -ApiHttp 5000 -ApiHttps 5001 -Web 3000
#>

param(
    [Parameter(Position = 0)]
    [Alias("n")]
    [string]$Name = "MySolution",

    [Parameter()]
    [Alias("p")]
    [string]$Path = ".",

    [Parameter()]
    [int]$ApiHttp = 5080,

    [Parameter()]
    [int]$ApiHttps = 7080,

    [Parameter()]
    [int]$Web = 5173
)

$ErrorActionPreference = "Stop"

# Get script directory for template access
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplateDir = Join-Path $ScriptDir "..\assets\templates"

function Write-Step {
    param([string]$Message)
    Write-Host "[STEP] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Copy-Template {
    param(
        [string]$TemplateFile,
        [string]$DestFile,
        [string]$SolutionName,
        [string]$SolutionNameLower,
        [string]$ProjectName,
        [string]$ServiceName,
        [string]$ServiceNameLower,
        [int]$HttpPort,
        [int]$HttpsPort,
        [int]$ApiHttp,
        [int]$ApiHttps,
        [int]$WebPort
    )
    
    $content = Get-Content -Path $TemplateFile -Raw
    $content = $content -replace '{{SOLUTION_NAME}}', $SolutionName
    $content = $content -replace '{{SOLUTION_NAME_LOWER}}', $SolutionNameLower
    $content = $content -replace '{{PROJECT_NAME}}', $ProjectName
    $content = $content -replace '{{SERVICE_NAME}}', $ServiceName
    $content = $content -replace '{{SERVICE_NAME_LOWER}}', $ServiceNameLower
    $content = $content -replace '{{HTTP_PORT}}', $HttpPort
    $content = $content -replace '{{HTTPS_PORT}}', $HttpsPort
    $content = $content -replace '{{API_HTTP_PORT}}', $ApiHttp
    $content = $content -replace '{{API_HTTPS_PORT}}', $ApiHttps
    $content = $content -replace '{{WEB_PORT}}', $WebPort
    
    Set-Content -Path $DestFile -Value $content -NoNewline
}

# Lowercase solution name for package.json
$SolutionNameLower = $Name.ToLower()

# Check prerequisites
Write-Step "Checking prerequisites..."

$dotnetVersion = & dotnet --version 2>$null
if (-not $dotnetVersion) {
    Write-ErrorMessage "dotnet CLI not found. Please install .NET 10 SDK."
    exit 1
}

$majorVersion = [int]($dotnetVersion -split '\.')[0]
if ($majorVersion -lt 10) {
    Write-Warning "Recommended .NET version is 10.x. Found: $dotnetVersion"
}

$nodeVersion = & node --version 2>$null
if (-not $nodeVersion) {
    Write-ErrorMessage "Node.js not found. Please install Node.js 20+."
    exit 1
}

$npmVersion = & npm --version 2>$null
if (-not $npmVersion) {
    Write-ErrorMessage "npm not found. Please install Node.js with npm."
    exit 1
}

Write-Step "Creating solution: $Name in $Path"

# Create root directory
$solutionPath = Join-Path $Path $Name
New-Item -ItemType Directory -Force -Path "$solutionPath\src" | Out-Null
Set-Location $solutionPath

# Create solution file
Write-Step "Creating .NET solution..."
& dotnet new sln -n $Name

# Create ServiceDefaults project
Write-Step "Creating ServiceDefaults project..."
$serviceDefaultsPath = "src\$Name.ServiceDefaults"
New-Item -ItemType Directory -Force -Path $serviceDefaultsPath | Out-Null

Copy-Template -TemplateFile "$TemplateDir\servicedefaults\ServiceDefaults.csproj" `
    -DestFile "$serviceDefaultsPath\$Name.ServiceDefaults.csproj" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.ServiceDefaults" -ServiceName "ServiceDefaults" -ServiceNameLower "servicedefaults" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Copy-Item "$TemplateDir\servicedefaults\Extensions.cs" "$serviceDefaultsPath\Extensions.cs"

# Create API project with 4+1 architecture (using microservice template)
Write-Step "Creating API project with 4+1 architecture..."
$apiPath = "src\$Name.Api"
New-Item -ItemType Directory -Force -Path "$apiPath\Properties" | Out-Null
New-Item -ItemType Directory -Force -Path "$apiPath\Models" | Out-Null
New-Item -ItemType Directory -Force -Path "$apiPath\Services" | Out-Null
New-Item -ItemType Directory -Force -Path "$apiPath\Endpoints" | Out-Null
New-Item -ItemType Directory -Force -Path "$apiPath\Infrastructure" | Out-Null

Copy-Template -TemplateFile "$TemplateDir\microservice\Microservice.csproj" `
    -DestFile "$apiPath\$Name.Api.csproj" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.Api" -ServiceName "Weather" -ServiceNameLower "weather" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Copy-Template -TemplateFile "$TemplateDir\microservice\Program.cs" `
    -DestFile "$apiPath\Program.cs" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.Api" -ServiceName "Weather" -ServiceNameLower "weather" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Copy-Template -TemplateFile "$TemplateDir\microservice\appsettings.json" `
    -DestFile "$apiPath\appsettings.json" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.Api" -ServiceName "Weather" -ServiceNameLower "weather" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Copy-Template -TemplateFile "$TemplateDir\microservice\appsettings.Development.json" `
    -DestFile "$apiPath\appsettings.Development.json" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.Api" -ServiceName "Weather" -ServiceNameLower "weather" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Copy-Template -TemplateFile "$TemplateDir\microservice\launchSettings.json" `
    -DestFile "$apiPath\Properties\launchSettings.json" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.Api" -ServiceName "Weather" -ServiceNameLower "weather" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Copy-Template -TemplateFile "$TemplateDir\microservice\Models\Model.cs" `
    -DestFile "$apiPath\Models\WeatherForecast.cs" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.Api" -ServiceName "Weather" -ServiceNameLower "weather" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Copy-Template -TemplateFile "$TemplateDir\microservice\Services\IService.cs" `
    -DestFile "$apiPath\Services\IWeatherService.cs" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.Api" -ServiceName "Weather" -ServiceNameLower "weather" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Copy-Template -TemplateFile "$TemplateDir\microservice\Services\Service.cs" `
    -DestFile "$apiPath\Services\WeatherService.cs" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.Api" -ServiceName "Weather" -ServiceNameLower "weather" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Copy-Template -TemplateFile "$TemplateDir\microservice\Endpoints\Endpoints.cs" `
    -DestFile "$apiPath\Endpoints\WeatherEndpoints.cs" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.Api" -ServiceName "Weather" -ServiceNameLower "weather" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Copy-Template -TemplateFile "$TemplateDir\microservice\Infrastructure\DaprStateStore.cs" `
    -DestFile "$apiPath\Infrastructure\DaprStateStore.cs" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.Api" -ServiceName "Weather" -ServiceNameLower "weather" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

# Create AppHost project
Write-Step "Creating AppHost project..."
$appHostPath = "src\$Name.AppHost"
New-Item -ItemType Directory -Force -Path "$appHostPath\Properties" | Out-Null

Copy-Template -TemplateFile "$TemplateDir\apphost\AppHost.csproj" `
    -DestFile "$appHostPath\$Name.AppHost.csproj" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.AppHost" -ServiceName "AppHost" -ServiceNameLower "apphost" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Copy-Template -TemplateFile "$TemplateDir\apphost\AppHost.cs" `
    -DestFile "$appHostPath\AppHost.cs" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.AppHost" -ServiceName "AppHost" -ServiceNameLower "apphost" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Copy-Template -TemplateFile "$TemplateDir\apphost\appsettings.json" `
    -DestFile "$appHostPath\appsettings.json" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.AppHost" -ServiceName "AppHost" -ServiceNameLower "apphost" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Copy-Template -TemplateFile "$TemplateDir\apphost\appsettings.Development.json" `
    -DestFile "$appHostPath\appsettings.Development.json" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.AppHost" -ServiceName "AppHost" -ServiceNameLower "apphost" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Copy-Item "$TemplateDir\apphost\launchSettings.json" "$appHostPath\Properties\launchSettings.json"

# Create Web (React) project
Write-Step "Creating React frontend..."
$webPath = "src\$Name.Web"
New-Item -ItemType Directory -Force -Path "$webPath\src\api" | Out-Null
New-Item -ItemType Directory -Force -Path "$webPath\src\store" | Out-Null
New-Item -ItemType Directory -Force -Path "$webPath\src\components" | Out-Null
New-Item -ItemType Directory -Force -Path "$webPath\src\pages" | Out-Null
New-Item -ItemType Directory -Force -Path "$webPath\src\types" | Out-Null
New-Item -ItemType Directory -Force -Path "$webPath\public" | Out-Null

Copy-Template -TemplateFile "$TemplateDir\web\package.json" `
    -DestFile "$webPath\package.json" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.Web" -ServiceName "Web" -ServiceNameLower "web" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Copy-Template -TemplateFile "$TemplateDir\web\vite.config.ts" `
    -DestFile "$webPath\vite.config.ts" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.Web" -ServiceName "Web" -ServiceNameLower "web" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Copy-Item "$TemplateDir\web\tailwind.config.js" "$webPath\tailwind.config.js"
Copy-Item "$TemplateDir\web\postcss.config.js" "$webPath\postcss.config.js"
Copy-Item "$TemplateDir\web\tsconfig.json" "$webPath\tsconfig.json"
Copy-Item "$TemplateDir\web\tsconfig.node.json" "$webPath\tsconfig.node.json"

Copy-Template -TemplateFile "$TemplateDir\web\.env" `
    -DestFile "$webPath\.env" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.Web" -ServiceName "Web" -ServiceNameLower "web" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Copy-Template -TemplateFile "$TemplateDir\web\index.html" `
    -DestFile "$webPath\index.html" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.Web" -ServiceName "Web" -ServiceNameLower "web" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Copy-Item "$TemplateDir\web\vite.svg" "$webPath\public\vite.svg"

# Copy React source files
Copy-Item "$TemplateDir\web\src\main.tsx" "$webPath\src\main.tsx"
Copy-Item "$TemplateDir\web\src\App.tsx" "$webPath\src\App.tsx"
Copy-Item "$TemplateDir\web\src\index.css" "$webPath\src\index.css"
Copy-Item "$TemplateDir\web\src\vite-env.d.ts" "$webPath\src\vite-env.d.ts"
Copy-Item "$TemplateDir\web\src\types\weather.ts" "$webPath\src\types\weather.ts"
Copy-Item "$TemplateDir\web\src\store\weatherStore.ts" "$webPath\src\store\weatherStore.ts"
Copy-Item "$TemplateDir\web\src\store\index.ts" "$webPath\src\store\index.ts"
Copy-Item "$TemplateDir\web\src\api\weatherApi.ts" "$webPath\src\api\weatherApi.ts"

Copy-Template -TemplateFile "$TemplateDir\web\src\components\Layout.tsx" `
    -DestFile "$webPath\src\components\Layout.tsx" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.Web" -ServiceName "Web" -ServiceNameLower "web" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Copy-Template -TemplateFile "$TemplateDir\web\src\components\Navbar.tsx" `
    -DestFile "$webPath\src\components\Navbar.tsx" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.Web" -ServiceName "Web" -ServiceNameLower "web" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Copy-Item "$TemplateDir\web\src\components\WeatherCard.tsx" "$webPath\src\components\WeatherCard.tsx"

Copy-Template -TemplateFile "$TemplateDir\web\src\pages\Home.tsx" `
    -DestFile "$webPath\src\pages\Home.tsx" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName "$Name.Web" -ServiceName "Web" -ServiceNameLower "web" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Copy-Item "$TemplateDir\web\src\pages\Weather.tsx" "$webPath\src\pages\Weather.tsx"

# Add projects to solution
Write-Step "Adding projects to solution..."
& dotnet sln add "$serviceDefaultsPath\$Name.ServiceDefaults.csproj"
& dotnet sln add "$apiPath\$Name.Api.csproj"
& dotnet sln add "$appHostPath\$Name.AppHost.csproj"

# Restore and build .NET projects
Write-Step "Restoring .NET packages..."
& dotnet restore

Write-Step "Building solution..."
& dotnet build

# Install npm dependencies
Write-Step "Installing frontend dependencies..."
Set-Location $webPath
& npm install
Set-Location ..\..

# Create README
Copy-Template -TemplateFile "$TemplateDir\README.md" `
    -DestFile "README.md" `
    -SolutionName $Name -SolutionNameLower $SolutionNameLower `
    -ProjectName $Name -ServiceName "Solution" -ServiceNameLower "solution" `
    -HttpPort $ApiHttp -HttpsPort $ApiHttps -ApiHttp $ApiHttp -ApiHttps $ApiHttps -WebPort $Web

Write-Step "Solution created successfully!"
Write-Host ""
Write-Host "To run the solution:"
Write-Host "  cd $Path\$Name"
Write-Host "  aspire run"
Write-Host ""
Write-Host "Endpoints:"
Write-Host "  API Docs:   https://localhost:$ApiHttps/scalar/v1"
Write-Host "  OpenAPI:    https://localhost:$ApiHttps/openapi/v1.json"
Write-Host "  Frontend:   http://localhost:$Web"
