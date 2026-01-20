import { Link, NavLink } from 'react-router-dom'

export default function Navbar() {
  return (
    <nav className="bg-blue-600 text-white shadow-lg">
      <div className="container mx-auto px-4">
        <div className="flex items-center justify-between h-16">
          <Link to="/" className="text-xl font-bold">
            {{SOLUTION_NAME}}
          </Link>
          <div className="flex space-x-4">
            <NavLink
              to="/"
              className={({ isActive }) =>
                `px-3 py-2 rounded-md text-sm font-medium ${
                  isActive ? 'bg-blue-700' : 'hover:bg-blue-500'
                }`
              }
            >
              Home
            </NavLink>
            <NavLink
              to="/weather"
              className={({ isActive }) =>
                `px-3 py-2 rounded-md text-sm font-medium ${
                  isActive ? 'bg-blue-700' : 'hover:bg-blue-500'
                }`
              }
            >
              Weather
            </NavLink>
          </div>
        </div>
      </div>
    </nav>
  )
}
