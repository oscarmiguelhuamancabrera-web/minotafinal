import { useEffect, useMemo, useRef, useState } from 'react'
import { supabase } from './lib/supabase'
import {
  DEFAULT_SETTINGS,
  EVALUATIONS,
  calculateGradeResult,
  emptyGrades,
  formatNumber,
  formatPercent,
  generateMissingGrades,
  normalizeGradesForDb,
  toNumber,
  validateSettings
} from './utils/grades'

const ADMIN_EMAIL = 'oscar.miguel.huaman.cabrera@gmail.com'
const APP_VERSION = '1.0.0'

const emptyAuth = {
  firstName: '',
  lastName: '',
  email: '',
  password: '',
  confirmPassword: '',
  careerId: '',
  cycleId: ''
}

function todayISO() {
  return new Date().toISOString().slice(0, 10)
}

function timeOnly(value) {
  if (!value) return '—'
  return new Date(value).toLocaleTimeString('es-PE', { hour: '2-digit', minute: '2-digit' })
}

function dateOnly(value) {
  if (!value) return '—'
  return new Date(value).toLocaleDateString('es-PE')
}

function firstWord(value) {
  return String(value || '').trim().split(/\s+/)[0] || 'Estudiante'
}

function fullName(profile) {
  const first = profile?.first_name || profile?.firstName || ''
  const last = profile?.last_name || profile?.lastName || ''
  const full = `${first} ${last}`.trim()
  return full || profile?.full_name || profile?.email || 'Sin nombre'
}

function buildProfileFromAuthUser(user) {
  const metadata = user?.user_metadata || {}
  const rawName = metadata.full_name || metadata.name || metadata.display_name || ''
  const first = metadata.first_name || firstWord(rawName || user?.email?.split('@')[0])
  const last = metadata.last_name || (rawName ? rawName.replace(/^\S+\s*/, '') : '')
  const email = user?.email || ''
  return {
    id: user?.id,
    email,
    first_name: first || '',
    last_name: last || '',
    full_name: `${first || ''} ${last || ''}`.trim(),
    role: email.toLowerCase() === ADMIN_EMAIL.toLowerCase() ? 'admin' : 'student',
    status: 'active',
    career_id: null,
    current_cycle_id: null,
    has_seen_tutorial: false
  }
}

function isProfileIncomplete(userProfile) {
  return !userProfile?.first_name || !userProfile?.last_name || !userProfile?.career_id || !userProfile?.current_cycle_id
}

function getErrorMessage(error) {
  const message = error?.message || ''
  const lower = message.toLowerCase()
  if (lower.includes('email not confirmed') || lower.includes('not confirmed') || lower.includes('confirm')) {
    return 'Tu cuenta aún no está confirmada. Revisa tu correo electrónico para confirmar tu cuenta. También revisa spam o correo no deseado.'
  }
  if (lower.includes('invalid login credentials') || lower.includes('invalid credentials')) {
    return 'No se pudo iniciar sesión. El correo no está registrado o la contraseña es incorrecta.'
  }
  if (lower.includes('user already registered') || lower.includes('already registered')) {
    return 'Este correo ya se encuentra registrado. Inicia sesión o recupera tu contraseña.'
  }
  if (lower.includes('email rate limit exceeded') || lower.includes('rate limit')) {
    return 'Se alcanzó el límite de envío de correos. Intenta nuevamente más tarde o comunícate con el administrador.'
  }
  return message ? `Ocurrió un error: ${message}` : 'Ocurrió un error inesperado.'
}

