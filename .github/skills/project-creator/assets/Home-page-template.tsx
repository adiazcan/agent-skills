import { useAppStore } from '../stores/appStore';

export default function Home() {
  const count = useAppStore((state) => state.count);
  const increment = useAppStore((state) => state.increment);
  const decrement = useAppStore((state) => state.decrement);
  const reset = useAppStore((state) => state.reset);

  return (
    <div className="space-y-6">
      {/* Hero Section */}
      <div className="bg-white rounded-lg shadow-md p-8 text-center">
        <h1 className="text-4xl font-bold text-gray-900 mb-4">
          Welcome to Your App
        </h1>
        <p className="text-xl text-gray-600">
          Built with React, Vite, TailwindCSS, Zustand, and React Router
        </p>
      </div>

      {/* Counter Example with Zustand */}
      <div className="bg-white rounded-lg shadow-md p-6">
        <h2 className="text-2xl font-semibold text-gray-800 mb-4">
          Counter Example
        </h2>
        <div className="flex flex-col items-center space-y-4">
          <div className="text-6xl font-bold text-blue-600">{count}</div>
          <div className="flex space-x-4">
            <button
              onClick={decrement}
              className="px-6 py-3 bg-red-500 text-white rounded-lg hover:bg-red-600 transition-colors font-medium"
            >
              Decrement
            </button>
            <button
              onClick={reset}
              className="px-6 py-3 bg-gray-500 text-white rounded-lg hover:bg-gray-600 transition-colors font-medium"
            >
              Reset
            </button>
            <button
              onClick={increment}
              className="px-6 py-3 bg-green-500 text-white rounded-lg hover:bg-green-600 transition-colors font-medium"
            >
              Increment
            </button>
          </div>
        </div>
      </div>

      {/* Features Grid */}
      <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
        <FeatureCard
          title="⚡ Vite"
          description="Lightning fast development with HMR"
        />
        <FeatureCard
          title="🎨 TailwindCSS"
          description="Utility-first CSS framework"
        />
        <FeatureCard
          title="🐻 Zustand"
          description="Simple and scalable state management"
        />
        <FeatureCard
          title="🗺️ React Router"
          description="Declarative routing for React"
        />
        <FeatureCard
          title="📡 Axios"
          description="Promise-based HTTP client"
        />
        <FeatureCard
          title="⚙️ TypeScript"
          description="Type-safe development"
        />
      </div>
    </div>
  );
}

function FeatureCard({ title, description }: { title: string; description: string }) {
  return (
    <div className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
      <h3 className="text-xl font-semibold text-gray-800 mb-2">{title}</h3>
      <p className="text-gray-600">{description}</p>
    </div>
  );
}
