# WUUT — What (yo)U Up To

A personal time-documentation app for iPhone. Every quarter hour from waking to sleeping, it
asks what you were doing for the last fifteen minutes. You answer in a sentence. Over a day it
produces an honest record of where your time went; over a week it produces numbers you cannot
argue with.

It is not a diary. Entries are short, factual and written to be counted, not reread.

**Status:** implemented 2026-09-21, not yet compiled. Written without access to Xcode — see §12.
Build instructions are in [docs/SETUP.md](docs/SETUP.md).

---

## 1. Scope of v1

| In | Out (and why) |
| --- | --- |
| iPhone app, all data on device | macOS app — stretch goal, see §11 |
| Start/End the Day, quarter-hour slots | Automatic wake detection — the deliberate start is part of the technique |
| Notification prompt + two follow-ups per slot | Remote push — unavailable on a free Apple ID, and unnecessary |
| Inline text reply from the notification banner | Voice/image capture — text only, by design |
| Live Activity on the lock screen | Home screen widget — needs App Groups, paid-only (§9) |
| Block out ahead for meetings | Snooze — one suppression mechanism is enough |
| Backfill window, then slots lock as Unaccounted | Unlimited retrospective editing — declined, it invites fiction |
| Fixed categories + freeform tags | Automatic classification — revisit once there's real data |
| Day timeline, week breakdown, accounted % | Hour-of-day heatmaps, trends, streaks, caps — §11 |
| End-of-day summary notification | Category caps and interventions — §11 |
| Versioned JSON export + automatic weekly backup | Cloud sync — needs CloudKit, paid-only (§9) |

---

## 2. Platform and stack

- **Native SwiftUI**, single iOS app target plus one widget extension for the Live Activity.
- **Minimum deployment target: iOS 18.0.** Trivially lowerable to 17.0 if the phone needs it;
  17.0 is the floor because of SwiftData.
- **Persistence:** SwiftData, local store only.
- **Notifications:** UserNotifications, local only.
- **Lock screen:** ActivityKit.
- **Charts:** Swift Charts.
- **No third-party dependencies.** Nothing to keep up to date on a hobby project.

Rationale for native over React Native: the whole product is notification behaviour, lock screen
presence and background scheduling. That is precisely the surface where a cross-platform layer
costs the most and delivers the least.

---

## 3. Time model

The single most important part of the spec, because every metric depends on it.

### 3.1 Slot boundaries

- Slots are anchored to **wall-clock quarter hours**: :00, :15, :30, :45.
- **First slot of a day is a stub** running from the moment you tap Start the Day to the next
  quarter hour. Tap at 07:07 and the first slot is `07:07 → 07:15`.
- **Last slot of a day is a stub** running from the last quarter hour to the moment you tap End
  the Day. Tap at 22:38 and the final slot is `22:30 → 22:38`.
- Everything between is a clean aligned 15 minutes.
- **Stub suppression:** if a stub would be shorter than `minimumStubMinutes` (default 3), it is
  not created. Starting at 07:14 gives a first slot of `07:14 → 07:30`; ending at 22:31 simply
  ends the day at 22:30 with no trailing stub.

### 3.2 Consequences

- **Slots are stored as explicit `startAt` / `endAt` timestamps, never as a slot index.**
- **All metrics are duration-weighted.** An 8-minute stub contributes 8 minutes, not 15. This is
  in the schema from day one because retrofitting it would mean rewriting every aggregate.
- **A logical day is not a calendar day.** A day that runs to 01:30 keeps those slots attached to
  the `Day` that started them. `Day.date` is the logical day; slot timestamps are absolute.
- **Auto-end cutoff** (default 02:00 local, configurable) ends a day you forgot to end, marking
  the remaining slots Unaccounted. Without this, one forgotten evening poisons a week of data.
- **DST:** slot maths runs in the day's recorded timezone. A transition mid-day produces one slot
  whose duration is not 15 minutes. That is the truth about that day and the schema records it
  correctly.

---

## 4. Data model (SwiftData)

