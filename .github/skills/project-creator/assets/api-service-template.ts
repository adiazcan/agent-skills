// Template de servicio API con Axios
import axios, { AxiosInstance, AxiosError, InternalAxiosRequestConfig } from 'axios';

// Configuración base de Axios
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'https://localhost:7000';

class ApiService {
  private api: AxiosInstance;

  constructor() {
    this.api = axios.create({
      baseURL: API_BASE_URL,
      timeout: 10000,
      headers: {
        'Content-Type': 'application/json',
      },
      withCredentials: true, // Para CORS con credenciales
    });

    this.setupInterceptors();
  }

  private setupInterceptors() {
    // Request interceptor
    this.api.interceptors.request.use(
      (config: InternalAxiosRequestConfig) => {
        // Agregar token de autenticación si existe
        const token = localStorage.getItem('auth_token');
        if (token && config.headers) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
      },
      (error: AxiosError) => {
        return Promise.reject(error);
      }
    );

    // Response interceptor
    this.api.interceptors.response.use(
      (response) => response,
      (error: AxiosError) => {
        // Manejo global de errores
        if (error.response) {
          switch (error.response.status) {
            case 401:
              // Manejar no autorizado
              console.error('No autorizado');
              // Redirigir al login si es necesario
              break;
            case 403:
              console.error('Acceso prohibido');
              break;
            case 404:
              console.error('Recurso no encontrado');
              break;
            case 500:
              console.error('Error del servidor');
              break;
            default:
              console.error('Error:', error.response.data);
          }
        } else if (error.request) {
          console.error('No se recibió respuesta del servidor');
        } else {
          console.error('Error:', error.message);
        }
        return Promise.reject(error);
      }
    );
  }

  // Métodos genéricos
  public async get<T>(url: string, config = {}): Promise<T> {
    const response = await this.api.get<T>(url, config);
    return response.data;
  }

  public async post<T>(url: string, data = {}, config = {}): Promise<T> {
    const response = await this.api.post<T>(url, data, config);
    return response.data;
  }

  public async put<T>(url: string, data = {}, config = {}): Promise<T> {
    const response = await this.api.put<T>(url, data, config);
    return response.data;
  }

  public async delete<T>(url: string, config = {}): Promise<T> {
    const response = await this.api.delete<T>(url, config);
    return response.data;
  }

  public async patch<T>(url: string, data = {}, config = {}): Promise<T> {
    const response = await this.api.patch<T>(url, data, config);
    return response.data;
  }
}

// Exportar una instancia única
export const apiService = new ApiService();

// Ejemplos de uso específico
export const healthApi = {
  check: () => apiService.get<{ status: string; timestamp: string }>('/api/health'),
};

export const versionApi = {
  get: () => apiService.get<{ version: string; framework: string }>('/api/version'),
};

export const greetingApi = {
  get: (name: string) => 
    apiService.get<{ message: string; timestamp: string }>(`/api/greeting/${name}`),
};

export const echoApi = {
  send: (message: string) => 
    apiService.post<{ echo: string; receivedAt: string }>('/api/echo', { message }),
};
