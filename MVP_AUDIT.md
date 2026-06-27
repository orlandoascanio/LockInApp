# FocusLock MVP Audit

## Release Decision

NOT READY FOR v0.1

FocusLock is close: it builds, tests pass, launches from the generated `.app` bundle, stores data locally, and the core focus/break/history/export paths are covered by tests. The main MVP blocker is the temporary allow flow: `Allow for 5 Minutes` does not actively re-guard the app when the five minutes expire if the user stays inside the allowed app. That breaks the core promise of guarding distracting apps during focus. There are also smaller release-readiness issues around break-ended recovery, error message styling, and the current dirty working tree.

## Summary

* What works
  * `swift test` passes: 35 XCTest cases, 0 failures.
  * `swift build` passes.
  * `Scripts/build_app.sh` builds `build/FocusLock.app`.
  * Launch smoke check passed: the built app started as `/Users/orlando/Documents/DND/build/FocusLock.app/Contents/MacOS/FocusLock`, then was stopped.
  * App lifecycle keeps a long-lived `MenuBarController` in `AppDelegate`.
  * `MenuBarController` creates one `NSStatusItem`, assigns a visible SF Symbol, and has an `FL` fallback.
  * Guard Screen mode hides blocked apps and does not terminate them.
  * FocusGuard is source-gated to the `.focus` phase and stops during break, break-ended, completed, cancelled, paused, and idle.
  * Session state, config, and history are stored locally under `~/Library/Application Support/FocusLock/`.
  * Config and active session writes are atomic.
  * CSV and JSON export code is covered by tests.
  * README explains current MVP scope and explicitly says there is no account, internet requirement, website blocking, `/etc/hosts` edit, sudo, Network Extension, or Electron.

* What is incomplete
  * The temporary allow expiry is passive, not enforced while the blocked app remains frontmost.
  * Break-ended recovery after relaunch can restore the `.breakEnded` state without showing the break-ended overlay.
  * Manual blocked-app QA was not fully executed in this audit; only source, tests, bundle inspection, and launch/process smoke were verified.
  * The working tree is not commit-ready: many release files are modified and several required files are still untracked.

* Biggest release risk
  * The app can let the user remain inside Discord or another allowed blocked app past the promised five-minute allowance, because expiry is only checked on a later activation event.

* Recommended next action
  * Fix active temporary-allow expiry first, add a test that proves a continuously frontmost allowed app is re-guarded after five minutes, then run the full manual QA checklist on the built `.app`.

## P0 Release Blockers

* Title
  * Temporary allow can last indefinitely if the user stays in the allowed app.

* Evidence from code/test/manual check
  * `FocusLock/Core/AppBlocker.swift`: `allowTemporarily(bundleId:duration:now:)` only stores an expiry date in `temporaryAllowances`.
  * `FocusLock/Core/AppBlocker.swift`: the expiry is only checked inside `handleActivation(of:now:)`.
  * `FocusLock/App/MenuBarController.swift`: `allowInterceptedAppTemporarily()` dismisses the overlay, grants the allowance, unhides the app, and activates it, but does not schedule any re-check at the five-minute mark.
  * `FocusLock/Tests/AppBlockerTests.swift`: `testTemporaryAllowanceExpires` manually calls `handleActivation` after 301 seconds, so it proves expiry on a later activation, not expiry while the app remains frontmost.
  * Manual continuous-frontmost expiry was not validated.

* Why it blocks release
  * The MVP explicitly promises `Allow for 5 Minutes` and that distracting apps are guarded during focus. With the current implementation, a user can click `Allow for 5 Minutes`, stay in Discord, and continue using it after five minutes because no activation event occurs to trigger expiry.

* Exact fix needed
  * When temporary allow is granted, schedule a timer or task for the allowance expiry.
  * At expiry, if the session is still in focus and the allowed app is still frontmost or running active, re-run guard handling for that app.
  * Add a regression test at the controller/blocker seam proving an allowed app that remains active is hidden/intercepted again after five minutes without requiring a new activation event.

* Files likely involved
  * `FocusLock/App/MenuBarController.swift`
  * `FocusLock/Core/AppBlocker.swift`
  * `FocusLock/Tests/AppBlockerTests.swift`
  * Potentially a new controller-level test seam if timer scheduling stays in `MenuBarController`.

