#Requires -Version 7.0
<#
.SYNOPSIS
    Add a new microservice to an existing solution

.DESCRIPTION
    Creates a new .NET 10 Minimal API microservice and registers it with the Aspire AppHost.

.PARAMETER Name
    The service name (required, e.g., 'Orders', 'Products')

.PARAMETER Solution
    Path to solution root. Default: current directory

.PARAMETER Http
    HTTP port. Default: auto-assigned

.PARAMETER Https
    HTTPS port. Default: auto-assigned

.EXAMPLE
    .\add-microservice.ps1 -Name "Orders"

.EXAMPLE
    .\add-microservice.ps1 -Name "Products" -Solution "C:\Projects\MySolution" -Http 5200 -Https 7200
#>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [Alias("n")]
    [string]$Name,

    [Parameter()]
    [Alias("s")]
    [string]$Solution = ".",

    [Parameter()]
    [int]$Http = 0,

    [Parameter()]
    [int]$Https = 0
)

$ErrorActionPreference = "Stop"

# Get script directory for template access
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$TemplateDir = Join-Path $ScriptDir "..\assets\templates\microservice"

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
        [string]$ProjectName,
        [string]$ServiceName,
        [string]$ServiceNameLower,
        [int]$HttpPort,
        [int]$HttpsPort
    )
    
    $content = Get-Content -Path $TemplateFile -Raw
    $content = $content -replace '{{SOLUTION_NAME}}', $SolutionName
    $content = $content -replace '{{PROJECT_NAME}}', $ProjectName
    $content = $content -replace '{{SERVICE_NAME}}', $ServiceName
    $content = $content -replace '{{SERVICE_NAME_LOWER}}', $ServiceNameLower
    $content = $content -replace '{{HTTP_PORT}}', $HttpPort
    $content = $content -replace '{{HTTPS_PORT}}', $HttpsPort
    
    Set-Content -Path $DestFile -Value $content -NoNewline
}

# Find solution file
Set-Location $Solution
$solutionFile = Get-ChildItem -Filter "*.sln" | Select-Object -First 1

if (-not $solutionFile) {
    Write-ErrorMessage "No .sln file found in $Solution"
    exit 1
}

$solutionName = $solutionFile.BaseName
Write-Step "Adding microservice '$Name' to solution '$solutionName'"

# Determine project name
$projectName = "$solutionName.$Name"
$projectPath = "src\$projectName"

# Check if project already exists
if (Test-Path $projectPath) {
    Write-ErrorMessage "Project $projectName already exists at $projectPath"
    exit 1
}

# Set default ports if not provided
if ($Http -eq 0) {
    $Http = Get-Random -Minimum 5100 -Maximum 5199
}

if ($Https -eq 0) {
    $Https = $Http + 1000
}

# Lowercase service name for API routes
$serviceNameLower = $Name.ToLower()

# Create project directory with 4+1 architecture folders
Write-Step "Creating project with Kruchten 4+1 architecture..."
New-Item -ItemType Directory -Force -Path "$projectPath\Properties" | Out-Null
New-Item -ItemType Directory -Force -Path "$projectPath\Models" | Out-Null
New-Item -ItemType Directory -Force -Path "$projectPath\Services" | Out-Null
New-Item -ItemType Directory -Force -Path "$projectPath\Endpoints" | Out-Null
New-Item -ItemType Directory -Force -Path "$projectPath\Infrastructure" | Out-Null

# Copy and substitute templates
Write-Step "Creating project files from templates..."

Copy-Template -TemplateFile "$TemplateDir\Microservice.csproj" `
    -DestFile "$projectPath\$projectName.csproj" `
    -SolutionName $solutionName -ProjectName $projectName `
    -ServiceName $Name -ServiceNameLower $serviceNameLower `
    -HttpPort $Http -HttpsPort $Https

Copy-Template -TemplateFile "$TemplateDir\Program.cs" `
    -DestFile "$projectPath\Program.cs" `
    -SolutionName $solutionName -ProjectName $projectName `
    -ServiceName $Name -ServiceNameLower $serviceNameLower `
    -HttpPort $Http -HttpsPort $Https

Copy-Template -TemplateFile "$TemplateDir\appsettings.json" `
    -DestFile "$projectPath\appsettings.json" `
    -SolutionName $solutionName -ProjectName $projectName `
    -ServiceName $Name -ServiceNameLower $serviceNameLower `
    -HttpPort $Http -HttpsPort $Https

Copy-Template -TemplateFile "$TemplateDir\appsettings.Development.json" `
    -DestFile "$projectPath\appsettings.Development.json" `
    -SolutionName $solutionName -ProjectName $projectName `
    -ServiceName $Name -ServiceNameLower $serviceNameLower `
    -HttpPort $Http -HttpsPort $Https

