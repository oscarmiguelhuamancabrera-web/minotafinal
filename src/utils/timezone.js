export const APP_TIME_ZONE = 'America/Lima'

export function todayISO(value = new Date()) {
  const parts = new Intl.DateTimeFormat('en-CA', { timeZone: APP_TIME_ZONE, year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(value)
  const values = Object.fromEntries(parts.filter((part) => part.type !== 'literal').map((part) => [part.type, part.value]))
  return `${values.year}-${values.month}-${values.day}`
}

export function getPeruDayBounds(value = new Date()) {
  const day = todayISO(value)
  const start = new Date(`${day}T00:00:00-05:00`)
  const end = new Date(start)
  end.setUTCDate(end.getUTCDate() + 1)
  return { start, end }
}

export function isWithinPeruPeriod(value, period = 'today', now = new Date()) {
  if (!value || period === 'all') return true
  const date = new Date(value)
  if (Number.isNaN(date.getTime())) return false
  const { start, end } = getPeruDayBounds(now)
  if (period === 'today') return date >= start && date < end
  const days = period === '7d' ? 7 : period === '30d' ? 30 : 0
  if (!days) return true
  const periodStart = new Date(start)
  periodStart.setUTCDate(periodStart.getUTCDate() - days)
  return date >= periodStart && date < end
}

export function formatPeruHour(value) {
  return new Date(value).toLocaleTimeString('es-PE', { timeZone: APP_TIME_ZONE, hour: '2-digit', hour12: false }) + ':00'
}