function App() {
  const [session, setSession] = useState(null)
  const [profile, setProfile] = useState(null)
  const [careers, setCareers] = useState([])
  const [cycles, setCycles] = useState([])
  const [settings, setSettings] = useState(DEFAULT_SETTINGS)
  const [courses, setCourses] = useState([])
  const [selectedCourseId, setSelectedCourseId] = useState('')
  const [grades, setGrades] = useState(emptyGrades())
  const [result, setResult] = useState(null)
  const [history, setHistory] = useState([])
  const [adminData, setAdminData] = useState(null)
  const [screen, setScreen] = useState('welcome')
  const [guestMode, setGuestMode] = useState(false)
  const [notice, setNotice] = useState(null)
  const [loading, setLoading] = useState(true)
  const recordedLoginRef = useRef('')

  const isAdmin = profile?.role === 'admin'
  const activeCourse = courses.find((course) => course.id === selectedCourseId) || null
  const greetingName = firstWord(profile?.first_name || profile?.full_name)

  useEffect(() => {
    initialize()
    const { data: listener } = supabase.auth.onAuthStateChange(async (_event, newSession) => {
      setSession(newSession)
      setGuestMode(false)
      if (newSession?.user) {
        await loadProfileAndData(newSession.user)
      } else {
        setProfile(null)
        setCourses([])
        setHistory([])
        setSelectedCourseId('')
        if (!guestMode) setScreen('welcome')
      }
    })
    return () => listener?.subscription?.unsubscribe()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  async function initialize() {
    setLoading(true)
    await Promise.all([loadCareers(), loadCycles()])
    const { data } = await supabase.auth.getSession()
    setSession(data.session)
    if (data.session?.user) {
      await loadProfileAndData(data.session.user)
    }
    setLoading(false)
  }

  function notify(type, message) {
    setNotice({ type, message })
    window.setTimeout(() => setNotice(null), 5500)
  }

  async function loadCareers() {
    const { data, error } = await supabase.from('careers').select('*').eq('status', 'active').order('name')
    if (!error) setCareers(data || [])
  }

  async function loadCycles() {
    const { data, error } = await supabase.from('cycles').select('*').eq('status', 'active').order('order_number')
    if (!error) setCycles(data || [])
  }

  async function loadProfileAndData(user) {
    const { data: userProfile, error } = await supabase
      .from('profiles')
      .select('*, career:careers(id,name), cycle:cycles(id,name,order_number)')
      .eq('id', user.id)
      .single()

    if (error || !userProfile) {
      const provisionalProfile = buildProfileFromAuthUser(user)
      setProfile(provisionalProfile)
      setCourses([])
      setHistory([])
      setScreen('complete-profile')
      return
    }

    if (userProfile.status === 'inactive') {
      notify('error', 'Tu usuario se encuentra inactivo. Comunícate con el administrador.')
      await supabase.auth.signOut()
      return
    }

    setProfile(userProfile)

    if (isProfileIncomplete(userProfile)) {
      await loadSettings(user.id)
      setScreen('complete-profile')
      return
    }

    await Promise.all([loadSettings(user.id), loadCourses(userProfile), loadHistory(user.id)])

    const key = `${user.id}-${todayISO()}`
    if (recordedLoginRef.current !== key) {
      recordedLoginRef.current = key
      recordLoginActivity(userProfile)
    }

    if (userProfile.role !== 'admin' && userProfile.has_seen_tutorial === false) {
      setScreen('tutorial')
      return
    }

    setScreen(userProfile.role === 'admin' ? 'admin-dashboard' : 'dashboard')
  }

  async function recordLoginActivity(userProfile) {
    await supabase.from('login_activity').insert({
      user_id: userProfile.id,
      role: userProfile.role,
      career_id: userProfile.career_id,
      cycle_id: userProfile.current_cycle_id,
      user_agent: navigator.userAgent
    })
  }

  async function loadSettings(userId = session?.user?.id) {
    if (!userId) return
    const { data, error } = await supabase.from('user_settings').select('*').eq('user_id', userId).single()
    if (!error && data) setSettings(data)
  }

  async function loadCourses(userProfile = profile) {
    if (!userProfile?.career_id || !userProfile?.current_cycle_id) {
      setCourses([])
      return
    }
    const { data, error } = await supabase
      .from('courses')
      .select('*, career:careers(name), cycle:cycles(name), creator:profiles!courses_created_by_fkey(first_name,last_name,email)')
      .eq('career_id', userProfile.career_id)
      .eq('cycle_id', userProfile.current_cycle_id)
      .eq('status', 'active')
      .order('name')
    if (!error) setCourses(data || [])
  }

  async function loadHistory(userId = session?.user?.id) {
    if (!userId) return
    const { data, error } = await supabase
      .from('calculation_history')
      .select('*, course:courses!inner(name,status)')
      .eq('user_id', userId)
      .eq('course.status', 'active')
      .order('created_at', { ascending: false })
      .limit(50)
    if (!error) setHistory(data || [])
  }

  async function loadCourseGrades(courseId) {
    setSelectedCourseId(courseId)
    setResult(null)
    if (!session?.user || !courseId) {
      setGrades(emptyGrades())
      return
    }
    const { data, error } = await supabase
      .from('course_grades')
      .select('*')
      .eq('course_id', courseId)
      .eq('user_id', session.user.id)
      .maybeSingle()
    if (!error && data) {
      setGrades({
        pc1: data.pc1 ?? '',
        pc2: data.pc2 ?? '',
        pc3: data.pc3 ?? '',
        pc4: data.pc4 ?? '',
        partial_exam: data.partial_exam ?? '',
        final_exam: data.final_exam ?? ''
      })
    } else {
      setGrades(emptyGrades())
    }
  }

  async function handleRegister(form) {
    if (!form.firstName.trim() || !form.lastName.trim() || !form.email.trim() || !form.password || !form.careerId || !form.cycleId) {
      notify('error', 'Completa nombres, apellidos, correo, carrera, ciclo y contraseña.')
      return
    }
    if (form.password.length < 6) {
      notify('error', 'La contraseña debe tener como mínimo 6 caracteres.')
      return
    }
    if (form.password !== form.confirmPassword) {
      notify('error', 'Las contraseñas no coinciden.')
      return
    }

    const { error } = await supabase.auth.signUp({
      email: form.email.trim(),
      password: form.password,
      options: {
        data: {
          first_name: form.firstName.trim(),
          last_name: form.lastName.trim(),
          full_name: `${form.firstName.trim()} ${form.lastName.trim()}`,
          career_id: form.careerId,
          current_cycle_id: form.cycleId
        }
      }
    })

    if (error) {
      notify('error', getErrorMessage(error))
      return
    }

    notify('success', 'Cuenta creada correctamente. Revisa tu correo electrónico para confirmar tu cuenta antes de iniciar sesión. También revisa spam o correo no deseado.')
    setScreen('login')
  }

  async function handleLogin(email, password) {
    if (!email.trim() || !password) {
      notify('error', 'Ingresa tu correo y contraseña para iniciar sesión.')
      return
    }
    const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password })
    if (error) {
      notify('error', getErrorMessage(error))
      return
    }
  }

  async function handleGoogleLogin() {
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: window.location.origin }
    })
    if (error) notify('error', getErrorMessage(error))
  }

  function handleMicrosoftLogin() {
    notify('info', 'Disponible próximamente.')
  }

  async function handleFinishTutorial() {
    if (!session?.user) return
    const { error } = await supabase
      .from('profiles')
      .update({ has_seen_tutorial: true, updated_at: new Date().toISOString() })
      .eq('id', session.user.id)
    if (error) {
      notify('error', getErrorMessage(error))
      return
    }
    setProfile((prev) => prev ? { ...prev, has_seen_tutorial: true } : prev)
    setScreen('calculator')
  }

  async function handlePasswordReset(email) {
    if (!email.trim()) {
      notify('error', 'Ingresa tu correo para recuperar la contraseña.')
      return
    }
    const { error } = await supabase.auth.resetPasswordForEmail(email.trim(), { redirectTo: window.location.origin })
    if (error) notify('error', getErrorMessage(error))
    else notify('success', 'Te enviamos un enlace para recuperar tu contraseña. Revisa tu correo.')
  }

  function enterGuestMode() {
    setGuestMode(true)
    setProfile(null)
    setSettings(loadGuestSettings())
    setCourses([])
    setGrades(emptyGrades())
    setResult(null)
    setScreen('guest-calculator')
  }

  function handleCalculate() {
    const calculation = calculateGradeResult(grades, settings)
    if (calculation.error) {
      notify('error', calculation.error)
      return
    }
    setResult(calculation.result)
  }

  function handleGenerate() {
    const generated = generateMissingGrades(grades, settings)
    if (generated.error) {
      notify('error', generated.error)
      return
    }
    setGrades(generated.grades)
    setResult(generated.result)
  }

  function handleClean() {
    setGrades(emptyGrades())
    setResult(null)
  }

  async function handleSaveResult() {
    if (!session?.user) {
      notify('error', 'Inicia sesión para guardar resultados.')
      return
    }
    if (!selectedCourseId) {
      notify('error', 'Selecciona un curso para guardar el resultado.')
      return
    }
    const calculation = result ? { error: null, result } : calculateGradeResult(grades, settings)
    if (calculation.error) {
      notify('error', calculation.error)
      return
    }
    const normalized = normalizeGradesForDb(grades)
    const upsertPayload = {
      user_id: session.user.id,
      course_id: selectedCourseId,
      ...normalized
    }
    const { error: gradeError } = await supabase.from('course_grades').upsert(upsertPayload, { onConflict: 'user_id,course_id' })
    if (gradeError) {
      notify('error', getErrorMessage(gradeError))
      return
    }
    const savePayload = {
      user_id: session.user.id,
      course_id: selectedCourseId,
      ...normalized,
      current_average: calculation.result.current_average,
      evaluated_weight: calculation.result.evaluated_weight,
      pending_weight: calculation.result.pending_weight,
      pending_evaluations: calculation.result.pending_evaluations,
      required_average: calculation.result.required_average,
      status: calculation.result.status
    }
    const { error } = await supabase.from('calculation_history').insert(savePayload)
    if (error) notify('error', getErrorMessage(error))
    else {
      notify('success', 'Resultado guardado correctamente.')
      await loadHistory()
    }
  }

  async function handleSaveSettings(newSettings, guest = false) {
    const error = validateSettings(newSettings)
    if (error) {
      notify('error', error)
      return
    }
    if (guest) {
      localStorage.setItem('mnf_guest_settings', JSON.stringify(newSettings))
      setSettings(newSettings)
      notify('success', 'Ajustes guardados en este navegador.')
      return
    }
    const { error: updateError } = await supabase.from('user_settings').upsert({
      user_id: session.user.id,
      ...newSettings
    }, { onConflict: 'user_id' })
    if (updateError) notify('error', getErrorMessage(updateError))
    else {
      setSettings(newSettings)
      notify('success', 'Ajustes guardados correctamente.')
    }
  }

  async function handleCreateCourse(name, options = {}) {
    if (!name.trim()) {
      notify('error', 'Ingresa el nombre del curso.')
      return null
    }
    if (!profile?.career_id || !profile?.current_cycle_id) {
      notify('error', 'Completa tu carrera y ciclo antes de crear cursos.')
      return null
    }
    const { data, error } = await supabase.from('courses').insert({
      name: name.trim(),
      career_id: profile.career_id,
      cycle_id: profile.current_cycle_id,
      created_by: profile.id
    }).select('*, career:careers(name), cycle:cycles(name), creator:profiles!courses_created_by_fkey(first_name,last_name,email)').single()
    if (error) {
      notify('error', 'No se pudo crear el curso. Puede que ya exista para tu carrera y ciclo.')
      return null
    }
    notify('success', 'Curso creado y disponible para tu carrera y ciclo.')
    await loadCourses()
    if (options.select && data?.id) {
      await loadCourseGrades(data.id)
    }
    return data
  }

  async function handleUpdateProfile(values) {
    if (!session?.user) return
    if (!values.firstName?.trim() || !values.lastName?.trim() || !values.careerId || !values.cycleId) {
      notify('error', 'Completa nombres, apellidos, carrera y ciclo.')
      return
    }
    const email = session.user.email || profile?.email || ''
    const payload = {
      id: session.user.id,
      email,
      first_name: values.firstName.trim(),
      last_name: values.lastName.trim(),
      full_name: `${values.firstName.trim()} ${values.lastName.trim()}`.trim(),
      career_id: values.careerId,
      current_cycle_id: values.cycleId,
      role: profile?.role || (email.toLowerCase() === ADMIN_EMAIL.toLowerCase() ? 'admin' : 'student'),
      status: profile?.status || 'active'
    }
    const { error } = await supabase.from('profiles').upsert(payload, { onConflict: 'id' })
    if (error) notify('error', getErrorMessage(error))
    else {
      notify('success', 'Perfil actualizado correctamente.')
      await loadProfileAndData(session.user)
    }
  }

  async function loadAdminData() {
    const [profilesRes, coursesRes, calculationsRes, loginsRes] = await Promise.all([
      supabase.from('profiles').select('*, career:careers(name), cycle:cycles(name,order_number)').order('created_at', { ascending: false }),
      supabase.from('courses').select('*, career:careers(name), cycle:cycles(name,order_number), creator:profiles!courses_created_by_fkey(first_name,last_name,email)').order('created_at', { ascending: false }),
      supabase.from('calculation_history').select('*, profile:profiles(first_name,last_name,email,career_id,current_cycle_id), course:courses(name, career:careers(name), cycle:cycles(name))').order('created_at', { ascending: false }).limit(200),
      supabase.from('login_activity').select('*, profile:profiles(first_name,last_name,email), career:careers(name), cycle:cycles(name)').order('login_at', { ascending: false }).limit(300)
    ])

    setAdminData({
      users: profilesRes.data || [],
      courses: coursesRes.data || [],
      calculations: calculationsRes.data || [],
      logins: loginsRes.data || []
    })
  }

  async function toggleUserStatus(user) {
    const nextStatus = user.status === 'active' ? 'inactive' : 'active'
    const { error } = await supabase.from('profiles').update({ status: nextStatus }).eq('id', user.id)
    if (error) notify('error', getErrorMessage(error))
    else {
      notify('success', `Usuario ${nextStatus === 'active' ? 'reactivado' : 'dado de baja'}.`)
      await loadAdminData()
    }
  }

  async function changeUserRole(user, role) {
    const { error } = await supabase.from('profiles').update({ role }).eq('id', user.id)
    if (error) notify('error', getErrorMessage(error))
    else {
      notify('success', 'Rol actualizado correctamente.')
      await loadAdminData()
    }
  }

  async function updateCourseAdmin(courseId, payload) {
    const { error } = await supabase.from('courses').update(payload).eq('id', courseId)
    if (error) notify('error', getErrorMessage(error))
    else {
      notify('success', 'Curso actualizado correctamente.')
      await loadAdminData()
      await loadCourses()
    }
  }

  const navItems = useMemo(() => {
    if (guestMode) return [
      ['guest-calculator', '🧮', 'Calcular'],
      ['guest-settings', '⚙️', 'Ajustes'],
      ['about', 'ℹ️', 'Acerca']
    ]
    if (!session) return []
    const base = [
      ['dashboard', '🏠', 'Inicio'],
      ['courses', '📚', 'Cursos'],
      ['calculator', '🧮', 'Calcular'],
      ['history', '📊', 'Historial'],
      ['more', '☰', 'Más']
    ]
    return base
  }, [session, guestMode])

  if (loading) return <Splash />

  return (
    <div className="app-shell">
      {notice && <div className={`toast ${notice.type}`}>{notice.message}</div>}
      <main className="app-container">
        {!session && !guestMode && screen === 'welcome' && (
          <Welcome onLogin={() => setScreen('login')} onRegister={() => setScreen('register')} onGuest={enterGuestMode} onGoogle={handleGoogleLogin} onMicrosoft={handleMicrosoftLogin} />
        )}
        {!session && !guestMode && screen === 'login' && (
          <Login onSubmit={handleLogin} onReset={handlePasswordReset} onGoogle={handleGoogleLogin} onMicrosoft={handleMicrosoftLogin} onRegister={() => setScreen('register')} onBack={() => setScreen('welcome')} />
        )}
        {!session && !guestMode && screen === 'register' && (
          <Register careers={careers} cycles={cycles} onSubmit={handleRegister} onBack={() => setScreen('welcome')} />
        )}
        {session && screen === 'complete-profile' && (
          <CompleteProfile careers={careers} cycles={cycles} profile={profile} onSubmit={handleUpdateProfile} />
        )}
        {session && screen === 'tutorial' && (
          <OnboardingTutorial onStart={handleFinishTutorial} onSkip={handleFinishTutorial} />
        )}
        {(session || guestMode) && (
          <AuthenticatedLayout
            profile={profile}
            isAdmin={isAdmin}
            guestMode={guestMode}
            screen={screen}
            setScreen={setScreen}
            navItems={navItems}
            onSignOut={async () => { setGuestMode(false); await supabase.auth.signOut() }}
          >
            {guestMode && screen === 'guest-calculator' && (
              <CalculatorScreen
                title="Calculadora rápida"
                subtitle="Modo invitado: tus datos se guardan solo en este navegador."
                courses={[]}
                selectedCourseId=""
                onSelectCourse={() => {}}
                grades={grades}
                setGrades={setGrades}
                settings={settings}
                result={result}
                onCalculate={handleCalculate}
                onGenerate={handleGenerate}
                onClean={handleClean}
                onSave={null}
                guestMode
              />
            )}
            {guestMode && screen === 'guest-settings' && <SettingsScreen settings={settings} onSave={(s) => handleSaveSettings(s, true)} guestMode />}
            {session && screen === 'dashboard' && <Dashboard profile={profile} courses={courses} history={history} setScreen={setScreen} />}
            {session && screen === 'courses' && <CoursesScreen courses={courses} profile={profile} onCreate={handleCreateCourse} onSelect={(id) => { loadCourseGrades(id); setScreen('calculator') }} />}
            {session && screen === 'calculator' && (
              <CalculatorScreen
                title="Calcular nota"
                subtitle="Selecciona un curso, ingresa tus notas y guarda tu resultado cuando lo necesites."
                courses={courses}
                selectedCourseId={selectedCourseId}
                onSelectCourse={loadCourseGrades}
                onCreateCourse={handleCreateCourse}
                grades={grades}
                setGrades={setGrades}
                settings={settings}
                result={result}
                onCalculate={handleCalculate}
                onGenerate={handleGenerate}
                onClean={handleClean}
                onSave={handleSaveResult}
                activeCourse={activeCourse}
              />
            )}
            {session && screen === 'history' && <HistoryScreen history={history} />}
            {session && screen === 'settings' && <SettingsScreen settings={settings} onSave={handleSaveSettings} />}
            {session && screen === 'profile' && <ProfileScreen profile={profile} careers={careers} cycles={cycles} onSave={handleUpdateProfile} />}
            {screen === 'about' && <About />}
            {screen === 'more' && <MoreScreen isAdmin={isAdmin} guestMode={guestMode} setScreen={setScreen} onSignOut={async () => { setGuestMode(false); await supabase.auth.signOut() }} />}
            {session && isAdmin && screen === 'admin-dashboard' && <AdminDashboard data={adminData} onLoad={loadAdminData} setScreen={setScreen} />}
            {session && isAdmin && screen === 'admin-users' && <AdminUsers data={adminData} onLoad={loadAdminData} onToggle={toggleUserStatus} onRole={changeUserRole} />}
            {session && isAdmin && screen === 'admin-courses' && <AdminCourses data={adminData} onLoad={loadAdminData} onUpdate={updateCourseAdmin} />}
            {session && isAdmin && screen === 'admin-calculations' && <AdminCalculations data={adminData} onLoad={loadAdminData} />}
          </AuthenticatedLayout>
        )}
      </main>
    </div>
  )
}

