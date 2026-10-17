---
name: Quietwhile
description: A native macOS focus app in SF Pro, laid open on one soft grey-green canvas, with moss as its only accent and hairlines instead of boxes.
colors:
  moss: "#618C69"
  moss-dark: "#7FAE88"
  moss-deep: "#3B6148"
  moss-deep-dark: "#8DBB97"
  lichen: "#E3ECE1"
  lichen-dark: "#26332A"
  on-moss: "#FFFFFF"
  on-moss-dark: "#122016"
  canvas: "#E5E7E1"
  canvas-dark: "#1C1D1C"
  surface: "#EFF1EB"
  surface-dark: "#272927"
  ink: "#1D211E"
  ink-dark: "#F2F2EF"
  thinned-ink: "rgba(29, 33, 30, 0.68)"
  thinned-ink-dark: "rgba(242, 242, 239, 0.62)"
  hairline: "rgba(29, 33, 30, 0.10)"
  hairline-dark: "rgba(255, 255, 255, 0.10)"
  field: "#F7F8F4"
  field-dark: "rgba(255, 255, 255, 0.07)"
  field-edge: "rgba(29, 33, 30, 0.17)"
  field-edge-dark: "rgba(255, 255, 255, 0.14)"
  sunken: "rgba(29, 33, 30, 0.055)"
  sunken-dark: "rgba(255, 255, 255, 0.07)"
  chip: "#F7F8F4"
  chip-dark: "#4A4D4A"
  clay: "#B87355"
  clay-dark: "#D4906F"
  clay-ink: "#8A4A30"
  clay-ink-dark: "#D4906F"
  slate-rest: "#56788B"
  slate-rest-dark: "#8EB1C4"
  slate-rest-ink: "#3E5E70"
  slate-rest-ink-dark: "#8EB1C4"
  rest-surface: "#E8EEF0"
  rest-surface-dark: "#232A2E"
  amber: "#B8874A"
  amber-dark: "#D2A862"
  amber-ink: "#76531E"
  amber-ink-dark: "#D2A862"
typography:
  timer:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "64px"
    fontWeight: 700
    fontFeature: "tnum"
  large-title:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "26px"
    fontWeight: 700
  display:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "20px"
    fontWeight: 700
  title:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 600
  figure:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "24px"
    fontWeight: 700
    fontFeature: "tnum"
  headline:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 600
  body:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "13px"
    fontWeight: 400
  callout:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "12px"
    fontWeight: 400
  caption:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "11.5px"
    fontWeight: 400
  micro:
    fontFamily: "SF Pro, -apple-system, system-ui, sans-serif"
    fontSize: "11px"
    fontWeight: 500
rounded:
  sm: "5px"
  md: "7px"
  lg: "10px"
  xl: "14px"
  capsule: "9999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "16px"
  lg: "24px"
  page-inset: "28px"
  band: "22px"
  column-gap: "24px"
  xl: "32px"
components:
  button-primary:
    backgroundColor: "{colors.moss-deep}"
    textColor: "{colors.on-moss}"
    rounded: "{rounded.capsule}"
    padding: "0 22px"
    height: "40px"
  button-primary-pressed:
    backgroundColor: "{colors.moss}"
  button-secondary:
    backgroundColor: "{colors.chip}"
    textColor: "{colors.ink}"
    borderColor: "{colors.hairline}"
    rounded: "{rounded.capsule}"
    padding: "0 22px"
    height: "40px"
  button-destructive:
    backgroundColor: "{colors.chip}"
    textColor: "{colors.clay-ink}"
    borderColor: "{colors.hairline}"
    rounded: "{rounded.capsule}"
  button-quiet:
    backgroundColor: "transparent"
    textColor: "{colors.thinned-ink}"
    padding: "0 10px"
  button-text:
    backgroundColor: "transparent"
    textColor: "{colors.moss-deep}"
  segmented-track:
    backgroundColor: "{colors.sunken}"
    rounded: "9px"
    padding: "2px"
  segmented-selected:
    backgroundColor: "{colors.chip}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    padding: "0 14px"
    height: "26px"
  field:
    backgroundColor: "{colors.field}"
    borderColor: "{colors.field-edge}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "7px 10px"
  tab-bar:
    backgroundColor: "{colors.sunken}"
    rounded: "{rounded.capsule}"
    padding: "3px"
  tab-selected:
    backgroundColor: "{colors.chip}"
    textColor: "{colors.ink}"
    rounded: "{rounded.capsule}"
    padding: "0 14px"
    height: "30px"
  callout:
    backgroundColor: "amber at 13%, clay at 11%, or lichen at 70%"
    rounded: "{rounded.lg}"
    padding: "10px 12px"
