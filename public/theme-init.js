// Se ejecuta antes de React/CSS para aplicar la apariencia sin destellos.
;(function () {
  const key = 'mnf:appearance'
  const options = ['light', 'dark', 'auto']
  const media = window.matchMedia('(prefers-color-scheme: dark)')
  let preference = 'auto'

  function readPreference() {
    try {
      const saved = window.localStorage.getItem(key)
      return options.includes(saved) ? saved : 'auto'
    } catch {
      return preference
    }
  }

  function apply(value) {
    preference = options.includes(value) ? value : 'auto'
    const theme = preference === 'auto' ? (media.matches ? 'dark' : 'light') : preference
    document.documentElement.dataset.theme = theme
    document.documentElement.dataset.themePreference = preference
    document.documentElement.style.colorScheme = theme
    const meta = document.querySelector('meta[name="theme-color"]')
    if (meta) meta.content = theme === 'dark' ? '#0f1020' : '#7c3aed'
    return preference
  }

  window.mnfTheme = {
    key,
    media,
    getPreference: () => preference,
    getTheme: () => document.documentElement.dataset.theme || 'light',
    refresh: () => apply(readPreference()),
    setPreference(value) {
      apply(value)
      try { window.localStorage.setItem(key, preference) } catch { /* Sigue disponible durante esta visita. */ }
      window.dispatchEvent(new Event('mnf:appearance-change'))
    }
  }
  apply(readPreference())
})()
