import type { ExportCategory, ExportDay } from '../types'
import {
  accountedFraction, formatDuration, formatLongDate, formatTime,
  loggedMinutes, longestGapMinutes, pendingMinutes, unaccountedMinutes,
} from '../stats'
import { AccountedBar, Masthead, Rule, SlotRow, UnaccountedChip } from '../components/primitives'

export function Today({ day, now, categories }: { day: ExportDay; now: Date; categories: Map<string, ExportCategory> }) {
  const logged = loggedMinutes(day)
  const lost = unaccountedMinutes(day)
  const pending = pendingMinutes(day)
  const gap = longestGapMinutes(day.slots)
  const ordered = [...day.slots].sort((a, b) => b.startAt.localeCompare(a.startAt))

  return (
    <div className="screen">
      <Masthead left={formatLongDate(day.date)} />

      <div className="headline">
        <div className="figure">
          <span className="figure__number">{Math.round(accountedFraction(logged, lost) * 100)}</span>
          <span className="figure__percent">%</span>
          <span className="figure__label">accounted for</span>
        </div>
        {lost > 0 && <UnaccountedChip amount={formatDuration(lost)} />}
      </div>

      <AccountedBar logged={logged} unaccounted={lost} pending={pending} />

      <div className="stats">
        <span className="mono">{formatDuration(logged)} logged</span>
        {gap >= 30 ? (
          <span className="mono" style={{ color: 'var(--violet)' }}>· longest gap {formatDuration(gap)}</span>
        ) : (
          day.startedAt && <span className="mono" style={{ color: 'var(--ink-3)' }}>· started {formatTime(day.startedAt)}</span>
        )}
      </div>

      <div style={{ paddingTop: 16 }}><Rule variant="ink" /></div>

      <div className="screen__scroll">
        {ordered.map((slot) => (
          <SlotRow
            key={slot.id}
            slot={slot}
            now={now}
            category={slot.categoryID ? categories.get(slot.categoryID) : undefined}
          />
        ))}
      </div>
    </div>
  )
}
