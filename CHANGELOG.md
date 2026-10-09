# Changelog

What changed in each LockIn release. Versions come from the git tag the release is built from (`vX.Y.Z`).

## 0.3.4 (unreleased)

- LockIn plays a chime when a focus block or a break runs out. It plays from the app itself, so you still hear it with notifications off, with Do Not Disturb or another Focus mode on, or while you are in a full-screen app. Pick the sound, or turn it off, in Settings › General › When time is up (Glass by default).
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

### Fixes

- The floating HUD can be moved again. Dragging it did nothing before.
- Guarding gmail.com now also guards mail.google.com, where Gmail actually opens. Before, a gmail.com rule never matched anything. twitter.com and x.com now cover each other the same way.
- When a browser hasn't given LockIn its OK, the Focus page now says that websites aren't guarded there, with a link straight to the Websites tab to allow it. Before, the only signs were one notification and a badge on the Blocked page, so guarded sites could open freely without you noticing.

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