function Splash() {
  return <div className="splash"><img src="/logo.png" alt="Mi Nota Final" /><p>Cargando Mi Nota Final...</p></div>
}

function Welcome({ onLogin, onRegister, onGuest, onGoogle, onMicrosoft }) {
  return (
    <section className="welcome-card">
      <img className="brand-logo" src="/logo.png" alt="Mi Nota Final" />
      <h1>Mi Nota Final</h1>
      <p>Calcula tu nota. Conoce tu meta. Aprueba.</p>
      <div className="stack">
        <SocialButton provider="google" onClick={onGoogle}>Continuar con Google</SocialButton>
        <SocialButton provider="microsoft" onClick={onMicrosoft}>Continuar con Microsoft</SocialButton>
        <button className="btn secondary" onClick={onLogin}>✉️ Iniciar sesión con correo</button>
        <button className="btn ghost" onClick={onRegister}>Crear cuenta</button>
        <button className="btn link" onClick={onGuest}>Continuar como invitado</button>
      </div>
      <Footer />
    </section>
  )
}

function SocialButton({ provider, onClick, children }) {
  return (
    <button type="button" className="social-button" onClick={onClick}>
      <span className={`social-icon ${provider}-icon`} aria-hidden="true">
        {provider === 'google' && 'G'}
        {provider === 'microsoft' && <><i></i><i></i><i></i><i></i></>}
      </span>
      <span>{children}</span>
      <span aria-hidden="true"></span>
    </button>
  )
}

