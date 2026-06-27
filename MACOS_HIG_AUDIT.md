# FocusLock macOS HIG Design Audit

Audited against `.agents/skills/macos-design-guidelines/SKILL.md` (Apple Human Interface Guidelines for Mac). This is a design/native-platform-conformance audit, separate from the functional `MVP_AUDIT.md`.

## Design Verdict

GOOD FOUNDATION, NOT FULLY HIG-COMPLIANT

FocusLock is a menu-bar utility (`.regular` activation policy, so it also shows in the Dock) built around an `NSStatusItem` + transient popover, with standalone AppKit windows for the main view, settings, and history, plus full-screen block overlays. The most severe earlier gaps have already been closed: the app now ships a complete menu bar (App / Edit / Session / History / Window) with keyboard shortcuts and dynamic enable/disable validation, `Cmd+,` opens the real settings, and windows persist their frames. The remaining issues are concentrated in two areas the HIG treats as CRITICAL: **full keyboard access inside the editable lists**, and **accessibility adaptation** (Reduce Motion, Increase Contrast). After those, the rest is hover/pointer polish and native-integration nice-to-haves.

## Summary

* What is already compliant (verified in source)
  * Menu bar present with standard menus and shortcuts (`MenuBarController.setupMainMenu()`): App menu with About / Settings… (`Cmd+,`) / Hide / Hide Others / Show All / Quit; Edit menu; Session (Start Focus `Cmd+N`, Stop Session `Cmd+.`); History (`Cmd+Y`, Export CSV `Cmd+E`, Export JSON `Shift+Cmd+E`); Window (FocusLock Window `Cmd+1`, Minimize / Zoom / Close).
  * Dynamic menu validation via `NSMenuItemValidation` (Start/Stop/Export enable based on state) — Rule 1.3.
  * `Cmd+,` now routes to the real settings window; the empty SwiftUI `Settings` scene is no longer reachable — Rule 1.5.
  * Window position/size persist via `setFrameAutosaveName` — Rule 2.5.
  * Main/Settings/History windows are resizable with sensible minimums — Rule 2.1.
  * `Esc` dismisses the focus overlay (`onExitCommand`) and break-ended dialog (`.cancelAction`); primary buttons use `.defaultAction` for `Return` — Rules 5.3, 5.4.
  * Right-click context menu on blocked-app rows (Remove, Copy Bundle Identifier) — Rules 1.4, 6.2.
  * Icon-only buttons carry accessibility labels (preset, duration steppers, remove, status item) — Rule 11.1.
  * The focus overlay respects Reduce Motion — Rule 11.3 (partial).
  * Semantic system colors used throughout (`labelColor`, `secondaryLabelColor`, `windowBackgroundColor`, etc.), so Light/Dark adapt automatically — Rule 9.4.
  * No translucent `NSVisualEffectView` materials are used, so there is nothing to break under Reduce Transparency — Rule 9.5 satisfied by absence.

* What is not compliant
  * Editable lists (blocked apps, history) are `ScrollView { VStack { ForEach } }`, not `List`/`Table`: no row selection, no arrow-key navigation, and the `Delete` key cannot remove a blocked app.
  * Reduce Motion is only honored in the focus overlay; popover and overlay button micro-animations always animate.
  * Custom non-semantic colors (opacity-based hairlines/fills and the single fixed accent) do not adapt to Increase Contrast.
  * No Help menu (HIG lists Help among the standard menus).
  * List rows have no hover state, which Mac users expect on interactive rows.
  * Settings feedback renders validation errors with success (green checkmark) styling — also tracked in `MVP_AUDIT.md` P1.

* Biggest design risk
  * Keyboard-only and VoiceOver users cannot manage the blocked-apps list the way every native Mac list works: select a row and press `Delete`. The skill is explicit — "An app without comprehensive keyboard support is a broken Mac app."

* Recommended next action
  * Convert the blocked-apps list (and ideally history) to `List`/`Table` with selection so `Delete` removes, arrows navigate, and `Cmd+C` copies; then close the Reduce Motion and Increase Contrast accessibility gaps.

## P0 Design Blockers

* Title
  * Editable lists lack full keyboard access; `Delete` does not remove a blocked app.

* Evidence from code
  * `FocusLock/UI/BlockedAppsView.swift`: the list is `ScrollView { VStack(spacing:) { ForEach(controller.config.blockedApps) { blockedAppRow($0) } } }` with no `selection:` binding and no `List`. Removal is only reachable by clicking the per-row minus button or the right-click context menu.
  * `FocusLock/UI/SessionHistoryView.swift`: history is `ScrollView { VStack { ForEach(controller.history) { HistoryRow } } }` of `Grid` rows — not a `Table`, so no selection, sorting, multi-select, or copy.
  * `FocusLock/App/MenuBarController.swift`: the Edit menu's `Delete` maps to `#selector(NSText.delete(_:))`, which only acts inside a text responder, so it never removes a selected list item.

