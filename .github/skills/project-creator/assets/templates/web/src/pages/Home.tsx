import { Link } from 'react-router-dom'

export default function Home() {
  return (
    <div className="text-center">
      <h1 className="text-4xl font-bold text-gray-800 mb-4">
        Welcome to {{SOLUTION_NAME}}
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