---

# Design System: Quietwhile

## Overview

**Creative North Star: "A Mac app, laid open"**

Quietwhile should feel like it shipped with the Mac. It is set in SF Pro and nothing else, and it builds hierarchy the way Apple's own apps do: bold titles, semibold headings, regular body text, and secondary text in a thinned ink. The window is one soft grey-green canvas on every page. It is never paper white, because the window stays open for hours. Moss is the only accent.

Nothing sits in a box. A page is a stack of bands lying on the canvas, divided by full-width hairlines. Two things side by side are divided by a vertical hairline. Settings are rows on the canvas with hairlines between them. The structure comes from type, alignment, hairlines and air, not from containers.

The feel is calm and exact. Generous space, nothing shouting, and one filled button per screen. The countdown is the loudest thing in the app and should stay that way.

It must never look like productivity SaaS (blue-purple dashboards, gradient hero numbers, grids of cards), like a web page (underlined links, spaced capitals as headings, a serif posing as editorial), or like a dashboard of white boxes.

**Key characteristics:**
- SF Pro throughout, with tabular figures for anything that counts.
- One canvas on every page, soft grey-green by day and charcoal after dark. No pure white anywhere large.
- Bands and hairlines, never cards. The only tinted containers are callouts that need an answer.
- Controls drawn the way AppKit draws them (raised segments on a sunken track, pop-up buttons, stock switches), but in moss instead of the Mac's accent colour.
- A unified-toolbar top: the app's name beside the traffic lights, and a four-place tab bar under it.

## Colors

A low-chroma palette: one moss accent, clay for regret, slate for rest, and amber for "needs your answer", on a canvas that only ever changes with the appearance, never with the page.

### Primary
- **Deep Moss** (`moss-deep`, `moss-deep-dark`): the one voice. The filled primary button, the dial's progress arc, today's bar, text buttons ("Manage ›", "Open Quietwhile"), switches when on, selected schedule days.
- **Moss** (`moss`, `moss-dark`): pressed primary buttons, past days' bars (at half strength), the current session bead.
- **Lichen** (`lichen`, `lichen-dark`): pale moss for the Strict chip when on, selected break-suggestion chips, and the info callout.
- **On Moss** (`on-moss`, `on-moss-dark`): words on a moss fill. White by day; near-black after dark, where the moss is light.

### Secondary
- **Clay** (fill) and **Clay Ink** (words): anything you would regret. Destructive buttons, the emergency exit, "Got stuck", abandoned blocks, "quitting ends its calls".
- **Slate Rest** (fill) and **Slate Rest Ink** (words): breaks. The dial's arc and label during a break, the break guide, the status corner during a break. **Rest Surface** sits behind the break-guide preview in Settings.

### Tertiary
- **Amber** (fill) and **Amber Ink** (words): needs your answer. A browser that hasn't allowed guarding (the dot on the Blocked tab, the line in the Focus page's guard row), the login hint on Schedules, "Made progress".

### Neutral
- **Canvas** (`canvas`, `canvas-dark`): the window, every page, the same everywhere. `#E5E7E1` by day: a soft grey with moss in it, at about OKLCH L 0.92, well short of white.
- **Surface** (`surface`, `surface-dark`): one step towards you, for the few things that float: the weekly chart's hover card and the floating HUD.
- **Ink** (`ink`, `ink-dark`): primary text.
- **Thinned Ink** (`thinned-ink`, `thinned-ink-dark`): secondary text, unselected tabs, column headings, captions. Ink at 68% by day and 62% after dark, which holds at least 4.5:1 on the canvas.
- **Hairline**: every divider, band rule and column rule. Ink (or white) at 10%.
- **Field** and **Field Edge**: text fields, pop-up buttons, the shortcut recorder. The edge is firmer than a hairline because it marks something you can type in or click.
- **Sunken**: tracks pressed into the canvas. The tab bar, segmented controls, the search field, behaviour pills, unselected day chips, hovered rows.
- **Chip** (`chip`, `chip-dark`): the selected tab or segment, and secondary buttons. A raised off-white, never pure white.

