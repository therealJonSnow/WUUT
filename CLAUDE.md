# WUUT — notes for future sessions

Personal iPhone app for quarter-hour time documentation. Single user, local-only, never shipped
to the App Store. **[SPEC.md](SPEC.md) is the agreed design — read it before changing behaviour,
and update it in the same commit when behaviour changes.**

## Where things are

`project.yml` generates the Xcode project (`xcodegen generate`); the `.xcodeproj` is
gitignored. Pure logic lives in `WUUT/Services` and `WUUT/Shared` and is covered by
`WUUTTests`, which run without a simulator. `WUUT/Model` is SwiftData. `WUUTWidgets` is the
Live Activity only — there is no home screen widget, and cannot be one (see below).
`docs/SETUP.md` is the build and install guide.

**On a Mac with Xcode**, build with `./scripts/build.sh` (or `./scripts/build.sh test`), which
prints only the unique error lines and writes the full log to `build.log`. Prefer it over a
bare `xcodebuild`, whose output is thousands of lines of noise.

## Constraints that are easy to forget

- **Cannot build or test here.** This repo is worked on from Linux; there is no Xcode. Swift is
  written blind and verified on the owner's Mac. Keep pure logic in `Services/` and `Shared/` and
  cover it with `WUUTTests`, which run without a simulator.
- **Free Apple ID (Personal Team).** No App Groups, no CloudKit, no remote push — so no home
  screen widget and no cloud sync. Don't propose them as if they were available. See SPEC §9.
- **64 pending local notifications, hard limit.** Never schedule a whole day at once. The rolling
  18-slot window in `NotificationScheduler` exists for this reason. See SPEC §5.1.
- **Slots are timestamps, not indices.** The first and last slot of a day are short stubs, so
  every aggregate must be duration-weighted. Nothing may assume 15 minutes. See SPEC §3.
- **A logical day is not a calendar day.** It can run past midnight. `Day.date` is the logical
  day; slot times are absolute.
- **Backfill locking has no override**, by explicit choice. Don't add an escape hatch.
- **The model type is `LogCategory`, not `Category`** — kept clear of type names in Charts and
  UIKit. Tags are inline `Slot.tagKeys: [String]`, not a many-to-many; the `Tag` model is just
  an index for autocomplete.
- **Light appearance only.** The app forces `.preferredColorScheme(.light)`. Don't add dark
  styling piecemeal; dark mode is a separate design (SPEC §7.7 and §11). `colorHexDark` is
  dead schema kept to avoid a migration — nothing reads it.
- **Violet is reserved** for the ruling and for unaccounted time. No category, button or
  accent may use it.
- **No chart may identify a category by colour alone.** The seeded set's weakest pair is
  ΔE 7.7 normal / 1.4 simulated-CVD: fourteen categories cannot be separated by colour, and
  no palette fixes it. Every bar, chip and legend row carries the symbol and name. Validate
  any palette change with a validator, don't eyeball it.

## Decisions already made, with reasons

Deciding these again wastes time; if one needs revisiting, say so explicitly.

- Native SwiftUI, not React Native — the product *is* notification and lock screen behaviour.
- Wall-clock quarter-hour alignment with stub first/last slots — keeps cross-day comparisons valid.
- Backfill window then permanent lock — a reversible lock invites retrospective fiction.
- Block out ahead rather than snooze — one suppression mechanism, and it captures what you did.
- Fixed categories plus freeform tags — clean charts without losing detail.
- End-of-day summary as the only nudge in v1 — caps and targets need real data first.
- Logbook visual direction: ivory paper, violet ruling, serif prose, mono times, flat ruled
  panels. Logged time is quiet, unaccounted time is loud — that inversion is the argument,
  so don't "tidy" missing time into something recessive.
- Week view is two small charts (per-day logged-vs-not, and a labelled category bar list), not
  one fourteen-colour stacked bar. The stack was tried and rejected on legibility grounds.
- The project is generated from `project.yml` rather than committing a `.xcodeproj`, because a
  hand-written project file cannot be verified without opening it.
