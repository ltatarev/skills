---
name: verify
description: >
  Build, launch and drive a React Native app on the iOS simulator to observe a
  change end-to-end. Use when verifying a code change actually works at runtime
  and not just in tests, when the user asks to run the app, take a screenshot,
  or check something on device, or when a bug can only be confirmed by driving
  the UI. Covers idb-based tapping, why synthetic clicks fail, where console
  output actually goes, and simulator gotchas.
---

# Verifying on the iOS simulator

Static checks and unit tests do not prove a UI change works. This skill is the
procedure for actually driving the app and observing it.

## Build and launch

```sh
npx react-native run-ios --simulator='iPhone 17 Pro Max'
```

Cold builds take a few minutes (longer on a fresh pod install). After a
**JS-only** change no rebuild is needed — Metro serves a fresh bundle on
relaunch:

```sh
xcrun simctl terminate booted <bundle-id>
xcrun simctl launch booted <bundle-id>
```

Get the bundle id from the Xcode project or `app.json` rather than guessing.

## Driving the UI — use idb, not synthetic clicks

**Do not** drive the simulator with AppleScript `click at` or `cliclick`. Both
post mouse events that the Simulator delivers unreliably: they land at the wrong
coordinates, get swallowed by the window's pointer capture ("Press esc to stop
capture" in the title bar), and succeed only intermittently. This costs a lot of
time and produces confusing evidence — you cannot tell a failed tap from a bug.

Use `idb`, which taps the device directly in **device points**:

```sh
brew install facebook/fb/idb-companion
/usr/bin/python3 -m venv idbenv && ./idbenv/bin/pip install fb-idb  # needs py3.9; fb-idb breaks on 3.14
idb_companion --udid <UDID> &                                       # note the grpc port it prints
./idbenv/bin/idb connect localhost <port>
./idbenv/bin/idb ui tap <x> <y>
```

**Coordinates.** A screenshot from `xcrun simctl io booted screenshot` is in
pixels, not device points. On a 3x device (e.g. iPhone 17 Pro Max, 1320×2868 px
↔ 440×956 pt) divide screenshot pixels by 3 to get the tap target. Confirm the
device's scale factor before converting.

A `Switch` needs a real press, not an instantaneous tap:

```sh
./idbenv/bin/idb ui tap --duration 0.12 <x> <y>
```

## Observing what the app did

`console.log` and the app's logger go to **Metro**, not to the system log — so
`xcrun simctl spawn booted log stream` will not show them.

To capture runtime state in a screenshot, temporarily `Alert.alert(...)` the
value from the code path under test, drive the flow, screenshot, then **remove
the instrumentation**. Alerts queue, so N calls means N dismissals.

For state-shaped questions, a Redux devtools bridge (Reactotron or similar, if
the repo wires one in dev) is usually faster than adding log lines.

## Gotchas

- The simulator's clock follows the host, so anything scheduled days out cannot
  be waited for. Read back the OS's own pending state instead (e.g.
  `notifee.getTriggerNotifications()`) — that is the real store of record.
- Apps that gate startup on a migration or backfill show a loading screen on the
  first launch after a schema bump, before anything renders. Do not mistake that
  for a hang.
- A stale Metro bundler serves the old bundle. If a JS change does not appear,
  restart Metro before doubting the code.

## Definition of done

- [ ] The change was observed running, not inferred from tests.
- [ ] Evidence captured (screenshot, or the specific observed behavior described).
- [ ] All temporary instrumentation (`Alert.alert`, log lines, debug flags)
      removed from the diff.
- [ ] Static checks still pass afterwards — see `validate-change`.
