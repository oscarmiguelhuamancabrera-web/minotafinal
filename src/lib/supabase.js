import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY

const REMEMBER_SESSION_KEY = 'mnf:remember-session'

function rememberSession() {
  if (typeof window === 'undefined') return true
  return window.localStorage.getItem(REMEMBER_SESSION_KEY) !== 'false'
}

// Supabase Auth admite un adaptador de almacenamiento. Elegimos localStorage
// o sessionStorage según la preferencia del formulario de acceso, sin guardar
// contraseñas ni duplicar tokens.
const sessionStorageAdapter = {
  getItem(key) {
    if (typeof window === 'undefined') return null
    const storage = rememberSession() ? window.localStorage : window.sessionStorage
    return storage.getItem(key)
  },
  setItem(key, value) {
    if (typeof window === 'undefined') return
    const target = rememberSession() ? window.localStorage : window.sessionStorage
    const other = rememberSession() ? window.sessionStorage : window.localStorage
    other.removeItem(key)
    target.setItem(key, value)
  },
  removeItem(key) {
    if (typeof window === 'undefined') return
    window.localStorage.removeItem(key)
    window.sessionStorage.removeItem(key)
  }
}

if (!supabaseUrl || !supabaseKey) {
  console.warn('Faltan variables de entorno de Supabase. Revisa .env.local')
}

export const supabase = createClient(supabaseUrl || '', supabaseKey || '', {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    storage: sessionStorageAdapter
  }
})

export { REMEMBER_SESSION_KEY }