function OnboardingTutorial({ onStart, onSkip }) {
  return (
    <section className="auth-card tutorial-card fade-in">
      <img className="mini-logo" src="/logo.png" alt="Mi Nota Final" />
      <p className="eyebrow">Primer uso</p>
      <h1>Bienvenido a Mi Nota Final</h1>
      <p>Para calcular tus notas sigue estos pasos:</p>
      <div className="tutorial-steps">
        <div><b>1</b><span><strong>Selecciona tu curso</strong><small>Elige uno de la lista. Si no aparece, agrégalo para tu carrera y ciclo.</small></span></div>
        <div><b>2</b><span><strong>Ingresa tus notas</strong><small>Coloca las notas que ya tienes y deja vacío lo pendiente.</small></span></div>
        <div><b>3</b><span><strong>Calcula tu promedio</strong><small>Verás cuánto llevas hasta ahora y qué necesitas para aprobar.</small></span></div>
        <div><b>4</b><span><strong>Guarda el resultado</strong><small>Solo se guarda cuando presionas “Guardar resultado”.</small></span></div>
      </div>
      <div className="action-row">
        <button className="btn primary" onClick={onStart}>Empezar</button>
        <button className="btn ghost" onClick={onSkip}>Omitir tutorial</button>
      </div>
      <Footer />
    </section>
  )
}

function Login({ onSubmit, onReset, onGoogle, onMicrosoft, onRegister, onBack }) {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  return (
    <AuthCard title="Iniciar sesión" onBack={onBack}>
      <input className="input" type="email" placeholder="Correo electrónico" value={email} onChange={(e) => setEmail(e.target.value)} />
      <input className="input" type="password" placeholder="Contraseña" value={password} onChange={(e) => setPassword(e.target.value)} />
      <button className="btn primary" onClick={() => onSubmit(email, password)}>Ingresar</button>
      <SocialButton provider="google" onClick={onGoogle}>Continuar con Google</SocialButton>
      <SocialButton provider="microsoft" onClick={onMicrosoft}>Continuar con Microsoft</SocialButton>
      <button className="btn link" onClick={() => onReset(email)}>Olvidé mi contraseña</button>
      <button className="btn ghost" onClick={onRegister}>Crear cuenta nueva</button>
      <p className="hint">Si acabas de registrarte, confirma tu correo antes de iniciar sesión. Revisa también spam o correo no deseado.</p>
    </AuthCard>
  )
}

function Register({ careers, cycles, onSubmit, onBack }) {
  const [form, setForm] = useState(emptyAuth)
  const update = (key, value) => setForm((prev) => ({ ...prev, [key]: value }))
  return (
    <AuthCard title="Crear cuenta" onBack={onBack}>
      <div className="grid two">
        <input className="input" placeholder="Nombres" value={form.firstName} onChange={(e) => update('firstName', e.target.value)} />
        <input className="input" placeholder="Apellidos" value={form.lastName} onChange={(e) => update('lastName', e.target.value)} />
      </div>
      <input className="input" type="email" placeholder="Correo electrónico" value={form.email} onChange={(e) => update('email', e.target.value)} />
      <select className="input" value={form.careerId} onChange={(e) => update('careerId', e.target.value)}>
        <option value="">Selecciona tu carrera</option>
        {careers.map((career) => <option key={career.id} value={career.id}>{career.name}</option>)}
      </select>
      <select className="input" value={form.cycleId} onChange={(e) => update('cycleId', e.target.value)}>
        <option value="">Selecciona tu ciclo</option>
        {cycles.map((cycle) => <option key={cycle.id} value={cycle.id}>{cycle.name}</option>)}
      </select>
      <div className="grid two">
        <input className="input" type="password" placeholder="Contraseña" value={form.password} onChange={(e) => update('password', e.target.value)} />
        <input className="input" type="password" placeholder="Confirmar contraseña" value={form.confirmPassword} onChange={(e) => update('confirmPassword', e.target.value)} />
      </div>
      <button className="btn primary" onClick={() => onSubmit(form)}>Crear cuenta</button>
      <p className="hint">Al registrarte deberás confirmar tu correo electrónico antes de iniciar sesión.</p>
    </AuthCard>
  )
}

function AuthCard({ title, children, onBack }) {
  return (
    <section className="auth-card">
      <button className="back" onClick={onBack}>← Volver</button>
      <img className="mini-logo" src="/logo.png" alt="Mi Nota Final" />
      <h1>{title}</h1>
      <div className="stack">{children}</div>
      <Footer />
    </section>
  )
}

