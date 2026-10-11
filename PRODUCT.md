# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos

Native macOS app, macOS 14 and later, built with Swift, SwiftUI and AppKit. The schema's values are web / ios / android / adaptive; `macos` is recorded deliberately because none of them is true.

## Users

Anyone on a Mac who wants to focus without leaving the people or things they have running. The typical situation is someone working or studying while on a Discord or FaceTime call with friends, or with music or a stream going. They want guarded apps and sites out of reach for a block of time, but closing the call or quitting apps would cost them the company they came for.

## Product Purpose

Quietwhile runs focus and break blocks from the menu bar and guards apps and websites during focus. It exists because ordinary blockers quit or kill the thing you were in, so the friends on the call are gone too. Success is someone finishing their blocks with the call still going, and coming back the next day.

## Positioning

"Your friends are on the call. Quietwhile lets you stay." Guard Screen hides a guarded app behind a full-screen "Not now." while it keeps running, so a Discord call carries on during focus. Websites are guarded without a browser extension, a hosts-file edit or a network filter. There is no account, no internet and no cloud; the only thing that goes online is the update check.

## Operating Context

- Lives in the menu bar, with a main window (Focus, Blocked, Schedules, History, Analytics, Settings), a floating HUD, a desktop and Notification Center widget, Shortcuts actions, a Focus filter, and global keyboard shortcuts (⌃⌥⌘S / E / N).
- A block runs while the person works in other apps. Quietwhile is mostly glanced at, at the start and end of blocks and on breaks, not worked in.
- Breaks offer something to actually do (box breathing, 20-20-20 for the eyes, stretches, water, a walk, push-ups), and a finished break that goes unanswered takes the screen back and starts the next block.
- Schedules start focus on their own, but only while the app is open, so it is often set to open at login.

## Capabilities and Constraints

- Guarding behaviours per app or globally: Guard Screen, Hide Only, Quit App.
- Websites are read about once a second from the frontmost supported browser over Apple Events (Safari, Chrome, Arc, Brave, Edge, Vivaldi, Opera, Chromium). Firefox cannot be covered. Each browser must be allowed once under Privacy & Security › Automation, and the app must never hide that a browser is unguarded.
- Strict mode: a block you can't end, skip, loosen or quit; a launch agent relaunches the app if it is force-quit; an emergency exit asks for a typed sentence and a wait. Breaks are never strict.
- Every permission request is preceded by an in-app explanation of why it is needed.
- Ending, skipping or quitting mid-session asks first by default, says how much time is left and what History will record, and makes the safe answer the default.
- Light and dark appearance, following macOS or the person's choice.
- Formerly called LockIn (renamed at 0.3.4). Identifiers installed copies depend on still say `lockin` and must not be renamed.
- Open decision: the paid model. It is free during the early build; a paid licence or Pro tier is planned but its shape, price and what it covers are undecided.

## Brand Commitments

- Name: Quietwhile. Tagline: "Your friends are on the call. Quietwhile lets you stay."
- Voice: plain, calm and short, writing to the person directly ("Not now.", "Break is done", "Websites aren't guarded in Chrome yet. It needs your OK first."). It explains consequences before asking for anything and never scolds.
- App icon: `docs/images/icon.png`.

## Evidence on Hand

- Product screenshots: `docs/images/focus.png`, `docs/images/focus-dark.png`, `docs/images/break.png`.
- Website and demo video at orlandoascanio.com/products/quietwhile (in the separate `Profesional-Portfolio` repo).
- Release history in `CHANGELOG.md`.
- No testimonials, user counts, reviews, press or benchmarks exist. Do not invent them.

## Product Principles

1. Stay with your people. Guarding takes the distraction out of reach, never the call, the music or the company.
2. Firm, but never sneaky. Strict mode really holds, and every limit says plainly what it does, what it costs and how to get out.
3. Out of the way while you work. The app is glanced at, not worked in; a block should need nothing from you until it ends.
4. Private by construction. No account, no cloud, no page contents or history read; only the update check goes online.
5. Breaks are real breaks. A break offers something to actually do and then hands you back to the next block.
