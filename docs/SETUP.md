# Getting WUUT onto your phone

You need a Mac with Xcode and an iPhone on iOS 18 or later. Nothing here costs money.

## 1. Generate the Xcode project

The repository holds source files and a `project.yml`, not a `.xcodeproj`. That is on purpose:
an Xcode project file is a thousand lines of UUID-keyed plist, and a hand-written one that is
subtly wrong simply refuses to open. XcodeGen builds it deterministically instead.

```sh
brew install xcodegen
cd /path/to/WUUT
xcodegen generate
open WUUT.xcodeproj
```

Re-run `xcodegen generate` after pulling changes that add files. The `.xcodeproj` is
gitignored, so you never get merge conflicts in it.

<details>
<summary>If you would rather not install XcodeGen</summary>

Create the project by hand in Xcode:

1. **File → New → Project → iOS → App.** Name it `WUUT`, interface SwiftUI, storage None,
   and save it in the repository root so it sits beside the `WUUT/` folder.
2. Delete the `ContentView.swift` and `WUUTApp.swift` that Xcode generates.
3. Drag the `WUUT/` folder into the project, choosing **Create groups** and *not*
   "Copy items if needed".
4. Set the app target's Info.plist to `WUUT/Info.plist` and set
   **Generate Info.plist File** to `No`.
5. **File → New → Target → Widget Extension**, name it `WUUTWidgets`, tick
   **Include Live Activity**, untick Configuration Intent. Delete the files it generates,
   drag in `WUUTWidgets/`, and add `WUUT/Shared/ActivityAttributes.swift` and
   `WUUT/Shared/Formatters.swift` to that target's membership as well — both targets need
   the same copy of the Live Activity payload type.
6. **File → New → Target → Unit Testing Bundle**, name it `WUUTTests`, and drag in
   `WUUTTests/`.

`project.yml` is the reference for every build setting if anything looks off.
</details>

## 2. Sign it with your Apple ID

For each of the two targets (`WUUT` and `WUUTWidgets`), under **Signing & Capabilities**:

1. Tick **Automatically manage signing**.
2. Pick your Apple ID under **Team**. Add it via Xcode → Settings → Accounts if it isn't there.
3. Change the **Bundle Identifier** to something globally unique — `com.wuut.app` will already
   be taken. Use a reverse-DNS form of a domain you own, e.g. `com.overnice.wuut`.
   **The widget's identifier must be the app's with `.widgets` appended**, so
   `com.overnice.wuut.widgets`. If that relationship breaks, the Live Activity silently
   never appears.

Leave every capability alone. The project deliberately requests no entitlements, because the
ones that would help — App Groups, iCloud, Time Sensitive Notifications — are not available on
a free Apple ID. See [SPEC §9](../SPEC.md).

## 3. Build and run

Plug the iPhone in, select it as the run destination, and press Run. On the phone, trust the
developer certificate under **Settings → General → VPN & Device Management** the first time.

Then, on first launch, **allow notifications**. Without them the app cannot do the one thing
it is for.

## 4. Every seven days

A free Apple ID signs apps for seven days. After that WUUT will not launch until you re-run it
from Xcode — about a minute, with the phone on the same wifi so you don't need the cable.

**Your data survives this.** Re-running installs over the existing app and the database is
untouched. What does lose data is deleting the app or changing signing identity, which is why
step 5 is not optional.

## 5. Set up the weekly backup, today

**Settings → Backup and export → Choose a backup folder**, and pick a folder in iCloud Drive.
WUUT then writes a dated JSON file there once a week and keeps the last eight, with no further
involvement from you.

This is the only thing standing between a deleted app and losing your history. Do it on day one.

## Four things to check on the first run

These behave differently on a free Personal Team and I could not test them from Linux. Each
already has a fallback, so none of them can stop the app working — but it's worth knowing which
you got.

| Check | How to tell | If it doesn't work |
|---|---|---|
| **Time Sensitive notifications** | Turn on a Focus mode and wait for a prompt | Turn off "Break through Focus" in Settings; prompts still arrive, they just respect Do Not Disturb |
| **Live Activity** | Start the day, then lock the phone | Turn off "Lock screen activity" in Settings; everything else is unaffected |
| **Widget extension installs** | The build succeeds and the app launches | Check the widget bundle ID is the app's plus `.widgets`; free accounts allow only 3 apps per device, so remove other sideloaded apps |
| **Background refresh** | Settings → Diagnostics shows prompts scheduled after a few hours untouched | Nothing depends on it; the window refills whenever you open the app or answer a prompt |

**Settings → Diagnostics** is the page to look at if prompts ever stop. It shows how many
notifications are scheduled against the platform's limit of 64. If that number is zero during a
logged day, something is wrong.

## Regenerating the app icon

The icon is generated, not hand-drawn, so it stays in step with the palette:

```sh
python3 -m pip install Pillow
python3 scripts/make_icon.py
```

It overwrites `WUUT/Assets.xcassets/AppIcon.appiconset/icon-1024.png` and drops an
`icon_preview.png` in the repo root showing it at home-screen sizes. The colours at the top
of the script must match `Theme` in `WUUT/Shared/Theme.swift`.

## If the build fails

This project was written without a compiler to hand, so expect a few errors on the first
build — most likely wrong argument labels or a SwiftUI modifier that has moved.

The quickest way to get them out of Xcode as text:

```sh
./scripts/build.sh          # build for device, print only the errors
./scripts/build.sh test     # build and run the unit tests on a simulator
```

It writes the full log to `build.log` and prints just the unique error lines, which is what
you want to paste into a conversation. Work down the list from the top: one bad type early on
tends to produce a dozen misleading errors after it.

Better still, run Claude Code on the Mac itself (`npm install -g @anthropic-ai/claude-code`,
then `claude` in this directory). It can run the script, read the errors and fix them without
anything being copied by hand. `CLAUDE.md` in the repository root orients a fresh session on
the constraints that matter.

To copy errors out of Xcode's own UI instead: **⌘5** for the issue navigator, click a row,
**⌘A**, **⌘C**.

Run the tests too — `Product → Test`. They cover slot generation, the stub rules, days that
run past midnight, DST, backfill expiry and duration-weighted totals, and they need no
simulator. If those pass, the parts that could quietly corrupt your history are sound.
