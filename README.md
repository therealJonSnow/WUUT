# WUUT

**What (yo)U Up To** — a personal time-documentation app for iPhone.

Every quarter hour between waking and sleeping, it asks what you did for the last fifteen
minutes. You reply in a sentence, straight from the notification. Over a day you get an honest
timeline; over a week you get numbers.

Private, local-only, single user. Not published to the App Store.

## Status

v1 is written but has never been compiled — it was built without access to Xcode, so expect a
few errors on the first build. See [SPEC §12](SPEC.md).

- **[SPEC.md](SPEC.md)** — the design, and why each decision went the way it did
- **[docs/SETUP.md](docs/SETUP.md)** — how to build it, sign it and get it on the phone

## Building

Requires a Mac with Xcode and an iPhone on iOS 18 or later. Nothing costs money.

```sh
brew install xcodegen
xcodegen generate
open WUUT.xcodeproj
```

The `.xcodeproj` is generated rather than committed. Full instructions, including signing and
the manual alternative to XcodeGen, are in [docs/SETUP.md](docs/SETUP.md).

**On a free Apple ID the app stops launching after 7 days.** Re-running from Xcode refreshes it
in about a minute and your data survives — but set up the automatic weekly backup on day one
anyway, because deleting the app does not.

## How it works

- Tap **Start the day**. The first slot runs from that moment to the next quarter hour; every
  slot after it is aligned to :00, :15, :30, :45.
- At each boundary a notification asks what you were up to, with two follow-ups after it. You
  can **reply straight from the banner**, or tap "Same as last" to copy the previous entry.
- Miss some? They stay fillable for two hours through a catch-up flow, then lock permanently as
  **unaccounted** and show up in the metrics as lost time.
- Going into a meeting? **Block out** the next hour and it fills those slots and stops asking.
- At the end of the day one notification gives you the numbers. The Week tab gives you the rest.