## P1 Should Fix Before v0.1

* Title
  * Break-ended overlay is not shown when the app relaunches directly into `.breakEnded`.

* Evidence
  * `TimerEngine` restores state during `TimerEngine.init`.
  * `MenuBarController` sets `self.snapshot = timerEngine.snapshot` before `setup()`.
  * `handleBreakEndedTransition(from:to:)` only shows the break-ended overlay when a later `apply` call observes a transition into `.breakEnded`.
  * On relaunch into an already `.breakEnded` snapshot, the previous and new phases are both `.breakEnded`, so the transition guard prevents the overlay from showing.

* User impact
  * If a focus/break cycle expires while FocusLock is closed, relaunch can show a break-ended state without the overlay that tells the user to start focus, snooze, or end the cycle. This weakens the "do not silently drift after break" promise.

* Exact fix needed
  * During `setup()` or immediately after timer restoration, explicitly handle initial `.breakEnded` state: show `BreakEndedWindowController` when `autoStartFocusAfterBreak` is false, or start focus when it is true.
  * Add a regression test around relaunch/restored `.breakEnded` behavior if a testable controller seam exists.

* Files likely involved
  * `FocusLock/App/MenuBarController.swift`
  * `FocusLock/Core/TimerEngine.swift`
  * `FocusLock/Tests/TimerEngineTests.swift` or a new controller-level test.

* Title
  * Project is not currently commit-ready.

* Evidence
  * `git status` shows many modified files and untracked files:
    * Modified: `FocusLock/App/FocusOverlayController.swift`, `FocusLock/App/MenuBarController.swift`, `FocusLock/Core/SessionHistoryStore.swift`, `FocusLock/Models/SessionHistoryEntry.swift`, `FocusLock/Tests/SessionHistoryStoreTests.swift`, multiple `FocusLock/UI/*` files, `Package.swift`, and `Scripts/build_app.sh`.
    * Untracked: `.agents/`, `FocusLock/Assets.xcassets/`, `FocusLock/DesignSystem.swift`, `FocusLock/UI/BlockOverlayWindow.swift`, and `skills-lock.json`.
  * `Package.swift` references `DesignSystem.swift` and `Assets.xcassets`, which are currently untracked and therefore would be missing from a clean commit unless staged.

* User impact
  * A release commit made from the wrong subset of files could fail to build from a fresh checkout or ship without the current UI/resources.

* Exact fix needed
  * Decide which modified/untracked files are intentional for v0.1.
  * Stage all required source/resources together.
  * Exclude local-only files such as `.agents/` if they are not part of the app.
  * Confirm `git status --short` contains only intentional release files before tagging or shipping.

* Files likely involved
  * `Package.swift`
  * `FocusLock/DesignSystem.swift`
  * `FocusLock/Assets.xcassets/`
  * `FocusLock/UI/BlockOverlayWindow.swift`
  * `skills-lock.json`
  * `.agents/`

* Title
  * Settings error messages are shown with success styling.

* Evidence
  * `MenuBarController.addBlockedApp(at:)` sets `settingsMessage` to error descriptions for unreadable apps, protected apps, and duplicates.
  * `SettingsView` renders any `settingsMessage` with `checkmark.circle.fill` and success green styling.

* User impact
  * Duplicate/protected-app failures can visually read as successful actions, which is confusing in the app-management flow.

* Exact fix needed
  * Split settings feedback into success and error states, or store a small feedback enum.
  * Render validation failures with warning/error icon and styling.

* Files likely involved
  * `FocusLock/App/MenuBarController.swift`
  * `FocusLock/UI/SettingsView.swift`
  * Potentially `FocusLock/UI/BlockedAppsView.swift`.

## P2 Later Polish

* Add UI automation or a debug-only test harness for the manual app-blocking flow.
* Make the export failure message more specific by surfacing the underlying save error where appropriate.
* Consider a small visual distinction between "Break Ended" state in the popover and the modal break-ended overlay.
* Website blocking, charts, onboarding, themes, analytics, calendar sync, account/sync/cloud backup, and advanced automation remain v0.2+ work.

## Command Results

