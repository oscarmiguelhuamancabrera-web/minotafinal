import { registerSW } from 'virtual:pwa-register'

const UPDATE_INTERVAL_MS = 15 * 60 * 1000
const UPDATE_ATTEMPT_KEY = 'mnf:last-update-attempt'

function canUpdateSafely() {
  return typeof window.mnfUpdateGuard !== 'function' ? Promise.resolve(true) : Promise.resolve(window.mnfUpdateGuard())
}

function readBuildId(payload) {
  return payload && typeof payload.buildId === 'string' ? payload.buildId : ''
}

export function initPwaUpdates({ onUpdateStart, onUpdateDeferred } = {}) {
  let disposed = false
  let registration = null
  let updateSW = null
  let checking = false
  let updateInFlight = false

  const rememberAttempt = (buildId) => {
    try { window.sessionStorage.setItem(UPDATE_ATTEMPT_KEY, buildId) } catch { /* La protección es opcional. */ }
  }

  const attemptedFor = (buildId) => {
    try { return window.sessionStorage.getItem(UPDATE_ATTEMPT_KEY) === buildId } catch { return false }
  }

  const applyUpdate = async (buildId = 'service-worker') => {
    if (disposed || updateInFlight || attemptedFor(buildId)) return false
    const safe = await canUpdateSafely()
    if (!safe) {
      onUpdateDeferred?.()
      return false
    }
    updateInFlight = true
    rememberAttempt(buildId)
    onUpdateStart?.()
    try {
      if (updateSW) {
        await updateSW(true)
        // Si la comprobación provino de version.json y aún no había un SW
        // esperando, fuerza la recarga después de solicitar su actualización.
        if (buildId !== 'service-worker' && registration?.update) {
          await registration.update()
          window.location.reload()
        }
      } else if (registration?.update) {
        await registration.update()
        window.location.reload()
      } else {
        window.location.reload()
      }
    } catch (error) {
      updateInFlight = false
      console.warn('No se pudo aplicar la actualización:', error)
      onUpdateDeferred?.()
      return false
    }
    return true
  }

  const checkPublishedVersion = async () => {
    if (disposed || checking || typeof __MN_BUILD_ID__ !== 'string' || __MN_BUILD_ID__.startsWith('local-')) return
    checking = true
    try {
      const response = await fetch(`/version.json?check=${Date.now()}`, { cache: 'no-store', credentials: 'same-origin' })
      if (response.ok) {
        const publishedBuildId = readBuildId(await response.json())
        if (publishedBuildId && publishedBuildId !== __MN_BUILD_ID__) await applyUpdate(publishedBuildId)
      }
      if (registration?.update) await registration.update()
    } catch (error) {
      console.warn('No se pudo verificar la versión publicada:', error)
    } finally {
      checking = false
    }
  }

  updateSW = registerSW({
    immediate: true,
    onNeedRefresh: () => applyUpdate('service-worker'),
    onRegisteredSW: (_swUrl, nextRegistration) => {
      registration = nextRegistration
      checkPublishedVersion()
    },
    onRegisterError: (error) => console.warn('No se pudo registrar el Service Worker:', error)
  })

  const onFocus = () => checkPublishedVersion()
  const onOnline = () => checkPublishedVersion()
  const onVisibility = () => { if (document.visibilityState === 'visible') checkPublishedVersion() }
  const interval = window.setInterval(checkPublishedVersion, UPDATE_INTERVAL_MS)
  window.addEventListener('focus', onFocus)
  window.addEventListener('online', onOnline)
  document.addEventListener('visibilitychange', onVisibility)
  checkPublishedVersion()

  return () => {
    disposed = true
    window.clearInterval(interval)
    window.removeEventListener('focus', onFocus)
    window.removeEventListener('online', onOnline)
    document.removeEventListener('visibilitychange', onVisibility)
  }
}