* Why it blocks native-quality release
  * Rules 5.2, 5.5, 5.7, 6.6, and 11.2 (all CRITICAL) require arrow-key navigation, `Delete` to remove selected items, and full keyboard reachability for everything reachable by mouse. A Mac user expects to select a blocked app and press `Delete`; today that is impossible without the pointer.

* Exact fix needed
  * Replace the blocked-apps `ScrollView`/`VStack` with a `List(selection:)` (or `Table(selection:)`) bound to a `@State` selection set.
  * Add a `.onDeleteCommand` / `Delete`-key handler that calls `controller.removeBlockedApp` for the selected row(s); keep the existing context menu and minus button.
  * Support `Cmd+Click` / `Shift+Click` multi-selection and Up/Down arrow navigation (free with `List`/`Table`).
  * Apply the same treatment to the history view via `Table` (also unlocks column sorting and `Cmd+C` copy for free).

* Files likely involved
  * `FocusLock/UI/BlockedAppsView.swift`
  * `FocusLock/UI/SessionHistoryView.swift`
  * `FocusLock/App/MenuBarController.swift` (optional: a `Remove` Session/Edit menu command bound to the current selection)

## P1 Should Fix

* Title
  * Reduce Motion is not respected outside the focus overlay.

* Evidence
  * `FocusLock/DesignSystem.swift`: `FLActionButtonStyle.makeBody` always applies `.animation(FLAnimation.quick, value: configuration.isPressed)` and a `scaleEffect` on press.
  * `FocusLock/UI/FocusOverlayView.swift`: `OverlayButton` always wraps hover changes in `withAnimation(FLAnimation.quick)`.
  * Only `FocusOverlayView`'s entrance animation checks `@Environment(\.accessibilityReduceMotion)`.

* User impact
  * Users who enable Reduce Motion still get scale/opacity/hover animations across the popover and overlays — Rule 11.3 (CRITICAL section 11).

* Exact fix needed
  * Read `@Environment(\.accessibilityReduceMotion)` where these animations live (or add a shared helper that returns `nil` when reduce-motion is on) and pass `reduceMotion ? nil : FLAnimation.quick` to the `.animation(...)`/`withAnimation` calls.

* Files likely involved
  * `FocusLock/DesignSystem.swift`
  * `FocusLock/UI/FocusOverlayView.swift`
  * `FocusLock/UI/MenuBarPopoverView.swift`

* Title
  * Custom colors do not adapt to Increase Contrast; hairlines may be too faint.

* Evidence
  * `FocusLock/DesignSystem.swift`: separators/fills use opacity-based colors such as `Color.flSeparator.opacity(0.45–0.6)`, `Color.primary.opacity(0.03–0.10)`, and a single fixed accent.
  * `FocusLock/Assets.xcassets/FocusAccent.colorset/Contents.json`: one `universal` color, no Dark Mode or High Contrast appearance variant.

* User impact
  * With Increase Contrast enabled, faint hairlines/borders and the fixed accent do not strengthen — Rules 9.7 and 11.7. (Text uses semantic label colors, which already adapt, so this is partial.)

* Exact fix needed
  * Read `@Environment(\.colorSchemeContrast)` and increase border/separator opacity (or switch to `Color(nsColor: .separatorColor)`/`.labelColor`) when `== .increased`.
  * Add High Contrast (and explicit Dark) appearance variants to `FocusAccent.colorset`.

* Files likely involved
  * `FocusLock/DesignSystem.swift`
  * `FocusLock/Assets.xcassets/FocusAccent.colorset/Contents.json`

* Title
  * No Help menu.

* Evidence
  * `FocusLock/App/MenuBarController.setupMainMenu()` builds App / Edit / Session / History / Window but no Help menu, and `NSApp.helpMenu` is unset.

* User impact
  * Rule 1.1 lists Help among the standard menus users expect at the right end of the menu bar.

* Exact fix needed
  * Add a Help menu with at least "FocusLock Help" pointing to in-app guidance or the README/website. (Only add a working item — a dead Help entry is worse than none, which is why it was deferred originally.)

* Files likely involved
  * `FocusLock/App/MenuBarController.swift`

* Title
  * No hover state on list rows.

* Evidence
  * `FocusLock/UI/BlockedAppsView.swift` `blockedAppRow` and `FocusLock/UI/SessionHistoryView.swift` `HistoryRow` use a static background with no `.onHover` feedback. (`OverlayButton` does implement hover correctly.)

* User impact
  * Rule 6.1 expects visible hover feedback on interactive rows; static rows read as non-interactive on the Mac.

* Exact fix needed
  * Adopting `List`/`Table` (P0) provides standard hover/selection highlighting automatically; otherwise add `.onHover` row highlighting.

* Files likely involved
  * `FocusLock/UI/BlockedAppsView.swift`
  * `FocusLock/UI/SessionHistoryView.swift`

