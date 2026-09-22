# Brief: make the Figma file match the app

For a Claude Code session running **locally on the Mac**, with Xcode and the Figma MCP
available. Written by the cloud session that built both the app and the Figma file, which
could not compile or run anything — which is precisely why this needs redoing.

## Why this exists

The Figma file was built from Python mock renders, which were themselves built from reading
the SwiftUI source. Two translations, neither checked against a running app, and the code
moved afterwards. You have what the cloud session did not: a simulator.

**Do not trust the existing Figma frames.** Treat them as a starting point to correct, not a
reference to preserve.

## Read first

- `CLAUDE.md` — the constraints. Several are load-bearing and non-obvious.
- `SPEC.md` §7.7 — the visual direction and *why* it is what it is.
- `WUUT/Shared/Theme.swift` — the tokens the Figma variables were generated from.

Two rules from those that matter most here, because a design tool invites breaking both:

1. **Violet is reserved** for the ruling and unaccounted time. Nothing else may use it.
2. **Logged time is quiet, unaccounted time is loud.** If a change makes missing time more
   recessive, it is wrong, however much tidier it looks.

And: **the code is the source of truth.** Figma mirrors it. Never change the app to match
the design file; change the design file to match the app.

## The Figma file

Live file, in Jonny's drafts inside the **Overnice Creatives GmbH** team:

```
https://www.figma.com/design/YYkF9UFJnjjj4mAZg7OQYu
fileKey: YYkF9UFJnjjj4mAZg7OQYu
```

| Node | ID |
|---|---|
| Components page | `2:40` |
| Hatch | `2:41` |
| Category Mark | `2:72` |
| Accounted Bar | `2:75` |
| Slot Row (variant set) | `2:159` |
| Screens page | `3:2` |
| Today / Week / Log entry / Settings | `3:3` / `3:261` / `3:434` / `3:490` |

It already contains 27 variables (collection `WUUT`, one mode, generated from `Theme.swift`),
10 text styles named `Ledger/*`, and the four components above with source paths in their
descriptions. **Reuse all of it.** Do not create a second variable collection, and do not
hardcode a hex where a variable exists.

There is an abandoned duplicate at `Xq3AIaRS5sJG5pwdxUD0gV` in Jonny's *personal* team.
Ignore it.

Before any `use_figma` call you must load the `figma-use` skill, plus `figma-swiftui` and
`figma-generate-design`. The server is explicit that skipping this causes hard-to-debug
failures, and it is right.

## Known drift — verified, not speculative

Start here, then find the rest yourself from real screenshots.

**Settings** — app has five sections, Figma shows three. Missing entirely:
- `End-of-day summary` toggle (Prompts)
- `Shortest stub` stepper (The day)
- the whole **Organisation** section (Categories)
- the whole **Data** section (Backup and export)

**Week** — app has five cards, Figma shows three. Missing:
- **How it was written** — the live / blocked out / reconstructed split plus typical reply delay
- **Top tags**

**Log entry** — the real screen is a SwiftUI `Form`: inset grouped sections, system navigation
bar, standard row insets. The Figma version is a flat invented layout. Structurally wrong,
not just cosmetically.

**No tab bar in any frame.** The app is a `TabView` — Today / Week / Settings.

**Today** is roughly correct and is the least urgent.

## Task 1 — make states reachable

This is the real blocker and the reason the first attempt was guesswork. **You cannot
screenshot a state you cannot reach.** A day with two consecutive unaccounted slots takes two
hours of real time to occur; so do the catch-up banner, an expired backfill window, and a live
block-out.

Build fixtures so every state exists on demand.

Add a preview-only fixture helper that builds an **in-memory** `ModelContainer`
(`isStoredInMemoryOnly: true`) seeded with a scripted day. Use this exact day, because the
Figma frames are built against it and the two should be comparable side by side:

- Started **07:07** — so the first slot is the 8-minute stub `07:07–07:15`
- `07:07–07:15` Fed the dog, let her out — **Dog**
- `07:15–07:30` Shower, dressed — **Admin**
- `07:30–07:45` Breakfast, read the news — **Eating**
- `07:45–08:00` **unaccounted**
- `08:00–08:15` **unaccounted**
- `08:15–08:30` Walked the dog — **Dog**
- `08:30–08:45` Standup — **Meetings**
- `08:45–09:00` PR review — auth branch — **Work**
- `09:00–09:15` PR review — auth branch — **Work**
- `09:15–09:30` Scrolling, no idea why — **Social media**
- `09:30–09:45` in progress, `now` = 09:37

Also seed a week (seven days plus the week before it, so the "up 8 points on last week"
comparison has something to compare against), and a variant with a live block-out.

Traps worth knowing before you start:

