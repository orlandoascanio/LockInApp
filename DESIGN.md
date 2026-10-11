---
name: Quietwhile
description: A native macOS focus app on sand paper and moss ink, where each page carries its own earth-pigment stain.
colors:
  moss: "#618C69"
  moss-dark: "#7FAE88"
  moss-deep: "#3B6148"
  moss-deep-dark: "#8DBB97"
  lichen: "#D9E0D1"
  lichen-dark: "#27352C"
  sand-paper: "#F5F2E8"
  sand-paper-dark: "#1A201C"
  warm-sand: "#EDE9D9"
  warm-sand-dark: "#151A17"
  moss-ink: "#293129"
  moss-ink-dark: "#E9E5D9"
  thinned-ink: "rgba(41, 49, 41, 0.74)"
  thinned-ink-dark: "rgba(233, 229, 217, 0.67)"
  hairline: "rgba(41, 49, 41, 0.20)"
  hairline-dark: "rgba(233, 229, 217, 0.13)"
  field: "rgba(255, 255, 255, 0.55)"
  field-dark: "rgba(255, 255, 255, 0.05)"
  sunken: "rgba(41, 49, 41, 0.05)"
  sunken-dark: "rgba(0, 0, 0, 0.20)"
  clay: "#B87355"
  clay-dark: "#D4906F"
  clay-ink: "#8A4A30"
  clay-ink-dark: "#D4906F"
  slate-rest: "#56788B"
  slate-rest-dark: "#8EB1C4"
  slate-rest-ink: "#3E5E70"
  slate-rest-ink-dark: "#8EB1C4"
  amber: "#B8874A"
  amber-dark: "#D2A862"
  amber-ink: "#76531E"
  amber-ink-dark: "#D2A862"
  lit-chip: "#FFFDF7"
  lit-chip-dark: "#EDE9DD"
  lit-chip-ink: "#293129"
  lit-chip-ink-dark: "#1A201C"
  wash-terre-verte-top: "#DDE8D7"
  wash-terre-verte-bottom: "#EEEFE3"
  wash-terre-verte-top-dark: "#223425"
  wash-terre-verte-bottom-dark: "#1B221B"
  wash-burnt-sienna-top: "#EFDED0"
  wash-burnt-sienna-bottom: "#F3ECE1"
  wash-burnt-sienna-top-dark: "#452318"
  wash-burnt-sienna-bottom-dark: "#261D18"
  wash-yellow-ochre-top: "#F4E4C7"
  wash-yellow-ochre-bottom: "#F5EEDE"
  wash-yellow-ochre-top-dark: "#413516"
  wash-yellow-ochre-bottom-dark: "#242218"
  wash-raw-umber-top: "#E9DED2"
  wash-raw-umber-bottom: "#F1ECE1"
  wash-raw-umber-top-dark: "#29211B"
  wash-raw-umber-bottom-dark: "#1D1C18"
  wash-paynes-grey-top: "#DCE3E6"
  wash-paynes-grey-bottom: "#EDEEE8"
  wash-paynes-grey-top-dark: "#1C2C39"
  wash-paynes-grey-bottom-dark: "#191F21"
  wash-rest-slate-top: "#CFE1EB"
  wash-rest-slate-bottom: "#EAEDE9"
  wash-rest-slate-top-dark: "#1A313D"
  wash-rest-slate-bottom-dark: "#192122"
  wash-unbleached-top: "#ECE9E2"
  wash-unbleached-bottom: "#F2EFE6"
  wash-unbleached-top-dark: "#2B2A27"
  wash-unbleached-bottom-dark: "#1E1F1C"
