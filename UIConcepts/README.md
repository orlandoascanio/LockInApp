# UI Concepts

Three competing UI/UX directions for LockIn, built as real SwiftUI so what you
see is what the app would actually render. **Mockups only** — nothing is wired
up, no buttons act, no state changes. Pick a direction, then it gets built for
real against `MenuBarController`.

None of the three reuses the current teal-on-system-chrome look, and none uses
black as a surface colour.

## Look at them

```bash
swift run UIConcepts               # interactive gallery, tabs across the top
swift run UIConcepts --export DIR  # write every screen to DIR as a 2x PNG
```

Pre-rendered PNGs live in `renders/`.

The real app is untouched — `swift run LockIn` and `swift test` behave exactly
as before. Delete this folder and its `Package.swift` target to drop the whole
exploration.

## ★ The redesign (`ConceptLockIn.swift`)

The chosen direction — Sage's minimalism as the base, with the parts of Ember
and Studio that tested well merged in.

| Taken from | What |
|---|---|
| **Sage** | Whole visual language: sand canvas, moss accent, serif numerals, hairline rules, one filled button per screen. Guard screen kept verbatim. |
| **Studio** | The sidebar (Focus / Blocked apps / History / Settings), the streak block, the weekly rhythm chart, and the blocked-apps table with behaviour + blocked-today counts. |
| **Ember** | The timer's control pair (outlined `Pause` + filled `End session`) and the guarded-app pile. |

Problems fixed from plain Sage:

- **Controls were stranded at the window edge** and read as page chrome. They now
  sit directly under the countdown, in Ember's pill treatment, so they clearly
  belong to the clock.
- **The guarded-app chip row** is gone, replaced by Ember's compact icon pile
  with a `Manage →` link into the real table.
- **The odd "today" bar log** is replaced by Studio's weekly rhythm on a real
  baseline, plus the streak block in the sidebar.

New feature carried out of the exploration: the **pinned HUD**. The collapsed
strip floats above every window so the countdown is always one glance away, and
reveals `Pause` / `End` on hover. The **menu-bar tuck** is the same strip,
dropped from the status item, with `Open LockIn` and `Pin HUD` actions.

## The three source directions

| | **Ember** | **Studio** | **Sage** |
|---|---|---|---|
| Architecture | One 380×600 panel | 960×640 window, sidebar | 560pt floating strip |
| Navigation | Footer tabs + in-panel sheet | Persistent sidebar, 5 sections | Expands in place |
| Hero | Radial progress ring | Live session card + stats | Serif numerals, nothing else |
| Colour | Coral / amber on cream | Indigo / violet on slate | Moss on sand |
| Type | SF Rounded throughout | SF, tight and dense | Serif display + micro-caps |
| Density | Low | High | Very low |
| Best if | LockIn should feel like a calm ritual | You want to see your focus data | LockIn should stay out of the way |

**Ember** — evolution of today's popover. The ring makes remaining time legible
as a shape before it is read as a number; presets, guarded apps and the primary
action orbit it. One filled button per screen.

**Studio** — promotes LockIn from menu-bar utility to a real app. Settings and
History stop being modal detours and become permanent addresses. The dashboard
answers "how is my day going" before you start a session.

**Sage** — the opposite bet. A focus app shouldn't be a place you visit; it
should be a thin presence at the edge of the screen. No cards, no shadows, one
filled button in the entire design.

Each direction includes its own guard-screen treatment, which is the screen
users actually see most during a session.

## Files

- `GalleryApp.swift` — gallery shell, concept picker, shared mock data
- `ConceptEmber.swift` / `ConceptStudio.swift` / `ConceptSage.swift`
- `Export.swift` — `--export` PNG renderer