* `pwd`
  * `/Users/orlando/Documents/DND`

* `ls`
  * Top-level entries include `FocusLock`, `Package.swift`, `README.md`, `Scripts`, `build`, `skills-lock.json`, and ignored `target*.png` files.

* `find . -maxdepth 3 -type f | sort`
  * Ran successfully.
  * It shows source files, tests, `.git` internals, `.build` internals, ignored local screenshots, and app resources.

* `git status`
  * Working tree is dirty with modified app/source/test/build-script files and untracked release-relevant files.

* `swift test`
  * Passed.
  * 35 XCTest cases executed, 0 failures.

* `swift build`
  * Passed.

* `Scripts/build_app.sh`
  * Passed.
  * Built `/Users/orlando/Documents/DND/build/FocusLock.app`.

* Bundle inspection
  * `build/FocusLock.app/Contents/Info.plist` contains `CFBundleIdentifier = com.focuslock.app`, `CFBundleShortVersionString = 0.1.0`, `CFBundleIconFile = AppIcon`, and `LSMinimumSystemVersion = 13.0`.
  * `build/FocusLock.app/Contents/Resources/AppIcon.icns` is present.

* Launch smoke
  * No FocusLock process was running before launch.
  * `open build/FocusLock.app` started `/Users/orlando/Documents/DND/build/FocusLock.app/Contents/MacOS/FocusLock`.
  * The smoke-launched process was stopped after verification.

## Release Criteria Status

* Zero P0 issues
  * Failed. One P0 blocker found.

* At most 3 small P1 issues
  * Currently exactly 3 P1 issues found in this audit.

* All tests pass
  * Passed.

* Manual core flow works end-to-end
  * Not verified in this audit.

* The app does not kill Discord or other blocked apps in Guard mode
  * Verified by source and tests. Guard Screen calls `hide()` and `testGuardModeDoesNotTerminateBlockedApps` asserts terminate count is 0.

* The app does not block anything during break
  * Verified by source and tests. `AppBlocker.shouldRun(for:)` returns true only for `.focus`, and `syncBlocker()` stops the blocker outside focus.

* The app can recover after restart
  * Partially verified by tests. Focus recovery and expired-break state recovery are tested, but break-ended overlay presentation after relaunch has a P1 gap.

* The user can export history
  * Verified by source and tests for CSV/JSON generation and save paths. Manual save-panel export was not performed.

## Manual QA Checklist

### Launch/Menu Bar

* App launches.
  * Smoke verified by launching `build/FocusLock.app` and confirming a FocusLock process.

* App appears in Dock.
  * Source-supported by `NSApp.setActivationPolicy(.regular)`, but manually unverified.

* Menu bar icon appears.
  * Source-supported by `NSStatusItem` creation and SF Symbol/fallback assignment, but manually unverified.

* Clicking icon opens popover.
  * Source-supported by status button target/action and `showPopover()`, but manually unverified.

* Clicking outside closes popover.
  * Source-supported by `popover.behavior = .transient`, but manually unverified.

* No duplicate menu bar icons appear after opening/closing windows.
  * Source-supported by `hasSetup` and `statusItem == nil` guards, but manually unverified.

### Settings/App Management

* Settings opens.
  * Source-supported, manually unverified.

* Settings reuses existing window if already open.
  * Source-supported by `presentWindow(existingWindow:)`, manually unverified.

* User can add Discord or another app from `/Applications`.
  * Source-supported by `NSOpenPanel` configured for `.applicationBundle`, manually unverified.

* App name and bundle ID are extracted correctly.
  * Verified by `AppBundleMetadataExtractorTests`.

* Added app appears in blocked list.
  * Source-supported, manually unverified.

* Added app persists after quit/relaunch.
  * Verified by `StateStoreTests.testBlockedAppsPersistInConfig`.

* Duplicate app cannot be added.
  * Verified by `AppBlockerTests.testDuplicateBlockedAppsCannotBeAdded`.

* Protected apps cannot be added.
  * Verified by `AppBlockerTests.testProtectedAppsCannotBeAdded` and related protected-app tests.

* Removing app works.
  * Source-supported by `removeBlockedApp(_:)`, manually unverified.

### Focus Flow