typography:
  timer:
    fontFamily: "New York (SF serif), Georgia, serif"
    fontSize: "88px"
    fontWeight: 400
    fontFeature: "tnum"
  timer-dial:
    fontFamily: "New York (SF serif), Georgia, serif"
    fontSize: "70px"
    fontWeight: 400
    fontFeature: "tnum"
  display:
    fontFamily: "New York (SF serif), Georgia, serif"
    fontSize: "22px"
    fontWeight: 400
  title:
    fontFamily: "New York (SF serif), Georgia, serif"
    fontSize: "19px"
    fontWeight: 400
  figure:
    fontFamily: "New York (SF serif), Georgia, serif"
    fontSize: "17px"
    fontWeight: 400
    fontFeature: "tnum"
  headline:
    fontFamily: "SF Pro Text, -apple-system, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 600
  body:
    fontFamily: "SF Pro Text, -apple-system, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
  button:
    fontFamily: "SF Pro Text, -apple-system, system-ui, sans-serif"
    fontSize: "13.5px"
    fontWeight: 600
  tab:
    fontFamily: "SF Pro Text, -apple-system, system-ui, sans-serif"
    fontSize: "12.5px"
    fontWeight: 600
  caption:
    fontFamily: "SF Pro Text, -apple-system, system-ui, sans-serif"
    fontSize: "11.5px"
    fontWeight: 400
  label:
    fontFamily: "SF Pro Text, -apple-system, system-ui, sans-serif"
    fontSize: "9.5px"
    fontWeight: 600
    letterSpacing: "1.6px"
rounded:
  sm: "4px"
  md: "6px"
  lg: "10px"
  xl: "14px"
  capsule: "9999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  page-gutter: "26px"
  xl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.moss-deep}"
    textColor: "{colors.sand-paper}"
    typography: "{typography.button}"
    rounded: "{rounded.capsule}"
    padding: "0 22px"
    height: "40px"
  button-primary-pressed:
    backgroundColor: "{colors.moss}"
    textColor: "{colors.sand-paper}"
  button-secondary:
    backgroundColor: "transparent"
    textColor: "{colors.moss-deep}"
    typography: "{typography.button}"
    rounded: "{rounded.capsule}"
    padding: "0 22px"
    height: "40px"
  button-destructive:
    backgroundColor: "transparent"
    textColor: "{colors.clay}"
    typography: "{typography.button}"
    rounded: "{rounded.capsule}"
    padding: "0 22px"
    height: "40px"
  button-quiet:
    backgroundColor: "transparent"
    textColor: "{colors.thinned-ink}"
    typography: "{typography.body}"
    padding: "0 8px"
  segmented-track:
    backgroundColor: "{colors.sunken}"
    rounded: "{rounded.capsule}"
    padding: "3px"
  segmented-selected:
    backgroundColor: "{colors.lit-chip}"
    textColor: "{colors.lit-chip-ink}"
    rounded: "{rounded.capsule}"
    padding: "0 16px"
    height: "28px"
  field:
    backgroundColor: "{colors.field}"
    textColor: "{colors.moss-ink}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "7px 10px"
  tab-bar:
    backgroundColor: "rgba(41, 49, 41, 0.06)"
    rounded: "{rounded.capsule}"
    padding: "4px"
  tab:
    textColor: "{colors.thinned-ink}"
    typography: "{typography.tab}"
    rounded: "{rounded.capsule}"
    padding: "0 15px"
    height: "30px"
  tab-selected:
    backgroundColor: "{colors.lit-chip}"
    textColor: "{colors.lit-chip-ink}"
    typography: "{typography.tab}"
    rounded: "{rounded.capsule}"
    padding: "0 15px"
    height: "30px"
  badge:
    backgroundColor: "transparent"
    textColor: "{colors.thinned-ink}"
    typography: "{typography.caption}"
    rounded: "{rounded.capsule}"
    padding: "4px 9px"
---

# Design System: Quietwhile

## Overview

**Creative North Star: "The Quiet Study"**

