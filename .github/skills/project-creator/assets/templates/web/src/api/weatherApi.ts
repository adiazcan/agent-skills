import axios from 'axios'
import { WeatherForecast } from '../types/weather'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || '',
  headers: {
    'Content-Type': 'application/json',
  },
})

export const weatherApi = {
  getForecasts: async (): Promise<WeatherForecast[]> => {
    const response = await api.get<WeatherForecast[]>('/api/weather')
    return response.data
  },
}
