import { useEffect, useState } from 'react'

export default function ConnectionStatus() {
  const [online, setOnline] = useState(() => navigator.onLine)
  const [reconnecting, setReconnecting] = useState(false)

  useEffect(() => {
    const onOffline = () => { setOnline(false); setReconnecting(false) }
    const onOnline = () => {
      setReconnecting(true)
      window.setTimeout(() => { setOnline(true); setReconnecting(false) }, 700)
    }
    window.addEventListener('offline', onOffline)
    window.addEventListener('online', onOnline)
    return () => {
      window.removeEventListener('offline', onOffline)
      window.removeEventListener('online', onOnline)
    }
  }, [])

  if (online && !reconnecting) return null
  return <div className={`connection-status ${online ? 'reconnecting' : 'offline'}`} role="status">{online ? 'Reconectando…' : 'Sin conexión. Puedes continuar con los datos disponibles.'}</div>
}
