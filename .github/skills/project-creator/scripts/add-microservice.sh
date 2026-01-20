#!/bin/bash
#
# add-microservice.sh - Add a new microservice to an existing solution
#
# Usage: ./add-microservice.sh -n <ServiceName> [-s <SolutionPath>] [--http <port>] [--https <port>]
#

set -e

# Default values
SERVICE_NAME=""
SOLUTION_PATH="."
HTTP_PORT=""
HTTPS_PORT=""

# Get script directory for template access
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/../assets/templates/microservice"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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
            SERVICE_NAME="$2"
            shift 2
            ;;
        -s|--solution)
            SOLUTION_PATH="$2"
            shift 2
            ;;
        --http)
            HTTP_PORT="$2"
            shift 2
            ;;
        --https)
            HTTPS_PORT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 -n <ServiceName> [-s <SolutionPath>] [--http <port>] [--https <port>]"
            echo ""
            echo "Options:"
            echo "  -n, --name       Service name (required, e.g., 'Orders', 'Products')"
            echo "  -s, --solution   Path to solution root (default: current directory)"
            echo "  --http           HTTP port (default: auto-assigned)"
            echo "  --https          HTTPS port (default: auto-assigned)"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$SERVICE_NAME" ]]; then
    print_error "Service name is required. Use -n <ServiceName>"
    exit 1
fi

# Find solution file
cd "$SOLUTION_PATH"
SOLUTION_FILE=$(find . -maxdepth 1 -name "*.sln" | head -1)

if [[ -z "$SOLUTION_FILE" ]]; then
    print_error "No .sln file found in $SOLUTION_PATH"
    exit 1
fi

SOLUTION_NAME=$(basename "$SOLUTION_FILE" .sln)
print_step "Adding microservice '$SERVICE_NAME' to solution '$SOLUTION_NAME'"

# Determine project name
PROJECT_NAME="${SOLUTION_NAME}.${SERVICE_NAME}"
PROJECT_PATH="src/${PROJECT_NAME}"

# Check if project already exists
if [[ -d "$PROJECT_PATH" ]]; then
    print_error "Project $PROJECT_NAME already exists at $PROJECT_PATH"
    exit 1
fi

# Set default ports if not provided
if [[ -z "$HTTP_PORT" ]]; then
    HTTP_PORT=$((5100 + RANDOM % 100))
fi

if [[ -z "$HTTPS_PORT" ]]; then
    HTTPS_PORT=$((HTTP_PORT + 1000))
fi

# Lowercase service name for API routes
SERVICE_NAME_LOWER=$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]')

# Helper function to copy and substitute template
copy_template() {
    local template_file="$1"
    local dest_file="$2"
    
    sed -e "s|{{SOLUTION_NAME}}|$SOLUTION_NAME|g" \
        -e "s|{{PROJECT_NAME}}|$PROJECT_NAME|g" \
        -e "s|{{SERVICE_NAME}}|$SERVICE_NAME|g" \
        -e "s|{{SERVICE_NAME_LOWER}}|$SERVICE_NAME_LOWER|g" \
        -e "s|{{HTTP_PORT}}|$HTTP_PORT|g" \
        -e "s|{{HTTPS_PORT}}|$HTTPS_PORT|g" \
        "$template_file" > "$dest_file"
}

# Create project directory with 4+1 architecture
print_step "Creating project with Kruchten 4+1 architecture..."
mkdir -p "$PROJECT_PATH/Properties"
mkdir -p "$PROJECT_PATH/Models"
mkdir -p "$PROJECT_PATH/Services"
mkdir -p "$PROJECT_PATH/Endpoints"
mkdir -p "$PROJECT_PATH/Infrastructure"

# Copy and substitute templates
print_step "Creating project files from templates..."
copy_template "$TEMPLATE_DIR/Microservice.csproj" "$PROJECT_PATH/${PROJECT_NAME}.csproj"
copy_template "$TEMPLATE_DIR/Program.cs" "$PROJECT_PATH/Program.cs"
copy_template "$TEMPLATE_DIR/appsettings.json" "$PROJECT_PATH/appsettings.json"
copy_template "$TEMPLATE_DIR/appsettings.Development.json" "$PROJECT_PATH/appsettings.Development.json"
copy_template "$TEMPLATE_DIR/launchSettings.json" "$PROJECT_PATH/Properties/launchSettings.json"

# Architecture files
copy_template "$TEMPLATE_DIR/Models/Model.cs" "$PROJECT_PATH/Models/${SERVICE_NAME}Model.cs"
copy_template "$TEMPLATE_DIR/Services/IService.cs" "$PROJECT_PATH/Services/I${SERVICE_NAME}Service.cs"
copy_template "$TEMPLATE_DIR/Services/Service.cs" "$PROJECT_PATH/Services/${SERVICE_NAME}Service.cs"
copy_template "$TEMPLATE_DIR/Endpoints/Endpoints.cs" "$PROJECT_PATH/Endpoints/${SERVICE_NAME}Endpoints.cs"
copy_template "$TEMPLATE_DIR/Infrastructure/DaprStateStore.cs" "$PROJECT_PATH/Infrastructure/DaprStateStore.cs"

# Add project to solution
print_step "Adding project to solution..."
dotnet sln add "$PROJECT_PATH/${PROJECT_NAME}.csproj"

# Add project reference to AppHost
print_step "Adding project reference to AppHost..."
APPHOST_CSPROJ="src/${SOLUTION_NAME}.AppHost/${SOLUTION_NAME}.AppHost.csproj"

if [[ -f "$APPHOST_CSPROJ" ]]; then
    # Add ProjectReference to AppHost csproj
    sed -i "/<\/ItemGroup>/i\\    <ProjectReference Include=\"..\\\\${PROJECT_NAME}\\\\${PROJECT_NAME}.csproj\" />" "$APPHOST_CSPROJ"
    
    print_step "Updating AppHost.cs..."
    APPHOST_CS="src/${SOLUTION_NAME}.AppHost/AppHost.cs"
    
    # Create variable name for the service
    SERVICE_VAR=$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]')
    PROJECT_CLASS="${SOLUTION_NAME}_${SERVICE_NAME}"
    
    # Insert the new service registration before builder.Build().Run();
    sed -i "/builder.Build().Run();/i\\\\n// Add ${SERVICE_NAME} service with Dapr sidecar\\nvar ${SERVICE_VAR} = builder.AddProject<Projects.${PROJECT_CLASS}>(\"${SERVICE_VAR}\")\\n    .WithDaprSidecar()\\n    .WithHttpHealthCheck(\"/health\");\\n" "$APPHOST_CS"
    
    print_warning "Please review AppHost.cs and add .WithReference() calls if this service needs to communicate with others."
fi

# Build the new project
print_step "Building new project..."
dotnet build "$PROJECT_PATH/${PROJECT_NAME}.csproj"

print_step "Microservice '${SERVICE_NAME}' added successfully!"
echo ""
echo "Project location: $PROJECT_PATH"
echo "HTTP port: $HTTP_PORT"
echo "HTTPS port: $HTTPS_PORT"
echo ""
echo "Next steps:"
echo "  1. Add your domain models and endpoints"
echo "  2. Update AppHost.cs if this service needs references to other services"
echo "  3. Run 'aspire run' to test the new service"