```
Day
  id                 UUID
  date               Date      // start of the logical day, local
  timeZoneIdentifier String
  startedAt          Date?
  endedAt            Date?
  endedAutomatically Bool
  summaryDeliveredAt Date?
  slots              [Slot]

Slot
  id          UUID
  startAt     Date
  endAt       Date            // explicit — stubs are honest
  text        String?
  category    LogCategory?
  tagKeys     [String]        // inline, not a join — see below
  state       SlotState
  loggedAt    Date?
  source      EntrySource
  day         Day

LogCategory                  // named `LogCategory` in code, to stay clear of type
  id           UUID           // names in Charts and UIKit
  name         String
  colorHex     String         // light appearance
  colorHexDark String         // dark appearance — see §4.1
  symbolName   String         // SF Symbol
  sortOrder    Int
  isArchived   Bool           // archive, never delete — history must stay readable

Tag
  id          UUID
  key         String          // normalised, lowercased — uniqueness lives here
  displayName String
  useCount    Int
  lastUsedAt  Date

BlockOut
  id        UUID
  startAt   Date
  endAt     Date
  text      String
  category  Category?
  createdAt Date
```

```
SlotState   = pending | logged | unaccounted
EntrySource = notification | app | backfill | blockOut | siri
```

`Slot.durationMinutes` is computed from the timestamps. Nothing else is allowed to assume 15.

Tags are stored inline on the slot as normalised keys rather than as a SwiftData many-to-many
relationship. At 64 slots a day the join buys nothing, it makes export trivial, and it removes
the one relationship shape most likely to misbehave. The `Tag` model remains as an index over
those keys, used to rank autocomplete and the week's top-tags list.

### 4.1 Seeded categories

Editable and reorderable in Settings; archived rather than deleted so old entries keep meaning.

Work · Meetings · Admin · Social media · Entertainment · Reading · Exercise · Dog · Chores ·
Errands · Eating · Family & friends · Travel · Rest

`Unaccounted` is not a category. It is the absence of a logged slot, computed from `SlotState`,
so it can never be assigned by hand.

**On the colours.** These were checked with a palette validator rather than chosen by eye, for
lightness band, chroma floor, colour-blind separation and contrast against the surface, in both
appearances. The first attempt had two faults worth recording: Work and Meetings were six units
apart, effectively the same colour for the two categories a working day is mostly made of; and
four categories read as grey, which is reserved here for unaccounted time.

Each category therefore carries **two** hexes. Dark mode is not a lightening of light mode —
the usable lightness band on a dark surface is narrower, so a flipped colour either loses
contrast or blows out.

Fourteen hues cannot all be mutually distinguishable, particularly in dark mode. Rather than
cut the list, **no chart in this app identifies a category by colour alone** — every bar, chip
and legend row carries the category's symbol and name. That constraint is what drove the week
view's form; see §7.6.

---

## 5. Notifications

### 5.1 The 64-request problem

iOS allows **64 pending local notification requests** per app. A 16-hour day is 64 slots; at
three prompts each that is 192 requests, and iOS silently keeps only the 64 soonest. The naive
"schedule the whole day at Start" approach therefore fails quietly around lunchtime.

**Solution: a rolling window.**

- Maintain prompts for the next **18 slot boundaries** = 54 pending requests.
- Reserve the remaining headroom for the day summary and block-out-end notifications.
- 18 slots is **4.5 hours of coverage**, so the window only runs dry if the phone is untouched
  for that long — by which point you have bigger logging problems than scheduling.

**Top-up is triggered by:** app foreground, logging a slot, responding to any notification
(the response handler runs the app briefly, which is the common case), Start/End the Day,
creating or cancelling a block-out, and a `BGAppRefreshTask` as a backstop.

### 5.2 Per-slot escalation

For a slot ending at time `q`, three requests fire at `q`, `q+5min`, `q+11min`:

| | Identifier | Body |
| --- | --- | --- |
| 1 | `slot-<uuid>-1` | "What were you up to? 07:15 – 07:30" |
| 2 | `slot-<uuid>-2` | "Still unlogged — 07:15 – 07:30" |
| 3 | `slot-<uuid>-3` | "Last call for 07:15 – 07:30" |

All three share a `threadIdentifier` so they collapse into one stack rather than three separate
banners. **Logging the slot immediately removes the outstanding requests** via
`removePendingNotificationRequests(withIdentifiers:)`, so you are never nagged about something
you have already answered.

Timings and counts live in Settings — the escalation is the point of the app, but 5 and 11
minutes are a guess and you should be able to tune them.

### 5.3 Notification actions

Category `SLOT_PROMPT`:

1. **Reply** — `UNTextInputNotificationAction`. Type the entry straight into the banner without
   opening the app. This is the feature the whole habit depends on.
