import { Marginalia, Masthead } from '../components/primitives'

interface Row { label: string; value: string; violet?: boolean }

const SECTIONS: { heading: string; rows: Row[]; note: string }[] = [
  {
    heading: 'Prompts',
    rows: [
      { label: 'First follow-up', value: '5 min' },
      { label: 'Second follow-up', value: '11 min' },
      { label: 'Break through Focus', value: 'On' },
      { label: 'End-of-day summary', value: 'On' },
      { label: 'Lock screen activity', value: 'On' },
    ],
    note: 'Each slot gets a prompt the moment it ends, then two follow-ups, all cancelled as soon as you log it.',
  },
  {
    heading: 'The day',
    rows: [
      { label: 'Shortest stub', value: '3 min' },
      { label: 'Backfill window', value: '2 hours' },
      { label: 'Remind me to start', value: '07:00' },
      { label: 'Close a forgotten day at', value: '02:00' },
    ],
    note: 'After the backfill window a slot is struck out and cannot be edited. A lock you can undo is not a lock.',
  },
  {
    heading: 'Organisation',
    rows: [{ label: 'Categories', value: '14' }],
    note: 'Order sets how they appear when logging, so put the ones you use most at the top.',
  },
  {
    heading: 'Data',
    rows: [{ label: 'Backup and export', value: 'Weekly' }],
    note: 'A dated JSON file, written to a folder you choose. The only thing standing between a deleted app and losing your history.',
  },
  {
    heading: 'Diagnostics',
    rows: [
      { label: 'Notifications', value: 'On' },
      { label: 'Prompts scheduled', value: '57 of 64' },
      { label: 'Window', value: '18 slots' },
    ],
    note: 'iOS keeps at most 64 pending notifications. If this sits at zero during a logged day, something is wrong.',
  },
]

export function Settings() {
  return (
    <div className="screen">
      <Masthead left="Settings" />
      <div className="screen__scroll">
        {SECTIONS.map((section) => (
          <div key={section.heading}>
            <div className="section-head"><Marginalia bold>{section.heading}</Marginalia></div>
            <div className="card">
              {section.rows.map((row, index) => (
                <div key={row.label}>
                  <div className="card__row">
                    <span>{row.label}</span>
                    <span className="mono" style={row.violet ? { color: 'var(--violet)' } : undefined}>{row.value}</span>
                  </div>
                  {index < section.rows.length - 1 && <div className="rule rule--faint" />}
                </div>
              ))}
            </div>
            <p className="note">{section.note}</p>
          </div>
        ))}
      </div>
    </div>
  )
}
