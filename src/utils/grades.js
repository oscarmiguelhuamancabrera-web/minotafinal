export const DEFAULT_SETTINGS = {
  pc1_percent: 15,
  pc2_percent: 15,
  pc3_percent: 15,
  pc4_percent: 15,
  partial_percent: 20,
  final_percent: 20,
  minimum_grade: 11
}

export const EVALUATIONS = [
  { key: 'pc1', label: 'PC1', group: 'Prácticas calificadas', percentKey: 'pc1_percent' },
  { key: 'pc2', label: 'PC2', group: 'Prácticas calificadas', percentKey: 'pc2_percent' },
  { key: 'pc3', label: 'PC3', group: 'Prácticas calificadas', percentKey: 'pc3_percent' },
  { key: 'pc4', label: 'PC4', group: 'Prácticas calificadas', percentKey: 'pc4_percent' },
  { key: 'partial_exam', label: 'Parcial', group: 'Exámenes', percentKey: 'partial_percent' },
  { key: 'final_exam', label: 'Final', group: 'Exámenes', percentKey: 'final_percent' }
]

export function toNumber(value) {
  if (value === null || value === undefined || value === '') return null
  const normalized = String(value).replace(',', '.')
  const number = Number(normalized)
  return Number.isFinite(number) ? number : null
}

export function formatNumber(value, decimals = 2) {
  if (value === null || value === undefined || Number.isNaN(Number(value))) return '—'
  return Number(value).toFixed(decimals)
}

export function formatPercent(value) {
  const number = Number(value || 0)
  return Number.isInteger(number) ? String(number) : number.toFixed(2)
}

export function getEffectiveMinimum(minimumGrade) {
  const minimum = Number(minimumGrade || 11)
  if (Number.isInteger(minimum) && minimum > 0) {
    return Math.max(0, minimum - 0.5)
  }
  return minimum
}

export function validateSettings(settings) {
  const total = EVALUATIONS.reduce((sum, item) => sum + Number(settings[item.percentKey] || 0), 0)
  if (Math.abs(total - 100) > 0.001) {
    return `La suma de porcentajes debe ser 100%. Actualmente es ${formatNumber(total, 2)}%.`
  }
  const minimum = Number(settings.minimum_grade)
  if (!Number.isFinite(minimum) || minimum < 0 || minimum > 20) {
    return 'La nota mínima debe estar entre 0 y 20.'
  }
  return null
}

export function validateGradeInputs(grades) {
  for (const item of EVALUATIONS) {
    const value = grades[item.key]
    if (value === null || value === undefined || value === '') continue
    const number = toNumber(value)
    if (number === null || number < 0 || number > 20) {
      return `${item.label} debe estar entre 0 y 20.`
    }
  }
  return null
}