function AuthenticatedLayout({ children, profile, isAdmin, guestMode, screen, setScreen, navItems, onSignOut }) {
  return (
    <div className="layout">
      <header className="topbar">
        <div className="brand-inline">
          <img src="/icon-192.png" alt="Logo" />
          <div>
            <strong>Mi Nota Final</strong>
            <span>{guestMode ? 'Modo invitado' : `Hola, ${firstWord(profile?.first_name || profile?.full_name)}`}</span>
          </div>
        </div>
        <nav className="desktop-nav">
          {!guestMode && <button onClick={() => setScreen('dashboard')}>Inicio</button>}
          {!guestMode && <button onClick={() => setScreen('courses')}>Cursos</button>}
          <button onClick={() => setScreen(guestMode ? 'guest-calculator' : 'calculator')}>Calcular</button>
          {!guestMode && <button onClick={() => setScreen('history')}>Historial</button>}
          <button onClick={() => setScreen(guestMode ? 'guest-settings' : 'settings')}>Ajustes</button>
          {isAdmin && <button className="admin-link" onClick={() => setScreen('admin-dashboard')}>Admin</button>}
          <button onClick={() => setScreen('about')}>Acerca</button>
          <button onClick={onSignOut}>{guestMode ? 'Salir' : 'Cerrar sesión'}</button>
        </nav>
      </header>
      <section className="content">{children}</section>
      <nav className="mobile-nav">
        {navItems.map(([key, icon, label]) => (
          <button key={key} className={screen === key ? 'active' : ''} onClick={() => setScreen(key)}>
            <span>{icon}</span><small>{label}</small>
          </button>
        ))}
      </nav>
    </div>
  )
}

function Dashboard({ profile, courses, history, setScreen }) {
  return (
    <div className="page fade-in">
      <div className="hero-panel">
        <div>
          <p className="eyebrow">Panel principal</p>
          <h1>Hola, {firstWord(profile?.first_name || profile?.full_name)}</h1>
          <p>{profile?.career?.name || 'Carrera pendiente'} · {profile?.cycle?.name || 'Ciclo pendiente'}</p>
        </div>
        <div className="hero-actions">
          <button className="btn secondary small" onClick={() => setScreen('profile')}>🔄 Cambiar ciclo</button>
          <button className="btn primary small" onClick={() => setScreen('calculator')}>🧮 Calcular nota</button>
        </div>
      </div>
      <div className="cards stats-grid">
        <StatCard icon="📚" label="Cursos visibles" value={courses.length} />
        <StatCard icon="📊" label="Resultados guardados" value={history.length} />
        <StatCard icon="⚙️" label="Ciclo actual" value={profile?.cycle?.name || '—'} />
      </div>
      <div className="grid two">
        <ActionCard title="Mis cursos" text="Cursos compartidos por tu carrera y ciclo." button="Ver cursos" onClick={() => setScreen('courses')} />
        <ActionCard title="Historial" text="Revisa los cálculos que decidiste guardar." button="Ver historial" onClick={() => setScreen('history')} />
      </div>
      <Footer />
    </div>
  )
}

function CoursesScreen({ courses, profile, onCreate, onSelect }) {
  const [selected, setSelected] = useState('')
  const [showNewCourse, setShowNewCourse] = useState(false)
  const [name, setName] = useState('')

  async function createAndSelect() {
    const created = await onCreate(name, { select: true })
    if (created?.id) {
      setSelected(created.id)
      setName('')
      setShowNewCourse(false)
      onSelect(created.id)
    }
  }

  function handleChange(value) {
    if (value === '__new__') {
      setShowNewCourse(true)
      return
    }
    setSelected(value)
    if (value) onSelect(value)
  }

  return (
    <div className="page fade-in">
      <Header title="Cursos" subtitle={`${profile?.career?.name || 'Carrera'} · ${profile?.cycle?.name || 'Ciclo'}`} />
      <Card>
        <h3>Selecciona un curso</h3>
        <p className="hint">Elige un curso activo de tu carrera y ciclo. Si no aparece, puedes agregarlo para que otros alumnos también lo encuentren.</p>
        <select className="input" value={selected} onChange={(e) => handleChange(e.target.value)}>
          <option value="">Selecciona tu curso</option>
          {courses.map((course) => <option key={course.id} value={course.id}>{course.name}</option>)}
          <option value="__new__">+ Agregar nuevo curso</option>
        </select>
        {showNewCourse && (
          <div className="inline-new-course">
            <input className="input" placeholder="Nombre del nuevo curso" value={name} onChange={(e) => setName(e.target.value)} />
            <div className="action-row left">
              <button className="btn primary small" onClick={createAndSelect}>➕ Agregar y usar</button>
              <button className="btn ghost small" onClick={() => { setShowNewCourse(false); setName('') }}>Cancelar</button>
            </div>
          </div>
        )}
      </Card>
      <div className="course-list">
        {courses.length === 0 && <Empty text="Aún no hay cursos activos para tu carrera y ciclo. Agrega el primero desde el combo." />}
        {courses.map((course) => (
          <Card key={course.id} className="course-card">
            <div>
              <h3>{course.name}</h3>
              <p>Creado por: {course.creator ? fullName(course.creator) : 'Usuario'}</p>
            </div>
            <button className="btn secondary small" onClick={() => onSelect(course.id)}>Usar curso</button>
          </Card>
        ))}
      </div>
    </div>
  )
}

function CalculatorScreen({ title, subtitle, courses, selectedCourseId, onSelectCourse, onCreateCourse, grades, setGrades, settings, result, onCalculate, onGenerate, onClean, onSave, activeCourse, guestMode }) {
  const practices = EVALUATIONS.filter((e) => e.group === 'Prácticas calificadas')
  const exams = EVALUATIONS.filter((e) => e.group === 'Exámenes')
  const updateGrade = (key, value) => setGrades((prev) => ({ ...prev, [key]: value }))

  return (
    <div className="page fade-in">
      <Header title={title} subtitle={subtitle} />
      {!guestMode && (
        <CourseCombo
          courses={courses}
          selectedCourseId={selectedCourseId}
          onSelectCourse={onSelectCourse}
          onCreateCourse={onCreateCourse}
          activeCourse={activeCourse}
        />
      )}
      <EvaluationSection title="Prácticas calificadas" items={practices} grades={grades} settings={settings} updateGrade={updateGrade} />
      <EvaluationSection title="Exámenes" items={exams} grades={grades} settings={settings} updateGrade={updateGrade} />
      <div className="action-row">
        <button className="btn primary" onClick={onCalculate}>🧮 Calcular</button>
        <button className="btn warning" onClick={onClean}>🧹 Limpiar</button>
        <button className="btn success" onClick={onGenerate}>✨ Generar</button>
      </div>
      {onSave && <button className="btn secondary full" onClick={onSave}>💾 Guardar resultado</button>}
      {result && <ResultCard result={result} />}
    </div>
  )
}

