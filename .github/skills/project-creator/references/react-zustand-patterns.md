# Patrones y Mejores Prácticas para React + Zustand + TailwindCSS + React Router

## Estructura del Proyecto React

### Organización Recomendada

```
src/
├── assets/                 # Recursos estáticos
├── components/             # Componentes reutilizables
│   ├── common/             # Componentes comunes (Button, Input, Card)
│   └── layout/             # Componentes de layout (Header, Footer, Sidebar)
├── features/               # Features organizadas por dominio
│   └── users/
│       ├── components/
│       ├── hooks/
│       ├── services/
│       └── stores/
├── hooks/                  # Custom hooks globales
├── layouts/                # Layouts de páginas (MainLayout, AuthLayout)
├── pages/                  # Componentes de página
├── services/               # Servicios de API
├── stores/                 # Stores de Zustand globales
├── types/                  # Tipos TypeScript
├── utils/                  # Utilidades
├── App.tsx
└── main.tsx
```

## Patrones Avanzados de Zustand

### 1. Store Modular (Slices)

```typescript
import { create } from 'zustand';
import { devtools } from 'zustand/middleware';

// Slice de autenticación
interface AuthSlice {
  user: User | null;
  token: string | null;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

const createAuthSlice = (set: any): AuthSlice => ({
  user: null,
  token: null,
  login: async (email, password) => {
    const response = await authApi.login(email, password);
    set({ user: response.user, token: response.token });
  },
  logout: () => set({ user: null, token: null }),
});

// Slice de UI
interface UISlice {
  theme: 'light' | 'dark';
  sidebarOpen: boolean;
  toggleTheme: () => void;
  toggleSidebar: () => void;
}

const createUISlice = (set: any): UISlice => ({
  theme: 'light',
  sidebarOpen: true,
  toggleTheme: () => set((state: UISlice) => ({ 
    theme: state.theme === 'light' ? 'dark' : 'light' 
  })),
  toggleSidebar: () => set((state: UISlice) => ({ 
    sidebarOpen: !state.sidebarOpen 
  })),
});

// Combinar slices
type StoreState = AuthSlice & UISlice;

export const useStore = create<StoreState>()(
  devtools(
    (...args) => ({
      ...createAuthSlice(...args),
      ...createUISlice(...args),
    })
  )
);
```

### 2. Store con Immer para Estado Complejo

```typescript
import { create } from 'zustand';
import { devtools } from 'zustand/middleware';
import { immer } from 'zustand/middleware/immer';

interface Todo {
  id: string;
  text: string;
  completed: boolean;
}

interface TodoStore {
  todos: Todo[];
  addTodo: (text: string) => void;
  toggleTodo: (id: string) => void;
  removeTodo: (id: string) => void;
  updateTodo: (id: string, text: string) => void;
}

export const useTodoStore = create<TodoStore>()(
  devtools(
    immer((set) => ({
      todos: [],
      addTodo: (text) =>
        set((state) => {
          state.todos.push({
            id: crypto.randomUUID(),
            text,
            completed: false,
          });
        }),
      toggleTodo: (id) =>
        set((state) => {
          const todo = state.todos.find((t) => t.id === id);
          if (todo) {
            todo.completed = !todo.completed;
          }
        }),
      removeTodo: (id) =>
        set((state) => {
          state.todos = state.todos.filter((t) => t.id !== id);
        }),
      updateTodo: (id, text) =>
        set((state) => {
          const todo = state.todos.find((t) => t.id === id);
          if (todo) {
            todo.text = text;
          }
        }),
    }))
  )
);
```

### 3. Selectores y Optimización

```typescript
import { create } from 'zustand';
import { shallow } from 'zustand/shallow';

// Usar selectores para evitar re-renders innecesarios
export const useStore = create<StoreState>((set) => ({
  // ... estado
}));

// Seleccionar solo lo necesario
function UserProfile() {
  const user = useStore((state) => state.user);
  const logout = useStore((state) => state.logout);
  // Componente solo se re-renderiza cuando user o logout cambian
}

// Seleccionar múltiples valores
function Dashboard() {
  const { user, isLoading } = useStore(
    (state) => ({ 
      user: state.user, 
      isLoading: state.isLoading 
    }),
    shallow // Comparación superficial para evitar re-renders
  );
}

// Selectores computados
const selectCompletedTodos = (state: TodoStore) => 
  state.todos.filter(todo => todo.completed);

function CompletedTodoList() {
  const completedTodos = useTodoStore(selectCompletedTodos);
}
```

