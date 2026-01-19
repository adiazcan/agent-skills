#!/bin/bash

# Script para crear una aplicación React con Vite y Zustand
# Uso: ./create_react_app.sh <nombre-proyecto> <ruta-destino>

set -e

PROJECT_NAME=${1:-"frontend"}
TARGET_PATH=${2:-"./"}
FULL_PATH="$TARGET_PATH/$PROJECT_NAME"

echo "🚀 Creando aplicación React con Vite y Zustand: $PROJECT_NAME"
echo "📂 Ubicación: $FULL_PATH"

# Crear el proyecto con Vite
npm create vite@latest "$FULL_PATH" -- --template react

cd "$FULL_PATH"

# Instalar dependencias
echo "📦 Instalando dependencias..."
npm install

# Instalar Zustand y otras dependencias útiles
echo "📦 Instalando Zustand y dependencias adicionales..."
npm install zustand
npm install axios
npm install react-router-dom

# Instalar TailwindCSS y dependencias
echo "📦 Instalando TailwindCSS..."
npm install -D tailwindcss postcss autoprefixer
npm install -D @types/node
"
echo "📦 Incluye:"
echo "   ✓ Vite"
echo "   ✓ Zustand (state management)"
echo "   ✓ React Router (navigation)"
echo "   ✓ TailwindCSS (styling)"
echo "   ✓ Axios (HTTP client)"
echo ""
echo "
# Inicializar TailwindCSS
npx tailwindcss init -p

# Configurar TailwindCSS
cat > tailwind.config.js << 'EOF'
/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
EOF

# Crear archivo CSS con directivas de Tailwind
cat > src/index.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;
EOF

# Crear estructura de carpetas
mkdir -p src/components
mkdir -p src/pages
mkdir -p src/layouts
mkdir -p src/stores
mkdir -p src/services
mkdir -p src/hooks
mkdir -p src/utils

echo "✅ Aplicación React con Vite creada exitosamente"
echo "📝 Para ejecutar:"
echo "   cd $FULL_PATH"
echo "   npm run dev"