function CourseCombo({ courses, selectedCourseId, onSelectCourse, onCreateCourse, activeCourse }) {
  const [showNewCourse, setShowNewCourse] = useState(false)
  const [name, setName] = useState('')

  async function createAndSelect() {
    const created = await onCreateCourse(name, { select: true })
    if (created?.id) {
      setName('')
      setShowNewCourse(false)
    }
  }

  function handleChange(value) {
    if (value === '__new__') {
      setShowNewCourse(true)
      return
    }
    setShowNewCourse(false)
    onSelectCourse(value)
  }

  return (
    <Card>
      <label className="label">Curso</label>
      <select className="input" value={selectedCourseId} onChange={(e) => handleChange(e.target.value)}>
        <option value="">Selecciona tu curso</option>
        {courses.map((course) => <option key={course.id} value={course.id}>{course.name}</option>)}
        <option value="__new__">+ Agregar nuevo curso</option>
      </select>
      {activeCourse && <p className="hint">Calculando para: {activeCourse.name}</p>}
      {courses.length === 0 && <p className="hint">No hay cursos activos para tu carrera y ciclo. Agrega uno nuevo desde el combo.</p>}
      {showNewCourse && (
        <div className="inline-new-course">
          <input className="input" placeholder="Nombre del nuevo curso" value={name} onChange={(e) => setName(e.target.value)} />
          <div className="action-row left">
            <button className="btn primary small" onClick={createAndSelect}>➕ Agregar y usar</button>
            <button className="btn ghost small" onClick={() => { setShowNewCourse(false); setName('') }}>Cancelar</button>
          </div>
          <p className="hint">El curso se compartirá con estudiantes de tu misma carrera y ciclo.</p>
        </div>
      )}
    </Card>
  )
}

function EvaluationSection({ title, items, grades, settings, updateGrade }) {
  return (
    <Card>
      <div className="section-title"><span>▦</span><h3>{title}</h3></div>
      <div className="eval-grid">
        {items.map((item) => (
          <div className="eval-card" key={item.key}>
            <div className="eval-head"><strong>{item.label}</strong><span>{formatPercent(settings[item.percentKey])}%</span></div>
            <input className="input grade" inputMode="decimal" placeholder="—" value={grades[item.key]} onChange={(e) => updateGrade(item.key, e.target.value)} />
          </div>
        ))}
      </div>
    </Card>
  )
}

function ResultCard({ result }) {
  return (
    <Card className={`result-card ${result.statusClass}`}>
      <div className="result-main">
        <span>Llevas hasta ahora</span>
        <strong>{formatNumber(result.current_average)}</strong>
        <small>Promedio acumulado según las notas ingresadas</small>
      </div>
      <div className="mini-stats">
        <StatBox label="Evaluado" value={`${formatPercent(result.evaluated_weight)}%`} />
        <StatBox label="Pendiente" value={`${formatPercent(result.pending_weight)}%`} />
        <StatBox label="Estado" value={result.status} />
      </div>
      <p className="message">{result.message}</p>
      {result.pending_evaluations && (
        <div className="pending-box">
          <strong>Evaluaciones pendientes</strong>
          <p>{result.pending_evaluations}</p>
          {result.required_values?.length > 0 && <strong>Para aprobar, necesitas sacar como mínimo:</strong>}
          <div className="required-list">
            {result.required_values?.map((value) => <span key={value.key}>{value.name}: <b>{formatNumber(value.value)}</b></span>)}
          </div>
        </div>
      )}
      <div className="target-box"><span>🎯 Nota mínima aprobatoria</span><b>{formatNumber(result.minimum_grade)}</b></div>
    </Card>
  )
}

function HistoryScreen({ history }) {
  return (
    <div className="page fade-in">
      <Header title="Historial" subtitle="Resultados guardados manualmente." />
      {history.length === 0 && <Empty text="Aún no guardaste resultados." />}
      <div className="table-list">
        {history.map((item) => (
          <Card key={item.id}>
            <div className="list-row">
              <div>
                <h3>{item.course?.name || 'Curso eliminado'}</h3>
                <p>{dateOnly(item.created_at)} · Pendientes: {item.pending_evaluations || 'Ninguna'}</p>
              </div>
              <div className="score-pill">{formatNumber(item.current_average)}</div>
            </div>
            <p className="hint">Estado: {item.status} · Evaluado: {formatPercent(item.evaluated_weight)}% · Pendiente: {formatPercent(item.pending_weight)}%</p>
          </Card>
        ))}
      </div>
    </div>
  )
}

function SettingsScreen({ settings, onSave, guestMode }) {
  const [form, setForm] = useState(settings)
  useEffect(() => setForm(settings), [settings])
  const update = (key, value) => setForm((prev) => ({ ...prev, [key]: value }))
  const total = EVALUATIONS.reduce((sum, item) => sum + Number(form[item.percentKey] || 0), 0)
  return (
    <div className="page fade-in">
      <Header title="Ajustes" subtitle={guestMode ? 'Configuración local del modo invitado.' : 'Porcentajes generales para tus cursos.'} />
      <Card>
        <div className="section-title"><span>⚙️</span><h3>Porcentajes</h3><b className={Math.abs(total - 100) < 0.001 ? 'ok' : 'bad'}>Total: {formatPercent(total)}%</b></div>
        <div className="settings-grid">
          {EVALUATIONS.map((item) => (
            <label className="setting-card" key={item.key}>
              <span>{item.label}</span>
              <input className="input" inputMode="decimal" value={form[item.percentKey]} onChange={(e) => update(item.percentKey, e.target.value)} />
            </label>
          ))}
        </div>
        <label className="setting-card wide">
          <span>Nota mínima aprobatoria</span>
          <input className="input" inputMode="decimal" value={form.minimum_grade} onChange={(e) => update('minimum_grade', e.target.value)} />
        </label>
        <p className="hint">La suma de porcentajes debe ser exactamente 100%.</p>
        <div className="action-row">
          <button className="btn primary" onClick={() => onSave(form)}>💾 Guardar cambios</button>
          <button className="btn secondary" onClick={() => setForm(DEFAULT_SETTINGS)}>↩️ Restablecer</button>
        </div>
      </Card>
    </div>
  )
}

function ProfileScreen({ profile, careers, cycles, onSave }) {
  return (
    <div className="page fade-in">
      <Header title="Perfil" subtitle="Actualiza tus datos personales, carrera y ciclo actual." />
      <Card>
        <ProfileForm profile={profile} careers={careers} cycles={cycles} onSave={onSave} buttonText="Guardar perfil" />
      </Card>
    </div>
  )
}

function ProfileForm({ profile, careers, cycles, onSave, buttonText = 'Guardar perfil' }) {
  const [form, setForm] = useState({
    firstName: profile?.first_name || '',
    lastName: profile?.last_name || '',
    careerId: profile?.career_id || '',
    cycleId: profile?.current_cycle_id || ''
  })
  useEffect(() => {
    setForm({
      firstName: profile?.first_name || '',
      lastName: profile?.last_name || '',
      careerId: profile?.career_id || '',
      cycleId: profile?.current_cycle_id || ''
    })
  }, [profile?.id, profile?.first_name, profile?.last_name, profile?.career_id, profile?.current_cycle_id])
  const update = (key, value) => setForm((prev) => ({ ...prev, [key]: value }))
  return (
    <div className="stack">
      <div className="grid two">
        <input className="input" placeholder="Nombres" value={form.firstName} onChange={(e) => update('firstName', e.target.value)} />
        <input className="input" placeholder="Apellidos" value={form.lastName} onChange={(e) => update('lastName', e.target.value)} />
      </div>
      {profile?.email && <input className="input" value={profile.email} disabled />}
      <select className="input" value={form.careerId} onChange={(e) => update('careerId', e.target.value)}>
        <option value="">Selecciona carrera</option>
        {careers.map((career) => <option key={career.id} value={career.id}>{career.name}</option>)}
      </select>
      <select className="input" value={form.cycleId} onChange={(e) => update('cycleId', e.target.value)}>
        <option value="">Selecciona ciclo</option>
        {cycles.map((cycle) => <option key={cycle.id} value={cycle.id}>{cycle.name}</option>)}
      </select>
      <button className="btn primary" onClick={() => onSave(form)}>{buttonText}</button>
    </div>
  )
}

