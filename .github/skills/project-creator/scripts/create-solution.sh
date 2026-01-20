#!/bin/bash
#
# create-solution.sh - Create a microservices solution with .NET Aspire + React
#
# Usage: ./create-solution.sh -n <SolutionName> [-p <RootPath>] [--api-http <port>] [--api-https <port>] [--web <port>]
#

set -e

# Default values
SOLUTION_NAME="MySolution"
ROOT_PATH="."
API_HTTP_PORT=5080
API_HTTPS_PORT=7080
WEB_PORT=5173

# Get script directory for template access
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../assets/templates"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            SOLUTION_NAME="$2"
            shift 2
            ;;
        -p|--path)
            ROOT_PATH="$2"
            shift 2
            ;;
        --api-http)
            API_HTTP_PORT="$2"
            shift 2
            ;;
        --api-https)
            API_HTTPS_PORT="$2"
            shift 2
            ;;
        --web)
            WEB_PORT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 -n <SolutionName> [-p <RootPath>] [--api-http <port>] [--api-https <port>] [--web <port>]"
            echo ""
            echo "Options:"
            echo "  -n, --name       Solution name (default: MySolution)"
            echo "  -p, --path       Root path for the solution (default: current directory)"
            echo "  --api-http       API HTTP port (default: 5080)"
            echo "  --api-https      API HTTPS port (default: 7080)"
            echo "  --web            Web dev server port (default: 5173)"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Lowercase solution name for package.json
SOLUTION_NAME_LOWER=$(echo "$SOLUTION_NAME" | tr '[:upper:]' '[:lower:]')

# Check prerequisites
print_step "Checking prerequisites..."

if ! command -v dotnet &> /dev/null; then
    print_error "dotnet CLI not found. Please install .NET 10 SDK."
    exit 1
fi

DOTNET_VERSION=$(dotnet --version | cut -d. -f1)
if [[ "$DOTNET_VERSION" -lt 10 ]]; then
    print_warning "Recommended .NET version is 10.x. Found: $(dotnet --version)"
fi

if ! command -v node &> /dev/null; then
    print_error "Node.js not found. Please install Node.js 20+."
    exit 1
fi

if ! command -v npm &> /dev/null; then
    print_error "npm not found. Please install Node.js with npm."
    exit 1
fi

print_step "Creating solution: $SOLUTION_NAME in $ROOT_PATH"

# Create root directory
mkdir -p "$ROOT_PATH/$SOLUTION_NAME/src"
cd "$ROOT_PATH/$SOLUTION_NAME"

# Create solution file
print_step "Creating .NET solution..."
dotnet new sln -n "$SOLUTION_NAME"

# Helper function to copy and substitute template
copy_template() {
    local template_file="$1"
    local dest_file="$2"
    
    sed -e "s|{{SOLUTION_NAME}}|$SOLUTION_NAME|g" \
        -e "s|{{SOLUTION_NAME_LOWER}}|$SOLUTION_NAME_LOWER|g" \
        -e "s|{{PROJECT_NAME}}|${SOLUTION_NAME}.Api|g" \
        -e "s|{{SERVICE_NAME}}|Weather|g" \
        -e "s|{{SERVICE_NAME_LOWER}}|weather|g" \
        -e "s|{{HTTP_PORT}}|$API_HTTP_PORT|g" \
        -e "s|{{HTTPS_PORT}}|$API_HTTPS_PORT|g" \
        -e "s|{{API_HTTP_PORT}}|$API_HTTP_PORT|g" \
        -e "s|{{API_HTTPS_PORT}}|$API_HTTPS_PORT|g" \
        -e "s|{{WEB_PORT}}|$WEB_PORT|g" \
        "$template_file" > "$dest_file"
}

# Create ServiceDefaults project
print_step "Creating ServiceDefaults project..."
mkdir -p "src/${SOLUTION_NAME}.ServiceDefaults"
copy_template "$TEMPLATE_DIR/servicedefaults/ServiceDefaults.csproj" "src/${SOLUTION_NAME}.ServiceDefaults/${SOLUTION_NAME}.ServiceDefaults.csproj"
cp "$TEMPLATE_DIR/servicedefaults/Extensions.cs" "src/${SOLUTION_NAME}.ServiceDefaults/Extensions.cs"

