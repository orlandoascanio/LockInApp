# LockIn

LockIn is a native macOS Pomodoro/focus app. It runs as a normal app with a menu bar status item, starts focus and break sessions, guards selected distracting apps, keeps local session history, and exports that history as CSV or JSON.

The default blocking behavior is **Guard Screen**. When you open a guarded app during focus, LockIn hides the app and shows a full-screen guard overlay. The app keeps running in the background, so Discord calls, camera, microphone, and screen sharing can continue.

## MVP Scope

- Native macOS app, built with Swift, AppKit, SwiftUI, and Swift Package Manager.
- Normal Dock app plus a menu bar status item.
- Focus and break timers with `25 / 5`, `45 / 10`, and custom durations.
- Guarded app list selected from `/Applications`.
- Guard Screen, Hide Only, and explicit Quit App blocking behaviors.
- Local config, active-session recovery, and session history.
- CSV and JSON export.
- No account required.
- No internet required.

## Not Included Yet

- No website blocking.
- No `/etc/hosts` edits.
- No Network Extension.
- No sudo or privileged helper.
- No account, login, sync, or cloud backend.
- No Electron.

## Requirements

- macOS 13 or newer
- Xcode command line tools or Xcode
- Swift Package Manager

## Build And Run

Run tests:

```bash
swift test
```

Build a real `.app` bundle:

```bash
Scripts/build_app.sh
```

Launch:

```bash
open build/LockIn.app
```

If an older copy is already running, stop it before opening the rebuilt app:

```bash
killall LockIn 2>/dev/null || true
open build/LockIn.app
```

You can also run the executable directly during development:

```bash
swift run LockIn
```

## Blocking Behavior

LockIn observes macOS app activation events. During focus, if a guarded app becomes active, LockIn reacts immediately.

- **Guard Screen**: hides the app, shows the guard overlay, and lets the app keep running in the background.
- **Hide Only**: hides the app without showing the guard overlay.
- **Quit App**: asks the app to quit. This only happens when selected explicitly.

Guarding only runs during focus. It stops during break, break-ended, idle, completed, and cancelled states.

Protected apps are never hidden or quit and cannot be added:

- Finder
- Dock
- System Settings / System Preferences
- Terminal
- loginwindow
- WindowServer
- LockIn itself

## Storage

LockIn stores all data locally in:

```text
~/Library/Application Support/LockIn/
```

Files:

- `config.json`
- `session-state.json`
- `session-history.jsonl`

Config and active session state use atomic writes. If config or active-session JSON becomes invalid, LockIn preserves a timestamped `.invalid-*` copy and recovers with safe defaults.

## Project Layout

```text
FocusLock/
├── App/
├── Core/
├── Models/
├── Resources/
├── UI/
└── Tests/
```

Core logic is in `FocusLockCore` so timer recovery, persistence, blocking validation, history, and export behavior can be tested without launching the app UI.

## Known Limitations

- Website blocking is intentionally out of scope for this MVP.
- Quit App mode uses normal app termination, not force quit.
- Session history still keeps a legacy `strictMode` export field for backward compatibility.
# LockInApp
