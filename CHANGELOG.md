# Changelog

What changed in each Quietwhile release (called LockIn up to 0.3.3). Versions come from the git tag the release is built from (`vX.Y.Z`).

## Unreleased

- A new main window. The sidebar is gone: the pages are tabs across the top, Settings is the gear in the corner, and the top right shows where you stand (the time left, or when you last focused). ⌘1–⌘5 switch pages; the Quietwhile Window item moves to ⌘0.
- Each page has its own colour, from a set of earth pigments: green for Focus, terracotta for Blocked, ochre for Schedules, umber for History, blue-grey for Analytics and plain paper for Settings. A break turns the Focus page slate.
- The Focus page now reads the way you set up a block: its length (25 / 5, 50 / 10, or Custom with the durations right there), your goal, what it guards, then Start, with a line under it saying what pressing it means. Return while typing a goal finishes the goal instead of starting the block.
- Before you start, the Focus page says what the block guards and that calls keep going ("Guards Discord · Guard Screen · apps keep running, calls keep going"). If an app you call people on is set to Quit App, the Focus and Blocked pages say that quitting ends its calls, and Quietwhile asks before you set it.
- The Blocked page explains Guard Screen, Hide Only and Quit App above the list, and each app's behaviour is a visible menu.
- Strict:
  - A Strict switch next to the block length makes just the next block strict, or not. Settings › Blocking still sets the default.
  - The button says "Start strict block", Return doesn't press it, and the line under it says when the block can be ended and how long the emergency exit waits.
  - Starting a strict block from the menu, ⌘N, the global shortcut, the menu bar, or "Start next block" asks first.
- Breaks:
  - The suggestion sits next to the timer, in slate. There is one thing to start; "Did it" appears once you have, and "Something else" swaps it.
  - It says what's yours again and until when ("Discord and 2 sites are yours until 3:40 PM").
  - Start next block and End session are quiet text instead of big buttons.
  - The check-in is one tap. A note is optional.
- Coming back after a few days off:
  - The top right says when you last focused instead of showing a lapsed streak.
  - The Focus chart shows the last 7 days ending today, so it's never blank just because a new week started.
  - History, when today has nothing yet, leads with your last day of focus instead of zeros.
- Analytics: dates sit under their own bars, the daily average counts every day in the range (the same way the Focus page does), and the sections are no longer boxed.
- Easier to read and use:
  - Warnings, errors and break text are darker in light mode, so they stay readable on every page colour.
  - Buttons you can't press yet look it.
  - With Increase Contrast on, lines and secondary text are stronger.
  - VoiceOver reads the tabs and segmented choices as pickers, can reach Remove on Blocked rows, and speaks each step of box breathing. Arrow keys move through segmented choices.
  - Reduce Motion now also covers the tab bar, the page colour changes and the break guides.
- Smaller changes: selected segments are a light chip instead of filled green; Settings switches line up on the right; cancelled blocks are no longer amber; apps that aren't installed show a plain app icon; the menu says End Session and Skip to Break like the window; and the Websites note now says plainly that Firefox can't be guarded.

## 0.3.4 (2026-10-10)

- LockIn is now called Quietwhile. Updating keeps your settings, history, schedules, permissions, widgets, Shortcuts and Focus filters. Your data is copied to `~/Library/Application Support/Quietwhile/` on first launch; the old `LockIn` folder is left untouched.
- Quietwhile plays a chime when a focus block or a break runs out. It plays from the app itself, so you still hear it with notifications off, with Do Not Disturb or another Focus mode on, or while you are in a full-screen app. Pick the sound, or turn it off, in Settings › General › When time is up (Glass by default).
- The notifications for those moments now arrive silently while the chime is on, so you don't hear two sounds at once.
- Skipping or ending something yourself doesn't play the chime.
- The "Break is done" window now opens over whatever is in front, including a full-screen app, instead of on the desktop behind it.
- A redesigned floating HUD:
  - It rests as a small pill with just the ring and the time. Hover over it to see the phase, your goal, and End session. Prefer it bigger? Choose Large.
  - It fades while you work (to 35% by default, or 60%, 20%, or not at all) and comes back on hover, when the phase changes, and for the last minute.
  - For reading, it can let clicks pass straight through to what is underneath. Hold Option to use it.
  - Drag it anywhere; it snaps to corners, edges and the middle, and it remembers where it sits on each display. It now starts in the top right, under the menu bar.
  - Breaks are slate blue, the last minute turns amber, and it pulses once at 0:00 with the chime.
  - It shows your goal instead of the guarded-apps line, and a single progress ring instead of a ring and a bar.
  - Right-click it for size, fading, click-through, moving it back to the top right, and Unpin, which no longer sits next to End session. Unpinning tells you how to pin it again. The same options are in Settings › General.