### 4. Persistencia Selectiva

```typescript
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';

interface AppStore {
  // Datos que queremos persistir
  preferences: {
    theme: string;
    language: string;
  };
  // Datos que NO queremos persistir
  temporaryData: any;
  
  setPreferences: (prefs: Partial<AppStore['preferences']>) => void;
  setTemporaryData: (data: any) => void;
}

export const useAppStore = create<AppStore>()(
  persist(
    (set) => ({
      preferences: {
        theme: 'light',
        language: 'es',
      },
      temporaryData: null,
      
      setPreferences: (prefs) =>
        set((state) => ({
          preferences: { ...state.preferences, ...prefs },
        })),
      setTemporaryData: (data) => set({ temporaryData: data }),
    }),
    {
      name: 'app-storage',
      storage: createJSONStorage(() => localStorage),
      // Solo persistir preferences
      partialize: (state) => ({ preferences: state.preferences }),
    }
  )
);
```

### 5. Async Actions con Estado de Carga

```typescript
interface DataStore {
  data: Item[];
  isLoading: boolean;
  error: string | null;
  
  fetchData: () => Promise<void>;
  createItem: (item: Omit<Item, 'id'>) => Promise<void>;
}

export const useDataStore = create<DataStore>((set, get) => ({
  data: [],
  isLoading: false,
  error: null,
  
  fetchData: async () => {
    set({ isLoading: true, error: null });
    try {
      const data = await apiService.get<Item[]>('/api/items');
      set({ data, isLoading: false });
    } catch (error) {
      set({ 
        error: error instanceof Error ? error.message : 'Error desconocido',
        isLoading: false 
      });
    }
  },
  
  createItem: async (item) => {
    set({ isLoading: true, error: null });
    try {
      const newItem = await apiService.post<Item>('/api/items', item);
      set((state) => ({ 
        data: [...state.data, newItem],
        isLoading: false 
      }));
    } catch (error) {
      set({ 
        error: error instanceof Error ? error.message : 'Error al crear',
        isLoading: false 
      });
    }
  },
}));
```

## Hooks Personalizados

### Hook para Manejo de Formularios

```typescript
import { useState, ChangeEvent, FormEvent } from 'react';

interface UseFormOptions<T> {
  initialValues: T;
  onSubmit: (values: T) => void | Promise<void>;
  validate?: (values: T) => Partial<Record<keyof T, string>>;
}

export function useForm<T extends Record<string, any>>({
  initialValues,
  onSubmit,
  validate,
}: UseFormOptions<T>) {
  const [values, setValues] = useState<T>(initialValues);
  const [errors, setErrors] = useState<Partial<Record<keyof T, string>>>({});
  const [isSubmitting, setIsSubmitting] = useState(false);

  const handleChange = (e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setValues((prev) => ({ ...prev, [name]: value }));
    // Limpiar error al escribir
    if (errors[name as keyof T]) {
      setErrors((prev) => ({ ...prev, [name]: undefined }));
    }
  };

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    
    if (validate) {
      const validationErrors = validate(values);
      if (Object.keys(validationErrors).length > 0) {
        setErrors(validationErrors);
        return;
      }
    }

    setIsSubmitting(true);
    try {
      await onSubmit(values);
      setValues(initialValues);
    } catch (error) {
      console.error('Error submitting form:', error);
    } finally {
      setIsSubmitting(false);
    }
  };

  const reset = () => {
    setValues(initialValues);
    setErrors({});
  };

  return {
    values,
    errors,
    isSubmitting,
    handleChange,
    handleSubmit,
    reset,
    setValues,
  };
}
```

### Hook para Fetch de Datos

