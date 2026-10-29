import original from '../original/theme.json' with { type: 'json' }
import halloween2026 from '../halloween-2026/theme.json' with { type: 'json' }
import { validateThemeRegistry } from './themeValidator.js'

const FALLBACK_ORIGINAL = {
  id: 'original',
  name: 'Mi Nota Final',
  type: 'base',
  version: '1.0.0',
  enabled: true,
  appearance: 'user',
  preserveUserPreference: true,
  restoreOriginalTheme: true,
  animations: { enabled: true, reducedMotionSupport: true }
}

const checked = validateThemeRegistry([original, halloween2026])
const validThemes = checked.themes.some((theme) => theme.id === 'original')
  ? checked.themes
  : [FALLBACK_ORIGINAL, ...checked.themes.filter((theme) => theme.id !== 'original')]

export const THEME_REGISTRY = Object.freeze(validThemes)
export const THEME_REGISTRY_ERRORS = Object.freeze(checked.errors)
export const ORIGINAL_THEME_ID = 'original'

export function getThemeById(id) {
  return THEME_REGISTRY.find((theme) => theme.id === id) || null
}