export function calculateGradeResult(grades, settings) {
  const error = validateSettings(settings) || validateGradeInputs(grades)
  if (error) return { error, result: null }

  let currentAverage = 0
  let evaluatedWeight = 0
  let pendingWeight = 0
  const pending = []

  for (const item of EVALUATIONS) {
    const percent = Number(settings[item.percentKey] || 0)
    const grade = toNumber(grades[item.key])
    if (grade === null) {
      pendingWeight += percent
      pending.push(item)
    } else {
      currentAverage += grade * (percent / 100)
      evaluatedWeight += percent
    }
  }

  const minimumGrade = Number(settings.minimum_grade || 11)
  const effectiveMinimum = getEffectiveMinimum(minimumGrade)
  const missingPoints = Math.max(0, effectiveMinimum - currentAverage)
  const requiredAverage = pendingWeight > 0 ? missingPoints / (pendingWeight / 100) : null

  let status = 'Sin datos'
  let statusClass = 'info'
  let message = 'Ingresa una o más notas para calcular tu avance.'

  if (evaluatedWeight === 0) {
    status = 'Pendiente'
    message = 'Aún no ingresaste notas. Puedes completar las evaluaciones que ya tienes.'
  } else if (pendingWeight === 0) {
    if (currentAverage >= effectiveMinimum) {
      status = 'Aprobado'
      statusClass = 'success'
      message = 'Ya alcanzaste la nota mínima aprobatoria.'
    } else {
      status = 'Desaprobado'
      statusClass = 'danger'
      message = 'Con las notas ingresadas no alcanzas la nota mínima aprobatoria.'
    }
  } else if (currentAverage >= effectiveMinimum) {
    status = 'Aprobado'
    statusClass = 'success'
    message = 'Ya alcanzaste la nota mínima aprobatoria con las notas ingresadas.'
  } else if (requiredAverage > 20) {
    status = 'No alcanza'
    statusClass = 'danger'
    message = 'Con las evaluaciones pendientes, ya no es posible alcanzar la nota mínima.'
  } else if (requiredAverage >= 15) {
    status = 'En riesgo'
    statusClass = 'warning'
    message = 'Todavía puedes aprobar, pero necesitas una nota alta en lo pendiente.'
  } else {
    status = 'Puede aprobar'
    statusClass = 'success'
    message = 'Todavía puedes aprobar si cumples la nota mínima en lo pendiente.'
  }

  const requiredValues = pending.map((item) => ({
    key: item.key,
    name: item.label,
    value: requiredAverage === null ? null : Math.max(0, requiredAverage)
  }))

  return {
    error: null,
    result: {
      current_average: round2(currentAverage),
      evaluated_weight: round2(evaluatedWeight),
      pending_weight: round2(pendingWeight),
      pending_evaluations: pending.map((item) => item.label).join(', '),
      required_average: requiredAverage === null ? null : round2(Math.max(0, requiredAverage)),
      required_values: requiredValues,
      minimum_grade: minimumGrade,
      status,
      statusClass,
      message
    }
  }
}

export function generateMissingGrades(grades, settings) {
  const { error, result } = calculateGradeResult(grades, settings)
  if (error) return { error, grades, result: null }
  if (!result || result.required_average === null) {
    return { error: 'No hay evaluaciones pendientes para generar.', grades, result }
  }
  if (result.required_average > 20) {
    return { error: 'No es posible generar notas porque se necesitaría más de 20.', grades, result }
  }
  const generated = { ...grades }
  for (const item of EVALUATIONS) {
    const value = toNumber(generated[item.key])
    if (value === null) {
      generated[item.key] = formatNumber(result.required_average, 2)
    }
  }
  const recalculated = calculateGradeResult(generated, settings)
  return { error: null, grades: generated, result: recalculated.result }
}

export function emptyGrades() {
  return {
    pc1: '',
    pc2: '',
    pc3: '',
    pc4: '',
    partial_exam: '',
    final_exam: ''
  }
}

export function normalizeGradesForDb(grades) {
  const normalized = {}
  for (const item of EVALUATIONS) {
    normalized[item.key] = toNumber(grades[item.key])
  }
  return normalized
}

function round2(value) {
  return Math.round((Number(value) + Number.EPSILON) * 100) / 100
}

// ============================================================
// Funciones flexibles para plantillas configurables por universidad
// ============================================================

export function normalizeEvaluationComponents(components = [], fallbackSettings = DEFAULT_SETTINGS) {
  if (components && components.length) {
    return components
      .filter((item) => item.status !== 'inactive')
      .sort((a, b) => Number(a.component_order || 0) - Number(b.component_order || 0))
      .map((item, index) => ({
        key: item.id || item.key || `component_${index + 1}`,
        id: item.id,
        label: item.short_name || item.label || item.name,
        name: item.name || item.short_name || item.label,
        group: item.unit_name || item.group || 'Evaluaciones',
        percent: Number(item.weight_percent ?? item.percent ?? 0)
      }))
  }
  return EVALUATIONS.map((item) => ({
    key: item.key,
    id: item.id || item.key,
    label: item.label,
    name: item.label,
    group: item.group,
    percent: Number(fallbackSettings[item.percentKey] || 0)
  }))
}

