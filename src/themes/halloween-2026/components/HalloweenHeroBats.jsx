/**
 * Ambient bats for the seasonal hero. This component is deliberately scoped
 * to the Halloween theme so the original experience never receives these
 * nodes or animations.
 */
export default function HalloweenHeroBats({ active, effects }) {
  if (!active || effects?.bats?.enabled === false) return null

  return (
    <div className="halloween-hero-bats" aria-hidden="true">
      <svg className="halloween-hero-bat halloween-hero-bat-one" viewBox="0 0 120 60" focusable="false">
        <path d="M4 22 25 14 39 24 60 8 81 24 95 14 116 22 94 27 88 49 74 36 60 54 46 36 32 49 26 27Z" />
      </svg>
      <svg className="halloween-hero-bat halloween-hero-bat-two" viewBox="0 0 120 60" focusable="false">
        <path d="M4 24 25 11 40 23 60 5 80 23 95 11 116 24 94 29 88 46 74 35 60 53 46 35 32 46 26 29Z" />
      </svg>
      <svg className="halloween-hero-bat halloween-hero-bat-three" viewBox="0 0 120 60" focusable="false">
        <path d="M5 20 24 15 41 27 60 12 79 27 96 15 115 20 93 30 86 45 72 37 60 52 48 37 34 45 27 30Z" />
      </svg>
    </div>
  )
}
