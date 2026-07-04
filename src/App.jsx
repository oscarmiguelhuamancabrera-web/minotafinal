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
const APP_VERSION = '1.2.1'

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

function cleanText(value = '') {
  return String(value || '').trim().replace(/\s+/g, ' ')
}

function removeLeadingDuplicateName(fullName = '') {
  const parts = cleanText(fullName).split(' ').filter(Boolean)
  if (parts.length >= 2 && parts[0].toLowerCase() === parts[1].toLowerCase()) {
    return parts.slice(1).join(' ')
  }
  return cleanText(fullName)
}

function splitFullName(fullName = '') {
  const normalized = removeLeadingDuplicateName(fullName)
  const parts = normalized
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

function getGoogleProfileName(metadata = {}, fallbackEmail = '') {
  const givenName = cleanText(metadata.given_name || metadata.first_name || '')
  const familyName = cleanText(metadata.family_name || metadata.last_name || '')
  const rawFullName = cleanText(
    metadata.full_name ||
    metadata.name ||
    metadata.display_name ||
    `${givenName} ${familyName}` ||
    fallbackEmail.split('@')[0] ||
    ''
  )
  const fullName = removeLeadingDuplicateName(rawFullName)
  const parsed = splitFullName(fullName)

  const familyLooksLikeFullName = Boolean(
    familyName &&
    givenName &&
    familyName.toLowerCase().startsWith(`${givenName.toLowerCase()} `)
  )

  const familyEqualsFullName = Boolean(
    familyName &&
    fullName &&
    familyName.toLowerCase() === fullName.toLowerCase()
  )

  const givenLooksDuplicated = Boolean(
    givenName &&
    fullName.toLowerCase().startsWith(`${givenName.toLowerCase()} ${givenName.toLowerCase()} `)
  )

  if (givenName && familyName && !familyLooksLikeFullName && !familyEqualsFullName && !givenLooksDuplicated) {
    return {
      firstName: removeLeadingDuplicateName(givenName),
      lastName: removeLeadingDuplicateName(familyName),
      fullName: cleanText(`${givenName} ${familyName}`)
    }
  }

  return {
    ...parsed,
    fullName
  }
}


function normalizeProfileNameFields(profile = {}) {
  const first = cleanText(profile.first_name || profile.firstName || '')
  const last = cleanText(profile.last_name || profile.lastName || '')
  const full = removeLeadingDuplicateName(cleanText(profile.full_name || profile.fullName || `${first} ${last}`))

  if (first && last && last.toLowerCase().startsWith(`${first.toLowerCase()} `)) {
    return { firstName: first, lastName: cleanText(last.slice(first.length)) }
  }

  if (!first && !last && full) return splitFullName(full)
  if (first && !last && full) {
    const parsed = splitFullName(full)
    return { firstName: first, lastName: parsed.lastName || '' }
  }
  return { firstName: first, lastName: last }
}

function normalizeCourseName(value = '') {
  return cleanText(value)
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9\s]/g, '')
}

function findSimilarCourses(name = '', courseList = []) {
  const query = normalizeCourseName(name)
  if (!query || query.length < 3) return []
  const queryTokens = query.split(/\s+/).filter(Boolean)
  return (courseList || [])
    .map((course) => {
      const candidate = normalizeCourseName(course.name)
      const candidateTokens = candidate.split(/\s+/).filter(Boolean)
      let score = 0
      if (candidate === query) score += 100
      if (candidate.includes(query) || query.includes(candidate)) score += 45
      score += queryTokens.filter((token) => candidateTokens.some((ct) => ct.startsWith(token) || token.startsWith(ct))).length * 18
      return { course, score }
    })
    .filter((item) => item.score >= 18)
    .sort((a, b) => b.score - a.score)
    .slice(0, 5)
    .map((item) => item.course)
}

function eventLabel(type) {
  const labels = {
    course_added: 'Curso agregado',
    course_hidden: 'Curso ocultado',
    course_requested: 'Curso solicitado',
    courses_bulk_added: 'Cursos agregados masivamente',
    calculation_done: 'Cálculo realizado',
    result_saved: 'Resultado guardado',
    settings_updated: 'Ajustes modificados',
    profile_updated: 'Perfil actualizado',
    template_selected: 'Plantilla seleccionada'
  }
  return labels[type] || type || 'Evento'
}


function normalizeForMatching(value = '') {
  return String(value || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9ñ\s]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
}

function daysSince(value) {
  if (!value) return null
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return null
  const diff = Date.now() - date.getTime()
  return Math.max(0, Math.floor(diff / (1000 * 60 * 60 * 24)))
}

function latestDate(a, b) {
  if (!a) return b || null
  if (!b) return a || null
  return new Date(a) > new Date(b) ? a : b
}

function parseGradeText(text = '', items = []) {
  const detected = []
  const ignored = []
  const normalizedItems = (items || []).map((item) => ({
    ...item,
    token: normalizeForMatching(`${item.label || ''} ${item.name || ''}`)
  }))
  const lines = String(text || '')
    .split(/\n+/)
    .map((line) => cleanText(line))
    .filter(Boolean)

  const aliases = [
    { code: 'PC1', keys: ['pc1', 'practica calificada 1', 'práctica calificada 1'] },
    { code: 'PC2', keys: ['pc2', 'practica calificada 2', 'práctica calificada 2'] },
    { code: 'PC3', keys: ['pc3', 'practica calificada 3', 'práctica calificada 3'] },
    { code: 'PC4', keys: ['pc4', 'practica calificada 4', 'práctica calificada 4'] },
    { code: 'EP', keys: ['ep', 'examen parcial', 'parcial'] },
    { code: 'EF', keys: ['ef', 'examen final', 'final'] }
  ]

  const matchItemForLine = (lineNorm) => {
    for (const alias of aliases) {
      if (alias.keys.some((key) => lineNorm.includes(normalizeForMatching(key)))) {
        const found = normalizedItems.find((item) => {
          const itemNorm = item.token
          return alias.keys.some((key) => itemNorm.includes(normalizeForMatching(key))) ||
            (alias.code === 'EP' && (itemNorm.includes('parcial') || itemNorm.includes('ep'))) ||
            (alias.code === 'EF' && (itemNorm.includes('final') || itemNorm.includes('ef')))
        })
        if (found) return found
      }
    }
    return normalizedItems.find((item) => item.token && lineNorm.includes(item.token)) || null
  }

  for (const line of lines) {
    const norm = normalizeForMatching(line)
    if (!norm) continue
    if (/\b(pf|pp)\b/.test(norm) || norm.includes('promedio final') || norm === 'promedio') {
      ignored.push({ line, reason: 'Promedio referencial' })
      continue
    }
    if (/\ber\b/.test(norm) || norm.includes('examen rezagado')) {
      ignored.push({ line, reason: 'Examen rezagado opcional' })
      continue
    }
    const item = matchItemForLine(norm)
    if (!item) continue
    const numbers = line.match(/\b(?:20(?:[.,]00?)?|1?\d(?:[.,]\d{1,2})?)\b/g) || []
    const numericValues = numbers
      .map((value) => toNumber(value))
      .filter((value) => value !== null && value >= 0 && value <= 20)
    const score = numericValues.length ? numericValues[numericValues.length - 1] : null
    detected.push({
      key: item.key,
      label: item.label,
      name: item.name,
      score,
      pending: score === null,
      line
    })
  }

  const byKey = new Map()
  for (const row of detected) {
    const existing = byKey.get(row.key)
    if (!existing || (existing.score === null && row.score !== null)) byKey.set(row.key, row)
  }
  return { detected: Array.from(byKey.values()), ignored }
}

function isWithinPeriod(value, period = 'today') {
  if (!value || period === 'all') return true
  const date = new Date(value)
  const now = new Date()
  const start = new Date(now)
  start.setHours(0, 0, 0, 0)
  if (period === 'today') return date >= start
  if (period === '7d') {
    const d = new Date(now)
    d.setDate(d.getDate() - 7)
    return date >= d
  }
  if (period === '30d') {
    const d = new Date(now)
    d.setDate(d.getDate() - 30)
    return date >= d
  }
  return true
}

function formatStatus(status) {
  if (status === 'active') return 'Activo'
  if (status === 'inactive') return 'Inactivo'
  if (status === 'visible') return 'Visible'
  if (status === 'hidden') return 'Oculto'
  return status || '—'
}

