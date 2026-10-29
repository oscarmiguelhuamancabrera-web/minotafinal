const VALID_TYPES = new Set(['base', 'seasonal', 'event', 'custom'])
const VALID_APPEARANCES = new Set(['light', 'dark', 'user'])

export function validateThemeConfig(value) {
  const errors = []
  const theme = value && typeof value === 'object' ? value : {}
  if (!theme.id || typeof theme.id !== 'string' || !/^[a-z0-9][a-z0-9-]*$/.test(theme.id)) errors.push('id must be a kebab-case string')
  if (!theme.name || typeof theme.name !== 'string') errors.push('name is required')
  if (!VALID_TYPES.has(theme.type)) errors.push(`type must be one of ${[...VALID_TYPES].join(', ')}`)
  if (!theme.version || typeof theme.version !== 'string') errors.push('version is required')
  if (typeof theme.enabled !== 'boolean') errors.push('enabled must be boolean')
  if (!VALID_APPEARANCES.has(theme.appearance)) errors.push('appearance must be light, dark, or user')
  if (theme.startAt !== undefined && Number.isNaN(Date.parse(theme.startAt))) errors.push('startAt must be an ISO date')
  if (theme.endAt !== undefined && Number.isNaN(Date.parse(theme.endAt))) errors.push('endAt must be an ISO date')
  if (theme.startAt && theme.endAt && Date.parse(theme.startAt) >= Date.parse(theme.endAt)) errors.push('startAt must precede endAt')
  if (theme.type === 'seasonal' && (!theme.startAt || !theme.endAt)) errors.push('seasonal themes require startAt and endAt')
  if (theme.timeZone !== undefined && typeof theme.timeZone !== 'string') errors.push('timeZone must be a string')
  if (typeof theme.timeZone === 'string') {
    try { new Intl.DateTimeFormat('en-US', { timeZone: theme.timeZone }).format() } catch { errors.push('timeZone must be a valid IANA zone') }
  }
  if (theme.priority !== undefined && (!Number.isFinite(theme.priority) || theme.priority < 0)) errors.push('priority must be a non-negative number')
  if (theme.animations !== undefined && (typeof theme.animations !== 'object' || theme.animations === null || Array.isArray(theme.animations))) errors.push('animations must be an object')
  if (theme.animations?.enabled !== undefined && typeof theme.animations.enabled !== 'boolean') errors.push('animations.enabled must be boolean')
  if (theme.animations?.reducedMotionSupport !== undefined && typeof theme.animations.reducedMotionSupport !== 'boolean') errors.push('animations.reducedMotionSupport must be boolean')
  if (theme.effects !== undefined && (typeof theme.effects !== 'object' || theme.effects === null || Array.isArray(theme.effects))) errors.push('effects must be an object')
  if (theme.effects?.bats !== undefined && (typeof theme.effects.bats !== 'object' || theme.effects.bats === null || Array.isArray(theme.effects.bats))) errors.push('effects.bats must be an object')
  if (theme.effects?.spiderWebs !== undefined && (typeof theme.effects.spiderWebs !== 'object' || theme.effects.spiderWebs === null || Array.isArray(theme.effects.spiderWebs))) errors.push('effects.spiderWebs must be an object')
  if (theme.effects?.accessibility !== undefined && (typeof theme.effects.accessibility !== 'object' || theme.effects.accessibility === null || Array.isArray(theme.effects.accessibility))) errors.push('effects.accessibility must be an object')
  if (theme.effects?.bats?.enabled !== undefined && typeof theme.effects.bats.enabled !== 'boolean') errors.push('effects.bats.enabled must be boolean')
  if (theme.effects?.bats) {
    ['desktopCount', 'tabletCount', 'mobileCount'].forEach((key) => {
      if (theme.effects.bats[key] !== undefined && (!Number.isInteger(theme.effects.bats[key]) || theme.effects.bats[key] < 0)) errors.push(`effects.bats.${key} must be a non-negative integer`)
    })
  }
  if (theme.effects?.spiderWebs?.enabled !== undefined && typeof theme.effects.spiderWebs.enabled !== 'boolean') errors.push('effects.spiderWebs.enabled must be boolean')
  if (theme.effects?.accessibility?.reducedMotion !== undefined && typeof theme.effects.accessibility.reducedMotion !== 'boolean') errors.push('effects.accessibility.reducedMotion must be boolean')
  if (theme.visual !== undefined && (typeof theme.visual !== 'object' || theme.visual === null || Array.isArray(theme.visual))) errors.push('visual must be an object')
  return { valid: errors.length === 0, errors, value: theme }
}

export function validateThemeRegistry(themes = []) {
  const list = Array.isArray(themes) ? themes : []
  const results = list.map(validateThemeConfig)
  const ids = new Set()
  results.forEach((result) => {
    if (result.value.id && ids.has(result.value.id)) result.errors.push('duplicate id')
    if (result.value.id) ids.add(result.value.id)
  })
  const valid = results.filter((result) => result.valid).map((result) => result.value)
  return { valid: valid.length === results.length, themes: valid, errors: results.flatMap((result) => result.errors) }
}
