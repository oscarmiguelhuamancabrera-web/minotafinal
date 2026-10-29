import { resolveActiveTheme } from './themeResolver.js'

export const THEME_CHANGE_EVENT = 'mnf:theme-change'

export function isLocalDevelopment() {
  if (typeof window === 'undefined') return false
  const host = window.location?.hostname || ''
  const localHost = host === 'localhost' || host === '127.0.0.1' || host === '::1' || /^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[0-1])\.)/.test(host)
  return Boolean(import.meta.env?.DEV && localHost)
}

export function getDevThemeOverride() {
  if (!isLocalDevelopment()) return null
  try {
    const value = window.localStorage.getItem('mnf:theme-preview')
    return value || null
  } catch {
    return null
  }
}

export function resolveThemeForBrowser({ now = new Date(), userAppearance = 'auto', themes } = {}) {
  const overrideId = getDevThemeOverride()
  const activeTheme = resolveActiveTheme({ now, overrideId, allowOverride: isLocalDevelopment(), themes })
  const seasonal = activeTheme.id !== 'original'
  const appearance = seasonal && activeTheme.appearance !== 'user' ? activeTheme.appearance : userAppearance
  const resolvedAppearance = appearance === 'auto'
    ? (typeof window !== 'undefined' && window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light')
    : appearance
  return { activeTheme, seasonal, appearance, resolvedAppearance }
}
