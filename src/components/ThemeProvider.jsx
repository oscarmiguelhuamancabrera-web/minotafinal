import { createContext, useContext, useEffect, useRef, useState } from 'react'
import { isLocalDevelopment } from '../themes/core/themeEngine.js'
import { getThemeById } from '../themes/core/themeRegistry.js'
import HalloweenDecorations from '../themes/halloween-2026/components/HalloweenDecorations.jsx'

const ThemeContext = createContext(null)

if (import.meta.env.DEV && typeof window !== 'undefined') window.__MN_THEME_DEV__ = true

// Reevalúa cualquier previsualización guardada antes del primer render. El
// script de arranque se ejecuta antes de que React marque el entorno como DEV,
// por lo que este segundo paso evita un destello del tema estacional al abrir
// el panel local. En producción `isLocalDevelopment()` siempre es falso.
if (isLocalDevelopment() && typeof window !== 'undefined') window.mnfTheme?.refreshSeasonal?.()

export function useTheme() {
  const value = useContext(ThemeContext)
  if (!value) throw new Error('useTheme debe usarse dentro de ThemeProvider')
  return value
}

export function ThemeProvider({ children }) {
  const [preference, setPreference] = useState(() => window.mnfTheme.getPreference())
  const [resolvedTheme, setResolvedTheme] = useState(() => window.mnfTheme.getTheme())
  const [activeThemeId, setActiveThemeId] = useState(() => window.mnfTheme.getActiveTheme?.() || 'original')
  const [previewDate, setPreviewDateState] = useState(() => window.mnfTheme.getPreviewDate?.() || '')

  useEffect(() => {
    const theme = window.mnfTheme
    const onPreferenceChange = () => {
      setPreference(theme.getPreference())
      setResolvedTheme(theme.getTheme())
      setActiveThemeId(theme.getActiveTheme?.() || 'original')
      setPreviewDateState(theme.getPreviewDate?.() || '')
    }
    const onSystemChange = () => {
      if (theme.getPreference() === 'auto') {
        theme.refresh()
        onPreferenceChange()
      }
    }
    const onStorage = (event) => {
      if (event.key === theme.key || event.key === 'mnf:theme-preview' || event.key === 'mnf:theme-preview-date' || event.key === null) {
        theme.refresh()
        onPreferenceChange()
      }
    }
    const refreshSeasonal = () => {
      theme.refreshSeasonal?.()
      onPreferenceChange()
    }
    window.addEventListener('mnf:appearance-change', onPreferenceChange)
    window.addEventListener('mnf:theme-change', onPreferenceChange)
    window.addEventListener('storage', onStorage)
    document.addEventListener('visibilitychange', refreshSeasonal)
    theme.media.addEventListener?.('change', onSystemChange)
    theme.media.addListener?.(onSystemChange)
    // Captura también un cambio del sistema ocurrido durante el arranque.
    onSystemChange()
    // React sets the development-only flag above; re-evaluate once so a saved
    // local preview can affect the first rendered tree without touching builds.
    if (isLocalDevelopment()) refreshSeasonal()
    const interval = window.setInterval?.(refreshSeasonal, 60 * 1000)
    return () => {
      window.removeEventListener('mnf:appearance-change', onPreferenceChange)
      window.removeEventListener('mnf:theme-change', onPreferenceChange)
      window.removeEventListener('storage', onStorage)
      document.removeEventListener('visibilitychange', refreshSeasonal)
      theme.media.removeEventListener?.('change', onSystemChange)
      theme.media.removeListener?.(onSystemChange)
      if (interval) window.clearInterval?.(interval)
    }
  }, [])

  const activeTheme = getThemeById(activeThemeId)
  const seasonal = Boolean(activeTheme && activeTheme.id !== 'original')
  const setPreviewTheme = (id) => {
    if (!isLocalDevelopment()) return
    try {
      if (id) window.localStorage.setItem('mnf:theme-preview', id)
      else window.localStorage.removeItem('mnf:theme-preview')
    } catch { /* Previsualización opcional; no debe bloquear la aplicación. */ }
    window.mnfTheme.refreshSeasonal?.()
    setPreference(window.mnfTheme.getPreference())
    setResolvedTheme(window.mnfTheme.getTheme())
    setActiveThemeId(window.mnfTheme.getActiveTheme?.() || 'original')
    setPreviewDateState(window.mnfTheme.getPreviewDate?.() || '')
  }

  const setPreviewDate = (value) => {
    if (!isLocalDevelopment()) return
    window.mnfTheme.setPreviewDate?.(value)
    setPreviewDateState(window.mnfTheme.getPreviewDate?.() || '')
    setPreference(window.mnfTheme.getPreference())
    setResolvedTheme(window.mnfTheme.getTheme())
    setActiveThemeId(window.mnfTheme.getActiveTheme?.() || 'original')
  }

  return (
    <ThemeContext.Provider value={{
      preference,
      resolvedTheme,
      activeTheme,
      seasonal,
      setPreference: (value) => window.mnfTheme.setPreference(value),
      setPreviewTheme,
      previewDate,
      setPreviewDate
    }}>
      {children}
      <HalloweenDecorations active={seasonal && activeTheme?.id === 'halloween-2026'} effects={activeTheme?.effects} />
      {isLocalDevelopment() && <LocalThemePreviewPanel activeThemeId={activeThemeId} previewDate={previewDate} setPreviewTheme={setPreviewTheme} setPreviewDate={setPreviewDate} />}
      <ThemeFloatingButton />
    </ThemeContext.Provider>
  )
}

