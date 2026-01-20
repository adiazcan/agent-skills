import { Routes, Route } from 'react-router-dom'
import Layout from './components/Layout'
import Home from './pages/Home'
import Weather from './pages/Weather'

function App() {
  return (
    <Routes>
      <Route path="/" element={<Layout />}>
        <Route index element={<Home />} />
        <Route path="weather" element={<Weather />} />
      </Route>
    </Routes>
  )
}

export default App