2. **Same as last** — copies the previous slot's text, category and tags. One tap. Turns an
   hour-long task into four taps with no typing.
3. **Tapping the notification** opens the app directly to the log sheet for that slot.

### 5.4 Category assignment from a banner reply

A banner reply carries text but no category, which would leave most entries uncategorised and
the metrics useless. Two cheap mitigations, both v1:

- **`CategorySuggester`** looks the normalised text up against previous entries and reuses the
  category of the closest previous match. "walked the dog" lands in Dog without being asked.
- The Today screen surfaces uncategorised entries with one-tap assignment, so a batch of them
  can be cleared in seconds.

No machine learning. A history lookup handles a repetitive life, which is exactly what this app
is for measuring.

### 5.5 Interruption level

Prompts request `.timeSensitive` so they break through Focus modes. **This needs verifying on a
free Personal Team (§9.3)** — if the entitlement is unavailable, the app falls back to `.active`
and still works, it just respects Do Not Disturb.

---

## 6. Live Activity

Starts at Start the Day, ends at End the Day.

**Lock screen shows:** the current slot window, a live countdown to the boundary, the number of
slots awaiting backfill, and the last logged entry truncated to one line.

**Dynamic Island:** compact shows the unlogged count; expanded matches the lock screen.

Two implementation details that matter:

- The countdown uses `Text(timerInterval:)`, so it ticks without the app running. Otherwise the
  lock screen would freeze between launches.
- `ActivityContent(state:staleDate:)` is set to the slot end, so a Live Activity the app has
  failed to update visibly goes stale rather than lying to you.

---

## 7. Interaction design

### 7.1 Today

A vertical timeline, one row per slot, each tinted by category. Unlogged slots render as visible
gaps — the day should *look* incomplete when it is. Header shows total logged time and
**accounted percentage**.

If slots are awaiting backfill, a banner offers the catch-up flow.

### 7.2 Catch-up

A focused sheet that walks unfilled slots oldest first. Each screen: the time window, a text
field, a category picker, "same as previous", "skip". Built for clearing six slots in under a
minute, because that is the realistic failure mode.

### 7.3 Backfill and locking

- A slot stays fillable until `endAt + backfillWindowMinutes` (default 120).
- After that it locks and counts as **Unaccounted** in every metric.
- Locked slots render as locked, showing when they expired. There is no override. That was a
  deliberate choice: a lock you can undo is not a lock, and the honesty of the data is the
  product.
- State transitions happen in a **`reconcile()` pass** on launch, foreground and background
  refresh — computed from timestamps rather than driven by timers, so the app is correct after
  being closed for a day.

### 7.4 Block out ahead

"Next 60 minutes: standup + planning, Meetings."

- Duration presets 30/45/60/90/120 plus custom.
- Pre-fills every slot whose **midpoint** falls inside the block, with `source: .blockOut`, and
  cancels their prompts.
- Any pre-filled slot can still be overwritten afterwards — the block-out is a prediction, not a
  claim.
- The Live Activity shows "Blocked until 10:00".
- One notification when the block ends, so you resume logging rather than drifting.

### 7.5 End of day

End the Day truncates the current slot, ends the Live Activity, and delivers a summary
notification: category breakdown and accounted percentage. This is the only nudge in v1 — real
numbers, once a day, with nothing to configure. Targets and caps come later, once there is data
to set them from (§11).

### 7.6 Week

Two charts, each answering one question, rather than one chart trying to answer both. The
originally sketched fourteen-colour stacked bar was abandoned: no palette makes fourteen
adjacent segments legible, and the colour work in §4.1 proved it rather than assuming it.

- **Per day** — how much of each day did you account for? Seven bars, two stacked series,
  logged and not logged, so a bar's full height is the time the day actually covered and the
  grey remainder is the honest gap. One question, two colours, nothing to get wrong. Rows
  beneath it navigate into a day.
- **By category** — where did the week go? A bar list sorted by duration, each row carrying its
  own symbol, name, duration and share. Identity comes from the label, so fourteen categories
  stay readable and the colour is reinforcement.

Below those, the week's top tags. Everything duration-weighted.

---

## 8. Export and backup

- **Versioned JSON** (`schemaVersion: 1`) covering days, slots, categories and tags.
- **Manual export** through the share sheet.
- **Automatic weekly backup** to a folder you choose once, retained via a security-scoped
  bookmark — an iCloud Drive folder works and needs no entitlement. Keeps the last 8 files.