* Title
  * Settings feedback shows validation errors with success styling.

* Evidence
  * `FocusLock/App/MenuBarController.addBlockedApp(at:)` sets `settingsMessage` for both successes and failures (duplicate/protected/unreadable).
  * `FocusLock/UI/SettingsView.swift` renders any `settingsMessage` with `checkmark.circle.fill` and success-green styling.

* User impact
  * Rule 7.5 (match feedback to meaning): a failure can read as a success. (Also logged in `MVP_AUDIT.md` P1.)

* Exact fix needed
  * Replace the single `settingsMessage: String?` with a small feedback enum (`.success` / `.error`) and render error states with a warning icon/color.

* Files likely involved
  * `FocusLock/App/MenuBarController.swift`
  * `FocusLock/UI/SettingsView.swift`

## P2 Later Polish

* Accept drag-and-drop of an app from Finder onto the blocked-apps list (`.dropDestination(for: URL.self)`), complementing the existing `NSOpenPanel` flow — Rule 6.3.
* Add an `applicationDockMenu` (e.g., Start Focus / Stop Session / Open FocusLock) and consider a Dock tile badge for an active session/countdown — Rules 8.1, 7.4.
* Add a search field to the history window via `.searchable` once it is a `Table` — Rule 3.4.
* Consider the standard tabbed, fixed-width Settings window chrome instead of a custom scrolling window, to match platform expectations for `Cmd+,` — Section 9 consistency.
* Add credits/usage to the standard About panel via `orderFrontStandardAboutPanel(options:)` — Rule 8.1.
* The break-ended floating window could be an `NSAlert`-style or sheet presentation rather than a bespoke `.floating` titled window — Section 7 / anti-pattern "sheet/modal for every action" is not violated, but a standard alert would be more idiomatic for this stop-and-decide moment.

## HIG Section Status

* 1. Menu Bar (CRITICAL) — Pass, except missing Help menu (P1).
* 2. Windows (CRITICAL) — Pass (resizable, minimums, frame autosave, traffic lights intact).
* 3. Toolbars (HIGH) — N/A for this utility; no document toolbar needed. Optional history search (P2).
* 4. Sidebars (HIGH) — N/A; app has no multi-section navigation.
* 5. Keyboard (CRITICAL) — Partial. Menu shortcuts and Esc/Return done; list navigation and Delete-to-remove missing (P0).
* 6. Pointer & Mouse (HIGH) — Partial. Right-click menus present; row hover (P1) and Finder drag-and-drop (P2) missing.
* 7. Notifications & Alerts (MEDIUM) — Mostly fine; feedback styling mismatch (P1).
* 8. System Integration (MEDIUM) — App icon present; Dock menu/badge, Spotlight, Share, App Intents not implemented (P2, mostly out of MVP scope).
* 9. Visual Design (HIGH) — Strong. Semantic colors + Dark Mode good; Increase Contrast adaptation missing (P1); accent lacks variants (P1).
* 10. Popovers (MEDIUM) — Pass; transient popover anchored to the status item, dismisses on Esc/outside click, sized to content.
* 11. Accessibility (CRITICAL) — Partial. Labels good; full keyboard access (P0), Reduce Motion (P1), and Increase Contrast (P1) incomplete.

## Evaluation Checklist (from skill)

### Menu Bar
* [x] Complete menu bar with standard menus
* [x] Actions have keyboard shortcuts
* [x] Menu items update dynamically (enable/disable)
* [x] Context menus on interactive elements (blocked-app rows)
* [x] App menu has About, Settings, Hide, Quit
* [ ] Help menu present (P1)

### Windows
* [x] Resizable with sensible minimums
* [x] Window position/size persist across launches
* [x] Traffic-light buttons intact
* [x] Fullscreen available (default for titled windows)

### Keyboard
* [x] Menu/global shortcuts for primary actions
* [x] Esc cancels/closes; Return triggers default action
* [ ] Arrow-key navigation in lists (P0)
* [ ] Delete key removes selected blocked app (P0)
* [ ] No keyboard traps in custom list management (P0)

### Pointer
* [x] Right-click context menus
* [ ] Hover states on list rows (P1)
* [ ] Cmd/Shift-click multi-selection in lists (P0)
* [ ] Drag-and-drop to add apps from Finder (P2)

### Visual Design
* [x] System fonts at semantic sizes
* [x] Dark Mode supported (semantic colors)
* [x] System accent respected for prominent controls
* [ ] Increase Contrast adaptation for custom colors (P1)
* [x] Consistent spacing scale (`FLSpacing`)

### Accessibility
* [x] Accessibility labels on icon-only buttons
* [ ] Full keyboard access for all mouse actions (P0)
* [ ] Reduce Motion respected app-wide (P1; overlay only today)
* [x] Reduce Transparency: no translucent materials to replace
* [ ] Increase Contrast respected for custom colors (P1)
