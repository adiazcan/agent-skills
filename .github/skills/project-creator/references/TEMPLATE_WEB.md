# Template: Vite + React + Zustand Frontend

Complete template for the frontend web project with TypeScript, Zustand state management, Tailwind CSS, and React Router.

## Table of Contents

1. [Project Structure](#project-structure)
2. [Configuration Files](#configuration-files)
3. [Source Files](#source-files)
4. [Store (Zustand)](#store-zustand)
5. [Components](#components)
6. [API Integration](#api-integration)

---

## Project Structure

```
{SolutionName}.Web/
├── index.html
├── package.json
├── tsconfig.json
├── tsconfig.node.json
├── vite.config.ts
├── tailwind.config.js
├── postcss.config.js
├── .env
├── .env.development
├── public/
│   └── vite.svg
└── src/
    ├── main.tsx
    ├── App.tsx
    ├── App.css
    ├── index.css
    ├── vite-env.d.ts
    ├── api/
    │   └── weatherApi.ts
    ├── store/
    │   ├── index.ts
    │   └── weatherStore.ts
    ├── components/
    │   ├── Layout.tsx
    │   ├── Navbar.tsx
    │   └── WeatherCard.tsx
    ├── pages/
    │   ├── Home.tsx
    │   └── Weather.tsx
    └── types/
        └── weather.ts
```

## Configuration Files

**package.json:**
```json
{
  "name": "{solution-name}-web",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "lint": "eslint . --ext ts,tsx --report-unused-disable-directives --max-warnings 0",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "react-router-dom": "^7.0.0",
    "zustand": "^5.0.0",
    "@tanstack/react-query": "^5.0.0",
    "axios": "^1.7.0"
  },
  "devDependencies": {
    "@types/react": "^19.0.0",
    "@types/react-dom": "^19.0.0",
    "@vitejs/plugin-react": "^4.0.0",
    "autoprefixer": "^10.4.0",
    "postcss": "^8.4.0",
    "tailwindcss": "^3.4.0",
    "typescript": "^5.5.0",
    "vite": "^6.0.0"
  }
}
```

**vite.config.ts:**
```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: process.env.VITE_API_URL || 'https://localhost:7080',
        changeOrigin: true,
        secure: false,
      },
    },
  },
})
```

**tailwind.config.js:**
```javascript
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
```

**postcss.config.js:**
```javascript
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
```

**tsconfig.json:**
```json
{
  "compilerOptions": {
    "target": "ES2022",
    "useDefineForClassFields": true,
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  },
  "include": ["src"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
```

**.env:**
```env
VITE_API_URL=https://localhost:7080
```

**.env.development:**
```env
VITE_API_URL=https://localhost:7080
```

## Source Files

**index.html:**
```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>{SolutionName}</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

**src/main.tsx:**
```tsx
import React from 'react'
import ReactDOM from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import App from './App'
import './index.css'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 1000 * 60 * 5, // 5 minutes
      retry: 1,
    },
  },
})

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <App />
      </BrowserRouter>
    </QueryClientProvider>
  </React.StrictMode>
)
```

**src/App.tsx:**
```tsx
import { Routes, Route } from 'react-router-dom'
import Layout from './components/Layout'
import Home from './pages/Home'
import Weather from './pages/Weather'

function App() {
  return (
    <Routes>
      <Route path="/" element={<Layout />}>
        <Route index element={<Home />} />
        <Route path="weather" element={<Weather />} />
      </Route>
    </Routes>
  )
}

export default App
```

**src/index.css:**
```css
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  font-family: Inter, system-ui, Avenir, Helvetica, Arial, sans-serif;
  line-height: 1.5;
  font-weight: 400;
}

body {
  @apply bg-gray-50 text-gray-900 min-h-screen;
}
```

## Store (Zustand)

**src/types/weather.ts:**
```typescript
export interface WeatherForecast {
  date: string
  temperatureC: number
  temperatureF: number
  summary: string | null
}
```

**src/store/weatherStore.ts:**
```typescript
import { create } from 'zustand'
import { WeatherForecast } from '../types/weather'

interface WeatherState {
  forecasts: WeatherForecast[]
  isLoading: boolean
  error: string | null
  setForecasts: (forecasts: WeatherForecast[]) => void
  setLoading: (loading: boolean) => void
  setError: (error: string | null) => void
  clearForecasts: () => void
}

export const useWeatherStore = create<WeatherState>((set) => ({
  forecasts: [],
  isLoading: false,
  error: null,
  setForecasts: (forecasts) => set({ forecasts, error: null }),
  setLoading: (isLoading) => set({ isLoading }),
  setError: (error) => set({ error, isLoading: false }),
  clearForecasts: () => set({ forecasts: [], error: null }),
}))
```

**src/store/index.ts:**
```typescript
export { useWeatherStore } from './weatherStore'
```

## API Integration

**src/api/weatherApi.ts:**
```typescript
import axios from 'axios'
import { WeatherForecast } from '../types/weather'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || '/api',
  headers: {
    'Content-Type': 'application/json',
  },
})

