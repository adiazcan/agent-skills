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
        <p>&copy; {new Date().getFullYear()} {{SOLUTION_NAME}}</p>
      </footer>
    </div>
  )
}
