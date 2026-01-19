import { Outlet, Link, useLocation } from 'react-router-dom';

export default function Layout() {
  const location = useLocation();

  const isActive = (path: string) => {
    return location.pathname === path
      ? 'bg-blue-700 text-white'
      : 'text-gray-300 hover:bg-blue-600 hover:text-white';
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Navigation */}
      <nav className="bg-blue-800 shadow-lg">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex">
              <div className="flex-shrink-0 flex items-center">
                <h1 className="text-white text-xl font-bold">My App</h1>
              </div>
              <div className="hidden sm:ml-6 sm:flex sm:space-x-8">
                <Link
                  to="/"
                  className={`${isActive('/')} inline-flex items-center px-3 py-2 rounded-md text-sm font-medium transition-colors`}
                >
                  Home
                </Link>
                <Link
                  to="/about"
                  className={`${isActive('/about')} inline-flex items-center px-3 py-2 rounded-md text-sm font-medium transition-colors`}
                >
                  About
                </Link>
              </div>
            </div>
          </div>
        </div>
      </nav>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          <Outlet />
        </div>
      </main>

      {/* Footer */}
      <footer className="bg-white border-t border-gray-200 mt-auto">
        <div className="max-w-7xl mx-auto py-4 px-4 sm:px-6 lg:px-8">
          <p className="text-center text-gray-500 text-sm">
            © {new Date().getFullYear()} My App. All rights reserved.
          </p>
        </div>
      </footer>
    </div>
  );
}
