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
  validateSettings,
  normalizeEvaluationComponents,
  emptyDynamicGrades,
  calculateFlexibleGradeResult,
  generateFlexibleMissingGrades
} from './utils/grades'

const ADMIN_EMAIL = 'oscar.miguel.huaman.cabrera@gmail.com'
const APP_VERSION = '1.1.0'

const emptyAuth = {
  firstName: '',
  lastName: '',
  email: '',
  password: '',
  confirmPassword: '',
  universityId: '',
  facultyId: '',
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

function splitFullName(fullName = '') {
  const parts = String(fullName)
    .trim()
    .replace(/\s+/g, ' ')
    .split(' ')
    .filter(Boolean)

  if (parts.length === 0) return { firstName: '', lastName: '' }
  if (parts.length === 1) return { firstName: parts[0], lastName: '' }
  if (parts.length === 2) return { firstName: parts[0], lastName: parts[1] }
  if (parts.length === 3) return { firstName: parts[0], lastName: parts.slice(1).join(' ') }
  return {
    firstName: parts.slice(0, 2).join(' '),
    lastName: parts.slice(2).join(' ')
  }
}

function formatStatus(status) {
  if (status === 'active') return 'Activo'
  if (status === 'inactive') return 'Inactivo'
  if (status === 'visible') return 'Visible'
  if (status === 'hidden') return 'Oculto'
  return status || '—'
}

function formatRole(role) {
  if (role === 'admin') return 'Administrador'
  if (role === 'student') return 'Estudiante'
  return role || '—'
}

function formatEnrollmentType(type) {
  const labels = {
    regular: 'Regular',
    arrastrado: 'Arrastrado',
    adelantado: 'Adelantado',
    electivo: 'Electivo',
    otro: 'Otro'
  }
  return labels[type] || 'Regular'
}

function creatorName(course) {
  return course?.creator ? fullName(course.creator) : 'Sistema'
}

function universityName(item) {
  return item?.university?.name || 'Sin universidad'
}

function facultyName(item) {
  return item?.faculty?.name || 'Sin facultad'
}

function academicContext(profile) {
  if (!profile) return 'Perfil pendiente'
  if (profile.role === 'admin' || profile.role === 'superadmin') return 'Administrador general'
  return [profile.university?.code || profile.university?.name, profile.faculty?.name, profile.career?.name, profile.cycle?.name].filter(Boolean).join(' · ') || 'Perfil pendiente'
}

function courseCycleName(course) {
  return course?.cycle?.name || 'Sin ciclo'
}

function latestHistoryForCourse(history, courseId) {
  return (history || []).find((item) => item.course_id === courseId) || null
}

function buildProfileFromAuthUser(user) {
  const metadata = user?.user_metadata || {}
  const rawName = metadata.full_name || metadata.name || metadata.display_name || ''
  const parsedName = splitFullName(rawName || user?.email?.split('@')[0] || '')
  const first = metadata.given_name || metadata.first_name || parsedName.firstName || ''
  const last = metadata.family_name || metadata.last_name || parsedName.lastName || ''
  const email = user?.email || ''
  return {
    id: user?.id,
    email,
    first_name: first || '',
    last_name: last || '',
    full_name: `${first || ''} ${last || ''}`.trim(),
    role: email.toLowerCase() === ADMIN_EMAIL.toLowerCase() ? 'admin' : 'student',
    status: 'active',
    university_id: metadata.university_id || null,
    faculty_id: metadata.faculty_id || null,
    career_id: metadata.career_id || null,
    current_cycle_id: metadata.current_cycle_id || null,
    has_seen_tutorial: false
  }
}

function isProfileIncomplete(userProfile) {
  if (userProfile?.role === 'admin' || userProfile?.role === 'superadmin') return false
  return !userProfile?.first_name || !userProfile?.last_name || !userProfile?.university_id || !userProfile?.faculty_id || !userProfile?.career_id || !userProfile?.current_cycle_id
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
  const [universities, setUniversities] = useState([])
  const [faculties, setFaculties] = useState([])
  const [careers, setCareers] = useState([])
  const [cycles, setCycles] = useState([])
  const [settings, setSettings] = useState(DEFAULT_SETTINGS)
  const [courses, setCourses] = useState([])
  const [availableCourses, setAvailableCourses] = useState([])
  const [selectedCourseId, setSelectedCourseId] = useState('')
  const [grades, setGrades] = useState(emptyGrades())
  const [evaluationTemplate, setEvaluationTemplate] = useState(null)
  const [evaluationItems, setEvaluationItems] = useState(normalizeEvaluationComponents([], settings))
  const [result, setResult] = useState(null)
  const [history, setHistory] = useState([])
  const [adminData, setAdminData] = useState(null)
  const [screen, setScreen] = useState('login')
  const [guestMode, setGuestMode] = useState(false)
  const [notice, setNotice] = useState(null)
  const [loading, setLoading] = useState(true)
  const recordedLoginRef = useRef('')

  const isAdmin = profile?.role === 'admin' || profile?.role === 'superadmin'
  const activeCourse = courses.find((course) => course.id === selectedCourseId) || null
  const greetingName = firstWord(profile?.first_name || profile?.full_name)

  function getDefaultTemplateIdForProfile() {
    return null
  }

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
        setAvailableCourses([])
        setHistory([])
        setSelectedCourseId('')
        if (!guestMode) setScreen('login')
      }
    })
    return () => listener?.subscription?.unsubscribe()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  async function initialize() {
    setLoading(true)
    await Promise.all([loadUniversities(), loadFaculties(), loadCareers(), loadCycles()])
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

  async function loadUniversities() {
    const { data, error } = await supabase.from('universities').select('*').eq('status', 'active').order('name')
    if (!error) setUniversities(data || [])
  }

  async function loadFaculties() {
    const { data, error } = await supabase.from('faculties').select('*, university:universities(id,name,code)').eq('status', 'active').order('name')
    if (!error) setFaculties(data || [])
  }

  async function loadCareers() {
    const { data, error } = await supabase.from('careers').select('*, faculty:faculties(id,name,university_id, university:universities(id,name,code))').eq('status', 'active').order('name')
    if (!error) setCareers(data || [])
  }

  async function loadCycles() {
    const { data, error } = await supabase.from('cycles').select('*').eq('status', 'active').order('order_number')
    if (!error) setCycles(data || [])
  }

  async function loadProfileAndData(user) {
    const { data: userProfile, error } = await supabase
      .from('profiles')
      .select('*, university:universities(id,name,code), faculty:faculties(id,name), career:careers(id,name,faculty_id), cycle:cycles(id,name,order_number)')
      .eq('id', user.id)
      .single()

    if (error || !userProfile) {
      const provisionalProfile = buildProfileFromAuthUser(user)
      setProfile(provisionalProfile)
      setCourses([])
      setAvailableCourses([])
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
      university_id: userProfile.university_id,
      faculty_id: userProfile.faculty_id,
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
    if (!userProfile?.career_id || !userProfile?.university_id) {
      setCourses([])
      setAvailableCourses([])
      return
    }

    const officialRes = await supabase
      .from('courses')
      .select('*, university:universities(id,name,code), faculty:faculties(id,name), career:careers(name), cycle:cycles(id,name,order_number), creator:profiles!courses_created_by_fkey(first_name,last_name,email), evaluation_template:evaluation_templates(id,name,min_passing_grade)')
      .eq('university_id', userProfile.university_id)
      .eq('career_id', userProfile.career_id)
      .eq('status', 'active')
      .order('name')

    const officialCourses = officialRes.error ? [] : (officialRes.data || [])
    const orderedOfficial = officialCourses.sort((a, b) => {
      const cycleDiff = Number(a.cycle?.order_number || 0) - Number(b.cycle?.order_number || 0)
      return cycleDiff || String(a.name).localeCompare(String(b.name), 'es')
    })
    setAvailableCourses(orderedOfficial)

    if (!userProfile?.id) {
      setCourses([])
      return
    }

    const studentRes = await supabase
      .from('student_courses')
      .select('id,enrollment_type,status,course_id,course:courses!inner(*, university:universities(id,name,code), faculty:faculties(id,name), career:careers(name), cycle:cycles(id,name,order_number), creator:profiles!courses_created_by_fkey(first_name,last_name,email), evaluation_template:evaluation_templates(id,name,min_passing_grade))')
      .eq('user_id', userProfile.id)
      .eq('status', 'visible')
      .eq('course.status', 'active')

    if (!studentRes.error) {
      const myCourses = (studentRes.data || [])
        .map((row) => ({
          ...row.course,
          student_course_id: row.id,
          enrollment_type: row.enrollment_type || 'regular',
          student_course_status: row.status || 'visible'
        }))
        .sort((a, b) => {
          const cycleDiff = Number(a.cycle?.order_number || 0) - Number(b.cycle?.order_number || 0)
          return cycleDiff || String(a.name).localeCompare(String(b.name), 'es')
        })
      setCourses(myCourses)
      return
    }

    // Compatibilidad si aún no se ejecutó la migración student_courses.
    const fallback = orderedOfficial.filter((course) => course.cycle_id === userProfile.current_cycle_id)
    setCourses(fallback.map((course) => ({ ...course, enrollment_type: 'regular' })))
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
      const fallback = normalizeEvaluationComponents([], settings)
      setEvaluationTemplate(null)
      setEvaluationItems(fallback)
      setGrades(emptyDynamicGrades(fallback))
      return
    }

    const course = courses.find((c) => c.id === courseId) || availableCourses.find((c) => c.id === courseId)
    let template = course?.evaluation_template || null

    if (!template && course?.evaluation_template_id) {
      const { data } = await supabase
        .from('evaluation_templates')
        .select('*')
        .eq('id', course.evaluation_template_id)
        .maybeSingle()
      template = data || null
    }

    if (!template) {
      let query = supabase
        .from('evaluation_templates')
        .select('*')
        .eq('status', 'active')
        .order('created_at', { ascending: true })
        .limit(1)
      if (course?.university_id) query = query.eq('university_id', course.university_id)
      const { data } = await query.maybeSingle()
      template = data || null
    }

    if (template?.id) {
      const { data: components, error: compError } = await supabase
        .from('evaluation_components')
        .select('*')
        .eq('template_id', template.id)
        .eq('status', 'active')
        .order('component_order')

      const items = compError ? normalizeEvaluationComponents([], settings) : normalizeEvaluationComponents(components || [], settings)
      setEvaluationTemplate(template)
      setEvaluationItems(items)

      const { data: scoreRows, error: scoreError } = await supabase
        .from('student_evaluation_scores')
        .select('*')
        .eq('course_id', courseId)
        .eq('user_id', session.user.id)

      if (!scoreError) {
        const next = emptyDynamicGrades(items)
        ;(scoreRows || []).forEach((row) => {
          const item = items.find((it) => it.id === row.evaluation_component_id)
          if (item) next[item.key] = row.score ?? ''
        })
        setGrades(next)
        return
      }
    }

    // Fallback de compatibilidad con la tabla antigua course_grades.
    const fallbackItems = normalizeEvaluationComponents([], settings)
    setEvaluationTemplate(null)
    setEvaluationItems(fallbackItems)
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
      setGrades(emptyDynamicGrades(fallbackItems))
    }
  }

  async function handleRegister(form) {
    if (!form.firstName.trim() || !form.lastName.trim() || !form.email.trim() || !form.password || !form.universityId || !form.facultyId || !form.careerId || !form.cycleId) {
      notify('error', 'Completa nombres, apellidos, correo, universidad, facultad, carrera, ciclo y contraseña.')
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
          university_id: form.universityId,
          faculty_id: form.facultyId,
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
    setAvailableCourses([])
    setGrades(emptyDynamicGrades(evaluationItems?.length ? evaluationItems : normalizeEvaluationComponents([], settings)))
    setResult(null)
    setScreen('guest-calculator')
  }

  function handleCalculate() {
    const items = evaluationItems?.length ? evaluationItems : normalizeEvaluationComponents([], settings)
    const minimum = evaluationTemplate?.min_passing_grade || settings.minimum_grade
    const calculation = calculateFlexibleGradeResult(grades, items, minimum)
    if (calculation.error) {
      notify('error', calculation.error)
      return
    }
    setResult(calculation.result)
  }

  function handleGenerate() {
    const items = evaluationItems?.length ? evaluationItems : normalizeEvaluationComponents([], settings)
    const minimum = evaluationTemplate?.min_passing_grade || settings.minimum_grade
    const generated = generateFlexibleMissingGrades(grades, items, minimum)
    if (generated.error) {
      notify('error', generated.error)
      return
    }
    setGrades(generated.grades)
    setResult(generated.result)
  }

  function handleClean() {
    const items = evaluationItems?.length ? evaluationItems : normalizeEvaluationComponents([], settings)
    setGrades(emptyDynamicGrades(items))
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
    const items = evaluationItems?.length ? evaluationItems : normalizeEvaluationComponents([], settings)
    const minimum = evaluationTemplate?.min_passing_grade || settings.minimum_grade
    const calculation = result ? { error: null, result } : calculateFlexibleGradeResult(grades, items, minimum)
    if (calculation.error) {
      notify('error', calculation.error)
      return
    }
    const normalized = normalizeGradesForDb(grades)
    if (evaluationTemplate?.id && items.some((item) => item.id)) {
      const scoreRows = items
        .filter((item) => item.id)
        .map((item) => ({
          user_id: session.user.id,
          course_id: selectedCourseId,
          student_course_id: activeCourse?.student_course_id || null,
          evaluation_template_id: evaluationTemplate.id,
          evaluation_component_id: item.id,
          score: toNumber(grades[item.key]),
          updated_at: new Date().toISOString()
        }))
      const { error: scoreError } = await supabase
        .from('student_evaluation_scores')
        .upsert(scoreRows, { onConflict: 'user_id,course_id,evaluation_component_id' })
      if (scoreError) {
        notify('error', getErrorMessage(scoreError))
        return
      }
    } else {
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
    }
    const savePayload = {
      user_id: session.user.id,
      course_id: selectedCourseId,
      ...normalized,
      evaluation_template_id: evaluationTemplate?.id || null,
      evaluation_snapshot: {
        template: evaluationTemplate ? { id: evaluationTemplate.id, name: evaluationTemplate.name } : null,
        components: items.map((item) => ({ label: item.label, name: item.name, percent: item.percent, score: toNumber(grades[item.key]) }))
      },
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
    if (!profile?.university_id || !profile?.faculty_id || !profile?.career_id || !profile?.current_cycle_id) {
      notify('error', 'Completa universidad, facultad, carrera y ciclo antes de crear cursos.')
      return null
    }
    const targetCycleId = options.cycleId || profile.current_cycle_id
    const enrollmentType = options.enrollmentType || 'regular'
    const { data, error } = await supabase.from('courses').insert({
      name: name.trim(),
      university_id: profile.university_id,
      faculty_id: profile.faculty_id,
      career_id: profile.career_id,
      cycle_id: targetCycleId,
      evaluation_template_id: getDefaultTemplateIdForProfile(profile),
      created_by: profile.id
    }).select('*, university:universities(id,name,code), faculty:faculties(id,name), career:careers(name), cycle:cycles(id,name,order_number), creator:profiles!courses_created_by_fkey(first_name,last_name,email), evaluation_template:evaluation_templates(id,name,min_passing_grade)').single()
    if (error) {
      notify('error', 'No se pudo crear el curso. Puede que ya exista para tu carrera y ciclo.')
      return null
    }
    if (options.addToMyCourses !== false && data?.id) {
      await handleAddStudentCourse(data.id, enrollmentType, { silent: true, select: options.select })
    }
    notify('success', 'Curso creado correctamente y agregado a tus cursos actuales.')
    await loadCourses()
    if (options.select && data?.id) {
      await loadCourseGrades(data.id)
    }
    return data
  }

  async function handleAddStudentCourse(courseId, enrollmentType = 'regular', options = {}) {
    if (!session?.user || !courseId) {
      notify('error', 'Selecciona un curso para agregarlo.')
      return null
    }
    const payload = {
      user_id: session.user.id,
      course_id: courseId,
      university_id: profile?.university_id || null,
      faculty_id: profile?.faculty_id || null,
      career_id: profile?.career_id || null,
      cycle_id: (availableCourses.find((c) => c.id === courseId)?.cycle_id || courses.find((c) => c.id === courseId)?.cycle_id || null),
      enrollment_type: enrollmentType,
      status: 'visible',
      updated_at: new Date().toISOString()
    }
    const { data, error } = await supabase
      .from('student_courses')
      .upsert(payload, { onConflict: 'user_id,course_id' })
      .select('id')
      .single()
    if (error) {
      notify('error', 'No se pudo agregar el curso a tu lista. Verifica que se haya ejecutado la migración 1.0.6.')
      return null
    }
    if (!options.silent) notify('success', 'Curso agregado a Mis cursos actuales.')
    await loadCourses()
    if (options.select) await loadCourseGrades(courseId)
    return data
  }

  async function handleHideStudentCourse(course) {
    if (!session?.user || !course?.id) return
    const targetId = course.student_course_id
    let error = null
    if (targetId) {
      const result = await supabase
        .from('student_courses')
        .update({ status: 'hidden', hidden_at: new Date().toISOString(), updated_at: new Date().toISOString() })
        .eq('id', targetId)
        .eq('user_id', session.user.id)
      error = result.error
    } else {
      const result = await supabase
        .from('student_courses')
        .upsert({
          user_id: session.user.id,
          course_id: course.id,
          university_id: course.university_id || profile?.university_id || null,
          faculty_id: course.faculty_id || profile?.faculty_id || null,
          career_id: course.career_id || profile?.career_id || null,
          cycle_id: course.cycle_id || null,
          enrollment_type: course.enrollment_type || 'regular',
          status: 'hidden',
          hidden_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        }, { onConflict: 'user_id,course_id' })
      error = result.error
    }
    if (error) notify('error', getErrorMessage(error))
    else {
      notify('success', 'Curso ocultado de tu página principal.')
      if (selectedCourseId === course.id) {
        setSelectedCourseId('')
        setGrades(emptyGrades())
        setResult(null)
      }
      await loadCourses()
    }
  }

  async function handleUpdateProfile(values) {
    if (!session?.user) return
    if (!values.firstName?.trim() || !values.lastName?.trim() || !values.universityId || !values.facultyId || !values.careerId || !values.cycleId) {
      notify('error', 'Completa nombres, apellidos, universidad, facultad, carrera y ciclo.')
      return
    }
    const email = session.user.email || profile?.email || ''
    const payload = {
      id: session.user.id,
      email,
      first_name: values.firstName.trim(),
      last_name: values.lastName.trim(),
      full_name: `${values.firstName.trim()} ${values.lastName.trim()}`.trim(),
      university_id: values.universityId,
      faculty_id: values.facultyId,
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
    const [profilesRes, coursesRes, calculationsRes, loginsRes, studentCoursesRes, universitiesRes, facultiesRes, templatesRes, componentsRes] = await Promise.all([
      supabase.from('profiles').select('*, university:universities(id,name,code), faculty:faculties(id,name), career:careers(name), cycle:cycles(name,order_number)').order('created_at', { ascending: false }),
      supabase.from('courses').select('*, university:universities(id,name,code), faculty:faculties(id,name), career:careers(name), cycle:cycles(name,order_number), creator:profiles!courses_created_by_fkey(first_name,last_name,email), evaluation_template:evaluation_templates(id,name)').order('created_at', { ascending: false }),
      supabase.from('calculation_history').select('*, profile:profiles(first_name,last_name,email,career_id,current_cycle_id, university:universities(name,code), faculty:faculties(name), career:careers(name), cycle:cycles(name)), course:courses(name, university:universities(name,code), faculty:faculties(name), career:careers(name), cycle:cycles(name)), evaluation_template:evaluation_templates(name)').order('created_at', { ascending: false }).limit(200),
      supabase.from('login_activity').select('*, profile:profiles(first_name,last_name,email), university:universities(name,code), faculty:faculties(name), career:careers(name), cycle:cycles(name)').order('login_at', { ascending: false }).limit(300),
      supabase.from('student_courses').select('*, profile:profiles(first_name,last_name,email, university:universities(name,code), faculty:faculties(name), career:careers(name), cycle:cycles(name)), course:courses(name, university:universities(name,code), faculty:faculties(name), career:careers(name), cycle:cycles(name))').order('created_at', { ascending: false }).limit(500),
      supabase.from('universities').select('*').order('name'),
      supabase.from('faculties').select('*, university:universities(id,name,code)').order('name'),
      supabase.from('evaluation_templates').select('*, university:universities(name,code), faculty:faculties(name), career:careers(name), course:courses(name), creator:profiles!evaluation_templates_created_by_fkey(first_name,last_name,email)').order('created_at', { ascending: false }),
      supabase.from('evaluation_components').select('*').order('component_order')
    ])

    setAdminData({
      users: profilesRes.data || [],
      courses: coursesRes.data || [],
      calculations: calculationsRes.data || [],
      logins: loginsRes.data || [],
      studentCourses: studentCoursesRes.data || [],
      universities: universitiesRes.data || [],
      faculties: facultiesRes.data || [],
      templates: templatesRes.data || [],
      components: componentsRes.data || []
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

  async function createEvaluationTemplate(payload) {
    const { error } = await supabase.from('evaluation_templates').insert({
      name: payload.name?.trim(),
      description: payload.description?.trim() || null,
      university_id: payload.universityId || null,
      faculty_id: payload.facultyId || null,
      career_id: payload.careerId || null,
      course_id: payload.courseId || null,
      min_passing_grade: Number(payload.minPassingGrade || 11),
      status: 'draft',
      created_by: profile?.id || null
    })
    if (error) notify('error', getErrorMessage(error))
    else {
      notify('success', 'Método de evaluación creado. Agrega componentes hasta sumar 100% y luego actívalo.')
      await loadAdminData()
    }
  }

  async function updateEvaluationTemplate(templateId, payload) {
    const { error } = await supabase.from('evaluation_templates').update(payload).eq('id', templateId)
    if (error) notify('error', getErrorMessage(error))
    else {
      notify('success', 'Método actualizado correctamente.')
      await loadAdminData()
    }
  }

  async function createEvaluationComponent(payload) {
    const { error } = await supabase.from('evaluation_components').insert({
      template_id: payload.templateId,
      short_name: payload.shortName?.trim(),
      name: payload.name?.trim(),
      unit_name: payload.unitName?.trim() || null,
      weight_percent: Number(payload.weightPercent || 0),
      component_order: Number(payload.componentOrder || 1),
      status: 'active'
    })
    if (error) notify('error', getErrorMessage(error))
    else {
      notify('success', 'Componente agregado correctamente.')
      await loadAdminData()
    }
  }

  async function updateEvaluationComponent(componentId, payload) {
    const { error } = await supabase.from('evaluation_components').update(payload).eq('id', componentId)
    if (error) notify('error', getErrorMessage(error))
    else {
      notify('success', 'Componente actualizado correctamente.')
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
        {!session && !guestMode && (screen === 'login' || screen === 'welcome') && (
          <Login
            onSubmit={handleLogin}
            onReset={handlePasswordReset}
            onGoogle={handleGoogleLogin}
            onMicrosoft={handleMicrosoftLogin}
            onRegister={() => setScreen('register')}
            onGuest={enterGuestMode}
          />
        )}
        {!session && !guestMode && screen === 'register' && (
          <Register universities={universities} faculties={faculties} careers={careers} cycles={cycles} onSubmit={handleRegister} onBack={() => setScreen('login')} />
        )}
        {session && screen === 'complete-profile' && (
          <CompleteProfile universities={universities} faculties={faculties} careers={careers} cycles={cycles} profile={profile} onSubmit={handleUpdateProfile} />
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
                evaluationTemplate={null}
                evaluationItems={normalizeEvaluationComponents([], settings)}
              />
            )}
            {guestMode && screen === 'guest-settings' && <SettingsScreen settings={settings} onSave={(s) => handleSaveSettings(s, true)} guestMode />}
            {session && screen === 'dashboard' && <Dashboard profile={profile} courses={courses} history={history} setScreen={setScreen} onSelectCourse={(id) => { loadCourseGrades(id); setScreen('calculator') }} />}
            {session && screen === 'courses' && <CoursesScreen courses={courses} availableCourses={availableCourses} cycles={cycles} profile={profile} onCreate={handleCreateCourse} onAdd={handleAddStudentCourse} onHide={handleHideStudentCourse} onSelect={(id) => { loadCourseGrades(id); setScreen('calculator') }} />}
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
                evaluationTemplate={evaluationTemplate}
                evaluationItems={evaluationItems}
              />
            )}
            {session && screen === 'history' && <HistoryScreen history={history} />}
            {session && screen === 'settings' && <SettingsScreen settings={settings} onSave={handleSaveSettings} />}
            {session && screen === 'profile' && <ProfileScreen profile={profile} universities={universities} faculties={faculties} careers={careers} cycles={cycles} onSave={handleUpdateProfile} />}
            {screen === 'about' && <About />}
            {screen === 'more' && <MoreScreen isAdmin={isAdmin} guestMode={guestMode} setScreen={setScreen} onSignOut={async () => { setGuestMode(false); await supabase.auth.signOut() }} />}
            {session && isAdmin && screen === 'admin-dashboard' && <AdminDashboard data={adminData} onLoad={loadAdminData} setScreen={setScreen} />}
            {session && isAdmin && screen === 'admin-users' && <AdminUsers data={adminData} onLoad={loadAdminData} onToggle={toggleUserStatus} onRole={changeUserRole} />}
            {session && isAdmin && screen === 'admin-courses' && <AdminCourses data={adminData} onLoad={loadAdminData} onUpdate={updateCourseAdmin} />}
            {session && isAdmin && screen === 'admin-calculations' && <AdminCalculations data={adminData} onLoad={loadAdminData} />}
            {session && isAdmin && screen === 'admin-evaluations' && <AdminEvaluations data={adminData} onLoad={loadAdminData} onCreateTemplate={createEvaluationTemplate} onUpdateTemplate={updateEvaluationTemplate} onCreateComponent={createEvaluationComponent} onUpdateComponent={updateEvaluationComponent} />}
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

function Login({ onSubmit, onReset, onGoogle, onMicrosoft, onRegister, onGuest }) {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const passwordRef = useRef(null)
  const submitLogin = () => onSubmit(email, password)
  return (
    <AuthCard title="Mi Nota Final" className="login-card">
      <p className="auth-subtitle">Ingresa tus datos o continúa con una cuenta social.</p>
      <input
        className="input"
        type="email"
        placeholder="Correo electrónico"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        onKeyDown={(e) => { if (e.key === 'Enter') passwordRef.current?.focus() }}
      />
      <input
        ref={passwordRef}
        className="input"
        type="password"
        placeholder="Contraseña"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        onKeyDown={(e) => { if (e.key === 'Enter') submitLogin() }}
      />
      <button className="btn primary" onClick={submitLogin}>Ingresar</button>
      <SocialButton provider="google" onClick={onGoogle}>Continuar con Google</SocialButton>
      <SocialButton provider="microsoft" onClick={onMicrosoft}>Continuar con Microsoft</SocialButton>
      <div className="auth-links">
        <button className="btn link" onClick={() => onReset(email)}>Olvidé mi contraseña</button>
        <button className="btn link" onClick={onRegister}>Crear cuenta nueva</button>
      </div>
      <button className="btn ghost full" onClick={onGuest}>Continuar como invitado</button>
      <p className="hint">Si acabas de registrarte, confirma tu correo antes de iniciar sesión. Revisa también spam o correo no deseado.</p>
    </AuthCard>
  )
}

function Register({ universities, faculties, careers, cycles, onSubmit, onBack }) {
  const [form, setForm] = useState(emptyAuth)
  const filteredFaculties = faculties.filter((faculty) => !form.universityId || faculty.university_id === form.universityId)
  const filteredCareers = careers.filter((career) => !form.facultyId || career.faculty_id === form.facultyId)
  const update = (key, value) => {
    setForm((prev) => {
      const next = { ...prev, [key]: value }
      if (key === 'universityId') {
        next.facultyId = ''
        next.careerId = ''
      }
      if (key === 'facultyId') next.careerId = ''
      return next
    })
  }
  return (
    <AuthCard title="Crear cuenta" onBack={onBack}>
      <div className="grid two">
        <input className="input" placeholder="Nombres" value={form.firstName} onChange={(e) => update('firstName', e.target.value)} />
        <input className="input" placeholder="Apellidos" value={form.lastName} onChange={(e) => update('lastName', e.target.value)} />
      </div>
      <input className="input" type="email" placeholder="Correo electrónico" value={form.email} onChange={(e) => update('email', e.target.value)} />
      <select className="input" value={form.universityId} onChange={(e) => update('universityId', e.target.value)}>
        <option value="">Selecciona tu universidad</option>
        {universities.map((university) => <option key={university.id} value={university.id}>{university.name}</option>)}
      </select>
      <select className="input" value={form.facultyId} onChange={(e) => update('facultyId', e.target.value)} disabled={!form.universityId}>
        <option value="">Selecciona tu facultad</option>
        {filteredFaculties.map((faculty) => <option key={faculty.id} value={faculty.id}>{faculty.name}</option>)}
      </select>
      <select className="input" value={form.careerId} onChange={(e) => update('careerId', e.target.value)} disabled={!form.facultyId}>
        <option value="">Selecciona tu carrera</option>
        {filteredCareers.map((career) => <option key={career.id} value={career.id}>{career.name}</option>)}
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
      <button className="btn link" onClick={onBack}>Ya tengo cuenta</button>
    </AuthCard>
  )
}

function AuthCard({ title, children, onBack, className = '' }) {
  return (
    <section className={`auth-card ${className}`.trim()}>
      {onBack && <button className="back" onClick={onBack}>← Volver</button>}
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

function Dashboard({ profile, courses, history, setScreen, onSelectCourse }) {
  return (
    <div className="page fade-in">
      <div className="hero-panel">
        <div>
          <p className="eyebrow">Panel principal</p>
          <h1>Hola, {firstWord(profile?.first_name || profile?.full_name)}</h1>
          <p>{academicContext(profile)}</p>
        </div>
        <div className="hero-actions">
          <button className="btn secondary small" onClick={() => setScreen('profile')}>🔄 Cambiar perfil académico</button>
          <button className="btn primary small" onClick={() => setScreen('calculator')}>🧮 Calcular</button>
        </div>
      </div>
      <div className="cards stats-grid">
        <StatCard icon="📚" label="Mis cursos actuales" value={courses.length} />
        <StatCard icon="📊" label="Resultados guardados" value={history.length} />
        <StatCard icon="🏛️" label="Universidad" value={profile?.university?.code || '—'} />
      </div>
      <Card>
        <div className="section-title">
          <span>📌</span>
          <h3>Resumen de tus notas</h3>
          <button className="btn primary small" onClick={() => setScreen('calculator')}>Calcular</button>
        </div>
        {courses.length === 0 && (
          <Empty text="Aún no agregaste cursos a tu lista. Entra a Cursos y agrega solo los que estás llevando." compact />
        )}
        {courses.length > 0 && (
          <div className="student-summary-list">
            {courses.map((course) => {
              const latest = latestHistoryForCourse(history, course.id)
              return (
                <div className="student-summary-row" key={course.id}>
                  <div>
                    <h3>{course.name}</h3>
                    <p>{courseCycleName(course)} · {formatEnrollmentType(course.enrollment_type)}</p>
                  </div>
                  <div className="summary-status">
                    <b>{latest ? formatNumber(latest.current_average) : 'Pendiente'}</b>
                    <span>{latest?.status || 'Sin notas'}</span>
                  </div>
                  <button className="btn secondary small" onClick={() => onSelectCourse(course.id)}>Calcular</button>
                </div>
              )
            })}
          </div>
        )}
      </Card>
      <div className="grid two">
        <ActionCard title="Mis cursos" text="Agrega cursos regulares, arrastrados, adelantados, electivos u otros." button="Ver cursos" onClick={() => setScreen('courses')} />
        <ActionCard title="Historial" text="Revisa los cálculos que decidiste guardar." button="Ver historial" onClick={() => setScreen('history')} />
      </div>
      <Footer />
    </div>
  )
}

function CoursesScreen({ courses, availableCourses, cycles, profile, onCreate, onAdd, onHide, onSelect }) {
  const [cycleId, setCycleId] = useState(profile?.current_cycle_id || '')
  const [courseId, setCourseId] = useState('')
  const [enrollmentType, setEnrollmentType] = useState('regular')
  const [showNewCourse, setShowNewCourse] = useState(false)
  const [name, setName] = useState('')

  const filteredAvailable = (availableCourses || []).filter((course) => !cycleId || course.cycle_id === cycleId)
  const selectedAvailable = filteredAvailable.find((course) => course.id === courseId)

  async function addSelectedCourse() {
    if (!courseId) return
    const added = await onAdd(courseId, enrollmentType)
    if (added) {
      setCourseId('')
      setEnrollmentType('regular')
    }
  }

  async function createAndAdd() {
    const created = await onCreate(name, { cycleId, enrollmentType, select: true })
    if (created?.id) {
      setName('')
      setShowNewCourse(false)
      onSelect(created.id)
    }
  }

  return (
    <div className="page fade-in">
      <Header title="Mis cursos" subtitle={academicContext(profile)} />
      <Card>
        <h3>Agregar curso a mi lista</h3>
        <p className="hint">Puedes agregar cursos de tu ciclo actual, cursos arrastrados, adelantados, electivos u otros. Tu página principal mostrará solo estos cursos.</p>
        <div className="grid three">
          <select className="input" value={cycleId} onChange={(e) => { setCycleId(e.target.value); setCourseId('') }}>
            <option value="">Todos los ciclos</option>
            {cycles.map((cycle) => <option key={cycle.id} value={cycle.id}>{cycle.name}</option>)}
          </select>
          <select className="input" value={courseId} onChange={(e) => setCourseId(e.target.value)}>
            <option value="">Selecciona curso</option>
            {filteredAvailable.map((course) => <option key={course.id} value={course.id}>{courseCycleName(course)} · {course.name}</option>)}
          </select>
          <select className="input" value={enrollmentType} onChange={(e) => setEnrollmentType(e.target.value)}>
            <option value="regular">Regular</option>
            <option value="arrastrado">Arrastrado</option>
            <option value="adelantado">Adelantado</option>
            <option value="electivo">Electivo</option>
            <option value="otro">Otro</option>
          </select>
        </div>
        {selectedAvailable && <p className="hint">Curso seleccionado: {selectedAvailable.name} · Creado por: {creatorName(selectedAvailable)}</p>}
        <div className="action-row left">
          <button className="btn primary small" disabled={!courseId} onClick={addSelectedCourse}>➕ Agregar a Mis cursos</button>
          <button className="btn ghost small" onClick={() => setShowNewCourse(!showNewCourse)}>+ Crear curso no listado</button>
        </div>
        {showNewCourse && (
          <div className="inline-new-course">
            <input className="input" placeholder="Nombre del nuevo curso" value={name} onChange={(e) => setName(e.target.value)} />
            <p className="hint">Se creará para tu carrera y para el ciclo seleccionado. También quedará agregado a Mis cursos.</p>
            <div className="action-row left">
              <button className="btn primary small" onClick={createAndAdd}>➕ Crear y usar</button>
              <button className="btn ghost small" onClick={() => { setShowNewCourse(false); setName('') }}>Cancelar</button>
            </div>
          </div>
        )}
      </Card>
      <Card>
        <div className="section-title">
          <span>📚</span>
          <h3>Mis cursos actuales</h3>
        </div>
        {courses.length === 0 && <Empty text="Aún no agregaste cursos. Usa el buscador superior para seleccionar solo los cursos que llevas." compact />}
        <div className="course-list">
          {courses.map((course) => (
            <div key={course.id} className="student-course-card">
              <div>
                <h3>{course.name}</h3>
                <p>{courseCycleName(course)} · <b>{formatEnrollmentType(course.enrollment_type)}</b> · {course.university?.code || ''} · Creado por: {creatorName(course)}</p>
              </div>
              <div className="action-row left compact-actions">
                <button className="btn secondary small" onClick={() => onSelect(course.id)}>Calcular</button>
                <button className="btn ghost small" onClick={() => onHide(course)}>Ocultar</button>
              </div>
            </div>
          ))}
        </div>
      </Card>
    </div>
  )
}

function CalculatorScreen({ title, subtitle, courses, selectedCourseId, onSelectCourse, onCreateCourse, grades, setGrades, settings, result, onCalculate, onGenerate, onClean, onSave, activeCourse, guestMode, evaluationTemplate, evaluationItems }) {
  const items = evaluationItems?.length ? evaluationItems : normalizeEvaluationComponents([], settings)
  const groups = [...new Set(items.map((item) => item.group || 'Evaluaciones'))]
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
      {evaluationTemplate && <Card><p className="hint"><b>Método de evaluación:</b> {evaluationTemplate.name}</p></Card>}
      {groups.map((group) => (
        <EvaluationSection key={group} title={group} items={items.filter((item) => item.group === group)} grades={grades} settings={settings} updateGrade={updateGrade} flexible />
      ))}
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
      {courses.length === 0 && <p className="hint">Aún no tienes cursos actuales. Agrega tus cursos desde la sección Cursos.</p>}
      {showNewCourse && (
        <div className="inline-new-course">
          <input className="input" placeholder="Nombre del nuevo curso" value={name} onChange={(e) => setName(e.target.value)} />
          <div className="action-row left">
            <button className="btn primary small" onClick={createAndSelect}>➕ Agregar y usar</button>
            <button className="btn ghost small" onClick={() => { setShowNewCourse(false); setName('') }}>Cancelar</button>
          </div>
          <p className="hint">El curso se compartirá con estudiantes de tu misma carrera y ciclo actual.</p>
        </div>
      )}
    </Card>
  )
}

function EvaluationSection({ title, items, grades, settings, updateGrade, flexible })  {
  return (
    <Card>
      <div className="section-title"><span>▦</span><h3>{title}</h3></div>
      <div className="eval-grid">
        {items.map((item) => (
          <div className="eval-card" key={item.key}>
            <div className="eval-head"><strong>{item.label}</strong><span>{formatPercent(flexible ? item.percent : settings[item.percentKey])}%</span></div>
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

function ProfileScreen({ profile, universities, faculties, careers, cycles, onSave }) {
  return (
    <div className="page fade-in">
      <Header title="Perfil" subtitle="Actualiza tus datos personales, universidad, facultad, carrera y ciclo actual." />
      <Card>
        <ProfileForm profile={profile} universities={universities} faculties={faculties} careers={careers} cycles={cycles} onSave={onSave} buttonText="Guardar perfil" />
      </Card>
    </div>
  )
}

function ProfileForm({ profile, universities, faculties, careers, cycles, onSave, buttonText = 'Guardar perfil' }) {
  const [form, setForm] = useState({
    firstName: profile?.first_name || '',
    lastName: profile?.last_name || '',
    universityId: profile?.university_id || '',
    facultyId: profile?.faculty_id || '',
    careerId: profile?.career_id || '',
    cycleId: profile?.current_cycle_id || ''
  })
  useEffect(() => {
    setForm({
      firstName: profile?.first_name || '',
      lastName: profile?.last_name || '',
      universityId: profile?.university_id || '',
      facultyId: profile?.faculty_id || '',
      careerId: profile?.career_id || '',
      cycleId: profile?.current_cycle_id || ''
    })
  }, [profile?.id, profile?.first_name, profile?.last_name, profile?.university_id, profile?.faculty_id, profile?.career_id, profile?.current_cycle_id])
  const filteredFaculties = (faculties || []).filter((faculty) => !form.universityId || faculty.university_id === form.universityId)
  const filteredCareers = (careers || []).filter((career) => !form.facultyId || career.faculty_id === form.facultyId)
  const update = (key, value) => {
    setForm((prev) => {
      const next = { ...prev, [key]: value }
      if (key === 'universityId') {
        next.facultyId = ''
        next.careerId = ''
      }
      if (key === 'facultyId') next.careerId = ''
      return next
    })
  }
  return (
    <div className="stack">
      <div className="grid two">
        <input className="input" placeholder="Nombres" value={form.firstName} onChange={(e) => update('firstName', e.target.value)} />
        <input className="input" placeholder="Apellidos" value={form.lastName} onChange={(e) => update('lastName', e.target.value)} />
      </div>
      {profile?.email && <input className="input" value={profile.email} disabled />}
      <select className="input" value={form.universityId} onChange={(e) => update('universityId', e.target.value)}>
        <option value="">Selecciona universidad</option>
        {(universities || []).map((university) => <option key={university.id} value={university.id}>{university.name}</option>)}
      </select>
      <select className="input" value={form.facultyId} onChange={(e) => update('facultyId', e.target.value)} disabled={!form.universityId}>
        <option value="">Selecciona facultad</option>
        {filteredFaculties.map((faculty) => <option key={faculty.id} value={faculty.id}>{faculty.name}</option>)}
      </select>
      <select className="input" value={form.careerId} onChange={(e) => update('careerId', e.target.value)} disabled={!form.facultyId}>
        <option value="">Selecciona carrera</option>
        {filteredCareers.map((career) => <option key={career.id} value={career.id}>{career.name}</option>)}
      </select>
      <select className="input" value={form.cycleId} onChange={(e) => update('cycleId', e.target.value)}>
        <option value="">Selecciona ciclo</option>
        {(cycles || []).map((cycle) => <option key={cycle.id} value={cycle.id}>{cycle.name}</option>)}
      </select>
      <p className="hint">Puedes cambiar de universidad, facultad, carrera o ciclo cuando sea necesario. El sistema conservará el historial.</p>
      <button className="btn primary" onClick={() => onSave(form)}>{buttonText}</button>
    </div>
  )
}

function CompleteProfile({ profile, universities, faculties, careers, cycles, onSubmit }) {
  return (
    <div className="page fade-in">
      <Card className="complete-profile-card">
        <img className="mini-logo" src="/logo.png" alt="Mi Nota Final" />
        <h1>Completa tu perfil</h1>
        <p className="muted">Antes de continuar, indica tu universidad, facultad, carrera y ciclo actual. Luego podrás agregar los cursos que realmente estás llevando.</p>
        <ProfileForm profile={profile || {}} universities={universities} faculties={faculties} careers={careers} cycles={cycles} onSave={onSubmit} buttonText="Guardar y continuar" />
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
  const studentCourses = data?.studentCourses || []
  const todayLogins = logins.filter((login) => login.login_date === todayISO())
  const uniqueToday = new Set(todayLogins.map((login) => login.user_id)).size
  const hourly = groupByHour(todayLogins)
  const byCareer = countBy(users, (u) => u.career?.name || 'Sin carrera')
  const byCycle = countBy(users, (u) => u.cycle?.name || 'Sin ciclo')
  const distribution = buildDistribution(users, courses, calculations)
  const byEnrollmentType = countBy(studentCourses.filter((item) => item.status === 'visible'), (item) => formatEnrollmentType(item.enrollment_type))

  return (
    <div className="page fade-in">
      <Header title="Panel administrador" subtitle="Reportes generales y actividad del sistema." />
      <div className="cards stats-grid">
        <StatCard icon="👥" label="Usuarios registrados" value={users.length} />
        <StatCard icon="✅" label="Usuarios activos hoy" value={uniqueToday} />
        <StatCard icon="🔐" label="Accesos del día" value={todayLogins.length} />
        <StatCard icon="📚" label="Cursos creados" value={courses.length} />
        <StatCard icon="🧾" label="Cursos en listas de alumnos" value={studentCourses.length} />
        <StatCard icon="📊" label="Cálculos guardados" value={calculations.length} />
      </div>
      <div className="grid two">
        <Card><h3>Accesos por hora de hoy</h3><BarChart data={hourly} /></Card>
        <Card><h3>Usuarios por carrera</h3><BarChart data={byCareer} /></Card>
        <Card><h3>Usuarios por ciclo</h3><BarChart data={byCycle} /></Card>
        <Card><h3>Cursos por tipo de matrícula</h3><BarChart data={byEnrollmentType} /></Card>
        <Card><h3>Usuarios que iniciaron sesión hoy</h3><RecentLogins items={todayLogins} /></Card>
      </div>
      <Card>
        <h3>Distribución por carrera y ciclo</h3>
        <ResponsiveTable rows={distribution} columns={['carrera', 'ciclo', 'usuarios', 'cursos', 'calculos']} />
      </Card>
      <div className="grid three">
        <button className="btn secondary" onClick={() => setScreen('admin-users')}>👥 Gestionar usuarios</button>
        <button className="btn secondary" onClick={() => setScreen('admin-courses')}>📚 Gestionar cursos</button>
        <button className="btn secondary" onClick={() => setScreen('admin-calculations')}>📊 Ver cálculos</button>
        <button className="btn secondary" onClick={() => setScreen('admin-evaluations')}>🧩 Métodos de evaluación</button>
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
      <div className="admin-list admin-scroll-list">
        {users.map((user) => (
          <Card key={user.id}>
            <div className="list-row">
              <div>
                <h3>{fullName(user)}</h3>
                <p>{user.email} · {user.career?.name || 'Sin carrera'} · {user.cycle?.name || 'Sin ciclo'}</p>
              </div>
              <span className={`badge ${user.status}`}>{formatStatus(user.status)}</span>
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
    const matchesQ = `${course.name} ${creatorName(course)}`.toLowerCase().includes(filters.q.toLowerCase())
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
      <div className="admin-list admin-scroll-list">
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
          <p>{course.career?.name || 'Sin carrera'} · {course.cycle?.name || 'Sin ciclo'} · Creado por: {creatorName(course)}</p>
        </div>
        <span className={`badge ${course.status}`}>{formatStatus(course.status)}</span>
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
      <div className="admin-list admin-scroll-list">
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

function AdminEvaluations({ data, onLoad, onCreateTemplate, onUpdateTemplate, onCreateComponent, onUpdateComponent }) {
  useEffect(() => { onLoad() }, []) // eslint-disable-line react-hooks/exhaustive-deps
  const templates = data?.templates || []
  const components = data?.components || []
  const universities = data?.universities || []
  const faculties = data?.faculties || []
  const careers = unique((data?.courses || []).map((c) => c.career).filter(Boolean))
  const courses = data?.courses || []
  const [newTemplate, setNewTemplate] = useState({ name: '', description: '', universityId: '', facultyId: '', careerId: '', courseId: '', minPassingGrade: 11 })
  const [newComponent, setNewComponent] = useState({ templateId: '', shortName: '', name: '', unitName: '', weightPercent: '', componentOrder: '' })

  const filteredFaculties = faculties.filter((f) => !newTemplate.universityId || f.university_id === newTemplate.universityId)
  const filteredCourses = courses.filter((c) => (!newTemplate.universityId || c.university_id === newTemplate.universityId) && (!newTemplate.facultyId || c.faculty_id === newTemplate.facultyId))

  function componentsFor(templateId) {
    return components.filter((item) => item.template_id === templateId).sort((a, b) => Number(a.component_order || 0) - Number(b.component_order || 0))
  }

  function totalFor(templateId) {
    return componentsFor(templateId).filter((item) => item.status !== 'inactive').reduce((sum, item) => sum + Number(item.weight_percent || 0), 0)
  }

  async function saveTemplate() {
    if (!newTemplate.name.trim()) return
    await onCreateTemplate(newTemplate)
    setNewTemplate({ name: '', description: '', universityId: '', facultyId: '', careerId: '', courseId: '', minPassingGrade: 11 })
  }

  async function saveComponent() {
    if (!newComponent.templateId || !newComponent.shortName.trim() || !newComponent.name.trim()) return
    await onCreateComponent(newComponent)
    setNewComponent({ templateId: newComponent.templateId, shortName: '', name: '', unitName: '', weightPercent: '', componentOrder: '' })
  }

  return (
    <div className="page fade-in">
      <Header title="Métodos de evaluación" subtitle="Configura las calificaciones por universidad, carrera o curso." />
      <Card>
        <h3>Nuevo método de evaluación</h3>
        <div className="grid three">
          <input className="input" placeholder="Nombre del método" value={newTemplate.name} onChange={(e) => setNewTemplate({ ...newTemplate, name: e.target.value })} />
          <input className="input" placeholder="Descripción" value={newTemplate.description} onChange={(e) => setNewTemplate({ ...newTemplate, description: e.target.value })} />
          <input className="input" inputMode="decimal" placeholder="Nota mínima" value={newTemplate.minPassingGrade} onChange={(e) => setNewTemplate({ ...newTemplate, minPassingGrade: e.target.value })} />
        </div>
        <div className="grid three">
          <select className="input" value={newTemplate.universityId} onChange={(e) => setNewTemplate({ ...newTemplate, universityId: e.target.value, facultyId: '', careerId: '', courseId: '' })}>
            <option value="">Universidad general</option>
            {universities.map((u) => <option key={u.id} value={u.id}>{u.code || u.name}</option>)}
          </select>
          <select className="input" value={newTemplate.facultyId} onChange={(e) => setNewTemplate({ ...newTemplate, facultyId: e.target.value, careerId: '', courseId: '' })}>
            <option value="">Facultad general</option>
            {filteredFaculties.map((f) => <option key={f.id} value={f.id}>{f.name}</option>)}
          </select>
          <select className="input" value={newTemplate.courseId} onChange={(e) => setNewTemplate({ ...newTemplate, courseId: e.target.value })}>
            <option value="">Todos los cursos del contexto</option>
            {filteredCourses.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
        </div>
        <button className="btn primary small" onClick={saveTemplate}>Crear método</button>
      </Card>

      <Card>
        <h3>Agregar componente</h3>
        <div className="grid three">
          <select className="input" value={newComponent.templateId} onChange={(e) => setNewComponent({ ...newComponent, templateId: e.target.value })}>
            <option value="">Selecciona método</option>
            {templates.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
          </select>
          <input className="input" placeholder="Código corto: PC1 / FK1-U1" value={newComponent.shortName} onChange={(e) => setNewComponent({ ...newComponent, shortName: e.target.value })} />
          <input className="input" placeholder="Nombre completo" value={newComponent.name} onChange={(e) => setNewComponent({ ...newComponent, name: e.target.value })} />
          <input className="input" placeholder="Unidad / Grupo" value={newComponent.unitName} onChange={(e) => setNewComponent({ ...newComponent, unitName: e.target.value })} />
          <input className="input" inputMode="decimal" placeholder="Porcentaje" value={newComponent.weightPercent} onChange={(e) => setNewComponent({ ...newComponent, weightPercent: e.target.value })} />
          <input className="input" inputMode="numeric" placeholder="Orden" value={newComponent.componentOrder} onChange={(e) => setNewComponent({ ...newComponent, componentOrder: e.target.value })} />
        </div>
        <button className="btn secondary small" onClick={saveComponent}>Agregar componente</button>
      </Card>

      <div className="admin-list admin-scroll-list">
        {templates.map((template) => {
          const total = totalFor(template.id)
          return (
            <Card key={template.id}>
              <div className="list-row">
                <div>
                  <h3>{template.name}</h3>
                  <p>{template.university?.code || 'General'} · {template.course?.name || template.career?.name || 'Contexto general'} · Nota mínima: {formatNumber(template.min_passing_grade)}</p>
                </div>
                <span className={`badge ${template.status}`}>{formatStatus(template.status)}</span>
              </div>
              <p className="hint">Total componentes activos: <b className={Math.abs(total - 100) <= 0.01 ? 'ok' : 'bad'}>{formatPercent(total)}%</b></p>
              <div className="component-list">
                {componentsFor(template.id).map((component) => (
                  <div key={component.id} className="component-row">
                    <span>{component.component_order}. <b>{component.short_name}</b> — {component.name}</span>
                    <span>{formatPercent(component.weight_percent)}%</span>
                    <button className="btn ghost small" onClick={() => onUpdateComponent(component.id, { status: component.status === 'active' ? 'inactive' : 'active' })}>{component.status === 'active' ? 'Desactivar' : 'Activar'}</button>
                  </div>
                ))}
              </div>
              <div className="action-row left">
                <button className="btn secondary small" disabled={Math.abs(total - 100) > 0.01} onClick={() => onUpdateTemplate(template.id, { status: 'active' })}>Activar</button>
                <button className="btn ghost small" onClick={() => onUpdateTemplate(template.id, { status: template.status === 'inactive' ? 'draft' : 'inactive' })}>{template.status === 'inactive' ? 'Restaurar' : 'Inactivar'}</button>
              </div>
            </Card>
          )
        })}
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
  return null
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