- **Import merges by UUID**, so restoring is non-destructive.

This is not a nice-to-have. On a free Apple ID the app stops launching every 7 days (§9), and if
signing identity ever changes or the app gets deleted, the store goes with it. The weekly backup
is what makes that survivable. It also becomes the bridge to a Mac app (§11).

---

## 9. Free Apple ID constraints

### 9.1 What it costs

| | Free Personal Team | Paid ($99/yr) |
| --- | --- | --- |
| App lifetime on device | **7 days** | 1 year |
| Install | Cable or local network from Xcode | TestFlight, over the air |
| Apps per device | 3 | unlimited |
| App Groups, CloudKit, remote push | unavailable | available |

**Agreed handling:** weekly re-run from Xcode (about a minute), backed by the automatic weekly
export. Re-running over an existing install with the same bundle ID and signing identity
preserves the data container; deleting the app does not.

### 9.2 Design changes this forced

- **No home screen widget.** Widgets read app data through App Groups, which is paid-only. The
  Live Activity covers the same need on the surface you actually look at.
- **No CloudKit sync.** Replaced by the shared-folder JSON in §8, which also serves as the
  eventual Mac bridge.

### 9.3 Verify on first build

Four things I cannot test from Linux and which behave differently on a Personal Team. Each has a
documented fallback so none of them can block the build:

1. **Time Sensitive Notifications** entitlement → fall back to `.active`.
2. **Live Activities** on a Personal Team → fall back to no Live Activity; the app is still fully
   functional.
3. **Widget extension bundle ID** against the 3-app and 10-App-IDs-per-7-days limits.
4. **`BGAppRefreshTask`** — Info.plist only, expected to be fine.

---

## 10. Project layout

```
WUUT.xcodeproj
WUUT/
  App/        WUUTApp, AppDelegate, RootView
  Model/      Day, Slot, Category, Tag, BlockOut, SlotState, EntrySource
  Services/   SlotScheduler, NotificationScheduler, LiveActivityController,
              DayController, BackfillReconciler, CategorySuggester, BackupService
  Features/
    Today/    TodayView, SlotRow, LogSheet, CatchUpSheet
    Week/     WeekView, CategoryTotalsView
    BlockOut/ BlockOutSheet
    Settings/ SettingsView, CategoryEditor, BackupSettings
  Shared/     QuarterHour (time maths), Formatters, Theme
WUUTWidgets/  ActivityAttributes, Live Activity views
WUUTTests/    QuarterHour, SlotScheduler, BackfillReconciler, aggregation
```

`WUUTTests` covers only pure logic — slot generation, stub suppression, day-crossing, DST,
backfill transitions, duration-weighted aggregation. No simulator needed, fast to run, and it is
where every bug that would corrupt your history would live.

---

## 11. Deferred

**Free, later:** App Intents so Siri and Shortcuts can log a slot; hour-of-day patterns and
week-over-week trends once there are weeks to compare; tag drill-down.

**macOS:** a menu bar app sharing the model layer, reading the same JSON folder. Worth noting
that a Mac app you build locally **never expires** — the 7-day limit is iOS device provisioning
only — so the desktop version is the cheaper platform on a free account, not the more expensive
one.

**Needs the paid tier:** home screen and lock screen widgets, CloudKit sync, over-the-air
install.

**Deliberately parked until there is data:** category caps and threshold alerts, streaks,
consistency nudges. Setting a social media budget before you know your real numbers is guessing.

---

## 12. How this was built

Written on Linux, with no ability to compile or run it. **Expect the first build to surface
some errors** — most likely argument labels or a SwiftUI modifier that has moved. Paste them
and they can be fixed directly. [docs/SETUP.md](docs/SETUP.md) has the build steps and the
four free-account behaviours to verify on device.

The project is generated by [XcodeGen](https://github.com/yonaskolb/XcodeGen) from
`project.yml` rather than shipping a `.xcodeproj`. A hand-written project file is a thousand
lines of UUID-keyed plist, and a subtly wrong one refuses to open at all — not a good bet
without the ability to open it.

`WUUTTests` covers the logic where a bug would quietly corrupt history rather than crash:
quarter-hour arithmetic including a DST transition, the stub rules at both ends of a day, days
that run past midnight, the exact minute a backfill window expires, duration-weighted totals,
and the notification identifier round-trip that a banner reply depends on. It needs no
simulator and runs in seconds.