- The screens read `DayController`, `AppRouter` and the model container from the environment.
  Nothing renders without all three injected.
- `DayController` owns a `NotificationScheduler` and a `LiveActivityController`. Rendering
  alone should not touch either, but anything that calls `reconcile()` will try to schedule.
  Keep fixtures declarative — build `Day` and `Slot` objects directly rather than driving the
  controller through a simulated day.
- Slots are timestamps, not indices, and the first slot is a stub. Do not generate them with a
  loop that assumes 15 minutes — use `SlotScheduler`, which already has this right and is
  covered by tests.

## Task 2 — render the screens

Add `#Preview` blocks for Today, Week, Log entry, Settings and the catch-up flow using those
fixtures. Useful on its own, independent of any Figma work.

Then add a test target case that renders each screen with SwiftUI's `ImageRenderer` and writes
PNGs to a known directory. Set the renderer scale to 3 for @3x. Deterministic, repeatable,
and it doubles as visual-regression protection later.

**`ImageRenderer` renders the view body, not the window.** No navigation bar, no tab bar, no
safe areas. For those, capture the simulator instead:

```sh
xcrun simctl io booted screenshot today.png
```

Use `ImageRenderer` for content fidelity and simulator capture for chrome. You need both; they
answer different questions.

The app forces `.preferredColorScheme(.light)`. Renders should be light — if anything comes
back dark, something is injecting the wrong environment.

## Task 3 — correct the Figma file

Working from the real screenshots, one screen at a time, with a Figma screenshot after each:

1. Add the missing Settings sections and Week cards.
2. Rebuild **Log entry** to match how a SwiftUI `Form` actually renders.
3. Add the tab bar. Check whether Apple's iOS Figma library is available via `get_libraries`
   and use its `Tab Bar` component rather than hand-rolling one.
4. Correct spacing, insets and type sizes against the captures.
5. Update the `Slot Row` variants if the real rows differ from the component.

Then verify: take a Figma screenshot and the simulator screenshot of the same screen and
compare them directly. Do not declare a screen done on the basis of the script having run
without error — the first build of this file had a text collision that only a screenshot
revealed.

## Fonts

The Figma file uses **IBM Plex Serif** and **IBM Plex Mono** as stand-ins. The app uses
SwiftUI `.serif` and `.monospaced`, which resolve to **New York** and **SF Mono** on iOS.
Those two are not in Figma's hosted font set.

Jonny has installed both locally. If you are running through a context that can see local
fonts (the Figma desktop app), update these ten styles — family and weight only, leaving every
size, line height and tracking exactly as listed:

| Style | → | Size / line height | Tracking |
|---|---|---|---|
| `Ledger/Figure` | New York Bold | 52 / 56 | 0 |
| `Ledger/Figure Small` | New York Bold | 34 / 38 | 0 |
| `Ledger/Entry` | New York Regular | 15 / 21 | 0 |
| `Ledger/Entry Emphasis` | New York Semibold | 15 / 21 | 0 |
| `Ledger/Note` | New York Regular | 12 / 17 | 0 |
| `Ledger/Time` | SF Mono Regular | 12 / 16 | 0 |
| `Ledger/Time Bold` | SF Mono Bold | 12 / 16 | 0 |
| `Ledger/Figure Mono` | SF Mono Bold | 15 / 20 | 0 |
| `Ledger/Marginalia` | SF Mono Regular | 9 / 12 | +1.1 |
| `Ledger/Marginalia Bold` | SF Mono Bold | 9 / 12 | +1.1 |

New York may appear as optical-size families (*New York Small / Medium / Large / Extra
Large*). Pick Small for the 12–15pt styles and Large or Extra Large for the 34 and 52pt
figures.

If `listAvailableFontsAsync` still does not return them, **stop and say so** rather than
substituting something else quietly. That is how the file ended up on IBM Plex in the first
place, and it was the right call — but only because it was stated out loud.

## Do not

- **Do not redesign.** If something in Figma looks better than the app, say so; do not silently
  make the file diverge. The file's job is to mirror.
- **Do not write Code Connect files.** Verified blocked: Code Connect needs a Dev or Full seat
  on Organization or Enterprise, and Overnice is on Professional. Templates written now could
  not be published or validated and would rot. If the plan changes, that is a fresh task.
- **Do not change app behaviour** to make a screen easier to capture. Fixtures are
  preview/test-only and must not alter shipping code paths.
- **Do not create a second variable collection** or hardcode hexes.

## Done looks like

- Every screen state reachable from a fixture, with previews for each.
- A test that writes PNGs of all screens, runnable on demand.
- Figma frames that match those PNGs, verified by comparing screenshots rather than by the
  script exiting cleanly.
- `SPEC.md` updated if anything here revealed the *app* is wrong — which is possible, and more
  valuable than any of the design work.
