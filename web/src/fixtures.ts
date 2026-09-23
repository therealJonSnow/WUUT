/**
 * The scripted day, verbatim from `docs/FIGMA-SYNC.md`.
 *
 * Every artifact — these screens, the Figma frames, the iOS previews — renders this same
 * day so they can be compared side by side rather than approximately.
 *
 * It is deliberately an imperfect morning: a stub first slot, two consecutive unaccounted
 * quarter hours, one slot in progress. A happy-path fixture would hide the states the
 * design exists to handle.
 *
 * Note the date: 21 September 2026 really is a Monday. The earlier mock renders and the
 * Figma frames say "Monday 22 September", which is a Tuesday — a small illustration of why
 * a fixture beats typing a date into a design by hand.
 */
import type { ExportCategory, ExportDay, ExportDocument, ExportSlot } from './types'

const DAY = '2026-09-21'

/** Local ISO string for the fixture day, so times read as written rather than as UTC. */
function at(time: string, day = DAY): string {
  return new Date(`${day}T${time}:00`).toISOString()
}

export const NOW = new Date(`${DAY}T09:37:00`)

function category(name: string, hex: string, symbol: string, order: number): ExportCategory {
  return {
    id: name.toLowerCase().replace(/[^a-z0-9]+/g, '-'),
    name,
    colorHex: hex,
    symbolName: symbol,
    sortOrder: order,
    isArchived: false,
  }
}

export const CATEGORIES: ExportCategory[] = [
  category('Work', '02589A', 'laptopcomputer', 0),
  category('Meetings', '099EA0', 'person.2.fill', 1),
  category('Admin', 'A07506', 'tray.full.fill', 2),
  category('Social media', '993D6E', 'iphone.gen3', 3),
  category('Entertainment', 'AB5242', 'tv.fill', 4),
  category('Reading', '03A567', 'book.fill', 5),
  category('Exercise', 'CC495F', 'figure.run', 6),
  category('Dog', '8B5505', 'dog.fill', 7),
  category('Chores', '037C9A', 'washer.fill', 8),
  category('Errands', '018370', 'bag.fill', 9),
  category('Eating', 'C57148', 'fork.knife', 10),
  category('Family & friends', 'AE5E8F', 'person.3.fill', 11),
  category('Travel', '0395D1', 'tram.fill', 12),
  category('Rest', '70883D', 'moon.zzz.fill', 13),
]

export const categoryById = new Map(CATEGORIES.map((c) => [c.id, c]))

/** Roughly a working week: Work dominant, then meetings and admin, with the rest trailing. */
const WEIGHTED = [
  'Work', 'Work', 'Work', 'Meetings', 'Work', 'Work', 'Admin', 'Work',
  'Social media', 'Work', 'Meetings', 'Eating', 'Work', 'Admin', 'Dog',
  'Work', 'Reading', 'Work', 'Meetings', 'Exercise',
].map((name) => CATEGORIES.find((c) => c.name === name)!)

type Spec = [start: string, end: string, text: string | null, categoryId: string | null, extra?: Partial<ExportSlot>]

const SPECS: Spec[] = [
  // The 8-minute opening stub: the day started at 07:07, not on a boundary.
  ['07:07', '07:15', 'Fed the dog, let her out', 'dog', { loggedAt: at('07:16') }],
  ['07:15', '07:30', 'Shower, dressed', 'admin', { loggedAt: at('07:32') }],
  ['07:30', '07:45', 'Breakfast, read the news', 'eating', { loggedAt: at('07:48') }],
  ['07:45', '08:00', null, null, { state: 'unaccounted' }],
  ['08:00', '08:15', null, null, { state: 'unaccounted' }],
  ['08:15', '08:30', 'Walked the dog', 'dog', { loggedAt: at('08:44'), source: 'backfill' }],
  ['08:30', '08:45', 'Standup', 'meetings', { loggedAt: at('08:47') }],
  ['08:45', '09:00', 'PR review — auth branch', 'work', { loggedAt: at('09:02') }],
  ['09:00', '09:15', 'PR review — auth branch', 'work', { loggedAt: at('09:16') }],
  ['09:15', '09:30', 'Scrolling, no idea why', 'social-media', { loggedAt: at('09:34') }],
  // In progress: contains NOW.
  ['09:30', '09:45', null, null, { state: 'pending' }],
]

