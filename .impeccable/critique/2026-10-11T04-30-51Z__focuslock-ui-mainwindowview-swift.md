---
target: main window (MainWindowView.swift)
total_score: 27
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 3
target_identity: "file:/Users/orlando/Documents/DND/FocusLock/UI/MainWindowView.swift"
target_fingerprint: "sha256:bde1a9196c70adbc0f414672b379152b63bf886d59dc531c786a549ed4b26ac0"
target_path: /Users/orlando/Documents/DND/FocusLock/UI/MainWindowView.swift
timestamp: 2026-10-11T04-30-51Z
slug: focuslock-ui-mainwindowview-swift
---
Method: dual-agent (A: design review · B: detector + mechanical evidence)

## Design Health Score
| # | Heuristic | Score | Key Issue |
|---|---|---|---|
| 1 | Visibility of System Status | 3 | Break looks like focus (moss wash/arc/guide); corner drops "last focus Fri" at 860pt. |
| 2 | Match System / Real World | 3 | "Block" = time and forbidden thing ("Start strict block" vs "Blocked" tab). |
| 3 | User Control and Freedom | 3 | Safe-default confirmations, honest exit; ⌘N / hotkey start strict unconfirmed. |
| 4 | Consistency and Standards | 2 | Blocked/Blocking vs guard; clay needs-OK dot on Websites vs amber tab; menu vs window wording. |
| 5 | Error Prevention | 3 | Quit App call warnings + no Return on strict; ⌘N bypasses. |
| 6 | Recognition Rather Than Recall | 3 | Guard line shows what's taken; strict is a remembered Settings toggle. |
| 7 | Flexibility and Efficiency | 2 | No ⌘1–5; segmented = Tab stop per segment, no arrows; sub-tabs reset. |
| 8 | Aesthetic and Minimalist Design | 3 | Idle Focus excellent; History zero band; Sunday week chart all empty. |
| 9 | Error Recovery | 3 | Clear, kind; "Allow…" on amber banner 4.46:1. |
| 10 | Help and Documentation | 2 | Firefox note far from field; schedules-only-while-open unstated; no shortcut docs. |
| **Total** | | **27/40** | **Acceptable** (was 24) |

## Design Specificity Verdict
Surface authored; commit column now carries the positioning ("Guards Discord · 2 sites — apps keep running, calls keep going", clay when Discord quits). Structure elsewhere interchangeable (tab pill, Blocked table, History stat band, Analytics KPIs); nav uses "Blocked". The break is the least authored moment — identical to focus.
Detector: exit 0, `[]`, reads HTML/CSS only. Mechanical: all -Ink text tokens pass both modes; no fill tokens as text; Reduce Motion handled on tab chip/wash/dial/breathing. Remaining: dark ochre unselected tabs 4.40; 0.85-faded 11pt helpers 3.7–4.3 (BlockedSitesSection.swift:145, SchedulesView.swift:32); "Allow…" on banner 4.46; light focus ring on sienna/umber/Payne's 2.9 vs wash (passes vs field); pressed primary 3.43; opacity-0 Remove buttons may leave the a11y tree (row accessibilityAction is fallback); guard line .combine may swallow Manage; 9.5–10.5pt in Analytics/weekly chart; water-glass spring and symbol pulse unguarded. False positives: shadows/mask, sheet fills, disabled fades, decorative hairlines.

## Priority Issues
- [P1] Break designed as a gap: filled "Start next block", second filled "Did it" below fold, check-in beside guide, all moss. Fix: quiet exits, guide in right column above fold, slate arc/guide/wash tint, one-tap check-in. Command: shape → colorize.
- [P1] Returning users greeted with failure: "Streak ended" on every page, History zeros, empty Sunday week chart. Fix: resumable corner or nothing, rolling 7-day chart, History leads with last active day. Command: clarify.
- [P1] ⌘N / ⌃⌥⌘S start strict silently (MenuBarController.swift:2144). Fix: "Start Strict Block…" title + confirmation with end time and exit wait, Cancel default. Command: harden.
- [P2] Words/meaning drift: Blocked/Blocking vs guard, clay needs-OK dot, menu vs window names, Add app vs Add site placement, break guard line says "Guards". Command: clarify.
- [P2] Thin keyboard/VoiceOver paths: no ⌘1–5, segmented not a picker, .combine guard line, opacity-0 Remove, sub-tabs reset, residual contrast misses. Command: harden.

## Persona Red Flags
Alex: ⌘N strict; 3-step add site; 5 Tab stops for Sound; repeated year; filter for 2 items.
Sam: Manage swallowed; tabs not a tab list; corner purpose only in tooltip; "＋" read aloud; "⛨ 3" unexplained; 11pt helpers.
Jo: start works; break doesn't say Discord is free; Chrome Guard Screen covers whole browser unwarned.

## Minor Observations
Schedules empty-state ambiguity; General in General; corner repeats dial countdown; 5pt arc start dot; moss break label; Analytics bar beside Oct 7 tick; padlock icon (LockIn metaphor); Analytics filler subtitle; stock Preview menu.

## Questions to Consider
Name the call on Focus? Strict chosen at commit instead of a standing setting? Break as the session's peak?