function formatRole(role) {
  if (role === 'superadmin') return 'Superadmin'
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
  if (course?.creator) return fullName(course.creator)
  if (course?.creator_name) return course.creator_name
  return 'Sistema'
}

const COURSE_SELECT = 'id,name,created_by,status,cycle_id,career_id,faculty_id,university_id,evaluation_template_id,created_at,updated_at,university:universities(id,name,code),faculty:faculties(id,name),career:careers(id,name),cycle:cycles(id,name,order_number),evaluation_template:evaluation_templates!courses_evaluation_template_id_fkey(id,name,min_passing_grade)'
const COURSE_SELECT_ADMIN = 'id,name,created_by,status,cycle_id,career_id,faculty_id,university_id,evaluation_template_id,created_at,updated_at,university:universities(id,name,code),faculty:faculties(id,name),career:careers(id,name),cycle:cycles(id,name,order_number),evaluation_template:evaluation_templates!courses_evaluation_template_id_fkey(id,name)'

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
  const email = user?.email || ''
  const parsedName = getGoogleProfileName(metadata, email)
  const first = parsedName.firstName || ''
  const last = parsedName.lastName || ''
  return {
    id: user?.id,
    email,
    first_name: first,
    last_name: last,
    full_name: parsedName.fullName || `${first} ${last}`.trim(),
    role: email.toLowerCase() === ADMIN_EMAIL.toLowerCase() ? 'superadmin' : 'student',
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
  const [evaluationTemplates, setEvaluationTemplates] = useState([])
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

  function findBestTemplateForContext(context = {}, course = null, templates = evaluationTemplates) {
    const candidates = (templates || []).filter((template) => {
      if (template.status && template.status !== 'active') return false
      if (template.course_id && course?.id && template.course_id !== course.id) return false
      if (template.course_id && !course?.id) return false
      if (template.university_id && context?.university_id && template.university_id !== context.university_id) return false
      if (template.university_id && !context?.university_id) return false
      if (template.faculty_id && context?.faculty_id && template.faculty_id !== context.faculty_id) return false
      if (template.career_id && context?.career_id && template.career_id !== context.career_id) return false
      return true
    })

    return candidates
      .sort((a, b) => {
        const score = (template) =>
          (template.course_id ? 8 : 0) +
          (template.career_id ? 4 : 0) +
          (template.faculty_id ? 2 : 0) +
          (template.university_id ? 1 : 0)
        return score(b) - score(a)
      })[0] || null
  }

  function getDefaultTemplateIdForProfile(userProfile = profile, course = null) {
    return findBestTemplateForContext(course || userProfile || {}, course, evaluationTemplates)?.id || null
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
    await Promise.all([loadUniversities(), loadFaculties(), loadCareers(), loadCycles(), loadEvaluationTemplates()])
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

  async function loadEvaluationTemplates() {
    const { data, error } = await supabase
      .from('evaluation_templates')
      .select('id,name,description,min_passing_grade,scale_min,scale_max,status,university_id,faculty_id,career_id,course_id,university:universities(id,name,code),faculty:faculties(id,name),career:careers(id,name)')
      .eq('status', 'active')
      .order('created_at', { ascending: true })
    if (error) {
      console.error('No se pudieron cargar plantillas de evaluación:', error)
      setEvaluationTemplates([])
      return []
    }
    const templates = data || []
    setEvaluationTemplates(templates)
    return templates
  }

  async function applyEvaluationTemplate(templateId) {
    if (!templateId) {
      const fallback = normalizeEvaluationComponents([], settings)
      setEvaluationTemplate(null)
      setEvaluationItems(fallback)
      setGrades(emptyDynamicGrades(fallback))
      setResult(null)
      return
    }

    let template = evaluationTemplates.find((item) => item.id === templateId) || null
    if (!template) {
      const { data } = await supabase
        .from('evaluation_templates')
        .select('id,name,description,min_passing_grade,scale_min,scale_max,status,university_id,faculty_id,career_id,course_id,university:universities(id,name,code),faculty:faculties(id,name),career:careers(id,name)')
        .eq('id', templateId)
        .maybeSingle()
      template = data || null
    }

    if (!template?.id) return

    const { data: components, error: compError } = await supabase
      .from('evaluation_components')
      .select('*')
      .eq('template_id', template.id)
      .eq('status', 'active')
      .order('component_order')

    let effectiveTemplate = template
    let componentRows = components || []

    if (!compError && session?.user?.id && !guestMode && !isAdmin) {
      const { data: userTemplate } = await supabase
        .from('user_evaluation_settings')
        .select('*')
        .eq('user_id', session.user.id)
        .eq('template_id', template.id)
        .maybeSingle()

      if (userTemplate) {
        effectiveTemplate = {
          ...template,
          min_passing_grade: userTemplate.min_passing_grade ?? template.min_passing_grade
        }
      }

      const { data: overrides } = await supabase
        .from('user_evaluation_component_settings')
        .select('*')
        .eq('user_id', session.user.id)
        .eq('template_id', template.id)

      const overrideMap = new Map((overrides || []).map((row) => [row.component_id, row]))
      componentRows = componentRows.map((component) => ({
        ...component,
        weight_percent: overrideMap.get(component.id)?.weight_percent ?? component.weight_percent
      }))
    }

    const items = compError ? normalizeEvaluationComponents([], settings) : normalizeEvaluationComponents(componentRows, settings)
    setEvaluationTemplate(effectiveTemplate)
    setEvaluationItems(items)
    setGrades(emptyDynamicGrades(items))
    setResult(null)
  }

  function templatesForCurrentCalculator() {
    const templates = evaluationTemplates || []
    if (guestMode || isAdmin) return templates

    const context = activeCourse || profile
    if (!context?.university_id) return []

    return templates.filter((template) => {
      const matchesUniversity = !template.university_id || template.university_id === context.university_id
      const matchesFaculty = !template.faculty_id || !context.faculty_id || template.faculty_id === context.faculty_id
      const matchesCareer = !template.career_id || !context.career_id || template.career_id === context.career_id
      const matchesCourse = !template.course_id || !activeCourse?.id || template.course_id === activeCourse.id
      return matchesUniversity && matchesFaculty && matchesCareer && matchesCourse
    })
  }

  function isAdminRole(role) {
    return role === 'admin' || role === 'superadmin'
  }

  function redirectToDefaultWhenNeeded(target) {
    setScreen((previous) => {
      const transientScreens = ['login', 'welcome', 'register', 'complete-profile', 'tutorial']
      if (!previous || transientScreens.includes(previous)) return target
      return previous
    })
  }

  async function loadProfileAndData(user) {
    const { data: userProfile, error } = await supabase
      .from('profiles')
      .select('*, university:universities(id,name,code), faculty:faculties(id,name), career:careers(id,name,faculty_id), cycle:cycles(id,name,order_number)')
      .eq('id', user.id)
      .single()

    if (error || !userProfile) {
      const provisionalProfile = buildProfileFromAuthUser(user)

      // Si el correo corresponde al administrador, no debe pasar por Completa tu perfil.
      // Se crea/actualiza el perfil con universidad/facultad/carrera/ciclo en null.
      if (isAdminRole(provisionalProfile.role)) {
        const adminPayload = {
          id: user.id,
          email: provisionalProfile.email,
          first_name: provisionalProfile.first_name || 'Administrador',
          last_name: provisionalProfile.last_name || '',
          full_name: provisionalProfile.full_name || provisionalProfile.email,
          role: 'superadmin',
          status: 'active',
          university_id: null,
          faculty_id: null,
          career_id: null,
          current_cycle_id: null,
          has_seen_tutorial: true
        }
        const { data: savedAdmin, error: saveAdminError } = await supabase
          .from('profiles')
          .upsert(adminPayload, { onConflict: 'id' })
          .select('*, university:universities(id,name,code), faculty:faculties(id,name), career:careers(id,name,faculty_id), cycle:cycles(id,name,order_number)')
          .single()

        if (saveAdminError) {
          notify('error', getErrorMessage(saveAdminError))
          setProfile(provisionalProfile)
          setScreen('login')
          return
        }

        const nextAdminProfile = savedAdmin || adminPayload
        setProfile(nextAdminProfile)
        await loadSettings(user.id)
        await loadAdminData()
        redirectToDefaultWhenNeeded('admin-dashboard')
        return
      }

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

    const normalizedProfile = userProfile.email?.toLowerCase() === ADMIN_EMAIL.toLowerCase()
      ? { ...userProfile, role: 'superadmin', university_id: null, faculty_id: null, career_id: null, current_cycle_id: null }
      : userProfile

    if (userProfile.email?.toLowerCase() === ADMIN_EMAIL.toLowerCase() && userProfile.role !== 'superadmin') {
      await supabase.from('profiles').update({
        role: 'superadmin',
        status: 'active',
        university_id: null,
        faculty_id: null,
        career_id: null,
        current_cycle_id: null,
        updated_at: new Date().toISOString()
      }).eq('id', userProfile.id)
    }

    setProfile(normalizedProfile)

    if (isProfileIncomplete(normalizedProfile)) {
      await loadSettings(user.id)
      setScreen('complete-profile')
      return
    }

    await Promise.all([loadSettings(user.id), loadCourses(normalizedProfile), loadHistory(user.id)])

    if (!isAdminRole(normalizedProfile.role)) {
      const templates = evaluationTemplates.length ? evaluationTemplates : await loadEvaluationTemplates()
      const defaultTemplate = findBestTemplateForContext(normalizedProfile, null, templates)
      if (defaultTemplate?.id) await applyEvaluationTemplate(defaultTemplate.id)
    }

    const key = `${user.id}-${todayISO()}`
    if (recordedLoginRef.current !== key) {
      recordedLoginRef.current = key
      recordLoginActivity(normalizedProfile)
    }

    if (!isAdminRole(normalizedProfile.role) && normalizedProfile.has_seen_tutorial === false) {
      setScreen('tutorial')
      return
    }

    redirectToDefaultWhenNeeded(isAdminRole(normalizedProfile.role) ? 'admin-dashboard' : 'dashboard')
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

  async function recordUsageEvent(eventType, metadata = {}) {
    if (!session?.user?.id && !profile?.id) return
    const userId = session?.user?.id || profile?.id
    const context = profile || {}
    await supabase.from('app_usage_events').insert({
      user_id: userId,
      event_type: eventType,
      university_id: metadata.university_id || context.university_id || null,
      faculty_id: metadata.faculty_id || context.faculty_id || null,
      career_id: metadata.career_id || context.career_id || null,
      cycle_id: metadata.cycle_id || context.current_cycle_id || null,
      course_id: metadata.course_id || null,
      metadata
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

    let officialQuery = supabase
      .from('courses')
      .select(COURSE_SELECT)
      .eq('university_id', userProfile.university_id)
      .eq('faculty_id', userProfile.faculty_id)
      .eq('career_id', userProfile.career_id)
      .eq('status', 'active')
      .order('name')

    const officialRes = await officialQuery

    if (officialRes.error) {
      console.error('No se pudieron cargar cursos disponibles:', officialRes.error)
      setAvailableCourses([])
      setCourses([])
      return
    }

    const officialCourses = officialRes.data || []
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
      .select(`id,enrollment_type,status,course_id,course:courses!inner(${COURSE_SELECT})`)
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

  async function enterGuestMode() {
    setGuestMode(true)
    setProfile(null)
    const guestSettings = loadGuestSettings()
    setSettings(guestSettings)
    setCourses([])
    setAvailableCourses([])
    setSelectedCourseId('')
    setResult(null)
    setScreen('guest-calculator')

    const templates = evaluationTemplates.length ? evaluationTemplates : await loadEvaluationTemplates()
    const defaultTemplate = templates.find((template) => template.university?.code === 'UPSJB') || templates[0]
    if (defaultTemplate?.id) {
      await applyEvaluationTemplate(defaultTemplate.id)
    } else {
      const fallback = normalizeEvaluationComponents([], guestSettings)
      setEvaluationTemplate(null)
      setEvaluationItems(fallback)
      setGrades(emptyDynamicGrades(fallback))
    }
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
    recordUsageEvent('calculation_done', { course_id: selectedCourseId || null, template_id: evaluationTemplate?.id || null })
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
      await recordUsageEvent('result_saved', { course_id: selectedCourseId, template_id: evaluationTemplate?.id || null })
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
      setSettings(newSettings)
      notify('success', 'Ajustes aplicados temporalmente. Si actualizas la página, volverán los valores por defecto.')
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

  async function handleSaveTemplateSettings(payload = {}) {
    const components = payload.components || []
    const total = components.reduce((sum, item) => sum + Number(item.weight_percent || 0), 0)
    if (Math.abs(total - 100) > 0.01) {
      notify('error', 'La suma de porcentajes debe ser 100%.')
      return
    }

    const nextTemplate = {
      ...(evaluationTemplate || {}),
      min_passing_grade: Number(payload.minPassingGrade || evaluationTemplate?.min_passing_grade || settings.minimum_grade)
    }
    const nextItems = normalizeEvaluationComponents(components.map((component, index) => ({
      ...component,
      component_order: component.component_order || index + 1,
      weight_percent: Number(component.weight_percent || 0),
      status: 'active'
    })), settings)

    if (isAdmin && payload.templateId) {
      const { error: templateError } = await supabase
        .from('evaluation_templates')
        .update({ min_passing_grade: nextTemplate.min_passing_grade, updated_at: new Date().toISOString() })
        .eq('id', payload.templateId)
      if (templateError) {
        notify('error', getErrorMessage(templateError))
        return
      }
      for (const component of components) {
        if (!component.id) continue
        const { error } = await supabase
          .from('evaluation_components')
          .update({
            short_name: component.short_name,
            name: component.name,
            unit_name: component.unit_name || null,
            weight_percent: Number(component.weight_percent || 0),
            component_order: Number(component.component_order || 1),
            updated_at: new Date().toISOString()
          })
          .eq('id', component.id)
        if (error) {
          notify('error', getErrorMessage(error))
          return
        }
      }
      notify('success', 'Plantilla actualizada correctamente.')
      await recordUsageEvent('settings_updated', { template_id: payload.templateId, scope: 'global' })
      await loadEvaluationTemplates()
      await applyEvaluationTemplate(payload.templateId)
      if (adminData) await loadAdminData()
      return
    }

    if (!guestMode && session?.user?.id && payload.templateId) {
      const { error: userTemplateError } = await supabase
        .from('user_evaluation_settings')
        .upsert({
          user_id: session.user.id,
          template_id: payload.templateId,
          min_passing_grade: nextTemplate.min_passing_grade,
          updated_at: new Date().toISOString()
        }, { onConflict: 'user_id,template_id' })
      if (userTemplateError) {
        notify('error', getErrorMessage(userTemplateError))
        return
      }

      const overrideRows = components
        .filter((component) => component.id)
        .map((component) => ({
          user_id: session.user.id,
          template_id: payload.templateId,
          component_id: component.id,
          weight_percent: Number(component.weight_percent || 0),
          updated_at: new Date().toISOString()
        }))

      if (overrideRows.length) {
        const { error: userComponentsError } = await supabase
          .from('user_evaluation_component_settings')
          .upsert(overrideRows, { onConflict: 'user_id,component_id' })
        if (userComponentsError) {
          notify('error', getErrorMessage(userComponentsError))
          return
        }
      }
    }

    setEvaluationTemplate(nextTemplate)
    setEvaluationItems(nextItems)
    setGrades((prev) => {
      const empty = emptyDynamicGrades(nextItems)
      Object.keys(empty).forEach((key) => { if (prev[key] !== undefined) empty[key] = prev[key] })
      return empty
    })
    setResult(null)
    if (guestMode) {
      notify('success', 'Ajustes aplicados temporalmente. Si actualizas la página, volverán los valores por defecto.')
    } else {
      await recordUsageEvent('settings_updated', { template_id: payload.templateId || evaluationTemplate?.id || null })
      notify('success', 'Ajustes guardados para tu cuenta.')
    }
  }

  async function handleCreateCourse(name, options = {}) {
    const proposedName = cleanText(name)
    if (!proposedName) {
      notify('error', 'Ingresa el nombre del curso a solicitar.')
      return null
    }
    if (!profile?.university_id || !profile?.faculty_id || !profile?.career_id) {
      notify('error', 'Completa universidad, facultad y carrera antes de solicitar cursos.')
      return null
    }
    const targetCycleId = options.cycleId || profile.current_cycle_id
    if (!targetCycleId) {
      notify('error', 'Selecciona el ciclo del curso antes de enviarlo a revisión.')
      return null
    }

    const similarCourses = findSimilarCourses(proposedName, availableCourses).slice(0, 5)
    const { data, error } = await supabase
      .from('course_requests')
      .insert({
        requested_by: profile.id,
        university_id: profile.university_id,
        faculty_id: profile.faculty_id,
        career_id: profile.career_id,
        cycle_id: targetCycleId,
        proposed_name: proposedName,
        enrollment_type: options.enrollmentType || 'regular',
        status: 'pending',
        similar_courses: similarCourses.map((course) => ({ id: course.id, name: course.name, cycle_id: course.cycle_id }))
      })
      .select('*')
      .single()

    if (error) {
      notify('error', 'No se pudo enviar la solicitud del curso. Intenta nuevamente.')
      return null
    }

    await recordUsageEvent('course_requested', {
      cycle_id: targetCycleId,
      proposed_name: proposedName,
      similar_count: similarCourses.length
    })

    notify('success', similarCourses.length
      ? 'Solicitud enviada. Encontramos cursos parecidos para que el administrador revise y evite duplicados.'
      : 'Solicitud enviada. El administrador revisará el curso antes de aprobarlo.')
    if (adminData) await loadAdminData()
    return data
  }

  async function handleAddStudentCourse(courseId, enrollmentType = 'regular', options = {}) {
    if (!session?.user || !courseId) {
      notify('error', 'Selecciona un curso para agregarlo.')
      return null
    }
    const selectedCourse = availableCourses.find((c) => c.id === courseId) || courses.find((c) => c.id === courseId) || {}
    const payload = {
      user_id: session.user.id,
      course_id: courseId,
      university_id: selectedCourse.university_id || profile?.university_id || null,
      faculty_id: selectedCourse.faculty_id || profile?.faculty_id || null,
      career_id: selectedCourse.career_id || profile?.career_id || null,
      cycle_id: selectedCourse.cycle_id || null,
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
    await recordUsageEvent('course_added', { course_id: courseId, cycle_id: selectedCourse.cycle_id || null, enrollment_type: enrollmentType })
    if (!options.skipReload) await loadCourses()
    if (options.select) await loadCourseGrades(courseId)
    return data
  }


  async function handleAddAllStudentCourses(courseIds = [], enrollmentType = 'regular') {
    if (!session?.user) {
      notify('error', 'Inicia sesión para agregar cursos.')
      return
    }
    const uniqueIds = [...new Set(courseIds)].filter(Boolean)
    if (!uniqueIds.length) {
      notify('error', 'No hay cursos oficiales para agregar en este ciclo.')
      return
    }
    const existingIds = new Set((courses || []).map((course) => course.id))
    const targetCourses = uniqueIds
      .filter((id) => !existingIds.has(id))
      .map((id) => availableCourses.find((course) => course.id === id))
      .filter(Boolean)

    if (!targetCourses.length) {
      notify('success', 'Todos los cursos de este ciclo ya estaban en tu lista.')
      return
    }

    const rows = targetCourses.map((course) => ({
      user_id: session.user.id,
      course_id: course.id,
      university_id: course.university_id || profile?.university_id || null,
      faculty_id: course.faculty_id || profile?.faculty_id || null,
      career_id: course.career_id || profile?.career_id || null,
      cycle_id: course.cycle_id || null,
      enrollment_type: enrollmentType || 'regular',
      status: 'visible',
      updated_at: new Date().toISOString()
    }))

    const { error } = await supabase
      .from('student_courses')
      .upsert(rows, { onConflict: 'user_id,course_id' })

    if (error) {
      notify('error', 'No se pudieron agregar todos los cursos. Verifica la migración de Mis cursos.')
      return
    }

    await recordUsageEvent('courses_bulk_added', {
      course_count: rows.length,
      skipped_existing: uniqueIds.length - rows.length,
      enrollment_type: enrollmentType || 'regular',
      cycle_id: rows[0]?.cycle_id || null
    })
    await loadCourses()
    notify('success', `Se agregaron ${rows.length} cursos. ${uniqueIds.length - rows.length} ya estaban en tu lista.`)
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
    const email = session.user.email || profile?.email || ''
    const nextRole = profile?.role || (email.toLowerCase() === ADMIN_EMAIL.toLowerCase() ? 'superadmin' : 'student')

    if (!values.firstName?.trim() || !values.lastName?.trim()) {
      notify('error', 'Completa nombres y apellidos.')
      return
    }

    if (!isAdminRole(nextRole) && (!values.universityId || !values.facultyId || !values.careerId || !values.cycleId)) {
      notify('error', 'Completa universidad, facultad, carrera y ciclo.')
      return
    }

    const payload = {
      id: session.user.id,
      email,
      first_name: values.firstName.trim(),
      last_name: values.lastName.trim(),
      full_name: `${values.firstName.trim()} ${values.lastName.trim()}`.trim(),
      university_id: isAdminRole(nextRole) ? null : values.universityId,
      faculty_id: isAdminRole(nextRole) ? null : values.facultyId,
      career_id: isAdminRole(nextRole) ? null : values.careerId,
      current_cycle_id: isAdminRole(nextRole) ? null : values.cycleId,
      role: nextRole,
      status: profile?.status || 'active'
    }
    const { error } = await supabase.from('profiles').upsert(payload, { onConflict: 'id' })
    if (error) notify('error', getErrorMessage(error))
    else {
      notify('success', 'Perfil actualizado correctamente.')
      await recordUsageEvent('profile_updated', { university_id: values.universityId, faculty_id: values.facultyId, career_id: values.careerId, cycle_id: values.cycleId })
      await loadProfileAndData(session.user)
    }
  }

  async function loadAdminData() {
    const [profilesRes, coursesRes, calculationsRes, loginsRes, studentCoursesRes, universitiesRes, facultiesRes, careersRes, cyclesRes, templatesRes, componentsRes, usageRes, requestsRes] = await Promise.all([
      supabase.from('profiles').select('*, university:universities(id,name,code), faculty:faculties(id,name), career:careers(name), cycle:cycles(name,order_number)').order('created_at', { ascending: false }),
      supabase.from('courses').select(COURSE_SELECT_ADMIN).order('created_at', { ascending: false }),
      supabase.from('calculation_history').select('*, profile:profiles(first_name,last_name,email,career_id,current_cycle_id, university:universities(name,code), faculty:faculties(name), career:careers(name), cycle:cycles(name)), course:courses(name, university:universities(name,code), faculty:faculties(name), career:careers(name), cycle:cycles(name)), evaluation_template:evaluation_templates(name)').order('created_at', { ascending: false }).limit(300),
      supabase.from('login_activity').select('*, profile:profiles(first_name,last_name,email), university:universities(name,code), faculty:faculties(name), career:careers(name), cycle:cycles(name)').order('login_at', { ascending: false }).limit(500),
      supabase.from('student_courses').select('*, profile:profiles(first_name,last_name,email, university:universities(name,code), faculty:faculties(name), career:careers(name), cycle:cycles(name)), course:courses(name, university:universities(name,code), faculty:faculties(name), career:careers(name), cycle:cycles(name))').order('created_at', { ascending: false }).limit(800),
      supabase.from('universities').select('*').order('name'),
      supabase.from('faculties').select('*, university:universities(id,name,code)').order('name'),
      supabase.from('careers').select('*, faculty:faculties(id,name,university_id, university:universities(id,name,code))').order('name'),
      supabase.from('cycles').select('*').order('order_number'),
      supabase.from('evaluation_templates').select('*, university:universities(name,code), faculty:faculties(name), career:careers(name), course:courses(name)').order('created_at', { ascending: false }),
      supabase.from('evaluation_components').select('*').order('component_order'),
      supabase.from('app_usage_events').select('*, profile:profiles(first_name,last_name,email), university:universities(name,code), faculty:faculties(name), career:careers(name), cycle:cycles(name), course:courses(name)').order('created_at', { ascending: false }).limit(1000),
      supabase.from('course_requests').select('*, requester:profiles(first_name,last_name,email), university:universities(name,code), faculty:faculties(name), career:careers(name), cycle:cycles(name), linked_course:courses(name)').order('created_at', { ascending: false }).limit(500)
    ])

    setAdminData({
      users: profilesRes.data || [],
      courses: coursesRes.data || [],
      calculations: calculationsRes.data || [],
      logins: loginsRes.data || [],
      studentCourses: studentCoursesRes.data || [],
      universities: universitiesRes.data || [],
      faculties: facultiesRes.data || [],
      careers: careersRes.data || [],
      cycles: cyclesRes.data || [],
      templates: templatesRes.data || [],
      components: componentsRes.data || [],
      usageEvents: usageRes.data || [],
      courseRequests: requestsRes.data || []
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
                evaluationTemplate={evaluationTemplate}
                evaluationItems={evaluationItems}
                evaluationTemplates={evaluationTemplates}
                onSelectTemplate={applyEvaluationTemplate}
                allowTemplateSelection
                onExtractedGrades={(nextGrades) => { setGrades((prev) => ({ ...prev, ...nextGrades })); setResult(null) }}
              />
            )}
            {guestMode && screen === 'guest-settings' && (
              <SettingsScreen
                settings={settings}
                guestMode
                isAdmin={false}
                profile={profile}
                evaluationTemplate={evaluationTemplate}
                evaluationItems={evaluationItems}
                evaluationTemplates={evaluationTemplates}
                onSelectTemplate={applyEvaluationTemplate}
                onSaveTemplate={handleSaveTemplateSettings}
                allowTemplateSelection
              />
            )}
            {session && screen === 'dashboard' && <Dashboard profile={profile} courses={courses} history={history} setScreen={setScreen} onSelectCourse={(id) => { loadCourseGrades(id); setScreen('calculator') }} />}
            {session && screen === 'courses' && <CoursesScreen courses={courses} availableCourses={availableCourses} cycles={cycles} profile={profile} onCreate={handleCreateCourse} onAdd={handleAddStudentCourse} onAddAll={handleAddAllStudentCourses} onHide={handleHideStudentCourse} onSelect={(id) => { loadCourseGrades(id); setScreen('calculator') }} />}
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
                evaluationTemplates={templatesForCurrentCalculator()}
                onSelectTemplate={applyEvaluationTemplate}
                allowTemplateSelection={isAdmin}
                onExtractedGrades={(nextGrades) => { setGrades((prev) => ({ ...prev, ...nextGrades })); setResult(null) }}
              />
            )}
            {session && screen === 'history' && <HistoryScreen history={history} />}
            {session && screen === 'settings' && (
              <SettingsScreen
                settings={settings}
                guestMode={false}
                isAdmin={isAdmin}
                profile={profile}
                evaluationTemplate={evaluationTemplate}
                evaluationItems={evaluationItems}
                evaluationTemplates={isAdmin ? evaluationTemplates : templatesForCurrentCalculator()}
                onSelectTemplate={applyEvaluationTemplate}
                onSaveTemplate={handleSaveTemplateSettings}
                allowTemplateSelection={isAdmin}
              />
            )}
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
      <label className="field-label">Universidad</label>
      <select className="input" value={form.universityId} onChange={(e) => update('universityId', e.target.value)}>
        <option value="">Selecciona tu universidad</option>
        {universities.map((university) => <option key={university.id} value={university.id}>{university.name}</option>)}
      </select>
      <label className="field-label">Facultad</label>
      <select className="input" value={form.facultyId} onChange={(e) => update('facultyId', e.target.value)} disabled={!form.universityId}>
        <option value="">Selecciona tu facultad</option>
        {filteredFaculties.map((faculty) => <option key={faculty.id} value={faculty.id}>{faculty.name}</option>)}
      </select>
      <label className="field-label">Carrera</label>
      <select className="input" value={form.careerId} onChange={(e) => update('careerId', e.target.value)} disabled={!form.facultyId}>
        <option value="">Selecciona tu carrera</option>
        {filteredCareers.map((career) => <option key={career.id} value={career.id}>{career.name}</option>)}
      </select>
      <label className="field-label">Ciclo actual</label>
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

function CoursesScreen({ courses, availableCourses, cycles, profile, onCreate, onAdd, onAddAll, onHide, onSelect }) {
  const [cycleId, setCycleId] = useState(profile?.current_cycle_id || '')
  const [courseId, setCourseId] = useState('')
  const [enrollmentType, setEnrollmentType] = useState('regular')
  const [showNewCourse, setShowNewCourse] = useState(false)
  const [name, setName] = useState('')

  const filteredAvailable = (availableCourses || []).filter((course) => !cycleId || course.cycle_id === cycleId)
  const filteredCurrentCourses = (courses || []).filter((course) => !cycleId || course.cycle_id === cycleId)
  const currentCourseIds = new Set((courses || []).map((course) => course.id))
  const missingAvailable = filteredAvailable.filter((course) => !currentCourseIds.has(course.id))
  const selectedAvailable = filteredAvailable.find((course) => course.id === courseId)

  async function addSelectedCourse() {
    if (!courseId) return
    const added = await onAdd(courseId, enrollmentType)
    if (added) {
      setCourseId('')
      setEnrollmentType('regular')
    }
  }

  async function addAllCoursesForCycle() {
    if (!cycleId) return
    await onAddAll?.(filteredAvailable.map((course) => course.id), enrollmentType || 'regular')
  }

  const similarCourses = findSimilarCourses(name, availableCourses)

  async function createAndAdd() {
    const request = await onCreate(name, { cycleId, enrollmentType })
    if (request?.id) {
      setName('')
      setShowNewCourse(false)
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
        {cycleId && filteredAvailable.length > 0 && <p className="hint">Cursos oficiales del ciclo: {filteredAvailable.length}. Faltan por agregar: {missingAvailable.length}.</p>}
        {filteredAvailable.length === 0 && (
          <p className="hint warning-hint">No hay cursos oficiales cargados para este contexto académico y ciclo. Puedes solicitar un curso no listado.</p>
        )}
        <div className="action-row left">
          <button className="btn primary small" disabled={!courseId} onClick={addSelectedCourse}>➕ Agregar a Mis cursos</button>
          <button className="btn secondary small" disabled={!cycleId || missingAvailable.length === 0} onClick={addAllCoursesForCycle}>📚 Agregar todos los cursos del ciclo</button>
          <button className="btn ghost small" onClick={() => setShowNewCourse(!showNewCourse)}>+ Solicitar curso no listado</button>
        </div>
        {showNewCourse && (
          <div className="inline-new-course">
            <input className="input" placeholder="Nombre del curso a solicitar" value={name} onChange={(e) => setName(e.target.value)} />
            <p className="hint">La solicitud quedará pendiente de revisión para evitar duplicados. No se agregará a tu lista hasta que sea aprobada o vinculada por el administrador.</p>
            {similarCourses.length > 0 && (
              <div className="similar-box">
                <b>Cursos similares encontrados</b>
                {similarCourses.map((course) => <span key={course.id}>{courseCycleName(course)} · {course.name}</span>)}
                <p className="hint">Revisa si tu curso ya existe antes de enviar la solicitud.</p>
              </div>
            )}
            <div className="action-row left">
              <button className="btn primary small" onClick={createAndAdd}>Enviar solicitud</button>
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
        {filteredCurrentCourses.length === 0 && <Empty text="Aún no agregaste cursos para el ciclo seleccionado." compact />}
        <div className="course-list">
          {filteredCurrentCourses.map((course) => (
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

function CalculatorScreen({ title, subtitle, courses, selectedCourseId, onSelectCourse, onCreateCourse, grades, setGrades, settings, result, onCalculate, onGenerate, onClean, onSave, activeCourse, guestMode, evaluationTemplate, evaluationItems, evaluationTemplates = [], onSelectTemplate, allowTemplateSelection = false, onExtractedGrades }) {
  const items = evaluationItems?.length ? evaluationItems : normalizeEvaluationComponents([], settings)
  const groups = [...new Set(items.map((item) => item.group || 'Evaluaciones'))]
  const updateGrade = (key, value) => setGrades((prev) => ({ ...prev, [key]: value }))
  const selectedContextId = selectedCourseId || activeCourse?.id || ''
  const canUseImageReader = guestMode ? Boolean(evaluationTemplate?.id) : Boolean(selectedContextId)
  const [imagePreview, setImagePreview] = useState('')
  const [imageName, setImageName] = useState('')
  const [ocrText, setOcrText] = useState('')
  const [detectedGrades, setDetectedGrades] = useState([])

  function handleImageChange(event) {
    const file = event.target.files?.[0]
    if (!file) return
    setImageName(file.name)
    setImagePreview(URL.createObjectURL(file))
    setDetectedGrades([])
  }

  function analyzeGradeText() {
    const parsed = parseGradeText(ocrText, items)
    setDetectedGrades(parsed.detected)
  }

  function applyDetectedGrades() {
    const next = {}
    detectedGrades.forEach((row) => {
      if (row.score !== null && row.score !== undefined) next[row.key] = formatNumber(row.score)
    })
    if (!Object.keys(next).length) return
    onExtractedGrades?.(next)
  }

  return (
    <div className="page fade-in">
      <Header title={title} subtitle={subtitle} />
      {allowTemplateSelection && evaluationTemplates.length > 0 && (
        <EvaluationTemplateCombo
          templates={evaluationTemplates}
          selectedTemplateId={evaluationTemplate?.id || ''}
          onSelectTemplate={onSelectTemplate}
          guestMode={guestMode}
        />
      )}
      {!guestMode && (
        <CourseCombo
          courses={courses}
          selectedCourseId={selectedCourseId}
          onSelectCourse={onSelectCourse}
          onCreateCourse={onCreateCourse}
          activeCourse={activeCourse}
        />
      )}
      <Card className={`image-reader-card ${canUseImageReader ? '' : 'disabled-card'}`}>
        <div className="section-title"><span>📷</span><h3>Leer notas desde imagen</h3></div>
        <p className="hint">
          {canUseImageReader
            ? 'Sube una captura de tus notas para autocompletar la calculadora. Antes de aplicar, revisa las notas detectadas.'
            : guestMode
              ? 'Selecciona una calculadora para cargar una captura de notas.'
              : 'Selecciona un curso para cargar una captura de notas.'}
        </p>
        <div className="grid two">
          <label className={`file-drop ${canUseImageReader ? '' : 'disabled'}`}>
            <input type="file" accept="image/*" disabled={!canUseImageReader} onChange={handleImageChange} />
            <span>{imageName || 'Seleccionar captura de notas'}</span>
          </label>
          <textarea
            className="input text-area"
            disabled={!canUseImageReader}
            placeholder="Pega aquí el texto leído de la captura, por ejemplo: PC1 Práctica Calificada 1 17.67..."
            value={ocrText}
            onChange={(e) => setOcrText(e.target.value)}
          />
        </div>
        {imagePreview && <img className="image-preview" src={imagePreview} alt="Vista previa de notas" />}
        <div className="action-row left">
          <button className="btn secondary small" disabled={!canUseImageReader || !ocrText.trim()} onClick={analyzeGradeText}>Detectar notas</button>
          <button className="btn primary small" disabled={!canUseImageReader || detectedGrades.filter((row) => row.score !== null).length === 0} onClick={applyDetectedGrades}>Aplicar a la calculadora</button>
        </div>
        {detectedGrades.length > 0 && (
          <div className="detected-list">
            {detectedGrades.map((row) => <span key={row.key}>{row.label}: <b>{row.score === null ? 'Pendiente' : formatNumber(row.score)}</b></span>)}
          </div>
        )}
      </Card>
      {evaluationTemplate && <Card><p className="hint"><b>Método de evaluación:</b> {evaluationTemplate.name} · <b>Nota mínima:</b> {formatNumber(evaluationTemplate.min_passing_grade || settings.minimum_grade)}</p></Card>}
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

function EvaluationTemplateCombo({ templates, selectedTemplateId, onSelectTemplate, guestMode }) {
  const groupedLabel = (template) => {
    const university = template.university?.code || template.university?.name || 'General'
    return `${university} · ${template.name}`
  }

  return (
    <Card>
      <label className="label">{guestMode ? 'Selecciona la calculadora' : 'Plantilla de evaluación'}</label>
      <select
        className="input"
        value={selectedTemplateId}
        onChange={(e) => onSelectTemplate?.(e.target.value)}
      >
        <option value="">Selecciona una plantilla</option>
        {templates.map((template) => (
          <option key={template.id} value={template.id}>{groupedLabel(template)}</option>
        ))}
      </select>
      <p className="hint">Los porcentajes se cargan desde la configuración del administrador. No están fijos en la app.</p>
    </Card>
  )
}

function CourseCombo({ courses, selectedCourseId, onSelectCourse, activeCourse }) {
  return (
    <Card>
      <label className="label">Curso</label>
      <select className="input" value={selectedCourseId} onChange={(e) => onSelectCourse(e.target.value)}>
        <option value="">Selecciona tu curso</option>
        {courses.map((course) => <option key={course.id} value={course.id}>{course.name}</option>)}
      </select>
      {activeCourse && <p className="hint">Calculando para: {activeCourse.name}</p>}
      {courses.length === 0 && <p className="hint">Aún no tienes cursos actuales. Agrega tus cursos desde la sección Cursos. La calculadora no permite crear cursos nuevos.</p>}
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

function SettingsScreen({ settings, guestMode, isAdmin, profile, evaluationTemplate, evaluationItems = [], evaluationTemplates = [], onSelectTemplate, onSaveTemplate, allowTemplateSelection = false }) {
  const [templateId, setTemplateId] = useState(evaluationTemplate?.id || '')
  const [minPassingGrade, setMinPassingGrade] = useState(evaluationTemplate?.min_passing_grade || settings.minimum_grade)
  const [components, setComponents] = useState([])

  useEffect(() => {
    setTemplateId(evaluationTemplate?.id || '')
    setMinPassingGrade(evaluationTemplate?.min_passing_grade || settings.minimum_grade)
    setComponents((evaluationItems || []).map((item, index) => ({
      id: item.id,
      key: item.key,
      short_name: item.shortName || item.label,
      name: item.name || item.label,
      unit_name: item.group || '',
      weight_percent: item.percent,
      component_order: item.order || index + 1
    })))
  }, [evaluationTemplate, evaluationItems, settings.minimum_grade])

  function updateComponent(index, key, value) {
    setComponents((prev) => prev.map((item, i) => i === index ? { ...item, [key]: value } : item))
  }

  async function handleTemplateChange(value) {
    setTemplateId(value)
    if (value) await onSelectTemplate?.(value)
  }

  const total = components.reduce((sum, item) => sum + Number(item.weight_percent || 0), 0)
  const title = guestMode ? 'Ajustes de invitado' : 'Ajustes'
  const subtitle = guestMode
    ? 'Elige una calculadora y ajusta porcentajes solo en este navegador.'
    : isAdmin
      ? 'Selecciona una plantilla y configura sus porcentajes globales.'
      : 'Porcentajes de la plantilla correspondiente a tu universidad.'

  return (
    <div className="page fade-in">
      <Header title={title} subtitle={subtitle} />
      <Card>
        {allowTemplateSelection && (
          <>
            <label className="label">Plantilla de evaluación</label>
            <select className="input" value={templateId} onChange={(e) => handleTemplateChange(e.target.value)}>
              <option value="">Selecciona una plantilla</option>
              {evaluationTemplates.map((template) => (
                <option key={template.id} value={template.id}>{template.university?.code || 'General'} · {template.name}</option>
              ))}
            </select>
          </>
        )}
        {!allowTemplateSelection && (
          <p className="hint"><b>Plantilla activa:</b> {evaluationTemplate?.name || 'No configurada'} · <b>Contexto:</b> {academicContext(profile)}</p>
        )}
        <div className="section-title"><span>⚙️</span><h3>Componentes y porcentajes</h3><b className={Math.abs(total - 100) < 0.01 ? 'ok' : 'bad'}>Total: {formatPercent(total)}%</b></div>
        {components.length === 0 && <Empty text="No hay componentes cargados para esta plantilla." compact />}
        <div className="settings-grid">
          {components.map((item, index) => (
            <label className="setting-card" key={item.id || item.key || index}>
              <span>{item.short_name || item.name}</span>
              {isAdmin && <input className="input" value={item.name || ''} onChange={(e) => updateComponent(index, 'name', e.target.value)} placeholder="Nombre" />}
              <input className="input" inputMode="decimal" value={item.weight_percent ?? ''} onChange={(e) => updateComponent(index, 'weight_percent', e.target.value)} />
            </label>
          ))}
        </div>
        <label className="setting-card wide">
          <span>Nota mínima aprobatoria</span>
          <input className="input" inputMode="decimal" value={minPassingGrade} onChange={(e) => setMinPassingGrade(e.target.value)} />
        </label>
        <p className="hint">La suma de porcentajes debe ser 100%. {isAdmin ? 'Como administrador, estos cambios se guardan para todos los usuarios de la plantilla.' : guestMode ? 'En invitado, los cambios son temporales y se pierden al actualizar.' : 'Los alumnos solo pueden cambiar porcentajes y nota mínima para su cuenta.'}</p>
        {components.length > 0 && (
          <div className="action-row">
            <button className="btn primary" onClick={() => onSaveTemplate?.({ templateId: templateId || evaluationTemplate?.id, minPassingGrade, components })}>💾 Guardar cambios</button>
          </div>
        )}
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
  const normalizedName = normalizeProfileNameFields(profile || {})
  const [form, setForm] = useState({
    firstName: normalizedName.firstName || '',
    lastName: normalizedName.lastName || '',
    universityId: profile?.university_id || '',
    facultyId: profile?.faculty_id || '',
    careerId: profile?.career_id || '',
    cycleId: profile?.current_cycle_id || ''
  })
  useEffect(() => {
    const nextName = normalizeProfileNameFields(profile || {})
    setForm({
      firstName: nextName.firstName || '',
      lastName: nextName.lastName || '',
      universityId: profile?.university_id || '',
      facultyId: profile?.faculty_id || '',
      careerId: profile?.career_id || '',
      cycleId: profile?.current_cycle_id || ''
    })
  }, [profile?.id, profile?.first_name, profile?.last_name, profile?.full_name, profile?.university_id, profile?.faculty_id, profile?.career_id, profile?.current_cycle_id])
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
      <label className="field-label">Universidad</label>
      <select className="input" value={form.universityId} onChange={(e) => update('universityId', e.target.value)}>
        <option value="">Selecciona universidad</option>
        {(universities || []).map((university) => <option key={university.id} value={university.id}>{university.name}</option>)}
      </select>
      <label className="field-label">Facultad</label>
      <select className="input" value={form.facultyId} onChange={(e) => update('facultyId', e.target.value)} disabled={!form.universityId}>
        <option value="">Selecciona facultad</option>
        {filteredFaculties.map((faculty) => <option key={faculty.id} value={faculty.id}>{faculty.name}</option>)}
      </select>
      <label className="field-label">Carrera</label>
      <select className="input" value={form.careerId} onChange={(e) => update('careerId', e.target.value)} disabled={!form.facultyId}>
        <option value="">Selecciona carrera</option>
        {filteredCareers.map((career) => <option key={career.id} value={career.id}>{career.name}</option>)}
      </select>
      <label className="field-label">Ciclo actual</label>
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
  const [filters, setFilters] = useState({ university: '', faculty: '', career: '', cycle: '', period: 'today' })
  const users = data?.users || []
  const courses = data?.courses || []
  const calculations = data?.calculations || []
  const logins = data?.logins || []
  const studentCourses = data?.studentCourses || []
  const usageEvents = (data?.usageEvents || []).filter((event) => isWithinPeriod(event.created_at, filters.period))
  const periodLogins = logins.filter((login) => isWithinPeriod(login.login_at, filters.period))
  const todayLogins = logins.filter((login) => login.login_date === todayISO())
  const uniqueToday = new Set(todayLogins.map((login) => login.user_id)).size
  const activeRealUsers = new Set(usageEvents.map((event) => event.user_id)).size
  const onlyLoginUsers = Math.max(new Set(periodLogins.map((login) => login.user_id)).size - activeRealUsers, 0)
  const hourly = groupByHour(filters.period === 'today' ? todayLogins : periodLogins)
  const byCareer = countBy(users, (u) => u.career?.name || 'Sin carrera')
  const byCycle = countBy(users, (u) => u.cycle?.name || 'Sin ciclo')
  const byUsage = countBy(usageEvents, (event) => eventLabel(event.event_type))

  const universities = unique([...users, ...courses].map((item) => item.university?.code || item.university?.name).filter(Boolean))
  const faculties = unique([...users, ...courses]
    .filter((item) => !filters.university || (item.university?.code || item.university?.name) === filters.university)
    .map((item) => item.faculty?.name)
    .filter(Boolean))
  const careers = unique([...users, ...courses]
    .filter((item) => !filters.university || (item.university?.code || item.university?.name) === filters.university)
    .filter((item) => !filters.faculty || item.faculty?.name === filters.faculty)
    .map((item) => item.career?.name)
    .filter(Boolean))
  const cycles = unique([...users, ...courses].map((item) => item.cycle?.name).filter(Boolean))

  const matchesContext = (item) => {
    const university = item?.university?.code || item?.university?.name || ''
    const faculty = item?.faculty?.name || ''
    const career = item?.career?.name || ''
    const cycle = item?.cycle?.name || ''
    return (!filters.university || university === filters.university) &&
      (!filters.faculty || faculty === filters.faculty) &&
      (!filters.career || career === filters.career) &&
      (!filters.cycle || cycle === filters.cycle)
  }
  const filteredUsers = users.filter(matchesContext)
  const filteredCourses = courses.filter(matchesContext)
  const filteredCalculations = calculations.filter((item) => matchesContext(item.course || {}))
  const distribution = buildDistribution(filteredUsers, filteredCourses, filteredCalculations)
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
        <StatCard icon="🔥" label="Usuarios con uso real" value={activeRealUsers} />
        <StatCard icon="👀" label="Solo iniciaron sesión" value={onlyLoginUsers} />
        <StatCard icon="📊" label="Cálculos guardados" value={calculations.length} />
      </div>
      <div className="grid two">
        <Card><h3>Accesos por hora de hoy</h3><BarChart data={hourly} /></Card>
        <Card><h3>Usuarios por carrera</h3><BarChart data={byCareer} /></Card>
        <Card><h3>Usuarios por ciclo</h3><BarChart data={byCycle} /></Card>
        <Card><h3>Cursos por tipo de matrícula</h3><BarChart data={byEnrollmentType} /></Card>
        <Card><h3>Uso real de la app</h3><BarChart data={byUsage} /></Card>
        <Card><h3>Usuarios que iniciaron sesión hoy</h3><RecentLogins items={todayLogins} /></Card>
      </div>
      <Card>
        <h3>Distribución por carrera y ciclo</h3>
        <div className="filters admin-course-filters">
          <select className="input" value={filters.period} onChange={(e) => setFilters({ ...filters, period: e.target.value })}>
            <option value="today">Hoy</option>
            <option value="7d">Últimos 7 días</option>
            <option value="30d">Últimos 30 días</option>
            <option value="all">Todo</option>
          </select>
          <select className="input" value={filters.university} onChange={(e) => setFilters({ ...filters, university: e.target.value, faculty: '', career: '' })}>
            <option value="">Todas las universidades</option>{universities.map((u) => <option key={u}>{u}</option>)}
          </select>
          <select className="input" value={filters.faculty} onChange={(e) => setFilters({ ...filters, faculty: e.target.value, career: '' })}>
            <option value="">Todas las facultades</option>{faculties.map((f) => <option key={f}>{f}</option>)}
          </select>
          <select className="input" value={filters.career} onChange={(e) => setFilters({ ...filters, career: e.target.value })}>
            <option value="">Todas las carreras</option>{careers.map((c) => <option key={c}>{c}</option>)}
          </select>
          <select className="input" value={filters.cycle} onChange={(e) => setFilters({ ...filters, cycle: e.target.value })}>
            <option value="">Todos los ciclos</option>{cycles.map((c) => <option key={c}>{c}</option>)}
          </select>
        </div>
        <div className="admin-scroll-list">
          <ResponsiveTable rows={distribution} columns={['carrera', 'ciclo', 'usuarios', 'cursos', 'calculos']} />
        </div>
      </Card>
      <Card>
        <h3>Solicitudes de cursos no listados</h3>
        <CourseRequestsSummary items={data?.courseRequests || []} />
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
  const [filter, setFilter] = useState('all')
  const studentCourses = data?.studentCourses || []
  const calculations = data?.calculations || []
  const logins = data?.logins || []
  const usageEvents = data?.usageEvents || []

  const courseCount = new Map()
  studentCourses
    .filter((item) => item.status === 'visible')
    .forEach((item) => courseCount.set(item.user_id, (courseCount.get(item.user_id) || 0) + 1))

  const calculationCount = new Map()
  calculations.forEach((item) => calculationCount.set(item.user_id, (calculationCount.get(item.user_id) || 0) + 1))

  const lastLogin = new Map()
  logins.forEach((item) => {
    if (!lastLogin.has(item.user_id)) lastLogin.set(item.user_id, item.login_at)
  })

  const lastActivity = new Map()
  usageEvents.forEach((item) => {
    if (!lastActivity.has(item.user_id)) lastActivity.set(item.user_id, item.created_at)
  })

  const enrichedUsers = (data?.users || []).map((user) => {
    const userLastLogin = lastLogin.get(user.id) || null
    const userLastActivity = lastActivity.get(user.id) || null
    const lastSeen = latestDate(userLastActivity, userLastLogin)
    return {
      ...user,
      course_count: courseCount.get(user.id) || 0,
      calculation_count: calculationCount.get(user.id) || 0,
      last_login_at: userLastLogin,
      last_activity_at: userLastActivity,
      inactivity_days: daysSince(lastSeen)
    }
  })

  const users = enrichedUsers
    .filter((u) => `${fullName(u)} ${u.email} ${u.university?.code || ''} ${u.career?.name || ''}`.toLowerCase().includes(q.toLowerCase()))
    .filter((u) => {
      if (filter === 'without_courses') return u.course_count === 0
      if (filter === 'without_real_activity') return !u.last_activity_at
      if (filter === 'inactive_7') return (u.inactivity_days ?? 9999) >= 7
      if (filter === 'inactive_15') return (u.inactivity_days ?? 9999) >= 15
      if (filter === 'inactive_30') return (u.inactivity_days ?? 9999) >= 30
      return true
    })

  return (
    <div className="page fade-in">
      <Header title="Usuarios" subtitle="Ver cursos registrados, última conexión, actividad real y estado." />
      <div className="filters admin-course-filters">
        <input className="input" placeholder="Buscar usuario, correo, universidad o carrera" value={q} onChange={(e) => setQ(e.target.value)} />
        <select className="input" value={filter} onChange={(e) => setFilter(e.target.value)}>
          <option value="all">Todos los usuarios</option>
          <option value="without_courses">Sin cursos registrados</option>
          <option value="without_real_activity">Sin actividad real</option>
          <option value="inactive_7">Inactivos 7+ días</option>
          <option value="inactive_15">Inactivos 15+ días</option>
          <option value="inactive_30">Inactivos 30+ días</option>
        </select>
      </div>
      <div className="admin-list admin-scroll-list">
        {users.map((user) => (
          <Card key={user.id}>
            <div className="list-row">
              <div>
                <h3>{fullName(user)}</h3>
                <p>{user.email} · {user.university?.code || 'Sin universidad'} · {user.career?.name || 'Sin carrera'} · {user.cycle?.name || 'Sin ciclo'}</p>
              </div>
              <span className={`badge ${user.status}`}>{formatStatus(user.status)}</span>
            </div>
            <div className="user-admin-metrics">
              <span>📚 Cursos: <b>{user.course_count}</b></span>
              <span>📊 Cálculos: <b>{user.calculation_count}</b></span>
              <span>🕒 Última conexión: <b>{user.last_login_at ? `${dateOnly(user.last_login_at)} ${timeOnly(user.last_login_at)}` : 'Sin registro'}</b></span>
              <span>🔥 Última actividad: <b>{user.last_activity_at ? `${dateOnly(user.last_activity_at)} ${timeOnly(user.last_activity_at)}` : 'Sin actividad real'}</b></span>
              <span>⏳ Inactividad: <b>{user.inactivity_days === null ? 'Sin datos' : `${user.inactivity_days} días`}</b></span>
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
  const [filters, setFilters] = useState({ q: '', university: '', faculty: '', career: '', cycle: '' })
  const allCourses = data?.courses || []
  const allUniversities = data?.universities || []
  const allFaculties = data?.faculties || []
  const allCareers = data?.careers || []
  const allCycles = data?.cycles || []
  const universities = unique(allUniversities.map((u) => u.code || u.name).filter(Boolean))
  const faculties = unique(allFaculties
    .filter((f) => !filters.university || (f.university?.code || f.university?.name) === filters.university)
    .map((f) => f.name)
    .filter(Boolean))
  const careers = unique(allCareers
    .filter((c) => !filters.university || (c.faculty?.university?.code || c.faculty?.university?.name) === filters.university)
    .filter((c) => !filters.faculty || c.faculty?.name === filters.faculty)
    .map((c) => c.name)
    .filter(Boolean))
  const cycles = unique(allCycles.map((c) => c.name).filter(Boolean))

  const courses = allCourses.filter((course) => {
    const contextText = `${course.name} ${creatorName(course)} ${course.university?.code || ''} ${course.faculty?.name || ''} ${course.career?.name || ''} ${course.cycle?.name || ''}`.toLowerCase()
    const matchesQ = contextText.includes(filters.q.toLowerCase())
    const matchesUniversity = !filters.university || (course.university?.code || course.university?.name) === filters.university
    const matchesFaculty = !filters.faculty || course.faculty?.name === filters.faculty
    const matchesCareer = !filters.career || course.career?.name === filters.career
    const matchesCycle = !filters.cycle || course.cycle?.name === filters.cycle
    return matchesQ && matchesUniversity && matchesFaculty && matchesCareer && matchesCycle
  })

  return (
    <div className="page fade-in">
      <Header title="Cursos" subtitle="Editar nombres, ver creador y dar de baja cursos." />
      <div className="filters admin-course-filters">
        <input className="input" placeholder="Buscar curso, creador o contexto" value={filters.q} onChange={(e) => setFilters({ ...filters, q: e.target.value })} />
        <select className="input" value={filters.university} onChange={(e) => setFilters({ ...filters, university: e.target.value, faculty: '', career: '' })}>
          <option value="">Todas las universidades</option>{universities.map((u) => <option key={u}>{u}</option>)}
        </select>
        <select className="input" value={filters.faculty} onChange={(e) => setFilters({ ...filters, faculty: e.target.value, career: '' })}>
          <option value="">Todas las facultades</option>{faculties.map((f) => <option key={f}>{f}</option>)}
        </select>
        <select className="input" value={filters.career} onChange={(e) => setFilters({ ...filters, career: e.target.value })}>
          <option value="">Todas las carreras</option>{careers.map((c) => <option key={c}>{c}</option>)}
        </select>
        <select className="input" value={filters.cycle} onChange={(e) => setFilters({ ...filters, cycle: e.target.value })}>
          <option value="">Todos los ciclos</option>{cycles.map((c) => <option key={c}>{c}</option>)}
        </select>
      </div>
      {courses.length === 0 && <Empty text="No hay cursos para los filtros seleccionados. Revisa que se haya ejecutado la migración v1.1.2." compact />}
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
          <p>{course.university?.code || 'Sin universidad'} · {course.faculty?.name || 'Sin facultad'} · {course.career?.name || 'Sin carrera'} · {course.cycle?.name || 'Sin ciclo'} · Creado por: {creatorName(course)}</p>
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

function CourseRequestsSummary({ items = [] }) {
  const pending = items.filter((item) => item.status === 'pending').slice(0, 8)
  if (!pending.length) return <Empty text="No hay solicitudes pendientes de cursos." compact />
  return (
    <div className="recent-list admin-scroll-list compact-list">
      {pending.map((item) => (
        <div key={item.id}>
          <b>{item.proposed_name}</b>
          <span>{fullName(item.requester)} · {item.university?.code || item.university?.name} · {item.career?.name} · {item.cycle?.name} · {dateOnly(item.created_at)}</span>
        </div>
      ))}
    </div>
  )
}

function RecentLogins({ items }) {
  if (!items.length) return <Empty text="Aún no hay accesos registrados hoy." compact />
  return <div className="recent-list">{items.map((item) => <div key={item.id}><b>{fullName(item.profile)}</b><span>{item.career?.name || 'Sin carrera'} · {item.cycle?.name || 'Sin ciclo'} · {timeOnly(item.login_at)}</span></div>)}</div>
}

function BarChart({ data, limit = 8 }) {
  let entries = Object.entries(data || {}).sort((a, b) => Number(b[1] || 0) - Number(a[1] || 0))
  if (entries.length > limit) {
    const top = entries.slice(0, limit)
    const other = entries.slice(limit).reduce((sum, [, value]) => sum + Number(value || 0), 0)
    entries = other > 0 ? [...top, ['Otros', other]] : top
  }
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
  return DEFAULT_SETTINGS
}

export default App