### Named Rules
**The No White Rule.** Nothing large is pure white. The canvas is grey-green, and the lightest thing on it (a chip, a field) is `#F7F8F4`. A page that glares has failed, however clean it looks.

**The One Canvas Rule.** Every page has the same canvas. A page doesn't announce itself with a colour; its title and its tab do.

**The One Voice Rule.** Deep Moss is the only filled accent on a screen, and a screen has one filled button. Everything else is a raised chip, quiet text, or a text button.

**The Ink Shade Rule.** Clay, amber and slate are fill colours. As words, glyphs or small dots, use their `-ink` shade, which clears 4.5:1 on the canvas.

**The Meaning Holds Rule.** Clay always means regret, slate always means rest, amber always means "needs your answer", and moss means focus and success. A check-in's outcome follows it: "Goal done" in moss, "Made progress" in amber, "Got stuck" in clay, never stuck in the colour of success.

**The Increase Contrast Rule.** With Increase Contrast on, thinned ink rises to 86%, hairlines to 40% and field edges to 50%. The faintness is a choice for calm, never a requirement.

## Typography

**Font:** SF Pro, the macOS system font, at every size. No serif, no custom face, no spaced capitals.

**Character:** Apple's own hierarchy: weight and size together. Bold for titles and the time, semibold for headings, regular for everything you read, thinned ink for everything secondary. Numbers that count use tabular figures, so they never jitter.

### Hierarchy
- **Timer** (700, tabular): the countdown. 64px in the dial and on overlays, 46px in the menu-bar popover, 30px in the HUD.
- **Large Title** (700, 26px): page titles: "Blocked", "Schedules", "Stats", "Settings".
- **Display** (700, 20px): sheet titles and empty states.
- **Title** (600, 15px): section headings inside a page ("Last 7 days", "When time is up", "What pulls you away").
- **Figure** (700, 24px, tabular): a number standing alone with its label, as on Analytics and History.
- **Headline** (600, 13px): emphasised labels and callout titles.
- **Body** (400, 13px): rows, fields, most copy.
- **Callout** (400, 12px): the description under a row's title, subtitles under page titles.
- **Caption** (400, 11.5px): footnotes and helper text.
- **Micro** (500, 11px): table column headings, chart axes, a figure's label.

### Named Rules
**The Weight Not Case Rule.** A heading is set apart by weight and size, in sentence case. Never uppercase with tracking.

**The Counted Number Rule.** A number that counts or changes uses tabular figures. It is set in the same SF Pro as the words around it, only heavier when it is the point.

## Layout

The main window (minimum 860 × 600, default 980 × 720) has no sidebar. The canvas runs edge to edge under a transparent titlebar.

**The top.** A 32px titlebar row holds the app's name (13px semibold) beside the traffic lights, where a unified toolbar puts its title; AppKit's own centred title is hidden. Under it, a 46px row holds the tab bar centred, with the status corner and the Settings gear on the right, 20px from the edge.

**Pages.** Content is inset 28px from the window's sides. A page header is a large title, an optional callout-size subtitle, any switcher under it, and at most one primary action on the right. Below it, the page is a stack of bands with 22px of air above and below, divided by full-width hairlines. Two columns in a band sit 24px either side of a vertical hairline. Lists are tables: micro column headings over a hairline, rows 46–50px tall, a hairline under each row, a sunken background on hover.

**Focus.** One open band: the dial and its beads on the left, and a 420px column on the right that reads top to bottom as set-up-then-commit: block length and Strict, goal and category, what the block guards, the full-width Start button, then a plain line saying what pressing it means. Below a hairline, the last 7 days and today's blocks sit side by side, divided by a vertical hairline.

**Settings.** One 660px column, centred, as System Settings keeps its panes. Groups are separated by full-width hairlines; inside a group, rows have their title and description on the left and their control on the right.

**Scrolling.** Scroll views fade their content out at the edges instead of cutting it, so nothing looks sliced where it passes under the header.

Spacing follows a 4/8/16/24/32 scale.

## Elevation & Depth