Quietwhile looks like a calm room with good paper on the desk. The canvas is unbleached sand, the ink is a deep moss, and the numbers you came to see (the countdown, durations, today's minutes, the streak) are set in a book serif, as if written down rather than displayed. Everything else is small, plain sans. Regions are separated by a single hairline rule or a change of pigment, never by boxes, so a page reads as one sheet rather than a dashboard.

Each page of the main window is stained with its own earth pigment: terre verte, burnt sienna, yellow ochre, raw umber, Payne's grey, and unbleached paper. The stain is strongest under the tab bar and settles back into the canvas lower down, so you know which room you are in before you read a word. The pigments differ in strength as well as hue, the way real paint does; they are a shelf of colours, not a rainbow.

The feel is calm but crisp. Warm palette, generous space, and nothing shouting, but alignment is exact and hierarchy is sharp. There is one filled button per screen. The countdown is the loudest thing in the app, and it should stay that way.

It must never look like productivity SaaS (blue-purple dashboards, gradient hero numbers, grids of icon-title-text cards), like stock macOS Settings (grey grouped forms with system-accent controls), or like a neon "hacker" tool (glows, monospace costume, pure-black backgrounds).

**Key Characteristics:**
- Sand paper and moss ink, in light and dark, with every colour resolving per appearance.
- Serif for numerals the eye lands on; SF for everything else; tracked micro-caps instead of section boxes.
- Hairline rules and pigment changes separate regions; there are almost no containers.
- Capsules for anything you press; softly rounded rectangles for anything you type into.
- Secondary text, rules, fields and recesses are thinned ink, so they take on the hue of whatever page they sit on.
- Flat by default: two small shadows in the whole system.

## Colors

An earthy, low-chroma palette: one moss accent, one clay for regret, one slate for rest, on sand paper that warms or darkens with the appearance.

### Primary
- **Deep Moss** (`moss-deep`, `moss-deep-dark` after dark): the one voice. Filled primary buttons, the selected segment, the dial's progress arc, today's bar in the weekly chart, link text and "Manage ›" style actions.
- **Moss** (`moss`, `moss-dark`): the lighter companion. Pressed primary buttons, past days' bars (at half strength), the current session bead.
- **Lichen** (`lichen`, `lichen-dark`): a pale moss for pressed secondary buttons and soft accent fills.

### Secondary
- **Clay** (`clay`, `clay-dark`; words in `clay-ink`): anything you would regret. Destructive buttons, the emergency exit, a needs-attention dot in a segmented control, error messages, and the "quitting ends its calls" warnings.
- **Slate Rest** (`slate-rest`, `slate-rest-dark`; words in `slate-rest-ink`): breaks. The break phase in the HUD, the status corner during a break, and anything that should never read as more focus.

### Tertiary
- **Amber** (`amber`, `amber-dark`; words in `amber-ink`): warnings that need an answer, such as a browser that hasn't allowed guarding yet (the dot on the Blocked tab and the banner on the Focus page) and the HUD's last minute.

### Neutral
- **Sand Paper** (`sand-paper`, `sand-paper-dark`): the canvas of every window that isn't stained: onboarding, overlays, sheets, the menu-bar popover.
- **Warm Sand** (`warm-sand`, `warm-sand-dark`): the window background behind the hosting view and the few opaque recesses inside sheets.
- **Moss Ink** (`moss-ink`, `moss-ink-dark`): primary text and the serif numerals.
- **Thinned Ink** (`thinned-ink`, `thinned-ink-dark`): secondary text, unselected tabs, captions and micro-caps. Ink at 74% (light) or 67% (dark) rather than a fixed grey, so it holds at least 4.5:1 on every wash (including under the tab bar's tint) while picking up the page's hue.
- **Hairline** (`hairline`, `hairline-dark`): rules, outlines, empty bars, the dial's track. Ink at 20% / 13%.
- **Field** (`field`, `field-dark`): text fields and dropdowns, a shade above whatever is behind them.
- **Sunken** (`sunken`, `sunken-dark`): pressed-in surfaces: segmented-control tracks, Analytics panels, History's stat band, hovered rows, the off state of a schedule switch.
- **Lit Chip** (`lit-chip`, `lit-chip-ink`): the selected tab and the selected Settings gear. Near-white on the light washes, warm cream after dark.

### Page Washes
Each main-window page is a vertical gradient from its pigment's top colour to its bottom colour, reaching the bottom colour at 70% of the window's height. Switching pages crossfades between them (0.28 s ease-out).

| Page | Pigment | Why |
|---|---|---|
| Focus | Terre verte | Moss is the focus colour. |
| Blocked | Burnt sienna | Clay's family: the things you'd regret. |
| Schedules | Yellow ochre | Daylight: the hours a schedule claims. |
| History | Raw umber | Sepia: the past. |
| Analytics | Payne's grey | Cool and measured, for the numbers. |
| Settings | Unbleached | The machinery, kept neutral. |
| Focus, during a break | Rest slate | Not a page but a state: the break turns the page slate over 0.9 s, because slate has always meant rest here. |

### Named Rules
**The One Voice Rule.** Deep Moss is the only filled accent on a screen, and a screen has one filled button. Everything else is outlined, quiet, or text.

**The Thinned Ink Rule.** Secondary text, rules, fields and recesses are ink or white at reduced alpha, never a fixed grey, so they belong to whichever pigment they sit on. A new neutral that is opaque is almost always a mistake.

**The Pigment Shelf Rule.** A new wash must be a real earth pigment, mixed into the sand paper rather than floated as a pastel, with its own strength. No lavender, no baby blue, no hue picked to fill a gap in the colour wheel. Light tops sit near OKLCH L 0.91, dark tops near L 0.29.

**The Ink Shade Rule.** Clay, amber and slate are fill colours. When they become words, glyphs or small status dots, use their `-ink` shade, which clears 4.5:1 on every light wash, hovered rows included; the fill values sit near 2.5–3.9:1 there. The floating HUD follows it too.

**The Increase Contrast Rule.** With Increase Contrast on, thinned ink rises to 90% and hairlines to about half strength, and chart bars draw at full moss. The faintness is a choice for calm, never a requirement.

**The Rest Is Slate Rule.** Everything that belongs to a break is slate, never moss: the wash, the dial's arc and phase label, the break guide's figures and its buttons. Moss means focus; a break that looks like focus is a break nobody takes.

**The Meaning Holds Rule.** Clay always means regret, slate always means rest, amber always means "needs your answer". A wash may borrow a family (sienna for Blocked) but a control never uses one of these colours just for variety.

## Typography

**Display Font:** New York, the macOS system serif (with Georgia, serif)
**Body Font:** SF Pro, the macOS system sans (with -apple-system, system-ui, sans-serif)

**Character:** A book serif for figures and page titles against a small, plain system sans for everything you operate. The serif makes time and counts feel written down and human; the sans keeps the controls native and quiet.

### Hierarchy
- **Timer** (400, 88px; 70px inside the dial, 64px on overlays, 30px in the HUD; tabular figures): the countdown. The loudest thing in the app, used nowhere else.
- **Display** (400 serif, 22px): page titles ("Blocked", "Analytics") and empty-state titles.
- **Title** (400 serif, 19px): headings inside a page, such as a break suggestion's name and the recap card's heading.
- **Figure** (400 serif, 17px; tabular figures): a number standing alone in a line of text, such as the streak or a live countdown in the status corner. Stat values use the same serif, larger (24px in Analytics, 26px in History).
- **Headline** (600 sans, 13px): row titles and emphasised labels.
- **Body** (400 sans, 13px): row text, field text, most copy.
- **Button** (600 sans, 13.5px): button labels.
- **Tab** (600 sans, 12.5px): main tab bar and segmented controls (segments drop to 400 when unselected).
- **Caption** (400 sans, 11.5px): subtitles under page titles, schedule lines, helper text, badges.
- **Label** (600 sans, 9.5px, 1.6px tracking, uppercase): section names ("This week", "When time is up"), table column heads, the dial's phase line.

### Named Rules
**The Written Number Rule.** A number the eye lands on is set in the serif with tabular figures. Numbers inside running sans text stay sans.

**The No-Box Header Rule.** A section is introduced by a tracked micro-caps label and separated by a hairline, never by a filled header bar or a card.

## Layout

The main window (minimum 860 × 600, default 920 × 660) has no sidebar. A 58px top bar holds a centred tab pill, with the status corner and the Settings gear on the right, 16px from the edge. The page wash runs edge to edge under a transparent titlebar.

The Focus page is two columns: the 276px dial with its beads on the left, and on the right a 440px column that reads top to bottom as set-up-then-commit (block length, goal and category, what the block guards and that calls keep going, any browser warning, the one button, then a plain line saying what pressing it means). The weekly chart and today's blocks follow below a hairline, and the scroll view fades its last 28px so the page reads as continuing.

Other pages are single full-width columns with a 26px gutter. Page headers sit at the top left: a serif display title, a caption subtitle, and at most one primary action on the right. Content below is a stack of full-width bands separated by hairline rules: the dial hero, preset tabs, the guarded-apps summary, the weekly chart, today's blocks. Lists are tables with micro-caps column heads and a hairline under each row.

Spacing follows a 4/8/16/24/32 scale. Groups are tight (4–8px inside a row, 14px between a section label and its content); bands are separated generously (20px vertical padding, plus the rule). The Focus hero centres a 276px dial with 16–24px between dial, beads, controls, goal and schedule line.

## Elevation & Depth

Flat by default. Depth comes from tone, not shadow: the wash behind, sunken recesses pressed into it, fields lifted a shade above it, and hairlines between. There are exactly two shadows, both small and soft with a downward offset; nothing glows.

### Shadow Vocabulary
- **Lit chip** (black 12%, 3px blur, 1px down): under the selected tab, so it reads as a lit tile sitting on the bar.
- **Hover card** (black 12%, 6px blur, 2px down): under the weekly chart's day detail card, the one floating surface inside a page.

### Named Rules
**The Tone Before Shadow Rule.** Separate with a rule, a recess or a pigment change first. A new shadow needs a reason a third shadow has never had.

## Shapes

Two families. Anything you press is a capsule: buttons, segmented controls and their selections, the tab bar and its chips, the status corner's hover, badges, stepper buttons, the session beads. Anything you type into or read inside is a softly rounded rectangle: fields and dropdowns at 6px, panels and break-guide cards at 10px, larger containers at 14px. Corners are continuous (squircle) curves throughout.

Borders are 1px hairlines (1.2px on outlined buttons). The dial is a 5px ring with a round-capped progress arc. Chart bars are slim (30px) with 5px rounded tops only.

## Components

### Buttons
Tactile but restrained: one confident filled capsule, everything else a line or a word.
- **Shape:** capsule, 40px tall (44px in the Focus hero, 36px in headers and sheets).
- **Primary:** Deep Moss fill, Sand Paper text, 22px horizontal padding; Moss when pressed.
- **Secondary:** no fill, Deep Moss text, 1.2px Deep Moss outline at 35%; Lichen at 50% when pressed.
- **Destructive:** as Secondary in Clay; Clay at 12% when pressed.
- **Quiet:** thinned-ink text, no outline, 8px padding; dims to 60% when pressed.
- **Link:** underlined Deep Moss text, for actions that shouldn't look like buttons ("Export CSV").
- **Motion:** state changes ease out in 0.16 s.

### Segmented Controls
- **Track:** Sunken capsule with a hairline outline and 3px inset.
- **Selected:** a Lit Chip with Lit Chip Ink semibold text and the lit-chip shadow, 28px tall, the same as the tab bar. A selection is where you are, so it never spends the page's one moss fill. Unselected segments are thinned-ink regular text.
- **Badge:** an optional 6px Amber Ink dot after a segment's title, meaning the same "needs your answer" as on the tab bar.
- **Keyboard and VoiceOver:** the left and right arrow keys step through the choices; VoiceOver hears one picker with its options. The tab bar works the same way.
- Replaces the stock segmented picker everywhere, because that one paints selection in the Mac's accent colour.

### Inputs / Fields
- **Style:** Field fill, 1px hairline, 6px radius, 7px × 10px padding, body text in Moss Ink.
- **Focus:** the border becomes Deep Moss at 1.5px over 0.12 s (Deep Moss, not Moss, so the ring clears 3:1 on every wash). Never the system accent.
- **Dropdowns:** the same chrome with a small up-down chevron in thinned ink; they open a native menu.

### Navigation
- **Tab bar:** a capsule centred in the titlebar: the app icon (26px), then Focus, Blocked, Schedules, History, Analytics. Ink at 6% fill and a hairline outline, 4px inset.
- **Tabs:** 12.5px semibold, 30px tall, 15px padding. Unselected tabs are thinned ink. The selected tab is a Lit Chip with Lit Chip Ink text and the lit-chip shadow, and it slides between tabs (spring, 0.32 s response, 0.86 damping).
- **Needs-answer dot:** a 6px Amber dot after a tab's title when that page needs the person's OK. It must stay visible; this is how an unguarded browser is never hidden.
- **Settings:** a 30px circular gear to the right of the status corner, not a tab. Selected, it becomes a Lit Chip.

### Status Corner
Where you stand, set as type rather than a badge. No dot, no capsule at rest.
- **Idle:** the streak as a serif Figure in Moss Ink, then "day streak · 1h 40m today" in thinned-ink caption. It shortens to "day streak" when space runs out. A lapsed streak says "Streak ended · last focus Fri" (or "Streak ended"); only someone who has never finished a block sees "No streak yet".
- **Space:** the corner gets only the room beside the centred pill and picks the longest form that fits; it never runs under the tabs.
- **Focus:** "Guarding" or "Strict" in semibold Deep Moss, then the countdown as a serif Figure.
- **Break:** "Break" in semibold Slate Rest, then the countdown.
- **Hover:** a Sunken capsule appears behind it. Clicking goes to Focus.

### Focus Dial (signature)
The heart of the Focus page: a 276px ring with a 5px Hairline track and a round-capped Deep Moss progress arc (Moss during a break), starting at twelve o'clock. Inside, the phase in micro-caps ("Focus · 50 / 10") above the countdown in the 70px serif with tabular figures and numeric content transitions. The arc animates linearly in 0.5 s steps and stands still with Reduce Motion on. Below it, session beads: 3px capsules (16px wide, 26px for the current block) in Deep Moss for done, Moss for current, Hairline for to come.

### Weekly Rhythm Chart
Seven slim bars on a shared hairline baseline against a dotted daily-goal line labelled in the right gutter. Today is Deep Moss, past days Moss at 50% (75% on hover), future days dashed empty slots up to the goal, and a day with no focus shows "–". Hovering a day raises the one hover card. The Analytics "Focus over time" chart follows the same grammar.

### Disabled Buttons
- A disabled button is a hairline outline with faint thinned ink and no fill, whatever its variant. It never looks pressable, least of all the page's one filled button.

### Start and Strict
- **Start focus** is the page's one filled button and answers Return.
- A **Strict** chip sits beside the block length: an outlined capsule with an open lock, or Lichen-tinted with a closed moss lock when on. It decides this one block, starts from the Settings default, and is disabled when a strict run or schedule makes the block strict anyway.
- When the next block is strict, the button reads **Start strict block**, Return does nothing, and the line under it says, in ink beside a moss lock, when the block can be ended and how long the emergency exit waits.
- While the goal is being typed, Return finishes the goal instead of pressing Start.
- While a block runs, the countdown is the loud thing: End session is secondary and Skip to break is quiet. A strict block shows "Strict until 1:23 PM" as plain type with the lock, beside a quiet "Emergency exit…".

### The Break
- During a break the Focus page's right column becomes the break: the suggestion ("Try this") with its guide, then what's free ("Discord and 1 site are yours until 12:44 AM · Guarding picks up again when the next block starts"), then "Start next block" and "End session" as quiet text buttons. Nothing during a break is a filled button.
- The guide offers one thing first, its own slate "Start · 1 min", with a quiet "Something else" beside it. "Did it" appears once the guide has started (or straight away for water, a walk or posture), so it never claims something that hasn't happened.
- Before starting, the breathing guide is an outlined slate ring reading "4·4·4·4", not a filled blob. Each step is announced to VoiceOver.
- The check-in is one tap: three outcomes with nothing preselected, saved the moment you pick one. A note is an "Add a note" link away.

### Coming Back
- The status corner offers something to pick up from ("Last focus Fri · 2h 55m", or "Last focus Fri" when tight), never a verdict like "Streak ended".
- The Focus chart is the last 7 days ending today, so it never opens blank because the calendar turned over.
- History, with nothing yet today, leads with the last active day ("2h 55m focused Fri · 6 sessions Fri · 2h 55m last 7 days"), and only shows a streak when there is one.

### Badges
An outlined capsule with a hairline border, caption text in thinned ink, 4px × 9px padding. Used for behaviours and states ("Guard Screen") beside a summary line.

### App Pile
Overlapping app icons (24px, up to four, then "+N" in a hairline circle) to sum up the guarded list in one line. The gap between icons is cut out of the image rather than painted, so it works on any wash.

## Do's and Don'ts

### Do:
- **Do** keep one filled Deep Moss button per screen and make everything else secondary, quiet or a link.
- **Do** set the countdown, durations, counts and the streak in the serif with tabular figures.
- **Do** introduce sections with a 9.5px tracked micro-caps label and separate them with a hairline rule.
- **Do** build new neutrals from thinned ink or white at reduced alpha (Hairline, Field, Sunken) so they take on the page's pigment.
- **Do** check secondary text against the darkest wash top in light mode and the lightest in dark: it must hold 4.5:1.
- **Do** use the app's own controls (FLSegmentedControl, FLMenuPicker, the field modifier, FLActionButtonStyle) instead of stock AppKit pickers, bezels and accent-coloured rings.
- **Do** give every colour a light and a dark value and check both.
- **Do** keep the amber needs-answer dot visible on the tab bar whenever a page needs the person's OK.
- **Do** write clay, amber and slate words in their `-ink` shades.
- **Do** say what a block guards, and that calls keep going, directly above Start; during a break, say what's free and until when.
- **Do** ask before a strict block starts from anywhere that couldn't show its cost first (the menu, ⌘N, the global shortcut, the menu bar, and "Start next block" after a strict break), with Cancel as the default.
- **Do** use one definition of a daily average everywhere: minutes over calendar days in the range.

### Don't:
- **Don't** make it look like productivity SaaS: no blue-purple dashboards, gradient hero numbers, or grids of icon-title-text cards.
- **Don't** make it look like stock macOS Settings: no grey grouped forms, no controls in the system accent colour.
- **Don't** make it look like a neon "hacker" tool: no glows, no monospace as decoration, no pure-black backgrounds.
- **Don't** add a page wash from a hue-wheel gap; lavender, baby blue and blush pastels are out. Use a real earth pigment mixed into the paper.
- **Don't** use clay, slate or amber decoratively; they mean regret, rest and needs-an-answer.
- **Don't** draw a status as a dot in a tinted capsule; set it as type.
- **Don't** paint gaps or rings in Sand Paper on a stained page; cut them out or use thinned ink.
- **Don't** add a third shadow, a coloured glow, or a card around something a hairline could separate. Analytics, too, is bands on the page, not boxed panels.
- **Don't** let a strict block start on Return, or a running block's loudest control be a way out.
- **Don't** greet a returning person with zeros or a lapsed streak; lead with what they last did.
- **Don't** hide a control at opacity 0; it drops out of the accessibility tree. Use a trace of opacity, switch off hit-testing, and show it whenever it has keyboard focus.
- **Don't** offer "Did it" before there's anything to have done.