function CompleteProfile({ profile, careers, cycles, onSubmit }) {
  return (
    <div className="page fade-in">
      <Card className="complete-profile-card">
        <img className="mini-logo" src="/logo.png" alt="Mi Nota Final" />
        <h1>Completa tu perfil</h1>
        <p className="muted">Antes de continuar, indica tu carrera y ciclo actual. Esto permitirá mostrarte solo los cursos que corresponden.</p>
        <ProfileForm profile={profile || {}} careers={careers} cycles={cycles} onSave={onSubmit} buttonText="Guardar y continuar" />
      </Card>
    </div>
  )
}

function MoreScreen({ isAdmin, guestMode, setScreen, onSignOut }) {
  return (
    <div className="page fade-in">
      <Header title="Más opciones" subtitle="Accesos rápidos del sistema." />
      <div className="grid two">
        {!guestMode && <ActionCard title="Perfil" text="Datos personales, carrera y ciclo." button="Abrir" onClick={() => setScreen('profile')} />}
        <ActionCard title="Ajustes" text="Porcentajes y nota mínima." button="Abrir" onClick={() => setScreen(guestMode ? 'guest-settings' : 'settings')} />
        <ActionCard title="Acerca de" text="Versión y datos del sistema." button="Abrir" onClick={() => setScreen('about')} />
        {isAdmin && <ActionCard title="Panel administrador" text="Reportes, usuarios, cursos y cálculos." button="Abrir" onClick={() => setScreen('admin-dashboard')} />}
      </div>
      <button className="btn danger full" onClick={onSignOut}>{guestMode ? 'Salir del modo invitado' : 'Cerrar sesión'}</button>
    </div>
  )
}

function About() {
  return (
    <div className="page fade-in">
      <Card className="about-card">
        <img className="brand-logo small" src="/logo.png" alt="Mi Nota Final" />
        <h1>Mi Nota Final</h1>
        <p>Aplicación web desarrollada para ayudar a estudiantes a calcular sus notas de fin de ciclo de forma rápida, sencilla y sin anuncios.</p>
        <p>Los cálculos guardados por usuarios registrados podrán ser revisados por el administrador del sistema con fines de soporte, control y mejora de la aplicación.</p>
        <b>Versión: {APP_VERSION}</b>
        <Footer />
      </Card>
    </div>
  )
}

function AdminDashboard({ data, onLoad, setScreen }) {
  useEffect(() => { onLoad() }, []) // eslint-disable-line react-hooks/exhaustive-deps
  const users = data?.users || []
  const courses = data?.courses || []
  const calculations = data?.calculations || []
  const logins = data?.logins || []
  const todayLogins = logins.filter((login) => login.login_date === todayISO())
  const uniqueToday = new Set(todayLogins.map((login) => login.user_id)).size
  const hourly = groupByHour(todayLogins)
  const byCareer = countBy(users, (u) => u.career?.name || 'Sin carrera')
  const byCycle = countBy(users, (u) => u.cycle?.name || 'Sin ciclo')
  const distribution = buildDistribution(users, courses, calculations)

  return (
    <div className="page fade-in">
      <Header title="Panel administrador" subtitle="Reportes generales y actividad del sistema." />
      <div className="cards stats-grid">
        <StatCard icon="👥" label="Usuarios registrados" value={users.length} />
        <StatCard icon="✅" label="Usuarios activos hoy" value={uniqueToday} />
        <StatCard icon="🔐" label="Accesos del día" value={todayLogins.length} />
        <StatCard icon="📚" label="Cursos creados" value={courses.length} />
        <StatCard icon="📊" label="Cálculos guardados" value={calculations.length} />
      </div>
      <div className="grid two">
        <Card><h3>Accesos por hora de hoy</h3><BarChart data={hourly} /></Card>
        <Card><h3>Usuarios por carrera</h3><BarChart data={byCareer} /></Card>
        <Card><h3>Usuarios por ciclo</h3><BarChart data={byCycle} /></Card>
        <Card><h3>Usuarios que iniciaron sesión hoy</h3><RecentLogins items={todayLogins.slice(0, 8)} /></Card>
      </div>
      <Card>
        <h3>Distribución por carrera y ciclo</h3>
        <ResponsiveTable rows={distribution} columns={['carrera', 'ciclo', 'usuarios', 'cursos', 'calculos']} />
      </Card>
      <div className="grid three">
        <button className="btn secondary" onClick={() => setScreen('admin-users')}>👥 Gestionar usuarios</button>
        <button className="btn secondary" onClick={() => setScreen('admin-courses')}>📚 Gestionar cursos</button>
        <button className="btn secondary" onClick={() => setScreen('admin-calculations')}>📊 Ver cálculos</button>
      </div>
    </div>
  )
}

function AdminUsers({ data, onLoad, onToggle, onRole }) {
  useEffect(() => { onLoad() }, []) // eslint-disable-line react-hooks/exhaustive-deps
  const [q, setQ] = useState('')
  const users = (data?.users || []).filter((u) => `${fullName(u)} ${u.email}`.toLowerCase().includes(q.toLowerCase()))
  return (
    <div className="page fade-in">
      <Header title="Usuarios" subtitle="Ver, dar de baja, reactivar y cambiar rol." />
      <input className="input" placeholder="Buscar usuario o correo" value={q} onChange={(e) => setQ(e.target.value)} />
      <div className="admin-list">
        {users.map((user) => (
          <Card key={user.id}>
            <div className="list-row">
              <div>
                <h3>{fullName(user)}</h3>
                <p>{user.email} · {user.career?.name || 'Sin carrera'} · {user.cycle?.name || 'Sin ciclo'}</p>
              </div>
              <span className={`badge ${user.status}`}>{user.status}</span>
            </div>
            <div className="action-row left">
              <button className="btn secondary small" onClick={() => onToggle(user)}>{user.status === 'active' ? 'Dar de baja' : 'Reactivar'}</button>
              <button className="btn ghost small" onClick={() => onRole(user, user.role === 'admin' ? 'student' : 'admin')}>{user.role === 'admin' ? 'Quitar admin' : 'Hacer admin'}</button>
            </div>
          </Card>
        ))}
      </div>
    </div>
  )
}

