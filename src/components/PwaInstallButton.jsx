import { useEffect, useState } from 'react'

function isStandalone() {
  return window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true
}

function isIos() {
  return /iphone|ipad|ipod/i.test(window.navigator.userAgent) || (window.navigator.platform === 'MacIntel' && window.navigator.maxTouchPoints > 1)
}

export default function PwaInstallButton() {
  const [promptEvent, setPromptEvent] = useState(null)
  const [installed, setInstalled] = useState(() => isStandalone())
  const [instructions, setInstructions] = useState(false)

  useEffect(() => {
    const onBeforeInstall = (event) => {
      event.preventDefault()
      setPromptEvent(event)
    }
    const onInstalled = () => {
      setInstalled(true)
      setPromptEvent(null)
      setInstructions(false)
    }
    window.addEventListener('beforeinstallprompt', onBeforeInstall)
    window.addEventListener('appinstalled', onInstalled)
    return () => {
      window.removeEventListener('beforeinstallprompt', onBeforeInstall)
      window.removeEventListener('appinstalled', onInstalled)
    }
  }, [])

  if (installed) return null

  async function install() {
    if (!promptEvent) {
      setInstructions((value) => !value)
      return
    }
    const event = promptEvent
    setPromptEvent(null)
    await event.prompt()
    await event.userChoice
  }

  return (
    <div className="pwa-install-wrap">
      <button type="button" className="btn secondary pwa-install-button" onClick={install}>📲 Instalar aplicación</button>
      {instructions && (
        <div className="pwa-install-help" role="status">
          <button type="button" className="pwa-install-close" aria-label="Cerrar instrucciones" onClick={() => setInstructions(false)}>×</button>
          {isIos() ? (
            <p><b>Instalar en iPhone o iPad</b><br />Abre Mi Nota Final en Safari, toca <b>Compartir</b>, elige <b>Agregar a Inicio</b> y confirma.</p>
          ) : (
            <p><b>Instalar aplicación</b><br />Usa el menú del navegador y selecciona <b>Instalar aplicación</b> o <b>Agregar a pantalla de inicio</b>.</p>
          )}
        </div>
      )}
    </div>
  )
}