Copy-Template -TemplateFile "$TemplateDir\launchSettings.json" `
    -DestFile "$projectPath\Properties\launchSettings.json" `
    -SolutionName $solutionName -ProjectName $projectName `
    -ServiceName $Name -ServiceNameLower $serviceNameLower `
    -HttpPort $Http -HttpsPort $Https

# Architecture files
Copy-Template -TemplateFile "$TemplateDir\Models\Model.cs" `
    -DestFile "$projectPath\Models\${Name}Model.cs" `
    -SolutionName $solutionName -ProjectName $projectName `
    -ServiceName $Name -ServiceNameLower $serviceNameLower `
    -HttpPort $Http -HttpsPort $Https

Copy-Template -TemplateFile "$TemplateDir\Services\IService.cs" `
    -DestFile "$projectPath\Services\I${Name}Service.cs" `
    -SolutionName $solutionName -ProjectName $projectName `
    -ServiceName $Name -ServiceNameLower $serviceNameLower `
    -HttpPort $Http -HttpsPort $Https

Copy-Template -TemplateFile "$TemplateDir\Services\Service.cs" `
    -DestFile "$projectPath\Services\${Name}Service.cs" `
    -SolutionName $solutionName -ProjectName $projectName `
    -ServiceName $Name -ServiceNameLower $serviceNameLower `
    -HttpPort $Http -HttpsPort $Https

Copy-Template -TemplateFile "$TemplateDir\Endpoints\Endpoints.cs" `
    -DestFile "$projectPath\Endpoints\${Name}Endpoints.cs" `
    -SolutionName $solutionName -ProjectName $projectName `
    -ServiceName $Name -ServiceNameLower $serviceNameLower `
    -HttpPort $Http -HttpsPort $Https

Copy-Template -TemplateFile "$TemplateDir\Infrastructure\DaprStateStore.cs" `
    -DestFile "$projectPath\Infrastructure\DaprStateStore.cs" `
    -SolutionName $solutionName -ProjectName $projectName `
    -ServiceName $Name -ServiceNameLower $serviceNameLower `
    -HttpPort $Http -HttpsPort $Https

# Add project to solution
Write-Step "Adding project to solution..."
& dotnet sln add "$projectPath\$projectName.csproj"

# Add project reference to AppHost
Write-Step "Adding project reference to AppHost..."
$appHostCsproj = "src\$solutionName.AppHost\$solutionName.AppHost.csproj"

if (Test-Path $appHostCsproj) {
    # Read and update AppHost csproj
    $csprojContent = Get-Content $appHostCsproj -Raw
    $newReference = "    <ProjectReference Include=`"..\$projectName\$projectName.csproj`" />"
    
    # Find the last ProjectReference and add after it
    if ($csprojContent -match '(<ProjectReference[^>]+/>)\s*(</ItemGroup>)') {
        $csprojContent = $csprojContent -replace '(<ProjectReference[^>]+/>)(\s*)(</ItemGroup>)', "`$1`$2$newReference`$2`$3"
        $csprojContent | Set-Content $appHostCsproj -NoNewline
    }
    
    Write-Step "Updating AppHost.cs..."
    $appHostCs = "src\$solutionName.AppHost\AppHost.cs"
    
    if (Test-Path $appHostCs) {
        $appHostContent = Get-Content $appHostCs -Raw
        $serviceVar = $Name.ToLower()
        $projectClass = "${solutionName}_$Name"
        
        $newServiceCode = @"

// Add $Name service with Dapr sidecar
var $serviceVar = builder.AddProject<Projects.$projectClass>("$serviceVar")
    .WithDaprSidecar()
    .WithHttpHealthCheck("/health");

"@
        
        # Insert before builder.Build().Run();
        $appHostContent = $appHostContent -replace '(builder\.Build\(\)\.Run\(\);)', "$newServiceCode`$1"
        $appHostContent | Set-Content $appHostCs -NoNewline
    }
    
    Write-Warning "Please review AppHost.cs and add .WithReference() calls if this service needs to communicate with others."
}

# Build the new project
Write-Step "Building new project..."
& dotnet build "$projectPath\$projectName.csproj"

Write-Step "Microservice '$Name' added successfully!"
Write-Host ""
Write-Host "Project location: $projectPath"
Write-Host "HTTP port: $Http"
Write-Host "HTTPS port: $Https"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Add your domain models and endpoints"
Write-Host "  2. Update AppHost.cs if this service needs references to other services"
Write-Host "  3. Run 'aspire run' to test the new service"
