import { toNumber } from './grades.js'

function cleanOcrLine(value = '') {
  return String(value || '').trim().replace(/\s+/g, ' ')
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

function evaluationSignature(value) {
  const normalized = normalizeForMatching(value)
    .replace(/\bfki\b/g, 'fk1')
    .replace(/\bfkl\b/g, 'fk1')
    .replace(/\bul\b/g, 'u1')
  const formative = normalized.match(/\bfk([12])\s*\(?\s*([123])/)
  if (formative) return `fk${formative[1]}_${formative[2]}`
  const summative = normalized.match(/\bu([123])\b/)
  if (summative) return `u${summative[1]}`
  return ''
}

export function parseGradeText(text = '', items = []) {
  const normalizedItems = (items || []).map((item) => ({
    ...item,
    token: normalizeForMatching(`${item.key || ''} ${item.label || ''} ${item.name || ''}`)
  }))
  const aliases = [
    ['pc1', 'pc 1', 'practica 1', 'practica calificada 1', 'práctica calificada 1'],
    ['pc2', 'pc 2', 'practica 2', 'practica calificada 2', 'práctica calificada 2'],
    ['pc3', 'pc 3', 'practica 3', 'practica calificada 3', 'práctica calificada 3'],
    ['pc4', 'pc 4', 'practica 4', 'practica calificada 4', 'práctica calificada 4'],
    ['ep', 'examen parcial', 'parcial'],
    ['ef', 'examen final', 'final']
  ]
  const allLines = String(text || '')
    .split(/\n+/)
    .map((line) => cleanOcrLine(line))
    .filter(Boolean)
  const evaluationHeaderIndex = allLines.findIndex((line) => normalizeForMatching(line) === 'evaluaciones')
  const lines = evaluationHeaderIndex >= 0 ? allLines.slice(evaluationHeaderIndex + 1) : allLines

  function findItem(line) {
    const normalizedLine = normalizeForMatching(line)
    const signature = evaluationSignature(line)
    if (signature) {
      const signatureMatch = normalizedItems.find((item) => evaluationSignature(`${item.key} ${item.label} ${item.name}`) === signature)
      if (signatureMatch) return signatureMatch
    }
    const aliasGroup = aliases.find((group) => group.some((alias) => normalizedLine.includes(normalizeForMatching(alias))))
    if (aliasGroup) {
      const match = normalizedItems.find((item) => aliasGroup.some((alias) => item.token.includes(normalizeForMatching(alias))))
      if (match) return match
    }
    return normalizedItems.find((item) => {
      const candidates = [item.key, item.label, item.name]
        .map(normalizeForMatching)
        .filter((candidate) => candidate.length >= 2)
      return candidates.some((candidate) => normalizedLine.includes(candidate))
    }) || null
  }

  function scoreAtEnd(value, item) {
    const normalizedValue = normalizeForMatching(value)
    const itemNames = [item?.label, item?.name]
      .map(normalizeForMatching)
      .filter(Boolean)
    if (itemNames.some((name) => normalizedValue.endsWith(name))) return null
    const matches = Array.from(value.matchAll(/\b(?:20(?:[.,]0+)?|1?\d(?:[.,]\d{1,2})?)\b/g))
    for (let index = matches.length - 1; index >= 0; index -= 1) {
      const match = matches[index]
      const score = toNumber(match[0])
      if (score === null || score < 0 || score > 20) continue
      const suffix = value.slice((match.index || 0) + match[0].length)
      if (/%/.test(suffix) || /[a-záéíóúñ]/i.test(suffix)) continue
      return score
    }
    return null
  }

  const detected = new Map()
  lines.forEach((line, lineIndex) => {
    const normalizedLine = normalizeForMatching(line)
    if (/\b(pf|pp)\b/.test(normalizedLine) || normalizedLine.includes('promedio final')) return
    if (/\ber\b/.test(normalizedLine) || normalizedLine.includes('examen rezagado')) return
    const item = findItem(line)
    if (!item) return
    let sourceLine = line
    let score = scoreAtEnd(sourceLine, item)
    for (let offset = 1; score === null && offset <= 2 && lineIndex + offset < lines.length; offset += 1) {
      const nextLine = lines[lineIndex + offset]
      const nextItem = findItem(nextLine)
      if (nextItem && nextItem.key !== item.key) break
      sourceLine = `${sourceLine} ${nextLine}`
      score = scoreAtEnd(sourceLine, item)
    }
    const previous = detected.get(item.key)
    // Capturas largas pueden incluir primero un resumen de otro curso.
    // La última calificación válida pertenece a la tabla visible principal.
    if (!previous || score !== null || previous.score === null) {
      detected.set(item.key, {
        key: item.key,
        label: item.label || item.name || item.key,
        score,
        sourceLine
      })
    }
  })

  return Array.from(detected.values())
}
