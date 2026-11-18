import Icon from './Icon.jsx'

const fmt = (value, decimals = 2) => (value === null || value === undefined || Number.isNaN(Number(value)) ? '—' : Number(value).toFixed(decimals))

// Anillo con el promedio general (escala 0–20).
export function AverageRing({ value, label = 'Promedio general' }) {
  const radius = 52
  const circumference = 2 * Math.PI * radius
  const ratio = value === null || value === undefined ? 0 : Math.max(0, Math.min(1, Number(value) / 20))
  return (
    <div className="avg-ring" role="img" aria-label={`${label}: ${fmt(value)} de 20`}>
      <svg viewBox="0 0 128 128" aria-hidden="true">
        <defs>
          <linearGradient id="avgRingGradient" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stopColor="#c4b5fd" />
            <stop offset="100%" stopColor="#7c3aed" />
          </linearGradient>
        </defs>
        <circle className="avg-ring-track" cx="64" cy="64" r={radius} />
        <circle
          className="avg-ring-value"
          cx="64"
          cy="64"
          r={radius}
          stroke="url(#avgRingGradient)"
          strokeDasharray={`${circumference * ratio} ${circumference}`}
          transform="rotate(-90 64 64)"
        />
      </svg>
      <div className="avg-ring-label">
        <strong>{fmt(value)}</strong>
        <span>{label}</span>
      </div>
    </div>
  )
}

export function StatusLegend({ approved, progress, failed }) {
  const rows = [
    ['approved', 'Aprobados', approved],
    ['progress', 'En proceso', progress],
    ['failed', 'Desaprobados', failed]
  ]
  return (
    <ul className="status-legend">
      {rows.map(([key, label, count]) => (
        <li key={key}>
          <i className={`dot ${key}`} aria-hidden="true" />
          <span>{label}</span>
          <b>{count}</b>
        </li>
      ))}
    </ul>
  )
}

// Línea de evolución del promedio por ciclo. points: [{ id, label, name, value }]
export function EvolutionChart({ points = [] }) {
  const width = 560
  const height = 220
  const pad = { top: 16, right: 18, bottom: 34, left: 40 }
  const innerW = width - pad.left - pad.right
  const innerH = height - pad.top - pad.bottom
  const ticks = [0, 5, 10, 15, 20]
  const x = (index) => pad.left + (points.length <= 1 ? innerW / 2 : (innerW * index) / (points.length - 1))
  const y = (value) => pad.top + innerH - (Math.max(0, Math.min(20, value)) / 20) * innerH

  const coords = points.map((point, index) => [x(index), y(point.value)])
  const line = coords.map(([cx, cy], index) => `${index ? 'L' : 'M'}${cx.toFixed(1)},${cy.toFixed(1)}`).join(' ')
  const area = coords.length > 1
    ? `${line} L${coords[coords.length - 1][0].toFixed(1)},${pad.top + innerH} L${coords[0][0].toFixed(1)},${pad.top + innerH} Z`
    : ''

  return (
    <svg className="evolution-chart" viewBox={`0 0 ${width} ${height}`} role="img" aria-label={`Evolución del promedio: ${points.map((p) => `${p.name} ${fmt(p.value)}`).join(', ') || 'sin datos'}`}>
      <defs>
        <linearGradient id="evolutionArea" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor="#8b5cf6" stopOpacity=".55" />
          <stop offset="100%" stopColor="#8b5cf6" stopOpacity="0" />
        </linearGradient>
      </defs>
      {ticks.map((tick) => (
        <g key={tick}>
          <line className="evo-grid" x1={pad.left} x2={width - pad.right} y1={y(tick)} y2={y(tick)} />
          <text className="evo-axis" x={pad.left - 10} y={y(tick) + 4} textAnchor="end">{tick.toFixed(0)}</text>
        </g>
      ))}
      {area && <path d={area} fill="url(#evolutionArea)" />}
      {coords.length > 1 && <path className="evo-line" d={line} />}
      {coords.map(([cx, cy], index) => (
        <g key={points[index].id}>
          <circle className="evo-point" cx={cx} cy={cy} r="5.5">
            <title>{`${points[index].name}: ${fmt(points[index].value)}`}</title>
          </circle>
          <text className="evo-axis evo-x" x={cx} y={height - 10} textAnchor="middle">{points[index].label}</text>
        </g>
      ))}
    </svg>
  )
}

export function TrendBadge({ delta }) {
  if (delta === null || delta === undefined) return null
  const up = delta >= 0
  return (
    <span className={`trend-badge ${up ? 'up' : 'down'}`}>
      <Icon name={up ? 'arrowUp' : 'arrowDown'} size={14} strokeWidth={2.4} />
      <b>{`${up ? '+' : ''}${fmt(delta)}`}</b>
      <span>vs. ciclo anterior</span>
    </span>
  )
}