export const weatherApi = {
  getForecasts: async (): Promise<WeatherForecast[]> => {
    const response = await api.get<WeatherForecast[]>('/api/weather')
    return response.data
  },

  getForecastsByDays: async (days: number): Promise<WeatherForecast[]> => {
    const response = await api.get<WeatherForecast[]>(`/api/weather/${days}`)
    return response.data
  },
}
```

## Components

**src/components/Layout.tsx:**
```tsx
import { Outlet } from 'react-router-dom'
import Navbar from './Navbar'

export default function Layout() {
  return (
    <div className="min-h-screen flex flex-col">
      <Navbar />
      <main className="flex-1 container mx-auto px-4 py-8">
        <Outlet />
      </main>
      <footer className="bg-gray-800 text-white py-4 text-center">
        <p>&copy; {new Date().getFullYear()} {SolutionName}</p>
      </footer>
    </div>
  )
}
```

**src/components/Navbar.tsx:**
```tsx
import { Link, NavLink } from 'react-router-dom'

export default function Navbar() {
  return (
    <nav className="bg-blue-600 text-white shadow-lg">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          <Link to="/" className="text-xl font-bold">
            {SolutionName}
          </Link>
          <div className="flex space-x-4">
            <NavLink
              to="/"
              className={({ isActive }) =>
                `px-3 py-2 rounded-md text-sm font-medium ${
                  isActive ? 'bg-blue-700' : 'hover:bg-blue-500'
                }`
              }
            >
              Home
            </NavLink>
            <NavLink
              to="/weather"
              className={({ isActive }) =>
                `px-3 py-2 rounded-md text-sm font-medium ${
                  isActive ? 'bg-blue-700' : 'hover:bg-blue-500'
                }`
              }
            >
              Weather
            </NavLink>
          </div>
        </div>
      </div>
    </nav>
  )
}
```

**src/components/WeatherCard.tsx:**
```tsx
import { WeatherForecast } from '../types/weather'

interface WeatherCardProps {
  forecast: WeatherForecast
}

export default function WeatherCard({ forecast }: WeatherCardProps) {
  return (
    <div className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
      <div className="text-sm text-gray-500 mb-2">
        {new Date(forecast.date).toLocaleDateString('en-US', {
          weekday: 'long',
          month: 'short',
          day: 'numeric',
        })}
      </div>
      <div className="text-3xl font-bold text-blue-600 mb-2">
        {forecast.temperatureC}°C
        <span className="text-lg text-gray-400 ml-2">
          / {forecast.temperatureF}°F
        </span>
      </div>
      <div className="text-gray-700">{forecast.summary}</div>
    </div>
  )
}
```

## Pages

**src/pages/Home.tsx:**
```tsx
import { Link } from 'react-router-dom'

export default function Home() {
  return (
    <div className="text-center">
      <h1 className="text-4xl font-bold text-gray-800 mb-4">
        Welcome to {SolutionName}
      </h1>
      <p className="text-xl text-gray-600 mb-8">
        A modern microservices solution with .NET and React
      </p>
      <Link
        to="/weather"
        className="inline-block bg-blue-600 text-white px-6 py-3 rounded-lg font-semibold hover:bg-blue-700 transition-colors"
      >
        View Weather Forecast
      </Link>
    </div>
  )
}
```

**src/pages/Weather.tsx:**
```tsx
import { useQuery } from '@tanstack/react-query'
import { weatherApi } from '../api/weatherApi'
import { useWeatherStore } from '../store'
import WeatherCard from '../components/WeatherCard'
import { useEffect } from 'react'

export default function Weather() {
  const { setForecasts, setLoading, setError } = useWeatherStore()

  const { data, isLoading, error } = useQuery({
    queryKey: ['weather'],
    queryFn: weatherApi.getForecasts,
  })

  useEffect(() => {
    setLoading(isLoading)
    if (data) {
      setForecasts(data)
    }
    if (error) {
      setError(error instanceof Error ? error.message : 'Failed to fetch weather')
    }
  }, [data, isLoading, error, setForecasts, setLoading, setError])

  if (isLoading) {
    return (
      <div className="flex justify-center items-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    )
  }

  if (error) {
    return (
      <div className="bg-red-100 border border-red-400 text-red-700 px-4 py-3 rounded">
        <p>Error loading weather data. Make sure the API is running.</p>
        <p className="text-sm mt-2">API URL: {import.meta.env.VITE_API_URL}</p>
      </div>
    )
  }

  return (
    <div>
      <h1 className="text-3xl font-bold text-gray-800 mb-6">Weather Forecast</h1>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-4">
        {data?.map((forecast, index) => (
          <WeatherCard key={index} forecast={forecast} />
        ))}
      </div>
    </div>
  )
}
```

## Installation Commands

```bash
# Create project with Vite
npm create vite@latest {solution-name}-web -- --template react-ts

# Navigate to project
cd {solution-name}-web

# Install core dependencies
npm install zustand @tanstack/react-query axios react-router-dom

# Install Tailwind CSS
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p

# Install development server
npm install
```
