# WUUT — What (yo)U Up To

A personal time-documentation app for iPhone. Every quarter hour from waking to sleeping, it
asks what you were doing for the last fifteen minutes. You answer in a sentence. Over a day it
produces an honest record of where your time went; over a week it produces numbers you cannot
argue with.

It is not a diary. Entries are short, factual and written to be counted, not reread.

**Status:** implemented 2026-09-21; first compiled and tested 2026-09-22 against Xcode 27 / iOS 27
SDK, on the simulator, and running on device. Redesigned to the Logbook visual direction (§7.7)
on 2026-09-22. The unit suite passes; the on-device behaviours in §12 are still unverified.
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
| Light appearance only | Dark mode — deferred deliberately, see §7.7 |
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

### 4.1 Seeded categories

Editable and reorderable in Settings; archived rather than deleted so old entries keep meaning.

Work · Meetings · Admin · Social media · Entertainment · Reading · Exercise · Dog · Chores ·
Errands · Eating · Family & friends · Travel · Rest

`Unaccounted` is not a category. It is the absence of a logged slot, computed from `SlotState`,
so it can never be assigned by hand.

**On the colours.** Hues are assigned by *meaning* — ink blue for Work, ochre for Dog,
magenta for Social media — and only their lightness and chroma were optimised, against the
ivory page rather than a neutral white. Violet is excluded from the whole set, because it
rules the page and marks missing time (§7.7).

Each category still carries a `colorHexDark` field. Nothing reads it: the app is light-only.
It is kept in the schema rather than removed because dropping a stored property means
migrating a store holding the only copy of real logged data, which is not a trade worth
making for a field nobody can see.

**The honest number:** the weakest pair in the seeded set is ΔE 7.7 in normal vision and 1.4
under simulated colour blindness, measured with a validator rather than by eye. Fourteen
categories **cannot** be told apart by colour alone, and no palette fixes that — it is a fact
about fourteen, not a tuning failure. It is why every appearance of a category in this app
carries its symbol and its name, and why colour is only ever reinforcement. Cutting the
seeded set to around eight is the only change that would make colour self-sufficient.

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

### 5.1a The start-of-day reminder

A daily reminder at a time you set (07:00 by default), scheduled only while **no** day is
running and removed the moment one starts.

This closes the app's worst failure mode. Missing a slot costs fifteen minutes; forgetting to
tap Start the Day costs the whole day, silently — no prompts, no Live Activity, no summary —
and it is the more likely mistake, because you are not thinking about the app when you wake
up. One repeating calendar request rather than one per day, since the 64-request ceiling is
mostly spent on the prompt window.

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

It also carries **the day's accounted percentage** — the countdown says when the next prompt
lands, the percentage says whether you are winning — and, when a slot is waiting and there is
something to repeat, **a button that logs "same as last" without unlocking the phone**. That
button is the lowest-friction path in the app, and friction is the whole game.

The button is a `LiveActivityIntent`, which needs no paid entitlement. It is compiled into
both targets because the widget needs the type to build the button while iOS performs it in
the app's process; the work sits behind `WUUTIntentHandler`, of which each target has its own
copy and the widget's does nothing.

**Dynamic Island:** compact shows the unlogged count; expanded carries the percentage and the
same button.

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

### 7.4a What Today shows beyond the timeline

Alongside the accounted percentage and the strip, the header reports **the longest unbroken
gap** once it reaches half an hour. A total hides the shape of a day: one ninety-minute hole
and six scattered quarter hours both read as "1h 30m", and only one of them is a day you
should worry about.

### 7.5 End of day

End the Day truncates the current slot, ends the Live Activity, and delivers a summary
notification: accounted percentage with its change against the previous recorded day, logged
and unaccounted totals, the longest gap when it is substantial, and the top categories. This is the only nudge in v1 — real
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

Below those, **how the record was written** — live, blocked out, or reconstructed — with the
typical reply delay, and the week's top tags. Everything duration-weighted.

The provenance split is the honesty check on your own data: a week that is mostly
reconstructed is a week you largely remembered rather than recorded, and you should be able to
see that rather than read a percentage that implies otherwise.

Each headline percentage carries **a comparison with the period before it** — "up 8 points on
last week" — or stays silent when there is nothing to compare against. A percentage in
isolation says nothing; the comparison is the only thing on either screen that answers whether
any of this is working.

### 7.7 Visual design — the Logbook

The first build wore stock iOS chrome with a web dashboard's chart colours: twenty uses of
`systemGroupedBackground`, an accent colour that was never defined and therefore resolved to
Apple's default blue, and fourteen category hues lifted from a general-purpose palette. It
looked like a settings screen because that is what it was made of.

The app is now drawn as what its own first paragraph says it is: **a ledger, not a diary.**

- **Soft ivory paper with violet ruling**, after a Rhodia pad. The ruling is the cheaper half
  of that borrow and the more distinctive.