Mostly flat. Depth comes from tone: tracks are sunken into the canvas, and chips and fields sit a shade above it. Shadows are small, soft and only on things that are raised or float. Nothing glows. After dark, shadows go and edges do the work.

### Shadow Vocabulary
- **Raised chip** (black 12–14%, 2–3px blur, 1px down): the selected tab or segment.
- **Primary button** (black 16%, 5px blur, 2px down): the one filled button.
- **Push button** (black 5–6%, 1–2px blur, 1px down): secondary and inline buttons, pop-up buttons.
- **Hover card** (black 12%, 6px blur, 2px down): the weekly chart's day detail.
- **HUD** (black 14%, 8px blur, 3px down): the floating countdown, which sits over other apps.

### Named Rules
**The No Box Rule.** Separate with a hairline and air, never with a card. A tinted container is allowed only for a callout that needs an answer, and never for content.

## Shapes

Anything you press is a capsule: buttons, the tab bar and its chips, badges, schedule day chips, behaviour pills. A segmented control is a rounded rectangle (9px track, 7px segment), as AppKit draws one. Fields, pop-ups and the shortcut recorder are 7px. Callouts are 10px. Corners are continuous curves throughout.

The dial is a 9px ring with a round-capped arc. Chart bars are slim with 5px rounded tops only.

## Components

