import { createContext, useContext, useEffect, useRef, useState } from 'react'

const ThemeContext = createContext(null)

export function ThemeProvider({ children }) {
  const [preference, setPreference] = useState(() => window.mnfTheme.getPreference())
  const [resolvedTheme, setResolvedTheme] = useState(() => window.mnfTheme.getTheme())

  useEffect(() => {
    const theme = window.mnfTheme
    const onPreferenceChange = () => {
      setPreference(theme.getPreference())
      setResolvedTheme(theme.getTheme())
    }
    const onSystemChange = () => {
      if (theme.getPreference() === 'auto') {
        theme.refresh()
        onPreferenceChange()
      }
    }
    const onStorage = (event) => {
      if (event.key === theme.key || event.key === null) {
        theme.refresh()
        onPreferenceChange()
      }
    }
    window.addEventListener('mnf:appearance-change', onPreferenceChange)
    window.addEventListener('storage', onStorage)
    theme.media.addEventListener?.('change', onSystemChange)
    theme.media.addListener?.(onSystemChange)
    // Captura también un cambio del sistema ocurrido durante el arranque.
    onSystemChange()
    return () => {
      window.removeEventListener('mnf:appearance-change', onPreferenceChange)
      window.removeEventListener('storage', onStorage)
      theme.media.removeEventListener?.('change', onSystemChange)
      theme.media.removeListener?.(onSystemChange)
    }
  }, [])

  return (
    <ThemeContext.Provider value={{ preference, resolvedTheme, setPreference: (value) => window.mnfTheme.setPreference(value) }}>
      {children}
      <ThemeFloatingButton />
    </ThemeContext.Provider>
  )
}

export function ThemeFloatingButton() {
  const { preference, resolvedTheme, setPreference } = useContext(ThemeContext)
  const [open, setOpen] = useState(false)
  const rootRef = useRef(null)
  const options = [
    { value: 'light', label: 'Claro', icon: '☀️' },
    { value: 'dark', label: 'Oscuro', icon: '🌙' },
    { value: 'auto', label: 'Automático', icon: '◐' }
  ]

  useEffect(() => {
    if (!open) return undefined
    const closeOnOutside = (event) => {
      if (!rootRef.current?.contains(event.target)) setOpen(false)
    }
    const closeOnEscape = (event) => {
      if (event.key === 'Escape') {
        setOpen(false)
        rootRef.current?.querySelector('button[aria-expanded]')?.focus()
      }
    }
    document.addEventListener('pointerdown', closeOnOutside)
    document.addEventListener('keydown', closeOnEscape)
    return () => {
      document.removeEventListener('pointerdown', closeOnOutside)
      document.removeEventListener('keydown', closeOnEscape)
    }
  }, [open])

  const buttonIcon = resolvedTheme === 'dark' ? '🌙' : '☀️'
  return (
    <div className={`theme-floating ${open ? 'is-open' : ''}`} ref={rootRef}>
      {open && (
        <div className="theme-floating-menu" role="menu" aria-label="Seleccionar apariencia">
          <span className="theme-floating-title">Apariencia</span>
          {options.map((option) => (
            <button
              type="button"
              role="menuitemradio"
              aria-checked={preference === option.value}
              className={preference === option.value ? 'active' : ''}
              key={option.value}
              onClick={() => { setPreference(option.value); setOpen(false) }}
            >
              <span aria-hidden="true">{option.icon}</span>
              <span>{option.label}</span>
              {preference === option.value && <span className="theme-floating-check" aria-label="Seleccionado">✓</span>}
            </button>
          ))}
        </div>
      )}
      <button
        type="button"
        className="theme-floating-trigger"
        aria-label={`Apariencia: ${preference === 'auto' ? 'automático' : preference}. Abrir opciones`}
        aria-expanded={open}
        aria-haspopup="menu"
        onClick={() => setOpen((value) => !value)}
      >
        <span aria-hidden="true">{buttonIcon}</span>
      </button>
    </div>
  )
}
