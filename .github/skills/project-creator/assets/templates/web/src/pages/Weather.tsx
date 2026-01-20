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
