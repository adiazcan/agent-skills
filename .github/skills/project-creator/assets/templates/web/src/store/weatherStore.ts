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
