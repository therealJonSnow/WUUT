import { useMemo, useState } from 'react'
import { CATEGORIES, FIXTURE_DOCUMENT, NOW, PREVIOUS_WEEK, TODAY, WEEK } from './fixtures'
import type { ExportDocument } from './types'
import { Today } from './screens/Today'
import { Week } from './screens/Week'
import { LogSheet } from './screens/LogSheet'
import { Settings } from './screens/Settings'

/**
 * The harness.
 *
 * Renders every screen side by side so they can be captured into Figma in one pass, and
 * accepts a real `ExportDocument` JSON so you can look at your own days rather than the
 * fixture. It deliberately has no behaviour beyond that — see web/README.md.
 */
export default function App() {
  const [doc, setDoc] = useState<ExportDocument>(FIXTURE_DOCUMENT)
  const [isolated, setIsolated] = useState<string | null>(null)
  const [fileName, setFileName] = useState<string | null>(null)

  const categories = useMemo(
    () => new Map(doc.categories.map((c) => [c.id, c])),
    [doc],
  )

  // With a real export, use its most recent day and the seven before it.
  const sorted = useMemo(() => [...doc.days].sort((a, b) => a.date.localeCompare(b.date)), [doc])
  const isFixture = doc === FIXTURE_DOCUMENT
  const today = isFixture ? TODAY : sorted[sorted.length - 1] ?? TODAY
  const week = isFixture ? WEEK : sorted.slice(-8, -1)
  const previousWeek = isFixture ? PREVIOUS_WEEK : sorted.slice(-15, -8)
  const now = isFixture ? NOW : new Date(today.startedAt ?? today.date)

  async function onFile(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]
    if (!file) return
    try {
      const parsed = JSON.parse(await file.text()) as ExportDocument
      if (typeof parsed.schemaVersion !== 'number' || !Array.isArray(parsed.days)) {
        throw new Error('not a WUUT export')
      }
      setDoc(parsed)
      setFileName(file.name)
    } catch (error) {
      setFileName(`could not read ${file.name} — ${(error as Error).message}`)
    }
  }

  const loggedSlot = today.slots.find((s) => s.state === 'logged' && s.text)
  const screens: { id: string; label: string; node: React.ReactNode }[] = [
    { id: 'today', label: 'Today', node: <Today day={today} now={now} categories={categories} /> },
    { id: 'week', label: 'Week', node: <Week week={week} previousWeek={previousWeek} categories={categories} /> },
    {
      id: 'log',
      label: 'Log entry',
      node: loggedSlot ? (
        <LogSheet
          slot={loggedSlot}
          categories={doc.categories}
          selectedCategoryId={loggedSlot.categoryID ?? ''}
          previousEntry="Walked the dog"
          lockAt={new Date(new Date(loggedSlot.endAt).getTime() + 2 * 3600_000).toISOString()}
        />
      ) : null,
    },
    { id: 'settings', label: 'Settings', node: <Settings /> },
  ]

  const visible = isolated ? screens.filter((s) => s.id === isolated) : screens

  return (
    <div className="harness">
      <div className="harness__bar">
        <strong>WUUT — design harness</strong>
        <button onClick={() => setIsolated(null)} aria-pressed={isolated === null}>All</button>
        {screens.map((screen) => (
          <button key={screen.id} onClick={() => setIsolated(screen.id)} aria-pressed={isolated === screen.id}>
            {screen.label}
          </button>
        ))}
        <label>
          Load export
          <input type="file" accept="application/json,.json" onChange={onFile} style={{ display: 'none' }} />
        </label>
        <span>{fileName ?? `fixture · ${CATEGORIES.length} categories`}</span>
      </div>

      <p className="harness__note">
        Renders the iOS app's screens from the scripted fixture in <code>docs/FIGMA-SYNC.md</code>,
        so this, the Figma frames and the iOS previews all show the same day. Colours come from{' '}
        <code>Theme.swift</code> via <code>scripts/extract_tokens.py</code>. Not a working app —
        there is no scheduling, no persistence and no notifications.
      </p>

      <div className="harness__screens">
        {visible.map((screen) => (
          <div key={screen.id}>
            {screen.node}
            <div className="harness__label">{screen.label}</div>
          </div>
        ))}
      </div>
    </div>
  )
}
