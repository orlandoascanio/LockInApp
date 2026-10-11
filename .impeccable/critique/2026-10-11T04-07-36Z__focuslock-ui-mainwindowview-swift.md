---
target: main window (MainWindowView.swift)
total_score: 24
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 3
target_identity: "file:/Users/orlando/Documents/DND/FocusLock/UI/MainWindowView.swift"
target_fingerprint: "sha256:11b8772580dea338aa40b62f20d9466462a83f5d501cfade3c119160f649ce3c"
target_path: /Users/orlando/Documents/DND/FocusLock/UI/MainWindowView.swift
timestamp: 2026-10-11T04-07-36Z
slug: focuslock-ui-mainwindowview-swift
---
Method: dual-agent (A: design review · B: detector + mechanical evidence)

## Design Health Score
| # | Heuristic | Score | Key Issue |
|---|---|---|---|
| 1 | Visibility of System Status | 3 | Guarded list below the fold; strict only as 9.5pt "· STRICT". |
| 2 | Match System / Real World | 3 | "50 / 4", "Guard Screen / Hide Only" unexplained, "ResistGate". |
| 3 | User Control and Freedom | 2 | Remove has no confirm/undo; strict starts on Return. |
| 4 | Consistency and Standards | 2 | Three selection styles; three moss fills on Blocked. |
| 5 | Error Prevention | 2 | No strict confirmation; Quit App on Discord unwarned. |
| 6 | Recognition Rather Than Recall | 2 | Behaviour picker looks like text; hover-only Remove; Custom fields off-screen. |
| 7 | Flexibility and Efficiency | 2 | No tab shortcuts, no ⌘F, no add shortcut; ⌘1 opens window. |
| 8 | Aesthetic and Minimalist Design | 3 | Hero beautiful; stats repeated 4×; Analytics boxed. |
| 9 | Error Recovery | 3 | Browser recovery excellent; warning/error text fails contrast (light). |
| 10 | Help and Documentation | 2 | No help at decision points (Blocked behaviour, strict at Start). |
| **Total** | | **24/40** | **Acceptable** |

## Design Specificity Verdict
Focus hero is authored (serif countdown in moss ring on terre verte, plain copy). The shell (centred pill tabs + gear + status corner) is the generic modern-Mac-utility template; washes are the only marker and in dark mode sienna/ochre/umber collapse into one brown. Analytics is a boxed KPI dashboard in earth tones. The positioning ("your friends are on the call") is absent from the window.
Detector: exit 0, `[]` — reads HTML/CSS only, scanned none of the Swift files. Mechanical scan + contrast math: light-mode amber 2.4–2.6, clay 2.8–3.1, slate 3.6–3.9 fail as text on every wash (dark passes); unselected tab inkSoft on raw umber 4.46; 9.5–10.5pt text cluster in AnalyticsView; tab spring + wash crossfade ignore Reduce Motion (MainWindowView.swift:110,178); hover-only Remove buttons (BlockedAppsView.swift:233, BlockedSitesSection.swift:182); hairline 1.43:1 where it is a control's only edge; inkSoft×0.8 / ×0.55 variants fail (future-day labels 2.1:1); BlockedAppsView.swift:142 filter field lacks moss focus ring. False positives: .black shadows, token .tint on switches, canvas fills in the strict escape sheet.

## Priority Issues
- [P1] Focus page hides how the block is set up behind the CTA and the fold (presets cut at bottom edge, Custom fields off-screen, guarded summary and browser warning below fold). Fix: preset capsule control with inline steppers by the dial; "Guards Discord, Chrome · Guard Screen — calls keep going" above Start; warning above fold; only rhythm + today scroll. Command: layout.
- [P1] Strict block starts with one keypress and a 9.5pt label (MainWindowView.swift:501). Fix: "Start strict block", consequence line with end time and exit wait, no Return shortcut, running state as plain type + lock. Command: harden.
- [P1] Differentiator invisible / contradicted on Blocked: Guard Screen unexplained, behaviour picker looks like text, Quit App on calling apps unwarned, "ResistGate covers it" (BlockedSitesSection.swift:143). Fix: column caption, chevron badge, call-app warning, "Firefox can't be guarded." Command: clarify.
- [P2] Warning/error/rest text fails contrast in light mode. Fix: split fill vs text values (#7E5A22, #934F33, #3E5E70); nudge inkSoft; drop ×0.55 for content. Command: colorize.
- [P2] Selection styles and One Voice Rule drift: lit chip vs moss capsule vs underline presets; End session filled during focus; Settings toggles at 560pt; cancelled in amber; Reduce Motion ignored on new motion. Command: polish.

## Persona Red Flags
Alex: no tab shortcuts (⌘1 taken), no ⌘F/add shortcut, 3-step duration change, dead status-corner click on Focus.
Sam: hover-only Remove; tabs not a tab group; idle dial "50:00 remaining" and "Session 1 of 4" misleading; no capsule focus ring; light warning text fails 4.5:1; dot-only "completed".
Jo (on a Discord call): guarded summary below fold; nothing promises the call survives; Guard Screen unexplained; Quit App hangs up unwarned; return visit greeted by "No streak yet" and four zeros.

## Minor Observations
Lapsed streak says "No streak yet"; History repeats year, filled header band; Analytics filler subtitle + sunken panels; dark sienna/ochre/umber too close; Settings "General" inside General; pill app icon looks like home; developer Sparkle copy; filter field focus ring.

## Questions to Consider
Why doesn't the Focus page show the call? Does a glance-only app need five pages? Should a running block offer any filled button?
