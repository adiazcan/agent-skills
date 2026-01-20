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
