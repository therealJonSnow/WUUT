# WUUT

**What (yo)U Up To** — a personal time-documentation app for iPhone.

Every quarter hour between waking and sleeping, it asks what you did for the last fifteen
minutes. You reply in a sentence, straight from the notification. Over a day you get an honest
timeline; over a week you get numbers.

Private, local-only, single user. Not published to the App Store.

## Status

Specification agreed. No code yet. See **[SPEC.md](SPEC.md)**.

## Building and installing (once the code exists)

Requires a Mac with Xcode, and an iPhone on iOS 18 or later.

1. Open `WUUT.xcodeproj`.
2. Select your Apple ID under Signing & Capabilities and set a unique bundle identifier.
3. Plug in the iPhone (or pair it over the local network) and hit Run.

**On a free Apple ID the app stops launching after 7 days.** Re-run from Xcode to refresh it —
about a minute, and your data survives as long as you don't delete the app. Set up the automatic
weekly backup on first launch anyway; see [SPEC.md §8](SPEC.md).
