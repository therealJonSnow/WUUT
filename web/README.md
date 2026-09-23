# WUUT — web design harness

Renders the iOS app's screens in a browser. **It is not a second implementation of WUUT**,
and is not meant to become one.

## Why it exists

The Figma MCP can capture a pixel-perfect design from a running **web** page
(`generate_figma_design`). For iOS there is no such path — a design has to be constructed
node by node from a description, which is how the Figma file ended up not matching the app
(see `docs/FIGMA-SYNC.md`).

So this harness exists to give the design pipeline a URL to point at. Being able to look at
the screens in a browser is a useful side effect, not the goal.

## What it deliberately does not do

No scheduling, no persistence, no notifications. That is a scoping decision — but the
notification part is also a platform limit worth knowing:

- While a tab is open, `setTimeout` plus the Notifications API works in Chromium.
- With the tab closed, nothing fires without a push server, which would contradict the
  app's local-only design.
- Scheduled local notifications (Notification Triggers) were experimental and behind a flag;
  don't build on them without checking their current status.
- Periodic Background Sync needs an installed PWA and has an effective floor measured in
  hours — useless for quarter-hourly prompts.

The app's defining mechanic — being interrupted whether or not you are looking — is not
reproducible on the web. A harness that pretended otherwise would be worse than one that
doesn't try.

## Running it

```sh
npm install
npm run dev          # http://localhost:5173
npm run build        # checks tokens, typechecks, builds
npm run preview      # serve the build on :4173
```

`npm run build` runs `tokens:check` first and **fails if the design tokens have drifted**
from `Theme.swift`.

## Design tokens

Colours are not written here. `scripts/extract_tokens.py` reads `WUUT/Shared/Theme.swift`
and the seeded categories in `WUUT/Model/LogCategory.swift`, and generates:

- `design/tokens.json`
- `web/src/styles/tokens.css`

Regenerate with `npm run tokens` after changing the Swift. Never edit `tokens.css` by hand —
two hand-maintained definitions of the same colours drift silently, and this project has
already paid for that lesson once.

**Typography is exact on a Mac.** `ui-serif` and `ui-monospace` resolve to New York and
SF Mono, which is what SwiftUI's `.serif` and `.monospaced` resolve to on iOS. So this
harness renders the app's real typefaces — something the Figma file cannot do, since those
families are not in Figma's hosted set.

## Fixtures

`src/fixtures.ts` holds the scripted day from `docs/FIGMA-SYNC.md`: an 8-minute opening
stub, two consecutive unaccounted quarter hours, one slot in progress. Every artifact —
this harness, the Figma frames, the iOS previews — renders that same day, so they can be
compared rather than eyeballed as roughly similar.

Deliberately an imperfect morning. A happy-path fixture hides the states the design exists
to handle.

**Load a real export** with the button in the harness bar. It reads the same
`ExportDocument` JSON the iPhone writes (`schemaVersion: 1`), so a weekly backup file works
as-is.

## The one place this can drift

`src/stats.ts` mirrors `DayStatistics.swift` — longest gap, provenance split, response
delay, period comparison. It is the only duplicated logic, kept small for that reason.
**The Swift side is authoritative and is the side with tests.** If the two ever disagree,
Swift is right.