- **Serif for what you wrote, monospace for what the clock says.** Times and durations are
  data and line up in a fixed column; entries are prose and read like it.
- **Flat, ruled panels** rather than floating rounded cards. This is a page.
- **Violet is reserved.** It rules the page, it marks time you failed to account for, and it
  is the app's accent. No category may claim it, and the seeded set excludes a band of hues
  either side of it.
- **The accent is wired in two places**, because one does not cover the other: `.tint()` on
  the root view for the SwiftUI tree, and `AccentColor` in the asset catalog
  (`ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`) for controls presented by UIKit, such as
  the document picker behind Backup and export. Without both, the tab bar and the pickers
  keep resolving to Apple's default blue — the redesign removed that blue from every surface
  it drew by hand, but a stock control has no way of knowing.

**The inversion is the point.** Logged time is quiet — it is finished and wants nothing from
you. Unaccounted time is the loudest thing on the screen: a violet plate struck through with
hatching. The stock treatment did exactly the opposite, rendering missing time as pale grey
that politely got out of the way, which is precisely backwards for an app whose entire thesis
is that time you cannot account for should bother you.

**Applied everywhere, not just the main screens.** The thing that made the first build look
generic was not any one view — it was twenty views each quietly accepting the system
defaults. Sheets, settings, the category editor, the backup screen and the Live Activity all
wear the same paper, ruling, serif and reserved violet, through shared modifiers
(`logbookSurface`, `logbookRow`, `logbookBars`) rather than per-screen styling. `Theme.swift`
is deliberately free of model references so the widget extension can compile it too, which is
why the Live Activity reads as a paper slip laid on the lock screen rather than a generic
notification.

**There is no red left in the app.** Unaccounted time is the only alarm, and it is violet.
The store-failure banner — the one genuinely catastrophic message — is ink on paper, because
a second alarm colour would weaken the first.

**The icon** is the same argument in one glance: a page of writing with one line struck
out. Four lines, because an hour is four quarter hours; three in ink, one the violet
redaction. It is generated by `scripts/make_icon.py` rather than hand-drawn, so it can be
regenerated if the palette moves — square ends rather than rounded, because bars of that
weight with rounded ends read as a loading skeleton, which is the one thing it must not
look like.

**Light appearance only, deliberately.** The app forces `.light`. Paper at night is a
different design rather than an inverted one, and shipping a half-considered dark mode is
worse than shipping none — the earlier attempt at one is what produced the two-hex category
system that never passed its own checks in dark. See §11.

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

**The web harness** (`web/`) is not a port and is not on a path to becoming one. It renders
the same screens from the same tokens so the Figma pipeline has a live URL to capture — the
pixel-perfect capture tool is web-only, and constructing an iOS design node by node from a
description is exactly what produced a Figma file that did not match the app. The app's
central mechanic cannot be reproduced there anyway: the web has no way to interrupt you once
the tab is closed without a push server, which local-only data forbids.

**Free, later:** a proper dark mode — paper at night designed from scratch, not an inversion,
with the redaction treatment re-solved since a dark block on a dark ground disappears;
App Intents so Siri and Shortcuts can log a slot; hour-of-day patterns and
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

Written on Linux, with no ability to compile or run it. The first build, on 2026-09-22, cost
four errors — all one mistake repeated: a `foregroundStyle` ternary mixing a
`HierarchicalShapeStyle` (`.secondary`) with a `Color` (`.red`), where both branches have to
name the same type. The test suite then caught one real bug, described below.
[docs/SETUP.md](docs/SETUP.md) has the build steps and the four free-account behaviours that
still need verifying on device — the simulator cannot answer any of them.

The project is generated by [XcodeGen](https://github.com/yonaskolb/XcodeGen) from
`project.yml` rather than shipping a `.xcodeproj`. A hand-written project file is a thousand
lines of UUID-keyed plist, and a subtly wrong one refuses to open at all — not a good bet
without the ability to open it.

`WUUTTests` covers the logic where a bug would quietly corrupt history rather than crash:
quarter-hour arithmetic including a DST transition, the stub rules at both ends of a day, days
that run past midnight, the exact minute a backfill window expires, duration-weighted totals,
and the notification identifier round-trip that a banner reply depends on. It needs no
simulator and runs in seconds.

It earned its keep on the first run. `SlotScheduler.slots(dayStart:through:)` walks
`while cursor <= now`, so a `now` landing exactly on a quarter-hour boundary opens one further
slot that has then run for zero minutes. `truncation` took that empty slot as the day's last,
truncated it to nothing, judged it shorter than the minimum stub and returned `nil` — losing a
whole final quarter hour for anyone who ended the day at exactly 22:30. It now discards the
zero-length slot first. `DayController.endDay` had been masking this, because it deletes slots
starting at or after `now` regardless.