function AdminCourses({ data, onLoad, onUpdate }) {
  useEffect(() => { onLoad() }, []) // eslint-disable-line react-hooks/exhaustive-deps
  const [filters, setFilters] = useState({ q: '', career: '', cycle: '' })
  const courses = (data?.courses || []).filter((course) => {
    const matchesQ = `${course.name} ${fullName(course.creator || {})}`.toLowerCase().includes(filters.q.toLowerCase())
    const matchesCareer = !filters.career || course.career?.name === filters.career
    const matchesCycle = !filters.cycle || course.cycle?.name === filters.cycle
    return matchesQ && matchesCareer && matchesCycle
  })
  const careers = unique((data?.courses || []).map((c) => c.career?.name).filter(Boolean))
  const cycles = unique((data?.courses || []).map((c) => c.cycle?.name).filter(Boolean))
  return (
    <div className="page fade-in">
      <Header title="Cursos" subtitle="Editar nombres, ver creador y dar de baja cursos." />
      <div className="filters">
        <input className="input" placeholder="Buscar curso o creador" value={filters.q} onChange={(e) => setFilters({ ...filters, q: e.target.value })} />
        <select className="input" value={filters.career} onChange={(e) => setFilters({ ...filters, career: e.target.value })}><option value="">Todas las carreras</option>{careers.map((c) => <option key={c}>{c}</option>)}</select>
        <select className="input" value={filters.cycle} onChange={(e) => setFilters({ ...filters, cycle: e.target.value })}><option value="">Todos los ciclos</option>{cycles.map((c) => <option key={c}>{c}</option>)}</select>
      </div>
      <div className="admin-list">
        {courses.map((course) => <AdminCourseCard key={course.id} course={course} onUpdate={onUpdate} />)}
      </div>
    </div>
  )
}

function AdminCourseCard({ course, onUpdate }) {
  const [editing, setEditing] = useState(false)
  const [name, setName] = useState(course.name)
  return (
    <Card>
      <div className="list-row">
        <div>
          {editing ? <input className="input" value={name} onChange={(e) => setName(e.target.value)} /> : <h3>{course.name}</h3>}
          <p>{course.career?.name || 'Sin carrera'} · {course.cycle?.name || 'Sin ciclo'} · Creado por: {course.creator ? fullName(course.creator) : 'Usuario'}</p>
        </div>
        <span className={`badge ${course.status}`}>{course.status}</span>
      </div>
      <div className="action-row left">
        {editing ? <button className="btn primary small" onClick={() => { onUpdate(course.id, { name: name.trim() }); setEditing(false) }}>Guardar</button> : <button className="btn secondary small" onClick={() => setEditing(true)}>Editar nombre</button>}
        <button className="btn ghost small" onClick={() => onUpdate(course.id, { status: course.status === 'active' ? 'inactive' : 'active' })}>{course.status === 'active' ? 'Dar de baja' : 'Reactivar'}</button>
      </div>
    </Card>
  )
}

function AdminCalculations({ data, onLoad }) {
  useEffect(() => { onLoad() }, []) // eslint-disable-line react-hooks/exhaustive-deps
  const [q, setQ] = useState('')
  const rows = (data?.calculations || []).filter((item) => `${item.course?.name || ''} ${fullName(item.profile || {})} ${item.status}`.toLowerCase().includes(q.toLowerCase()))
  return (
    <div className="page fade-in">
      <Header title="Cálculos guardados" subtitle="Resultados guardados por los usuarios." />
      <input className="input" placeholder="Buscar por usuario, curso o estado" value={q} onChange={(e) => setQ(e.target.value)} />
      <div className="admin-list">
        {rows.map((item) => (
          <Card key={item.id}>
            <div className="list-row">
              <div>
                <h3>{item.course?.name || 'Curso eliminado'} · {fullName(item.profile)}</h3>
                <p>{dateOnly(item.created_at)} · Pendientes: {item.pending_evaluations || 'Ninguna'}</p>
              </div>
              <div className="score-pill">{formatNumber(item.current_average)}</div>
            </div>
            <p className="hint">Estado: {item.status} · Evaluado: {formatPercent(item.evaluated_weight)}% · Pendiente: {formatPercent(item.pending_weight)}%</p>
          </Card>
        ))}
      </div>
    </div>
  )
}

function RecentLogins({ items }) {
  if (!items.length) return <Empty text="Aún no hay accesos registrados hoy." compact />
  return <div className="recent-list">{items.map((item) => <div key={item.id}><b>{fullName(item.profile)}</b><span>{item.career?.name || 'Sin carrera'} · {item.cycle?.name || 'Sin ciclo'} · {timeOnly(item.login_at)}</span></div>)}</div>
}

function BarChart({ data }) {
  const entries = Object.entries(data || {})
  if (!entries.length) return <Empty text="Sin datos suficientes." compact />
  const max = Math.max(...entries.map(([, value]) => value), 1)
  return <div className="bar-chart">{entries.map(([label, value]) => <div className="bar-row" key={label}><span>{label}</span><div><i style={{ width: `${(value / max) * 100}%` }} /></div><b>{value}</b></div>)}</div>
}

function buildDistribution(users, courses, calculations) {
  const map = new Map()
  const keyOf = (career, cycle) => `${career || 'Sin carrera'}|${cycle || 'Sin ciclo'}`
  const ensure = (career, cycle) => {
    const key = keyOf(career, cycle)
    if (!map.has(key)) map.set(key, { carrera: career || 'Sin carrera', ciclo: cycle || 'Sin ciclo', usuarios: 0, cursos: 0, calculos: 0 })
    return map.get(key)
  }
  users.forEach((u) => ensure(u.career?.name, u.cycle?.name).usuarios += 1)
  courses.forEach((c) => ensure(c.career?.name, c.cycle?.name).cursos += 1)
  calculations.forEach((c) => ensure(c.course?.career?.name, c.course?.cycle?.name).calculos += 1)
  return Array.from(map.values()).sort((a, b) => `${a.carrera}${a.ciclo}`.localeCompare(`${b.carrera}${b.ciclo}`))
}

function groupByHour(logins) {
  const result = {}
  logins.forEach((login) => {
    const hour = new Date(login.login_at).toLocaleTimeString('es-PE', { hour: '2-digit', hour12: false }) + ':00'
    result[hour] = (result[hour] || 0) + 1
  })
  return result
}

function countBy(items, getter) {
  return items.reduce((acc, item) => {
    const key = getter(item)
    acc[key] = (acc[key] || 0) + 1
    return acc
  }, {})
}

function unique(items) {
  return [...new Set(items)]
}

function Header({ title, subtitle }) {
  return <div className="page-header"><h1>{title}</h1>{subtitle && <p>{subtitle}</p>}</div>
}

function Card({ children, className = '' }) {
  return <section className={`card ${className}`}>{children}</section>
}

function StatCard({ icon, label, value }) {
  return <Card className="stat-card"><span>{icon}</span><div><strong>{value}</strong><p>{label}</p></div></Card>
}

function StatBox({ label, value }) {
  return <div className="stat-box"><small>{label}</small><b>{value}</b></div>
}

function ActionCard({ title, text, button, onClick }) {
  return <Card><h3>{title}</h3><p>{text}</p><button className="btn secondary small" onClick={onClick}>{button}</button></Card>
}

function Empty({ text, compact }) {
  return <div className={`empty ${compact ? 'compact' : ''}`}>{text}</div>
}

function ResponsiveTable({ rows, columns }) {
  if (!rows.length) return <Empty text="Sin datos." compact />
  return (
    <div className="responsive-table">
      <table>
        <thead><tr>{columns.map((col) => <th key={col}>{col}</th>)}</tr></thead>
        <tbody>{rows.map((row, index) => <tr key={index}>{columns.map((col) => <td key={col}>{row[col]}</td>)}</tr>)}</tbody>
      </table>
    </div>
  )
}

function Footer() {
  return <footer>Desarrollado por: Ing. Oscar Huamán</footer>
}

function loadGuestSettings() {
  try {
    const saved = localStorage.getItem('mnf_guest_settings')
    return saved ? JSON.parse(saved) : DEFAULT_SETTINGS
  } catch {
    return DEFAULT_SETTINGS
  }
}

export default App
