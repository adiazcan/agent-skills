// Template de store básico con Zustand
import { create } from 'zustand';
import { devtools, persist } from 'zustand/middleware';

// Definir el tipo del estado
interface AppState {
  // Estado
  count: number;
  user: User | null;
  isLoading: boolean;
  
  // Acciones
  increment: () => void;
  decrement: () => void;
  reset: () => void;
  setUser: (user: User | null) => void;
  setLoading: (loading: boolean) => void;
}

interface User {
  id: string;
  name: string;
  email: string;
}

// Crear el store con middleware
export const useAppStore = create<AppState>()(
  devtools(
    persist(
      (set) => ({
        // Estado inicial
        count: 0,
        user: null,
        isLoading: false,
        
        // Acciones
        increment: () => set((state) => ({ count: state.count + 1 })),
        decrement: () => set((state) => ({ count: state.count - 1 })),
        reset: () => set({ count: 0 }),
        setUser: (user) => set({ user }),
        setLoading: (isLoading) => set({ isLoading }),
      }),
      {
        name: 'app-storage', // Nombre para localStorage
        // Opcional: seleccionar qué parte del estado persistir
        // partialize: (state) => ({ user: state.user }),
      }
    )
  )
);

// Selectores (opcional pero recomendado para optimización)
export const selectCount = (state: AppState) => state.count;
export const selectUser = (state: AppState) => state.user;
export const selectIsLoading = (state: AppState) => state.isLoading;
