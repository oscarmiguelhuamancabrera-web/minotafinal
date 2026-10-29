import test from 'node:test'
import assert from 'node:assert/strict'
import fs from 'node:fs'
import vm from 'node:vm'
import postcss from 'postcss'
import { getPeruDayBounds, isWithinPeruPeriod, todayISO, formatPeruHour } from '../src/utils/timezone.js'
import { isThemeActive } from '../src/themes/core/themeResolver.js'

const bootSource = fs.readFileSync(new URL('../public/theme-init.js', import.meta.url), 'utf8')

function browser({ saved = null, dark = false, blocked = false } = {}) {
  const values = new Map(saved === null ? [] : [['mnf:appearance', saved]])
  const media = { matches: dark }
  const root = { dataset: {}, style: {} }
  const meta = { content: '#7c3aed' }
  const events = []
  const window = {
    matchMedia: () => media,
    localStorage: {
      getItem: key => { if (blocked) throw Error('blocked'); return values.get(key) ?? null },
      setItem: (key, value) => { if (blocked) throw Error('blocked'); values.set(key, value) }
    },
    dispatchEvent: event => events.push(event.type)
  }
  vm.runInNewContext(bootSource, { window, document: { documentElement: root, querySelector: () => meta }, Event: class { constructor(type) { this.type = type } } })
  return { window, root, media, meta, events, values, theme: window.mnfTheme }
}

test('Automático aplica la apariencia del sistema antes de React', () => {
  for (const dark of [true, false]) {
    const { root, meta } = browser({ dark })
    assert.equal(root.dataset.theme, dark ? 'dark' : 'light')
    assert.equal(root.dataset.themePreference, 'auto')
    assert.equal(root.style.colorScheme, root.dataset.theme)
    assert.equal(meta.content, dark ? '#0f1020' : '#7c3aed')
  }
})

test('una elección explícita prevalece sobre el sistema y se recupera al reabrir', () => {
  for (const preference of ['light', 'dark']) {
    const first = browser({ dark: preference === 'light' })
    first.theme.setPreference(preference)
    const saved = first.values.get('mnf:appearance')
    assert.equal(saved, preference)
    assert.equal(browser({ saved, dark: preference === 'light' }).root.dataset.theme, preference)
    assert.deepEqual(first.events, ['mnf:appearance-change'])
  }
})

test('Automático responde a cambios posteriores del sistema sin cambiar la preferencia', () => {
  const { theme, media, root } = browser()
  media.matches = true
  theme.refresh()
  assert.equal(root.dataset.theme, 'dark')
  assert.equal(theme.getPreference(), 'auto')
  media.matches = false
  theme.refresh()
  assert.equal(root.dataset.theme, 'light')
})

test('una preferencia inválida y almacenamiento bloqueado no impiden el acceso', () => {
  assert.equal(browser({ saved: 'invalid', dark: true }).root.dataset.theme, 'dark')
  const { theme, root } = browser({ blocked: true })
  theme.setPreference('dark')
  theme.refresh()
  assert.equal(root.dataset.theme, 'dark')
})

const styles = postcss.parse(fs.readFileSync(new URL('../src/styles.css', import.meta.url), 'utf8'))
const themes = postcss.parse(fs.readFileSync(new URL('../src/themes.css', import.meta.url), 'utf8'))
const darkTokens = {}
styles.walkRules(':root', rule => rule.walkDecls(decl => { darkTokens[decl.prop] = decl.value }))
themes.walkRules(':root[data-theme="dark"]', rule => rule.walkDecls(decl => { darkTokens[decl.prop] = decl.value }))

function luminance(hex) {
  const rgb = hex.slice(1).match(/../g).map(value => parseInt(value, 16) / 255)
  const linear = rgb.map(value => value <= .04045 ? value / 12.92 : ((value + .055) / 1.055) ** 2.4)
  return linear[0] * .2126 + linear[1] * .7152 + linear[2] * .0722
}
function contrast(a, b) {
  const x = luminance(a), y = luminance(b)
  return (Math.max(x, y) + .05) / (Math.min(x, y) + .05)
}

test('la paleta oscura cumple AA en texto y estados, y contraste de controles', () => {
  for (const background of ['--bg', '--surface', '--surface-subtle', '--surface-accent', '--control-bg']) {
    for (const text of ['--ink', '--muted', '--purple', '--purple-dark']) {
      assert.ok(contrast(darkTokens[text], darkTokens[background]) >= 4.5, `${text} sobre ${background}`)
    }
  }
  for (const state of ['success', 'warning', 'error', 'info']) {
    assert.ok(contrast(darkTokens[`--${state}-text`], darkTokens[`--${state}-bg`]) >= 4.5, state)
  }
  for (const brand of ['--brand-start', '--brand-end', '--modal-header']) {
    assert.ok(contrast(darkTokens['--on-brand'], darkTokens[brand]) >= 4.5, brand)
  }
  assert.ok(contrast(darkTokens['--control-border'], darkTokens['--control-bg']) >= 3)
})