* Start a 1-minute focus session.
  * Source-supported; unit tests start focus sessions. Manual 1-minute flow unverified.

* Timer starts.
  * Verified by `TimerEngineTests`.

* Menu bar status updates.
  * Source-supported by `updateStatusItem()`, manually unverified.

* Open a blocked app.
  * Unit-tested with mocked activations. Manual app activation unverified.

* Blocked app is hidden/intercepted.
  * Verified by `AppBlockerTests.testBlockedAppActivationTriggersOverlayDelegateAndHidesApp`.

* Guard overlay appears.
  * Source-supported through `AppBlockerDelegate` and `FocusOverlayController`; unit-level delegate is tested. Manual overlay appearance unverified.

* Blocked app process remains running.
  * Verified by source/tests for Guard Screen: it hides and does not terminate.

* Back to Focus works.
  * Source-supported, manually unverified.

* Allow for 5 Minutes works.
  * Partially verified: allowance suppresses blocking inside the stored allowance window.

* Allow expires and app is guarded again.
  * Failed for continuous-frontmost use. Expiry is only enforced on a later activation event.

* End Session cancels and saves history.
  * Verified by `TimerEngineTests.testCancelCreatesCancelledHistoryEntry` for focus cancellation.

### Break Flow

* Focus completes.
  * Verified by `TimerEngineTests.testFocusTransitionsToBreakThenBreakEndedAndSavesFocusHistory`.

* Break starts.
  * Verified by `TimerEngineTests.testFocusTransitionsToBreakThenBreakEndedAndSavesFocusHistory`.

* FocusGuard stops during break.
  * Verified by source and `AppBlockerTests.testBlockerRunsOnlyDuringFocusPhase`.

* Blocked apps are allowed during break.
  * Source/test-supported by focus-only blocker gating. Manual unverified.

* Break-ended overlay appears when break ends.
  * Source-supported during in-app transition. Manual unverified. Relaunch into break-ended has a P1 gap.

* Start Focus starts another focus session.
  * Verified by `TimerEngineTests.testStartFocusFromBreakEndedStartsNewFocusSession`.

* Snooze 2 Minutes extends break.
  * Verified by `TimerEngineTests.testSnoozeExtendsBreakByTwoMinutes`.

* End Cycle returns to idle.
  * Verified by `TimerEngineTests.testEndCycleReturnsToIdleFromBreakEnded`.

### History/Export

* Completed session appears in history.
  * Verified by timer/history tests.

* Cancelled session appears in history.
  * Verified by `TimerEngineTests.testCancelCreatesCancelledHistoryEntry`.

* Stats update.
  * Verified by `SessionHistoryStoreTests.testStatsCountTodayAndWeek`.

* CSV export creates a valid file.
  * Verified at service level by `ExportServiceTests.testCSVExportFormatting`. Manual save-panel export unverified.

* JSON export creates a valid file.
  * Verified at service level by `ExportServiceTests.testJSONExportFormatting`. Manual save-panel export unverified.

* Export errors are handled clearly.
  * Partially verified by source. Message is generic but acceptable for v0.1 unless manual QA finds a confusing case.

### Recovery

* Start focus session, quit app, relaunch app.
  * Timer recovery is unit-tested. Manual relaunch flow unverified.

* Timer/session state recovers correctly.
  * Verified by `TimerEngineTests.testRecoveryUsesSavedStartTimeInsteadOfMemoryCountdown`.

* If still in focus, FocusGuard resumes.
  * Source-supported by `setup()` calling `syncBlocker()` after restoring `snapshot`. Manual unverified.

* If session expired while app was closed, app transitions correctly.
  * Partially verified by `TimerEngineTests.testRecoveryOfExpiredBreakShowsBreakEndedState`; overlay presentation after relaunch has a P1 gap.

* No stale blocking remains after session ends.
  * Source-supported by `syncBlocker()` stopping the blocker outside focus. Manual unverified.

## Non-Goals Confirmed

* No active website blocking code found.
* No `/etc/hosts` modification found.
* No sudo or privileged helper requirement found.
* No Electron dependency found.
* No account, network, sync, or cloud backend code found.
* No committed session history, config, active session state, `.build`, `build`, `target*.png`, or `.DS_Store` files found in `git ls-files`.

