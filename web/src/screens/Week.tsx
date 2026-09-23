import type { ExportCategory, ExportDay } from '../types'
import {
  accountedFraction, durationMinutes, formatDuration, formatPercent, loggedMinutes,
  medianResponseMinutes, minutesByProvenance, percentagePointChange, provenanceLabel,
  unaccountedMinutes,
} from '../stats'
import { Marginalia, Masthead, Rule, UnaccountedChip } from '../components/primitives'
import type { Provenance } from '../stats'

interface Props {
  week: ExportDay[]
  previousWeek: ExportDay[]
  categories: Map<string, ExportCategory>
}

export function Week({ week, previousWeek, categories }: Props) {
  const logged = week.reduce((t, d) => t + loggedMinutes(d), 0)
  const lost = week.reduce((t, d) => t + unaccountedMinutes(d), 0)
  const fraction = accountedFraction(logged, lost)

  const prevLogged = previousWeek.reduce((t, d) => t + loggedMinutes(d), 0)
  const prevLost = previousWeek.reduce((t, d) => t + unaccountedMinutes(d), 0)
  const change = percentagePointChange(
    prevLogged + prevLost > 0 ? accountedFraction(prevLogged, prevLost) : null,
    fraction,
  )

  const peak = Math.max(...week.map((d) => loggedMinutes(d) + unaccountedMinutes(d)), 1)
  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S']

  const totals = new Map<string, number>()
  for (const day of week) {
    for (const slot of day.slots) {
      if (slot.state !== 'logged' || !slot.categoryID) continue
      totals.set(slot.categoryID, (totals.get(slot.categoryID) ?? 0) + durationMinutes(slot))
    }
  }
  const grand = logged + lost
  const ranked = [...totals.entries()].sort((a, b) => b[1] - a[1]).slice(0, 6)
  const widest = Math.max(ranked[0]?.[1] ?? 0, lost, 1)

  const allSlots = week.flatMap((d) => d.slots)
  const provenance = minutesByProvenance(allSlots)
  const provenanceTotal = Object.values(provenance).reduce((a, b) => a + b, 0)
  const median = medianResponseMinutes(allSlots)

  return (
    <div className="screen">
      <Masthead left="15 – 21 September" />

      <div className="headline">
        <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
          <div className="figure">
            <span className="figure__number figure__number--small">{Math.round(fraction * 100)}</span>
            <span className="figure__percent">%</span>
            <span className="figure__label">accounted for</span>
          </div>
          {change !== null && (
            <Marginalia tone={change < 0 ? 'violet' : undefined}>
              {change === 0 ? 'level with last week'
                : change > 0 ? `up ${change} points on last week`
                : `down ${-change} points on last week`}
            </Marginalia>
          )}
        </div>
        {lost > 0 && <UnaccountedChip amount={formatDuration(lost)} />}
      </div>

      <div className="section-head"><Marginalia bold>Per day</Marginalia></div>
      <div className="chart">
        {week.map((day, i) => {
          const l = loggedMinutes(day)
          const u = unaccountedMinutes(day)
          return (
            <div className="chart__col" key={day.id}>
              <div className="chart__stack">
                <div className="chart__lost" style={{ height: `${(u / peak) * 132}px` }} />
                <div className="chart__logged" style={{ height: `${(l / peak) * 132}px` }} />
              </div>
              <span className="mono">{labels[i]}</span>
            </div>
          )
        })}
      </div>
      <Rule variant="ink" />

      <div className="section-head"><Marginalia bold>By category</Marginalia></div>
      <div className="screen__scroll">
        {ranked.map(([id, minutes]) => {
          const category = categories.get(id)
          const colour = category ? `#${category.colorHex}` : 'var(--ink-3)'
          return (
            <div key={id}>
              <div className="total">
                <div className="total__top">
                  <span className="mark__swatch" style={{ background: colour }} />
                  <span className="total__name">{category?.name ?? id}</span>
                  <span className="total__dur">{formatDuration(minutes)}</span>
                  <span className="total__pct">{formatPercent(minutes / grand)}</span>
                </div>
                <div className="total__track" style={{ background: colour, width: `${(minutes / widest) * 100}%` }} />
              </div>
              <Rule variant="faint" />
            </div>
          )
        })}
        <div className="total">
          <div className="total__top">
            <span className="mark__swatch" style={{ background: 'var(--violet)' }} />
            <span className="total__name" style={{ color: 'var(--violet)' }}>Unaccounted</span>
            <span className="total__dur" style={{ color: 'var(--violet)' }}>{formatDuration(lost)}</span>
            <span className="total__pct">{formatPercent(lost / grand)}</span>
          </div>
          <div className="total__track" style={{ background: 'var(--violet)', width: `${(lost / widest) * 100}%` }} />
        </div>
        <Rule variant="faint" />

        <div className="section-head"><Marginalia bold>How it was written</Marginalia></div>
        {(Object.keys(provenance) as Provenance[]).map((kind) =>
          provenance[kind] > 0 ? (
            <div className="card__row" key={kind} style={{ padding: '8px 0' }}>
              <span>{provenanceLabel[kind]}</span>
              <span className="total__dur">{formatDuration(provenance[kind])}</span>
              <span className="total__pct">{formatPercent(provenance[kind] / provenanceTotal)}</span>
            </div>
          ) : null,
        )}
        {median !== null && (
          <>
            <Rule variant="faint" />
            <div className="card__row" style={{ padding: '8px 0' }}>
              <span style={{ color: 'var(--ink-2)' }}>Typical reply</span>
              <span className="mono">{median === 0 ? 'within the slot' : `${median} min after`}</span>
            </div>
          </>
        )}
      </div>
    </div>
  )
}