# Create API project with 4+1 architecture (using microservice template)
print_step "Creating API project with 4+1 architecture..."
mkdir -p "src/${SOLUTION_NAME}.Api/Properties"
mkdir -p "src/${SOLUTION_NAME}.Api/Models"
mkdir -p "src/${SOLUTION_NAME}.Api/Services"
mkdir -p "src/${SOLUTION_NAME}.Api/Endpoints"
mkdir -p "src/${SOLUTION_NAME}.Api/Infrastructure"

copy_template "$TEMPLATE_DIR/microservice/Microservice.csproj" "src/${SOLUTION_NAME}.Api/${SOLUTION_NAME}.Api.csproj"
copy_template "$TEMPLATE_DIR/microservice/Program.cs" "src/${SOLUTION_NAME}.Api/Program.cs"
copy_template "$TEMPLATE_DIR/microservice/appsettings.json" "src/${SOLUTION_NAME}.Api/appsettings.json"
copy_template "$TEMPLATE_DIR/microservice/appsettings.Development.json" "src/${SOLUTION_NAME}.Api/appsettings.Development.json"
copy_template "$TEMPLATE_DIR/microservice/launchSettings.json" "src/${SOLUTION_NAME}.Api/Properties/launchSettings.json"

copy_template "$TEMPLATE_DIR/microservice/Models/Model.cs" "src/${SOLUTION_NAME}.Api/Models/WeatherForecast.cs"
copy_template "$TEMPLATE_DIR/microservice/Services/IService.cs" "src/${SOLUTION_NAME}.Api/Services/IWeatherService.cs"
copy_template "$TEMPLATE_DIR/microservice/Services/Service.cs" "src/${SOLUTION_NAME}.Api/Services/WeatherService.cs"
copy_template "$TEMPLATE_DIR/microservice/Endpoints/Endpoints.cs" "src/${SOLUTION_NAME}.Api/Endpoints/WeatherEndpoints.cs"
copy_template "$TEMPLATE_DIR/microservice/Infrastructure/DaprStateStore.cs" "src/${SOLUTION_NAME}.Api/Infrastructure/DaprStateStore.cs"

# Create AppHost project
print_step "Creating AppHost project..."
mkdir -p "src/${SOLUTION_NAME}.AppHost/Properties"

copy_template "$TEMPLATE_DIR/apphost/AppHost.csproj" "src/${SOLUTION_NAME}.AppHost/${SOLUTION_NAME}.AppHost.csproj"
copy_template "$TEMPLATE_DIR/apphost/AppHost.cs" "src/${SOLUTION_NAME}.AppHost/AppHost.cs"
copy_template "$TEMPLATE_DIR/apphost/appsettings.json" "src/${SOLUTION_NAME}.AppHost/appsettings.json"
copy_template "$TEMPLATE_DIR/apphost/appsettings.Development.json" "src/${SOLUTION_NAME}.AppHost/appsettings.Development.json"
cp "$TEMPLATE_DIR/apphost/launchSettings.json" "src/${SOLUTION_NAME}.AppHost/Properties/launchSettings.json"

# Create Web (React) project
print_step "Creating React frontend..."
mkdir -p "src/${SOLUTION_NAME}.Web/src/api"
mkdir -p "src/${SOLUTION_NAME}.Web/src/store"
mkdir -p "src/${SOLUTION_NAME}.Web/src/components"
mkdir -p "src/${SOLUTION_NAME}.Web/src/pages"
mkdir -p "src/${SOLUTION_NAME}.Web/src/types"
mkdir -p "src/${SOLUTION_NAME}.Web/public"

