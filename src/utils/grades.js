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