- A clearer "This week" chart on the Focus page:
  - Each day is measured against a 2-hour daily goal, shown as a dotted line, instead of against the week's best day. One day of focus no longer fills the whole chart.
  - Slim bars with rounded tops and the time above each one. A past day with no focus shows "–", and days still to come are empty slots.
  - The header shows the week's total, and how it compares with last week up to the same point, or your daily average when there is nothing to compare.
  - Days are labelled Mon, Tue, Wed…, and the week starts on the day your Mac's region settings use.
  - Hover over a day to see its sessions and every category you focused on, with the time for each.
- The Analytics "Focus over time" chart matches it:
  - Slim bars with rounded tops instead of bars as wide as the whole day.
  - Day labels sit under their bars instead of at the line between days.
  - The scale goes past the best day to the next gridline instead of ending at it, and the axis reads in hours ("1h 30m", "2h") rather than "100m".
  - Daily charts show the same dotted daily-goal line as the Focus page, and charts by week or month keep the average line.
  - Each bar shows its time when there is room.

- During a break, the HUD shows the break suggestion (such as "Stretch") instead of your goal.
- Break suggestions you do, not just read:
  - Each one is guided on the Focus page: a breathing circle that grows and shrinks for four rounds of box breathing, a 20-second ring for your eyes with a soft chime at the end, three timed stretches with progress dots, a posture checklist, a glass that fills when you've had your water, and a "Back in 4:30" countdown for a walk.
  - New: push-ups and squats, paced rep by rep. If you had every suggestion on, they're on for you too.
  - "Did it" counts it ("You stretched 4 times this week", "3 glasses today"), and so does finishing a guide. "Another one" swaps it for something you haven't seen this break.
  - Suggestions fit the break: breathing or your eyes for a short one, a walk for a long one, and something that gets you moving after three blocks in a row. The same one never comes twice in a row.
  - In Settings › Breaks, each suggestion shows its icon, with a checkmark when it's on, and you can preview any of them.
- Settings › General no longer repeats the focus and break durations, which are set on the Focus page, and the Appearance section loses its extra line of text.

### Removed

- The Integrations page, with Slack status, Discord status and Discord recaps. They took too much setup for what they gave back. Quietwhile no longer sends anything to other services; only the update check goes online. Your other settings are kept, and the recap card after a run still lets you copy the recap.

### Fixes

- Messages like "Added gmail.com." under Settings and Blocked now go away after a few seconds instead of staying until you leave the page.
- The floating HUD can be moved again. Dragging it did nothing before.
- Guarding gmail.com now also guards mail.google.com, where Gmail actually opens. Before, a gmail.com rule never matched anything. twitter.com and x.com now cover each other the same way.
- When a browser hasn't given Quietwhile its OK, the Focus page now says that websites aren't guarded there, with a link straight to the Websites tab to allow it. Before, the only signs were one notification and a badge on the Blocked page, so guarded sites could open freely without you noticing.

## 0.3.3 (2026-10-02)

- LockIn now asks before ending a session, skipping a focus block, or quitting while one is running, and says how much time is left and what History will record. The safe answer is the default; turn it off with "Don't ask again" or in Settings › General.
- Deleting a schedule and removing a Slack token or Discord webhook ask first too.
- Shortcuts and the Focus filter still end a session without a dialog.

## 0.3.2 (2026-10-02)

- The welcome guide now suggests apps to guard from how your Mac is actually used: what you open most and most recently, what is in your Dock, and what is open right now. Each suggestion says why it is there. That information stays on your Mac.
- Work tools and browsers are never suggested, and apps you have never opened are left out.
- Local builds are signed with whichever certificate the team has on this Mac.

## 0.3.1 (2026-10-02)

- A welcome guide on first launch: pick the apps and sites to guard, choose a rhythm, and start a first block. Replay it any time from Help › Welcome Guide.
- Permissions are explained before macOS asks. Notifications and browser access each get a plain description and an Allow button, in the guide and in Settings. Nothing is requested at launch any more.
- A fuller About window: version, update status, where your data lives, and links.
- Report a Problem (About and the Help menu) opens a feedback form.
- Every release now also ships an unversioned `LockIn.dmg`, so the website's download button always gets the latest version.

## 0.3.0 (2026-10-01)

The first public release.

- **Focus timer** in the menu bar: focus blocks and breaks, the countdown in the menu bar, and a floating HUD that stays above every window. Focus blocks can run up to a full day.
- **App guarding**: guarded apps are covered by a guard screen, hidden, or quit while you focus, set per app.
- **Website guarding**: guarded sites are swapped out of the current browser tab during focus.
- **Strict mode**: a block that can't be ended, skipped, or quit early, with a timed emergency exit.
- **Schedules** that start focus blocks on their own.
- **Breaks**: break suggestions, an optional eye-rest reminder during focus, and a choice of what happens when a break ends: ask, start straight away, or autopilot, which takes the screen back and counts down to the next block.
- **Goals and categories** for each block, with **History** and an **Analytics** dashboard, and data export.
- **Shortcuts actions**, a **Focus filter**, global keyboard shortcuts, and a desktop and Notification Center **widget**.
- **Integrations**: set your Slack status and show focus on Discord.
- Dark mode, a native sidebar, and tabbed Settings.
- Signed, notarized DMGs with automatic updates through Sparkle.
