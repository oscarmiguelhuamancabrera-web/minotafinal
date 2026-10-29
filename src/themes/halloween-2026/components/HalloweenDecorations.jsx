export default function HalloweenDecorations({ active, effects }) {
  if (!active) return null
  const batsEnabled = effects?.bats?.enabled !== false
  const websEnabled = effects?.spiderWebs?.enabled !== false
  return (
    <div className="theme-halloween-ornaments" aria-hidden="true">
      {websEnabled && <span className="halloween-web-thread halloween-web-thread-one" />}
      {batsEnabled && <>
        <svg className="halloween-bat halloween-bat-one" viewBox="0 0 120 60" focusable="false">
          <path d="M4 22 25 14 39 24 60 8 81 24 95 14 116 22 94 27 88 49 74 36 60 54 46 36 32 49 26 27Z" />
        </svg>
        <svg className="halloween-bat halloween-bat-two" viewBox="0 0 120 60" focusable="false">
          <path d="M4 24 25 11 40 23 60 5 80 23 95 11 116 24 94 29 88 46 74 35 60 53 46 35 32 46 26 29Z" />
        </svg>
      </>}
    </div>
  )
}
