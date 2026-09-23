/**
 * The app's export schema, verbatim.
 *
 * These mirror `WUUT/Model/ExportDocument.swift` so the harness can read a real backup
 * file: export from the phone, drop the JSON in, and look at your own days in a browser.
 * Dates are ISO 8601 strings because the Swift encoder uses `.iso8601`.
 */
export type SlotState = 'pending' | 'logged' | 'unaccounted'

export type EntrySource = 'notification' | 'app' | 'backfill' | 'blockOut' | 'siri'

export interface ExportSlot {
  id: string
  startAt: string
  endAt: string
  text?: string | null
  categoryID?: string | null
  tagKeys: string[]
  state: SlotState
  source: EntrySource
  loggedAt?: string | null
}

export interface ExportDay {
  id: string
  date: string
  timeZoneIdentifier: string
  startedAt?: string | null
  endedAt?: string | null
  endedAutomatically: boolean
  slots: ExportSlot[]
}

export interface ExportCategory {
  id: string
  name: string
  colorHex: string
  colorHexDark?: string | null
  symbolName: string
  sortOrder: number
  isArchived: boolean
}

export interface ExportTag {
  id: string
  key: string
  displayName: string
  useCount: number
  lastUsedAt: string
}

export interface ExportDocument {
  schemaVersion: number
  exportedAt: string
  categories: ExportCategory[]
  tags: ExportTag[]
  days: ExportDay[]
}