test('las superficies de los componentes usan tokens, excepto las marcas de proveedores', () => {
  styles.walkDecls(decl => {
    if (!decl.prop.startsWith('background') || /google-icon|microsoft-icon/.test(decl.parent.selector || '')) return
    // Un color claro fijo solo se permite como fallback de un token semántico.
    const raw = decl.value.replace(/var\(.+/g, '')
    assert.doesNotMatch(raw, /white|#fff\b|#faf7ff|#fbf8ff/i, `${decl.parent.selector}: ${decl.value}`)
  })
})

test('el arranque del tema precede a React y el script se incluye en la PWA', () => {
  const html = fs.readFileSync(new URL('../index.html', import.meta.url), 'utf8')
  assert.ok(html.indexOf('/theme-init.js') < html.indexOf('/src/main.jsx'))
  const config = fs.readFileSync(new URL('../vite.config.js', import.meta.url), 'utf8')
  assert.match(config, /includeAssets:.*theme-init\.js/)
})

test('el botón flotante es global y los logotipos OAuth son recursos SVG locales', () => {
  const provider = fs.readFileSync(new URL('../src/components/ThemeProvider.jsx', import.meta.url), 'utf8')
  const app = fs.readFileSync(new URL('../src/App.jsx', import.meta.url), 'utf8')
  const config = fs.readFileSync(new URL('../vite.config.js', import.meta.url), 'utf8')
  assert.match(provider, /<ThemeFloatingButton \/>/)
  assert.doesNotMatch(app, /ThemeSelector/)
  assert.match(app, /src="\/google-g\.svg"/)
  assert.match(app, /src="\/microsoft\.svg"/)
  assert.match(config, /google-g\.svg.*microsoft\.svg/)
  assert.match(fs.readFileSync(new URL('../public/google-g.svg', import.meta.url), 'utf8'), /#4285F4/)
  assert.match(fs.readFileSync(new URL('../public/microsoft.svg', import.meta.url), 'utf8'), /#F25022/)
})

test('el modal del flyer usa un área de imagen amplia con scroll interno', () => {
  const app = fs.readFileSync(new URL('../src/App.jsx', import.meta.url), 'utf8')
  const css = fs.readFileSync(new URL('../src/styles.css', import.meta.url), 'utf8')
  assert.match(app, /floating-announcement-image-scroll/)
  assert.match(css, /\.floating-announcement-image-scroll[\s\S]*overflow-y: auto/)
  assert.match(css, /\.floating-announcement-image[\s\S]*width: 100%[\s\S]*height: auto/)
  assert.match(css, /\.floating-announcement\.image-mode[\s\S]*width: min\(94vw, 760px\)/)
  assert.match(css, /\.floating-announcement-header[\s\S]*flex: 0 0 auto/)
})

test('la PWA usa un identificador de build y verifica version.json sin caché', () => {
  const config = fs.readFileSync(new URL('../vite.config.js', import.meta.url), 'utf8')
  const updater = fs.readFileSync(new URL('../src/pwaUpdates.js', import.meta.url), 'utf8')
  const vercel = fs.readFileSync(new URL('../vercel.json', import.meta.url), 'utf8')
  assert.match(config, /VERCEL_GIT_COMMIT_SHA/)
  assert.match(config, /fileName: 'version\.json'/)
  assert.match(config, /globIgnores: \['version\.json'\]/)
  assert.match(config, /NetworkOnly/)
  assert.match(updater, /fetch\(`\/version\.json\?check=\$\{Date\.now\(\)\}`,[\s\S]*cache: 'no-store'/)
  assert.match(updater, /UPDATE_INTERVAL_MS = 15 \* 60 \* 1000/)
  assert.match(updater, /mnf:last-update-attempt/)
  assert.match(vercel, /"\/version\.json"/)
  assert.match(vercel, /"\/index\.html"/)
})

test('las estadísticas respetan el cambio de día de America/Lima', () => {
  const beforeUtc = new Date('2026-10-12T23:59:00Z') // 18:59 en Lima
  const afterUtc = new Date('2026-10-13T00:00:00Z') // 19:00 en Lima
  const midnightUtc = new Date('2026-10-13T05:00:00Z') // 00:00 del día siguiente en Lima
  assert.equal(todayISO(beforeUtc), '2026-10-12')
  assert.equal(todayISO(afterUtc), '2026-10-12')
  assert.equal(todayISO(midnightUtc), '2026-10-13')
  assert.equal(formatPeruHour(afterUtc), '19:00')
  const bounds = getPeruDayBounds(beforeUtc)
  assert.equal(bounds.start.toISOString(), '2026-10-12T05:00:00.000Z')
  assert.equal(bounds.end.toISOString(), '2026-10-13T05:00:00.000Z')
  assert.equal(isWithinPeruPeriod(new Date('2026-10-13T00:30:00Z'), 'today', beforeUtc), true)
  assert.equal(isWithinPeruPeriod(new Date('2026-10-13T05:00:00Z'), 'today', beforeUtc), false)
})

test('el build de producción no expone acceso demo o invitado', () => {
  const app = fs.readFileSync(new URL('../src/App.jsx', import.meta.url), 'utf8')
  assert.doesNotMatch(app, /Continuar como invitado/)
  assert.doesNotMatch(app, /onGuest/)
  assert.doesNotMatch(app, /enterGuestMode/)
})

test('Halloween 2026 se activa en Lima durante su ventana y vuelve a Original al vencer', () => {
  const config = JSON.parse(fs.readFileSync(new URL('../src/themes/halloween-2026/theme.json', import.meta.url), 'utf8'))
  assert.equal(config.timeZone, 'America/Lima')
  assert.equal(isThemeActive(config, new Date('2026-10-29T12:00:00-05:00')), true)
  assert.equal(isThemeActive(config, new Date('2026-11-01T00:00:00-05:00')), false)
  assert.match(fs.readFileSync(new URL('../public/theme-init.js', import.meta.url), 'utf8'), /dataset\.themeId/)
})
