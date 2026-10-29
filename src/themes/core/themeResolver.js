import { ORIGINAL_THEME_ID, THEME_REGISTRY, getThemeById } from './themeRegistry.js'

function validDate(value) {
  const timestamp = value instanceof Date ? value.getTime() : (typeof value === 'number' ? value : Date.parse(value))
  return Number.isFinite(timestamp) ? timestamp : null
}

export function isThemeActive(theme, now = new Date()) {
  if (!theme?.enabled) return false
  const current = validDate(now)
  if (current === null) return false
  const start = theme.startAt ? validDate(theme.startAt) : -Infinity
  const end = theme.endAt ? validDate(theme.endAt) : Infinity
  return start !== null && current >= start && current < end
}

/**
 * Resolve one active visual theme. Seasonal conflicts are deterministic:
 * highest priority, then latest start date, then lexical id.
 * `overrideId` is intentionally opt-in and must only be passed by a local dev surface.
 */
export function resolveActiveTheme({ now = new Date(), overrideId = null, allowOverride = false, themes = THEME_REGISTRY } = {}) {
  const original = themes.find((theme) => theme.id === ORIGINAL_THEME_ID) || getThemeById(ORIGINAL_THEME_ID)
  if (allowOverride && overrideId) {
    const override = themes.find((theme) => theme.id === overrideId)
    if (override?.enabled) return override
  }
  const candidates = themes
    .filter((theme) => theme.id !== ORIGINAL_THEME_ID && isThemeActive(theme, now))
    .sort((a, b) => (b.priority || 0) - (a.priority || 0) || validDate(b.startAt) - validDate(a.startAt) || a.id.localeCompare(b.id))
  return candidates[0] || original
}

export function resolveThemeState({ now = new Date(), userAppearance = 'auto', systemAppearance = 'light', overrideId = null, allowOverride = false, themes = THEME_REGISTRY } = {}) {
  const activeTheme = resolveActiveTheme({ now, overrideId, allowOverride, themes })
  const seasonal = activeTheme.id !== ORIGINAL_THEME_ID
  const appearance = seasonal && activeTheme.appearance !== 'user' ? activeTheme.appearance : userAppearance
  const resolvedAppearance = appearance === 'auto' ? systemAppearance : appearance
  return { activeTheme, seasonal, appearance, resolvedAppearance }
}
