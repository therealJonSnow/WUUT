import type { ExportCategory, ExportSlot } from '../types'
import { formatTime, formatWindow } from '../stats'
import { Marginalia, Rule } from '../components/primitives'

interface Props {
  slot: ExportSlot
  categories: ExportCategory[]
  selectedCategoryId: string
  previousEntry?: string
  lockAt: string
}

export function LogSheet({ slot, categories, selectedCategoryId, previousEntry, lockAt }: Props) {
  return (
    <div className="screen">
      <div className="masthead" style={{ alignItems: 'center' }}>
        <span style={{ fontSize: 12, color: 'var(--ink-2)' }}>Cancel</span>
        <span style={{ fontSize: 15, fontWeight: 600 }}>Log entry</span>
        <span style={{ fontSize: 12 }}>Save</span>
      </div>
      <Rule variant="ink" />

      <div style={{ display: 'flex', gap: 8, alignItems: 'center', paddingTop: 20 }}>
        <span className="mono mono--bold mono--ink">{formatWindow(slot)}</span>
        <Marginalia tone="tertiary">Struck out at {formatTime(lockAt)}</Marginalia>
      </div>

      <div style={{ paddingTop: 10 }}>
        <div className="field">{slot.text ?? ''}</div>
      </div>

      {previousEntry && (
        <div style={{ paddingTop: 8 }}>
          <div className="subtle">
            <Marginalia tone="tertiary">Same as last</Marginalia>
            <span style={{ fontSize: 12, color: 'var(--ink-2)' }}>{previousEntry}</span>
          </div>
        </div>
      )}

      <div className="section-head"><Marginalia bold>Category</Marginalia></div>
      <div className="grid">
        {categories.slice(0, 8).map((category) => {
          const on = category.id === selectedCategoryId
          return (
            <div className={`cat${on ? ' cat--on' : ''}`} key={category.id}>
              <span className="mark__swatch" style={{ background: `#${category.colorHex}` }} />
              <Marginalia bold={on}>{category.name}</Marginalia>
            </div>
          )
        })}
      </div>

      <div className="section-head"><Marginalia bold>Tags</Marginalia></div>
      <div className="tagrow">
        {['#deep-work', '#review', '#auth'].map((tag) => <span key={tag}>{tag}</span>)}
      </div>
    </div>
  )
}
