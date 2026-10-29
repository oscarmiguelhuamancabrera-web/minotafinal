// Se ejecuta antes de React/CSS para aplicar la apariencia sin destellos.
// La resolución estacional es pequeña y sin dependencias para que el arranque
// siga funcionando aunque el almacenamiento o un recurso fallen.
;(function () {
  const key = 'mnf:appearance'
  const previewKey = 'mnf:theme-preview'
  const previewDateKey = 'mnf:theme-preview-date'
  const options = ['light', 'dark', 'auto']
  const media = window.matchMedia('(prefers-color-scheme: dark)')
  const halloween = {
    id: 'halloween-2026',
    startAt: '2026-10-22T00:00:00-05:00',
    endAt: '2026-11-01T00:00:00-05:00',
    appearance: 'dark'
  }
  let preference = 'auto'
  let activeThemeId = 'original'

  function readPreference() {
    try {
      const saved = window.localStorage.getItem(key)
      return options.includes(saved) ? saved : 'auto'
    } catch {
      return preference
    }
  }

  function isLocalHost() {
    const host = window.location?.hostname
    return host === 'localhost' || host === '127.0.0.1' || /^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[0-1])\.)/.test(host || '')
  }

  function isDevPreviewEnabled() {
    return isLocalHost() && window.__MN_THEME_DEV__ === true
  }

  function readPreview() {
    if (!isDevPreviewEnabled()) return null
    try {
      const value = window.localStorage.getItem(previewKey)
      return value === halloween.id || value === 'original' ? value : null
    } catch {
      return null
    }
  }

  function readPreviewDate() {
    if (!isDevPreviewEnabled()) return null
    try {
      const value = window.localStorage.getItem(previewDateKey)
      return value && Number.isFinite(Date.parse(value)) ? value : null
    } catch {
      return null
    }
  }

  function isHalloweenActive(now = Date.now()) {
    // The boot test VM has no location; a real browser always supplies it.
    if (!window.location) return false
    const timestamp = now instanceof Date ? now.getTime() : Number(now)
    const start = Date.parse(halloween.startAt)
    const end = Date.parse(halloween.endAt)
    return Number.isFinite(timestamp) && timestamp >= start && timestamp < end
  }

  function resolveTheme() {
    const preview = readPreview()
    const simulatedDate = readPreviewDate()
    if (simulatedDate) return isHalloweenActive(Date.parse(simulatedDate)) ? halloween : { id: 'original' }
    if (preview === 'original') return { id: 'original' }
    if (preview === halloween.id || isHalloweenActive()) return halloween
    return { id: 'original' }
  }

  function apply(value) {
    preference = options.includes(value) ? value : 'auto'
    const selected = resolveTheme()
    activeThemeId = selected.id
    const theme = selected.id === halloween.id
      ? halloween.appearance
      : (preference === 'auto' ? (media.matches ? 'dark' : 'light') : preference)
    document.documentElement.dataset.theme = theme
    document.documentElement.dataset.themePreference = preference
    document.documentElement.dataset.themeId = activeThemeId
    document.documentElement.style.colorScheme = theme
    const meta = document.querySelector('meta[name="theme-color"]')
    if (meta) meta.content = activeThemeId === halloween.id ? '#160b2b' : (theme === 'dark' ? '#0f1020' : '#7c3aed')
    return preference
  }

  window.mnfTheme = {
    key,
    media,
    getPreference: () => preference,
    getTheme: () => document.documentElement.dataset.theme || 'light',
    getActiveTheme: () => activeThemeId,
    getPreviewDate: () => readPreviewDate() || '',
    isSeasonalActive: () => activeThemeId !== 'original',
    refresh: () => apply(readPreference()),
    setPreference(value) {
      apply(value)
      try { window.localStorage.setItem(key, preference) } catch { /* Sigue disponible durante esta visita. */ }
      window.dispatchEvent(new Event('mnf:appearance-change'))
    },
    setPreviewDate(value) {
      if (!isDevPreviewEnabled()) return
      try {
        if (value && Number.isFinite(Date.parse(value))) window.localStorage.setItem(previewDateKey, value)
        else window.localStorage.removeItem(previewDateKey)
      } catch { /* Previsualización opcional. */ }
      apply(readPreference())
      window.dispatchEvent(new Event('mnf:theme-change'))
    },
    refreshSeasonal() {
      apply(readPreference())
      window.dispatchEvent(new Event('mnf:theme-change'))
      return activeThemeId
    }
  }
  apply(readPreference())
})()