```typescript
import { useState, useEffect } from 'react';

interface UseFetchResult<T> {
  data: T | null;
  isLoading: boolean;
  error: string | null;
  refetch: () => void;
}

export function useFetch<T>(
  fetcher: () => Promise<T>,
  dependencies: any[] = []
): UseFetchResult<T> {
  const [data, setData] = useState<T | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refetchTrigger, setRefetchTrigger] = useState(0);

  useEffect(() => {
    let isMounted = true;

    const fetchData = async () => {
      setIsLoading(true);
      setError(null);
      
      try {
        const result = await fetcher();
        if (isMounted) {
          setData(result);
        }
      } catch (err) {
        if (isMounted) {
          setError(err instanceof Error ? err.message : 'Error desconocido');
        }
      } finally {
        if (isMounted) {
          setIsLoading(false);
        }
      }
    };

    fetchData();

    return () => {
      isMounted = false;
    };
  }, [...dependencies, refetchTrigger]);

  const refetch = () => setRefetchTrigger((prev) => prev + 1);

  return { data, isLoading, error, refetch };
}
```

## React Router con Zustand

```typescript
import { create } from 'zustand';
import { useNavigate } from 'react-router-dom';

interface NavigationStore {
  history: string[];
  pushToHistory: (path: string) => void;
  canGoBack: () => boolean;
}

export const useNavigationStore = create<NavigationStore>((set, get) => ({
  history: [],
  pushToHistory: (path) =>
    set((state) => ({ history: [...state.history, path] })),
  canGoBack: () => get().history.length > 1,
}));

// Uso en componente
function NavigationButtons() {
  const navigate = useNavigate();
  const { canGoBack, pushToHistory } = useNavigationStore();

  const handleNavigate = (path: string) => {
    navigate(path);
    pushToHistory(path);
  };

  return (
    <div>
      <button onClick={() => handleNavigate('/home')}>Home</button>
      <button onClick={() => navigate(-1)} disabled={!canGoBack()}>
        Atrás
      </button>
    </div>
  );
}
```

## Configuración de React Router

### Estructura Básica con Layout

```typescript
import { BrowserRouter, Routes, Route, Outlet } from 'react-router-dom';
import Layout from './layouts/Layout';
import Home from './pages/Home';
import About from './pages/About';
import Dashboard from './pages/Dashboard';
import NotFound from './pages/NotFound';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Layout />}>
          <Route index element={<Home />} />
          <Route path="about" element={<About />} />
          <Route path="dashboard" element={<Dashboard />} />
          <Route path="*" element={<NotFound />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}
```

### Protected Routes

```typescript
import { Navigate, Outlet } from 'react-router-dom';
import { useAuthStore } from '@/stores/authStore';

function ProtectedRoute() {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return <Outlet />;
}

// Uso en App.tsx
<Route element={<ProtectedRoute />}>
  <Route path="dashboard" element={<Dashboard />} />
  <Route path="profile" element={<Profile />} />
</Route>
```

### Navegación con Estado

```typescript
import { useNavigate, useLocation } from 'react-router-dom';

function LoginForm() {
  const navigate = useNavigate();
  const location = useLocation();

  const handleLogin = async (credentials: Credentials) => {
    await authApi.login(credentials);
    
    // Redirigir a la página anterior o al dashboard
    const from = location.state?.from?.pathname || '/dashboard';
    navigate(from, { replace: true });
  };
}
```

### Lazy Loading de Rutas

```typescript
import { lazy, Suspense } from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';

const Home = lazy(() => import('./pages/Home'));
const Dashboard = lazy(() => import('./pages/Dashboard'));

function App() {
  return (
    <BrowserRouter>
      <Suspense fallback={<div className="flex justify-center items-center h-screen">Loading...</div>}>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/dashboard" element={<Dashboard />} />
        </Routes>
      </Suspense>
    </BrowserRouter>
  );
}
```

## TailwindCSS Patterns

### Componentes Reutilizables con Tailwind

