---
target: main window (MainWindowView.swift)
total_score: 28
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 3
target_identity: "file:/Users/orlando/Documents/DND/FocusLock/UI/MainWindowView.swift"
target_fingerprint: "sha256:ed2566cca85e8c73f15533273558cac12a65c472f6e290a1eb442881872827f0"
target_path: /Users/orlando/Documents/DND/FocusLock/UI/MainWindowView.swift
timestamp: 2026-10-11T04-50-52Z
slug: focuslock-ui-mainwindowview-swift
---
Method: dual-agent (A: design review · B: detector + mechanical evidence)

## Design Health Score
| # | Heuristic | Score | Key Issue |
|---|---|---|---|
| 1 | Visibility of System Status | 3 | "Ends at…" computed at render, goes stale idle. |
| 2 | Match System / Real World | 3 | "Blocked" vs guard (kept), "50 / 4", ambiguous schedule "window". |
| 3 | User Control and Freedom | 3 | Strict is a standing setting with no switch on Focus; no undo on Remove. |
| 4 | Consistency and Standards | 2 | Disabled buttons look enabled; Focus vs Analytics averages disagree; hotkey titles "Stop session"/"Skip to next phase"; Add placement. |
| 5 | Error Prevention | 3 | Skip routes start strict next block unconfirmed; Analytics misdates bar. |
| 6 | Recognition Rather Than Recall | 3 | Strict's home must be remembered. |
| 7 | Flexibility and Efficiency | 3 | ⌘1–5 etc. present; apps added one at a time; segmented ignores arrows. |
| 8 | Aesthetic and Minimalist Design | 3 | Break column six actions, time repeated. |
| 9 | Error Recovery | 3 | Clear browser-denied recovery. |
| 10 | Help and Documentation | 2 | Welcome Guide only in Help menu; HUD options behind right-click. |
| **Total** | | **28/40** | **Good** (24 → 27 → 28) |

## Design Specificity Verdict
~70% authored: guard line, slate break with "yours until", strict cost, kind return. Generic: Analytics stat strip + filler subtitle, History repeated dates, Settings list; LockIn padlock in tab pill.
Detector: exit 0 `[]`; verified working on an HTML probe; no Swift rules. Scan: all text tokens ≥4.5 on all seven washes both modes (min clayInk 4.59). Misses: hairline 1.43 as sole edge of fields/pickers/steppers/segmented track; amber tab dot 2.27 light; "Quitting ends its calls" on hovered sienna row 4.32; pressed primary 3.43 (transient). Every skip route → startFocus bypasses strict confirmation (MenuBarController skipPhase). Goal field no onSubmit — Return may press Start (runtime check). Unguarded motion: stretch pulse, water spring, segmented withAnimation driving layout. Menu End Session disabled in breakEnded while window offers End cycle. PinnedHUD uses fill colours as text (final-minute 2.84). False positives: shadows/masks, zero-opacity wash layers, .combine without buttons, disabled fades, decorative glyphs.

## Priority Issues
- [P1] Disabled buttons look enabled (FLActionButtonStyle has no isEnabled; "Add site" full moss when empty; "Start the wait"). Fix: disabled = hairline outline + thinned ink ~45%. Command: harden.
- [P1] Analytics misdates (AxisValueLabel centered with 5-day stride, AnalyticsView.swift:238) and averages disagree (Focus Avg 25m vs Analytics 2h 55m per active day). Fix: center only at stride 1; one average definition. Command: harden → clarify.
- [P1] Strict side door + strict buried: skip routes start strict next block unconfirmed; "Run every block strict" only in Settings › Blocking. Fix: confirm strict on person-triggered skips; Strict chip beside block length on Focus. Command: harden → layout.
- [P2] Break column asks too much: six actions, "Did it" before starting, time twice, grey placeholder breathing graphic. Fix: one slate Start + quiet "Something else"; Did it after start; drop "Focus resumes at". Command: distill.
- [P2] Accessibility gaps: no Increase Contrast; tabs/segmented not tab/radio groups, no arrows; breathing steps unannounced; 0.001-opacity Remove focusable invisibly; amber dot 2.27. Command: audit.

## Persona Red Flags
Alex: strict alert confirm has no key equivalent (unstated); five panel round trips for five apps; strict off via ⌘, + segment; Start next block no key.
Sam: tabs not "tab 1 of 5"; segmented no group semantics; silent breathing guide; disabled Add site looks/sounds enabled; faint switches/bars, no Increase Contrast.
Jo: guard line/break reassurance right; open panel says "Choose an app to block"; goal field during focus edits next block silently; all break suggestions solo.

## Minor Observations
"?" tile for uninstalled app; Blocked subtitle/header Add drift; alert Cancel in system accent, commit styled destructive; corner repeats countdown on Focus; History repeated dates, cryptic "⛨ 3"; General in General; dark Settings wash stock grey; inactive Chrome chip full strength.

## Questions to Consider
Say "Discord stayed connected through 3 blocks"? Strict per block or per person? Break as a word with friends?