function ThemePreviewPanel({ activeThemeId, previewDate, setPreviewTheme, setPreviewDate }) {
  const [expanded, setExpanded] = useState(false)
  const inputValue = previewDate ? previewDate.slice(0, 16) : ''
  const setDate = (value) => setPreviewDate(value ? `${value}:00-05:00` : '')
  return (
    <aside className={`theme-preview-panel ${expanded ? 'is-expanded' : 'is-collapsed'}`} aria-label="Previsualización de temas">
      <button
        type="button"
        className="theme-preview-toggle"
        aria-expanded={expanded}
        onClick={() => setExpanded((value) => !value)}
      >
        <span>Vista previa local</span>
        <span aria-hidden="true">{expanded ? '−' : '+'}</span>
      </button>
      {expanded && <div className="theme-preview-content">
        <span>Tema activo: {activeThemeId === 'halloween-2026' ? 'Halloween 2026' : 'Original'}</span>
        <div className="theme-preview-actions">
          <button type="button" className={activeThemeId === 'original' && !previewDate ? 'active' : ''} onClick={() => { setPreviewDate(''); setPreviewTheme('original') }}>Original</button>
          <button type="button" className={activeThemeId === 'halloween-2026' && !previewDate ? 'active' : ''} onClick={() => { setPreviewDate(''); setPreviewTheme('halloween-2026') }}>Halloween</button>
        </div>
        <label>Simular fecha <input type="datetime-local" value={inputValue} onChange={(event) => setDate(event.target.value)} /></label>
        <div className="theme-preview-actions compact">
          <button type="button" onClick={() => setDate('2026-10-25T12:00')}>En vigencia</button>
          <button type="button" onClick={() => setDate('2026-11-01T00:00')}>Expirada</button>
          <button type="button" onClick={() => { setPreviewDate(''); setPreviewTheme(null) }}>Fecha real</button>
        </div>
      </div>}
    </aside>
  )
}

// Mantén el componente del panel fuera del árbol de producción; Vite resuelve
// esta condición en build y deja únicamente un componente vacío cuando DEV es
// falso.
const LocalThemePreviewPanel = import.meta.env.DEV ? ThemePreviewPanel : () => null

export function ThemeFloatingButton() {
  const { preference, resolvedTheme, seasonal, setPreference } = useContext(ThemeContext)
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
          {seasonal && <p className="theme-floating-season-note">Halloween usa apariencia nocturna durante su vigencia.</p>}
          {options.map((option) => (
            <button
              type="button"
              role="menuitemradio"
              aria-checked={preference === option.value}
              className={preference === option.value ? 'active' : ''}
              key={option.value}
              disabled={seasonal}
              title={seasonal ? 'La apariencia se restaura al terminar Halloween' : undefined}
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
