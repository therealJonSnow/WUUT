# WUUT — notes for future sessions

Personal iPhone app for quarter-hour time documentation. Single user, local-only, never shipped
to the App Store. **[SPEC.md](SPEC.md) is the agreed design — read it before changing behaviour,
and update it in the same commit when behaviour changes.**

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

## Decisions already made, with reasons

Deciding these again wastes time; if one needs revisiting, say so explicitly.

- Native SwiftUI, not React Native — the product *is* notification and lock screen behaviour.
- Wall-clock quarter-hour alignment with stub first/last slots — keeps cross-day comparisons valid.
- Backfill window then permanent lock — a reversible lock invites retrospective fiction.
- Block out ahead rather than snooze — one suppression mechanism, and it captures what you did.
- Fixed categories plus freeform tags — clean charts without losing detail.
- End-of-day summary as the only nudge in v1 — caps and targets need real data first.
