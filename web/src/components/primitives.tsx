import type { ReactNode } from 'react'
import type { ExportCategory, ExportSlot } from '../types'
import { durationMinutes, formatDuration, formatTime, formatWindow, isStub } from '../stats'

export const Rule = ({ variant }: { variant?: 'ink' | 'faint' }) => (
  <div className={`rule${variant ? ` rule--${variant}` : ''}`} />
)

export const Marginalia = ({
  children, bold, tone,
}: { children: ReactNode; bold?: boolean; tone?: 'violet' | 'tertiary' }) => (
  <span className={`marginalia${bold ? ' marginalia--bold' : ''}${tone ? ` marginalia--${tone}` : ''}`}>
    {children}
  </span>
)

export const Masthead = ({ left }: { left: string }) => (
  <>
    <div className="masthead">
      <Marginalia>{left}</Marginalia>
      <Marginalia bold tone="tertiary">W U U T</Marginalia>
    </div>
    <Rule variant="ink" />
  </>
)

/** Category identity. The name always travels with the swatch — fourteen categories
 *  cannot be told apart by hue, so colour is reinforcement only. */
export const CategoryMark = ({ category }: { category: ExportCategory }) => (
  <span className="mark">
    <span className="mark__swatch" style={{ background: `#${category.colorHex}` }} />
    <Marginalia>{category.name}</Marginalia>
  </span>
)

export const UnaccountedChip = ({ amount }: { amount: string }) => (
  <div className="lost">
    <span className="lost__amount">{amount}</span>
    <span className="chip">Unaccounted</span>
  </div>
)

/** Logged / unaccounted / still open, in proportion. Duration-weighted, so the stub
 *  slots at either end of a day do not overstate themselves. */
export const AccountedBar = ({ logged, unaccounted, pending }: { logged: number; unaccounted: number; pending: number }) => {
  const total = Math.max(1, logged + unaccounted + pending)
  const pct = (value: number) => `${(value / total) * 100}%`
  return (
    <div className="bar">
      <div className="bar__logged" style={{ width: pct(logged) }} />
      <div className="bar__lost" style={{ width: pct(unaccounted) }} />
      <div className="bar__open" style={{ width: pct(pending) }} />
    </div>
  )
}

interface SlotRowProps {
  slot: ExportSlot
  now: Date
  category?: ExportCategory
}

/** One line of the ledger. Logged time is quiet; unaccounted time is the loudest thing
 *  on the page. That inversion is the argument, not decoration. */
export function SlotRow({ slot, now, category }: SlotRowProps) {
  const inProgress =
    slot.state === 'pending' &&
    now >= new Date(slot.startAt) &&
    now < new Date(slot.endAt)

  if (slot.state === 'unaccounted') {
    return (
      <>
        <div className="slot slot--lost">
          <div className="slot__edge" />
          <div className="slot__inner">
            <span className="mono mono--violet">{formatWindow(slot)}</span>
            <Marginalia bold tone="violet">Unaccounted</Marginalia>
            <span className="hatch" />
          </div>
        </div>
        <div className="rule" style={{ background: 'var(--violet)' }} />
      </>
    )
  }

  return (
    <>
      <div className="slot">
        <div className="slot__time">
          <span className={`mono${inProgress ? ' mono--ink' : ''}`}>{formatWindow(slot)}</span>
          {isStub(slot) && <span className="slot__stub">{formatDuration(durationMinutes(slot))}</span>}
        </div>
        <div className="slot__body">
          {slot.state === 'logged' ? (
            <>
              <span className="slot__text">{slot.text}</span>
              <span className="slot__meta">
                {category ? <CategoryMark category={category} /> : <Marginalia tone="violet">No category</Marginalia>}
                {slot.tagKeys.map((tag) => (
                  <span key={tag} className="slot__tag">#{tag}</span>
                ))}
              </span>
            </>
          ) : inProgress ? (
            <div className="slot__progress">
              <span className="slot__marker" />
              <span style={{ display: 'flex', flexDirection: 'column', gap: 5 }}>
                <span className="slot__text" style={{ color: 'var(--ink-2)' }}>In progress</span>
                <Marginalia tone="tertiary">Prompt at {formatTime(slot.endAt)}</Marginalia>
              </span>
            </div>
          ) : (
            <span className="slot__text slot__text--quiet">Not logged yet</span>
          )}
        </div>
      </div>
      <Rule />
    </>
  )
}
