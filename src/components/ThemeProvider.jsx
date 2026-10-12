import { createContext, useContext, useEffect, useState } from 'react'

const ThemeContext = createContext(null)

export function ThemeProvider({ children }) {
  const [preference, setPreference] = useState(() => window.mnfTheme.getPreference())

  useEffect(() => {
    const theme = window.mnfTheme
    const onPreferenceChange = () => setPreference(theme.getPreference())
    const onSystemChange = () => {
      if (theme.getPreference() === 'auto') theme.refresh()
    }
    const onStorage = (event) => {
      if (event.key === theme.key || event.key === null) {
        theme.refresh()
        onPreferenceChange()
      }
    }
    window.addEventListener('mnf:appearance-change', onPreferenceChange)
    window.addEventListener('storage', onStorage)
    theme.media.addEventListener('change', onSystemChange)
    // Captura también un cambio del sistema ocurrido durante el arranque.
    onSystemChange()
    return () => {
      window.removeEventListener('mnf:appearance-change', onPreferenceChange)
      window.removeEventListener('storage', onStorage)
      theme.media.removeEventListener('change', onSystemChange)
    }
  }, [])

  return <ThemeContext.Provider value={{ preference, setPreference: (value) => window.mnfTheme.setPreference(value) }}>{children}</ThemeContext.Provider>
}

export function ThemeSelector({ compact = false }) {
  const { preference, setPreference } = useContext(ThemeContext)
  return (
    <label className={`theme-selector ${compact ? 'compact' : ''}`}>
      <span>Apariencia</span>
      <select className="input" aria-label="Apariencia" value={preference} onChange={(event) => setPreference(event.target.value)}>
        <option value="auto">Automático</option>
        <option value="light">Claro</option>
        <option value="dark">Oscuro</option>
      </select>
    </label>
  )
}