```typescript
import { ButtonHTMLAttributes, ReactNode } from 'react';
import { twMerge } from 'tailwind-merge';
import clsx from 'clsx';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger';
  size?: 'sm' | 'md' | 'lg';
  children: ReactNode;
}

export function Button({ 
  variant = 'primary', 
  size = 'md', 
  className, 
  children, 
  ...props 
}: ButtonProps) {
  return (
    <button
      className={twMerge(
        'rounded-lg font-medium transition-colors',
        clsx({
          'bg-blue-600 hover:bg-blue-700 text-white': variant === 'primary',
          'bg-gray-600 hover:bg-gray-700 text-white': variant === 'secondary',
          'bg-red-600 hover:bg-red-700 text-white': variant === 'danger',
          'px-3 py-1.5 text-sm': size === 'sm',
          'px-4 py-2 text-base': size === 'md',
          'px-6 py-3 text-lg': size === 'lg',
        }),
        className
      )}
      {...props}
    >
      {children}
    </button>
  );
}
```

### Card Component

```typescript
import { ReactNode } from 'react';

interface CardProps {
  title?: string;
  children: ReactNode;
  className?: string;
}

export function Card({ title, children, className = '' }: CardProps) {
  return (
    <div className={`bg-white rounded-lg shadow-md p-6 ${className}`}>
      {title && (
        <h3 className="text-xl font-semibold text-gray-800 mb-4">{title}</h3>
      )}
      {children}
    </div>
  );
}
```

### Input Component

```typescript
import { InputHTMLAttributes, forwardRef } from 'react';

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ label, error, className = '', ...props }, ref) => {
    return (
      <div className="space-y-1">
        {label && (
          <label className="block text-sm font-medium text-gray-700">
            {label}
          </label>
        )}
        <input
          ref={ref}
          className={`
            w-full px-4 py-2 border rounded-lg
            focus:outline-none focus:ring-2 focus:ring-blue-500
            ${error ? 'border-red-500' : 'border-gray-300'}
            ${className}
          `}
          {...props}
        />
        {error && <p className="text-sm text-red-600">{error}</p>}
      </div>
    );
  }
);
```

### Modal Component

```typescript
import { ReactNode, useEffect } from 'react';
import { createPortal } from 'react-dom';

interface ModalProps {
  isOpen: boolean;
  onClose: () => void;
  children: ReactNode;
  title?: string;
}

export function Modal({ isOpen, onClose, children, title }: ModalProps) {
  useEffect(() => {
    if (isOpen) {
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = 'unset';
    }
    return () => {
      document.body.style.overflow = 'unset';
    };
  }, [isOpen]);

  if (!isOpen) return null;

  return createPortal(
    <div className="fixed inset-0 z-50 overflow-y-auto">
      <div className="flex min-h-screen items-center justify-center p-4">
        {/* Backdrop */}
        <div
          className="fixed inset-0 bg-black bg-opacity-50 transition-opacity"
          onClick={onClose}
        />

        {/* Modal */}
        <div className="relative bg-white rounded-lg shadow-xl max-w-md w-full p-6 z-10">
          {title && (
            <h3 className="text-xl font-semibold text-gray-900 mb-4">
              {title}
            </h3>
          )}
          {children}
        </div>
      </div>
    </div>,
    document.body
  );
}
```

### Layout con Tailwind

```typescript
import { Outlet, Link } from 'react-router-dom';

export default function Layout() {
  return (
    <div className="min-h-screen bg-gray-50">
      {/* Navigation */}
      <nav className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex space-x-8">
              <Link to="/" className="flex items-center text-gray-900 hover:text-blue-600">
                Home
              </Link>
              <Link to="/about" className="flex items-center text-gray-900 hover:text-blue-600">
                About
              </Link>
            </div>
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <Outlet />
      </main>

      {/* Footer */}
      <footer className="bg-white border-t border-gray-200 mt-auto">
        <div className="max-w-7xl mx-auto py-4 px-4 text-center text-gray-500">
          © {new Date().getFullYear()} My App
        </div>
      </footer>
    </div>
  );
}
```

### Dark Mode con Tailwind