copy_template "$TEMPLATE_DIR/web/package.json" "src/${SOLUTION_NAME}.Web/package.json"
copy_template "$TEMPLATE_DIR/web/vite.config.ts" "src/${SOLUTION_NAME}.Web/vite.config.ts"
cp "$TEMPLATE_DIR/web/tailwind.config.js" "src/${SOLUTION_NAME}.Web/tailwind.config.js"
cp "$TEMPLATE_DIR/web/postcss.config.js" "src/${SOLUTION_NAME}.Web/postcss.config.js"
cp "$TEMPLATE_DIR/web/tsconfig.json" "src/${SOLUTION_NAME}.Web/tsconfig.json"
cp "$TEMPLATE_DIR/web/tsconfig.node.json" "src/${SOLUTION_NAME}.Web/tsconfig.node.json"
copy_template "$TEMPLATE_DIR/web/.env" "src/${SOLUTION_NAME}.Web/.env"
copy_template "$TEMPLATE_DIR/web/index.html" "src/${SOLUTION_NAME}.Web/index.html"
cp "$TEMPLATE_DIR/web/vite.svg" "src/${SOLUTION_NAME}.Web/public/vite.svg"

# Copy React source files
cp "$TEMPLATE_DIR/web/src/main.tsx" "src/${SOLUTION_NAME}.Web/src/main.tsx"
cp "$TEMPLATE_DIR/web/src/App.tsx" "src/${SOLUTION_NAME}.Web/src/App.tsx"
cp "$TEMPLATE_DIR/web/src/index.css" "src/${SOLUTION_NAME}.Web/src/index.css"
cp "$TEMPLATE_DIR/web/src/vite-env.d.ts" "src/${SOLUTION_NAME}.Web/src/vite-env.d.ts"
cp "$TEMPLATE_DIR/web/src/types/weather.ts" "src/${SOLUTION_NAME}.Web/src/types/weather.ts"
cp "$TEMPLATE_DIR/web/src/store/weatherStore.ts" "src/${SOLUTION_NAME}.Web/src/store/weatherStore.ts"
cp "$TEMPLATE_DIR/web/src/store/index.ts" "src/${SOLUTION_NAME}.Web/src/store/index.ts"
cp "$TEMPLATE_DIR/web/src/api/weatherApi.ts" "src/${SOLUTION_NAME}.Web/src/api/weatherApi.ts"
copy_template "$TEMPLATE_DIR/web/src/components/Layout.tsx" "src/${SOLUTION_NAME}.Web/src/components/Layout.tsx"
copy_template "$TEMPLATE_DIR/web/src/components/Navbar.tsx" "src/${SOLUTION_NAME}.Web/src/components/Navbar.tsx"
cp "$TEMPLATE_DIR/web/src/components/WeatherCard.tsx" "src/${SOLUTION_NAME}.Web/src/components/WeatherCard.tsx"
copy_template "$TEMPLATE_DIR/web/src/pages/Home.tsx" "src/${SOLUTION_NAME}.Web/src/pages/Home.tsx"
cp "$TEMPLATE_DIR/web/src/pages/Weather.tsx" "src/${SOLUTION_NAME}.Web/src/pages/Weather.tsx"

# Add projects to solution
print_step "Adding projects to solution..."
dotnet sln add "src/${SOLUTION_NAME}.ServiceDefaults/${SOLUTION_NAME}.ServiceDefaults.csproj"
dotnet sln add "src/${SOLUTION_NAME}.Api/${SOLUTION_NAME}.Api.csproj"
dotnet sln add "src/${SOLUTION_NAME}.AppHost/${SOLUTION_NAME}.AppHost.csproj"

# Restore and build .NET projects
print_step "Restoring .NET packages..."
dotnet restore

print_step "Building solution..."
dotnet build

# Install npm dependencies
print_step "Installing frontend dependencies..."
cd "src/${SOLUTION_NAME}.Web"
npm install
cd ../..

# Create README
copy_template "$TEMPLATE_DIR/README.md" "README.md"

print_step "Solution created successfully!"
echo ""
echo "To run the solution:"
echo "  cd $ROOT_PATH/$SOLUTION_NAME"
echo "  aspire run"
echo ""
echo "Endpoints:"
echo "  API Docs:   https://localhost:${API_HTTPS_PORT}/scalar/v1"
echo "  OpenAPI:    https://localhost:${API_HTTPS_PORT}/openapi/v1.json"
echo "  Frontend:   http://localhost:${WEB_PORT}"