### Buttons
- **Primary:** Deep Moss capsule, On Moss text, 40px (44px and full width for Start focus, 34px in page headers), the primary shadow; Moss when pressed; shrinks to 98% while held.
- **Secondary:** a raised chip with a hairline edge and ink text (or slate for a break's own actions).
- **Destructive:** as Secondary with Clay Ink text.
- **Quiet:** thinned-ink text, no chrome; a sunken capsule while pressed.
- **Text button:** Deep Moss, 13px medium, never underlined ("Manage ›", "Allow…", "Open Quietwhile"). It is a button, not a link.
- **Inline:** a small raised capsule, 26px, for actions inside a row ("Show me", "Check Now", "Export CSV").
- **Disabled:** a sunken fill with faint thinned ink. It never looks pressable.

### Segmented Controls
- A sunken rounded track with a 2px inset; the selection is a raised chip with ink semibold text and the chip shadow, 26px tall. Unselected segments are thinned-ink medium.
- An optional 6px Amber Ink dot after a segment's title means "needs your answer".
- Arrow keys step through the choices; VoiceOver hears one picker.
- Used instead of the stock picker, which paints the selection in the Mac's accent colour.

### Fields and Pop-ups
- Field fill, 1px Field Edge, 7px radius, body text in ink. On focus the edge becomes Deep Moss at 1.5px over 0.12s, never the system accent.
- Pop-up buttons share the chrome, add the up-down chevron and a push-button shadow, and open a native menu. Lists of more than about five choices are pop-ups, not segmented controls.

### Switches
The stock switch at small size, tinted Deep Moss.

### Navigation
- **Tab bar:** four places in a sunken capsule: Focus, Blocked, Schedules, Stats. Each tab is an SF Symbol and a 13px semibold title, 30px tall. The selected tab is a raised chip that slides between tabs on a critically damped spring (0.32s), and just moves with Reduce Motion on.
- **Stats** holds Analytics, Insights and History. A segmented switcher under the Stats title moves between them, and the tab reopens whichever you had last. The Window menu still lists all six pages under ⌘1–⌘6.
- **Needs-answer dot:** a 6px Amber Ink dot after "Blocked" when a browser hasn't allowed guarding. It must stay visible.
- **Settings:** a 32px round gear in the top right, sunken at rest, a raised chip when selected.

### Status Corner
Where you stand, set as type. The streak figure in 13px bold, then "day streak · 1h 40m today" in thinned ink, shortening to fit beside the tabs. During focus, "Guarding" or "Strict" in Deep Moss and the countdown; during a break, "Break" in slate. Someone coming back gets "Last focus Fri · 2h 55m", never a verdict. Clicking goes to Focus.

### Focus Dial (signature)
A 264px ring: a 9px track in ink at 7%, and a round-capped Deep Moss arc (slate during a break) from twelve o'clock. Inside, the phase ("Ready · 50 / 10") in 13px semibold, then the countdown at 64px bold with tabular figures and numeric transitions. The arc moves in 0.5s linear steps and holds still with Reduce Motion on. Below, session beads: 3px capsules in Deep Moss for done, Moss for current, hairline for to come.

### Guard Row
Directly above Start: the app pile, "Guards 3 apps and 3 websites" in 13px semibold (counts, because the icons already say which), the behaviour in one line ("Guard Screen · calls keep going"), and where websites are guarded. "Manage ›" on the right. An unguarded browser adds an amber line with "Allow…". During a break the row says what is free and until when.

### Weekly Rhythm Chart
Seven slim bars on a hairline baseline against a dotted daily-goal line labelled in the right gutter. Today is Deep Moss, past days Moss at half strength, future days dashed empty slots. A bar's value sits on a canvas-coloured pill, so the goal line passes behind it instead of through it. Hovering a day raises the hover card. Analytics' "Focus over time" follows the same grammar.

### Groups and Rows (Settings)
A group is a 15px semibold heading, then rows on the canvas with hairlines between them, then a caption footnote. A row is a 13px title with an optional 12px thinned-ink description on the left, and its control (switch, pop-up, segmented control, inline button) on the right, at least 44px tall.

### Figures
A label in micro, the number in Figure, an optional caption under it. A row of figures is divided by vertical hairlines, not boxed.

### Callouts
The one tinted container: a 10px panel in amber (needs an answer), clay (something is wrong) or lichen (information), with its glyph, a headline, an optional description, and the one action that settles it. Used for browser permission and the schedules login hint.

### Menu-bar Popover
A small Focus page, 300px wide, on the system's own popover material (so the panel and its arrow are one surface), following the app's appearance setting. The phase, the countdown at 46px, a progress bar while a block runs, the guard row, one full-width action (Start focus, End session, or a plain line when strict), then Today and Streak as figures divided by a hairline, and "Open Quietwhile" / "Pin HUD" as text buttons.

### Start and Strict
- **Start focus** is the page's one filled button and answers Return, except while the goal is being typed.
- **Strict** is a chip beside the block length: sunken with an open lock, or lichen with a closed moss lock when on. It is disabled when a strict run or schedule makes the block strict anyway.
- When the next block is strict, the button reads **Start strict block**, Return does nothing, and the line under it says when the block can be ended and how long the emergency exit waits.
- While a block runs, the countdown is the loud thing: End session is secondary, Skip to break and +5 min are quiet.

### The Break
- The right column becomes the break: "Try this" and its guide, what's free and until when, then quiet "Start next block" and "End session". Nothing during a break is a filled button.
- The guide offers its own slate Start first; "Did it" appears once there is something to have done.
- The check-in is one tap: three outcomes, nothing preselected, saved on the pick.

## Do's and Don'ts

### Do:
- **Do** set everything in SF Pro, with weight and size doing the hierarchy.
- **Do** keep one canvas on every page and nothing large in pure white.
- **Do** separate with hairlines and air: full-width rules between bands, vertical rules between columns, row rules in lists and groups.
- **Do** put a setting's title and description on the left and its control on the right.
- **Do** keep one filled Deep Moss button per screen.
- **Do** use the app's controls (FLSegmentedControl, FLMenuPicker, FLSwitch, the field modifier, FLActionButtonStyle) so nothing shows up in the Mac's accent colour.
- **Do** give every colour a light and a dark value and check both, including the popover.
- **Do** say what a block guards, and that calls keep going, directly above Start.
- **Do** keep the amber needs-answer dot visible whenever a page needs the person's OK.

### Don't:
- **Don't** put content in cards or boxes. A callout that needs an answer is the only tinted container.
- **Don't** use pure white for a background, a page, or a large surface.
- **Don't** change the canvas colour per page.
- **Don't** use a serif, or uppercase-and-tracked labels, for headings.
- **Don't** underline actions; a text button is moss text, nothing more.
- **Don't** use clay, slate or amber for decoration; they mean regret, rest and needs-an-answer.
- **Don't** cut content off under the header; fade it.
- **Don't** let a strict block start on Return, or make a running block's loudest control a way out.
- **Don't** greet a returning person with zeros or a lapsed streak; lead with what they last did.
- **Don't** hide a control at opacity 0; it drops out of the accessibility tree. Use a trace of opacity, switch off hit-testing, and show it whenever it has keyboard focus.