```typescript
// En tailwind.config.js
export default {
  darkMode: 'class',
  // ...
}

// Hook para dark mode
import { create } from 'zustand';
import { persist } from 'zustand/middleware';

interface ThemeStore {
  isDark: boolean;
  toggleTheme: () => void;
}

export const useThemeStore = create<ThemeStore>()(
  persist(
    (set) => ({
      isDark: false,
      toggleTheme: () =>
        set((state) => {
          const newIsDark = !state.isDark;
          if (newIsDark) {
            document.documentElement.classList.add('dark');
          } else {
            document.documentElement.classList.remove('dark');
          }
          return { isDark: newIsDark };
        }),
    }),
    { name: 'theme-storage' }
  )
);

// Componente
function ThemeToggle() {
  const { isDark, toggleTheme } = useThemeStore();

  return (
    <button
      onClick={toggleTheme}
      className="p-2 rounded-lg bg-gray-200 dark:bg-gray-700"
    >
      {isDark ? '🌙' : '☀️'}
    </button>
  );
}
```

### Responsive Design Patterns

```typescript
// Mobile-first approach
<div className="
  flex flex-col          // Mobile: stack vertically
  md:flex-row            // Tablet: horizontal layout
  lg:space-x-8           // Desktop: add spacing
">
  <aside className="
    w-full               // Mobile: full width
    md:w-64              // Tablet: fixed sidebar width
    lg:w-80              // Desktop: wider sidebar
  ">
    {/* Sidebar */}
  </aside>
  
  <main className="
    flex-1               // Take remaining space
    p-4                  // Mobile padding
    md:p-6               // Tablet padding
    lg:p-8               // Desktop padding
  ">
    {/* Main content */}
  </main>
</div>
```

### Formularios con Tailwind y React Hook Form

```bash
npm install react-hook-form
```

```typescript
import { useForm } from 'react-hook-form';
import { Input } from '@/components/Input';
import { Button } from '@/components/Button';

interface FormData {
  email: string;
  password: string;
}

function LoginForm() {
  const { register, handleSubmit, formState: { errors } } = useForm<FormData>();

  const onSubmit = (data: FormData) => {
    console.log(data);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4 max-w-md mx-auto">
      <Input
        label="Email"
        type="email"
        error={errors.email?.message}
        {...register('email', {
          required: 'Email is required',
          pattern: {
            value: /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$/i,
            message: 'Invalid email address',
          },
        })}
      />

      <Input
        label="Password"
        type="password"
        error={errors.password?.message}
        {...register('password', {
          required: 'Password is required',
          minLength: {
            value: 6,
            message: 'Password must be at least 6 characters',
          },
        })}
      />

      <Button type="submit" variant="primary" className="w-full">
        Login
      </Button>
    </form>
  );
}
```

## React Router con Zustand

```typescript
import { create } from 'zustand';
import { useNavigate } from 'react-router-dom';

interface NavigationStore {
  history: string[];
  pushToHistory: (path: string) => void;
  canGoBack: () => boolean;
}

export const useNavigationStore = create<NavigationStore>((set, get) => ({
  history: [],
  pushToHistory: (path) =>
    set((state) => ({ history: [...state.history, path] })),
  canGoBack: () => get().history.length > 1,
}));

// Uso en componente
function NavigationButtons() {
  const navigate = useNavigate();
  const { canGoBack, pushToHistory } = useNavigationStore();

  const handleNavigate = (path: string) => {
    navigate(path);
    pushToHistory(path);
  };

  return (
    <div>
      <button onClick={() => handleNavigate('/home')}>Home</button>
      <button onClick={() => navigate(-1)} disabled={!canGoBack()}>
        Atrás
      </button>
    </div>
  );
}
```

## Componentes de Ejemplo

### Componente con Zustand

```typescript
import { useAppStore } from '@/stores/appStore';

function Counter() {
  const count = useAppStore((state) => state.count);
  const increment = useAppStore((state) => state.increment);
  const decrement = useAppStore((state) => state.decrement);

  return (
    <div>
      <h2>Count: {count}</h2>
      <button onClick={increment}>+</button>
      <button onClick={decrement}>-</button>
    </div>
  );
}
```

### Componente con API

```typescript
import { useEffect } from 'react';
import { useDataStore } from '@/stores/dataStore';

function DataList() {
  const { data, isLoading, error, fetchData } = useDataStore();

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  if (isLoading) return <div>Cargando...</div>;
  if (error) return <div>Error: {error}</div>;

  return (
    <ul>
      {data.map((item) => (
        <li key={item.id}>{item.name}</li>
      ))}
    </ul>
  );
}
```
