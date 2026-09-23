/**
 * Display-only mirrors of `WUUT/Services/DayStatistics.swift` and `Formatters.swift`.
 *
 * This is the one place the harness duplicates logic from the app, and therefore the one
 * place it can disagree with it. Kept deliberately small for that reason. The Swift side
 * is authoritative and is the side with tests; if these ever disagree, Swift is right.
 *
 * Everything is duration-weighted. The first and last slot of a day are short stubs, so
 * counting slots and multiplying by fifteen overstates every figure.
 */
import type { ExportDay, ExportSlot } from './types'

export type Provenance = 'live' | 'planned' | 'reconstructed'

export const provenanceLabel: Record<Provenance, string> = {
  live: 'Written live',
  planned: 'Blocked out',
  reconstructed: 'Reconstructed',
}

export function durationMinutes(slot: ExportSlot): number {
  const ms = new Date(slot.endAt).getTime() - new Date(slot.startAt).getTime()
  return ms > 0 ? Math.round(ms / 60000) : 0
}

export function isStub(slot: ExportSlot): boolean {
  return durationMinutes(slot) < 15
}

const sum = (slots: ExportSlot[]) => slots.reduce((total, s) => total + durationMinutes(s), 0)

export const loggedMinutes = (day: ExportDay) => sum(day.slots.filter((s) => s.state === 'logged'))
export const unaccountedMinutes = (day: ExportDay) => sum(day.slots.filter((s) => s.state === 'unaccounted'))
export const pendingMinutes = (day: ExportDay) => sum(day.slots.filter((s) => s.state === 'pending'))
export const elapsedMinutes = (day: ExportDay) => sum(day.slots)

/** Logged share of everything that has settled. A fresh day is 100%, not 0%. */
export function accountedFraction(logged: number, unaccounted: number): number {
  const settled = logged + unaccounted
  return settled > 0 ? logged / settled : 1
}

/**
 * The longest unbroken run of unaccounted time. One ninety-minute hole and six scattered
 * quarter hours both total 1h 30m, and only one of them is a day worth worrying about.
 */
export function longestGapMinutes(slots: ExportSlot[]): number {
  const ordered = [...slots].sort((a, b) => a.startAt.localeCompare(b.startAt))
  let longest = 0
  let run = 0
  for (const slot of ordered) {
    if (slot.state === 'unaccounted') {
      run += durationMinutes(slot)
      longest = Math.max(longest, run)
    } else {
      run = 0
    }
  }
  return longest
}

export function provenanceOf(slot: ExportSlot): Provenance {
  if (slot.source === 'blockOut') return 'planned'
  if (slot.source === 'backfill') return 'reconstructed'
  return 'live'
}

export function minutesByProvenance(slots: ExportSlot[]): Record<Provenance, number> {
  const totals: Record<Provenance, number> = { live: 0, planned: 0, reconstructed: 0 }
  for (const slot of slots) {
    if (slot.state !== 'logged') continue
    totals[provenanceOf(slot)] += durationMinutes(slot)
  }
  return totals
}

/** Median, not mean — one entry logged eleven hours late would swamp an average. */
export function medianResponseMinutes(slots: ExportSlot[]): number | null {
  const delays = slots
    .filter((s) => s.state === 'logged' && s.loggedAt && provenanceOf(s) !== 'planned')
    .map((s) => Math.max(0, Math.round((new Date(s.loggedAt!).getTime() - new Date(s.endAt).getTime()) / 60000)))
    .sort((a, b) => a - b)
  if (delays.length === 0) return null
  const middle = Math.floor(delays.length / 2)
  return delays.length % 2 === 1 ? delays[middle] : Math.floor((delays[middle - 1] + delays[middle]) / 2)
}

export function percentagePointChange(previous: number | null, current: number): number | null {
  if (previous === null) return null
  return Math.round(current * 100) - Math.round(previous * 100)
}

// ---- formatting ------------------------------------------------------------

export function formatDuration(minutes: number): string {
  if (minutes <= 0) return '0m'
  const hours = Math.floor(minutes / 60)
  const rest = minutes % 60
  if (hours === 0) return `${rest}m`
  if (rest === 0) return `${hours}h`
  return `${hours}h ${rest}m`
}

const timeFormat = new Intl.DateTimeFormat('en-GB', { hour: '2-digit', minute: '2-digit', hour12: false })

export const formatTime = (iso: string) => timeFormat.format(new Date(iso))
export const formatWindow = (slot: ExportSlot) => `${formatTime(slot.startAt)}–${formatTime(slot.endAt)}`
export const formatPercent = (fraction: number) => `${Math.round(Math.min(1, Math.max(0, fraction)) * 100)}%`

const longDateFormat = new Intl.DateTimeFormat('en-GB', { weekday: 'long', day: 'numeric', month: 'long' })
export const formatLongDate = (iso: string) => longDateFormat.format(new Date(iso))