function buildSlots(specs: Spec[], day = DAY): ExportSlot[] {
  return specs.map(([start, end, text, categoryId, extra], index) => ({
    id: `${day}-${index}`,
    startAt: at(start, day),
    endAt: at(end, day),
    text,
    categoryID: categoryId,
    tagKeys: text === 'PR review — auth branch' ? ['deep-work', 'review'] : [],
    state: text ? 'logged' : 'pending',
    source: 'notification',
    loggedAt: null,
    ...extra,
  }))
}

export const TODAY: ExportDay = {
  id: 'fixture-today',
  date: at('00:00'),
  timeZoneIdentifier: 'Europe/London',
  startedAt: at('07:07'),
  endedAt: null,
  endedAutomatically: false,
  slots: buildSlots(SPECS),
}

/** Seven finished days, plus the week before, so the comparison line has a baseline. */
function syntheticDay(dayOffset: number, loggedMin: number, unaccountedMin: number, id: string): ExportDay {
  const date = new Date(`${DAY}T00:00:00`)
  date.setDate(date.getDate() + dayOffset)
  const iso = date.toISOString().slice(0, 10)
  const slots: ExportSlot[] = []
  const totalSlots = Math.round((loggedMin + unaccountedMin) / 15)
  const unaccountedSlots = Math.round(unaccountedMin / 15)
  for (let i = 0; i < totalSlots; i++) {
    const startMinutes = 7 * 60 + i * 15
    const endMinutes = startMinutes + 15
    const fmt = (m: number) => `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`
    // Cluster the unaccounted slots so the longest-gap figure means something.
    const missing = i >= totalSlots - unaccountedSlots
    // Weighted rather than round-robin: an even split across six categories produces a
    // chart where every bar is 13% and the ranking means nothing. A real week is
    // dominated by one or two things, which is the shape the design has to handle.
    const cat = WEIGHTED[i % WEIGHTED.length]
    slots.push({
      id: `${id}-${i}`,
      startAt: at(fmt(startMinutes), iso),
      endAt: at(fmt(endMinutes), iso),
      text: missing ? null : cat.name,
      categoryID: missing ? null : cat.id,
      tagKeys: [],
      state: missing ? 'unaccounted' : 'logged',
      source: i % 5 === 0 ? 'backfill' : 'notification',
      loggedAt: missing ? null : at(fmt(endMinutes + 3), iso),
    })
  }
  return {
    id,
    date: at('00:00', iso),
    timeZoneIdentifier: 'Europe/London',
    startedAt: at('07:00', iso),
    endedAt: at('22:00', iso),
    endedAutomatically: false,
    slots,
  }
}

const THIS_WEEK: [number, number][] = [
  [660, 150], [690, 120], [570, 240], [705, 105], [630, 180], [345, 255], [390, 225],
]
const LAST_WEEK: [number, number][] = [
  [600, 195], [615, 180], [525, 270], [630, 165], [570, 225], [300, 285], [345, 255],
]

export const WEEK: ExportDay[] = THIS_WEEK.map(([l, u], i) => syntheticDay(i, l, u, `this-${i}`))
export const PREVIOUS_WEEK: ExportDay[] = LAST_WEEK.map(([l, u], i) => syntheticDay(i - 7, l, u, `prev-${i}`))

export const FIXTURE_DOCUMENT: ExportDocument = {
  schemaVersion: 1,
  exportedAt: NOW.toISOString(),
  categories: CATEGORIES,
  tags: [
    { id: 't1', key: 'deep-work', displayName: 'deep work', useCount: 12, lastUsedAt: NOW.toISOString() },
    { id: 't2', key: 'review', displayName: 'review', useCount: 8, lastUsedAt: NOW.toISOString() },
    { id: 't3', key: 'auth', displayName: 'auth', useCount: 5, lastUsedAt: NOW.toISOString() },
  ],
  days: [...PREVIOUS_WEEK, ...WEEK, TODAY],
}
