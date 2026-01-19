/// <reference types="vite/client" />

// Definición de variables de entorno
interface ImportMetaEnv {
  readonly VITE_API_BASE_URL: string
  readonly VITE_APP_TITLE: string
  // Agregar más variables según sea necesario
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