export function emptyDynamicGrades(items = []) {
  return Object.fromEntries((items || []).map((item) => [item.key, '']))
}

export function calculateFlexibleGradeResult(grades, items, minimumGrade = 11) {
  const components = normalizeEvaluationComponents(items)
  const total = components.reduce((sum, item) => sum + Number(item.percent || 0), 0)
  if (Math.abs(total - 100) > 0.05) {
    return { error: `La suma de porcentajes debe ser 100%. Actualmente es ${formatNumber(total, 2)}%.`, result: null }
  }

  let currentAverage = 0
  let evaluatedWeight = 0
  let pendingWeight = 0
  const pending = []

  for (const item of components) {
    const percent = Number(item.percent || 0)
    const grade = toNumber(grades[item.key])
    if (grade === null) {
      pendingWeight += percent
      pending.push(item)
      continue
    }
    if (grade < 0 || grade > 20) {
      return { error: `${item.label} debe estar entre 0 y 20.`, result: null }
    }
    evaluatedWeight += percent
    currentAverage += (grade * percent) / 100
  }

  const minimum = Number(minimumGrade || 11)
  const requiredAverage = pendingWeight > 0 ? ((minimum - currentAverage) / pendingWeight) * 100 : null
  const requiredClamped = requiredAverage === null ? null : Math.max(0, requiredAverage)
  const requiredValues = pending.map((item) => ({ key: item.key, name: item.label, value: requiredClamped }))

  let status = 'Sin notas'
  let statusClass = 'neutral'
  let message = 'Ingresa tus notas para calcular tu avance.'

  if (evaluatedWeight > 0 && pendingWeight > 0) {
    status = currentAverage >= minimum ? 'Aprobando' : 'En proceso'
    statusClass = currentAverage >= minimum ? 'success' : 'warning'
    if (requiredClamped > 20) {
      status = 'En riesgo'
      statusClass = 'danger'
      message = 'Con las notas actuales, necesitarías más de 20 en lo pendiente para llegar a la nota mínima.'
    } else {
      message = `Necesitas un promedio aproximado de ${formatNumber(requiredClamped)} en las evaluaciones pendientes.`
    }
  }

  if (pendingWeight === 0) {
    status = currentAverage >= minimum ? 'Aprobado' : 'Desaprobado'
    statusClass = currentAverage >= minimum ? 'success' : 'danger'
    message = currentAverage >= minimum ? 'Llegaste a la nota mínima aprobatoria.' : 'No llegaste a la nota mínima aprobatoria.'
  }

  return {
    error: null,
    result: {
      current_average: Number(currentAverage.toFixed(2)),
      evaluated_weight: Number(evaluatedWeight.toFixed(2)),
      pending_weight: Number(pendingWeight.toFixed(2)),
      pending_evaluations: pending.map((item) => item.label).join(', '),
      required_average: requiredClamped === null ? null : Number(requiredClamped.toFixed(2)),
      required_values: requiredValues,
      status,
      statusClass,
      message,
      minimum_grade: minimum
    }
  }
}

export function generateFlexibleMissingGrades(grades, items, minimumGrade = 11) {
  const calculation = calculateFlexibleGradeResult(grades, items, minimumGrade)
  if (calculation.error) return calculation
  const value = calculation.result.required_average
  if (value === null) return { error: 'No hay evaluaciones pendientes para generar.', result: null }
  if (value > 20) return { error: 'No es posible aprobar con lo pendiente porque se necesitaría más de 20.', result: null }

  const nextGrades = { ...grades }
  for (const item of normalizeEvaluationComponents(items)) {
    if (toNumber(nextGrades[item.key]) === null) nextGrades[item.key] = formatNumber(Math.max(0, value), 2)
  }
  return { grades: nextGrades, ...calculateFlexibleGradeResult(nextGrades, items, minimumGrade) }
}
