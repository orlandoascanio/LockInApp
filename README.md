# LockIn

LockIn is a native macOS Pomodoro/focus app. It runs as a normal app with a menu bar status item, starts focus and break sessions, guards selected distracting apps, keeps local session history, and exports that history as CSV or JSON.

The default blocking behavior is **Guard Screen**. When you open a guarded app during focus, LockIn hides the app and shows a full-screen guard overlay. The app keeps running in the background, so Discord calls, camera, microphone, and screen sharing can continue.

## MVP Scope

- Native macOS app, built with Swift, AppKit, SwiftUI, and Swift Package Manager.
- Normal Dock app plus a menu bar status item.
- Focus and break timers with `25 / 5`, `50 / 10`, and custom durations.
- Autopilot: if a finished break goes unanswered, LockIn takes the screen back, counts down, and starts the next block for you.
- Guarded app list selected from `/Applications`.
- Guard Screen, Hide Only, and explicit Quit App blocking behaviors.
- Local config, active-session recovery, and session history.
- CSV and JSON export.
- No account required.
- No internet required.

## Bring your own task streams

Open **Stream** in the sidebar to host a study/work-with-me session. Everyone
brings their own task; LockIn gives the group a shared focus/break rhythm.

1. Turn on **Host a shared session**. Set your goal, choose or add a category,
   and set focus and break durations.
2. Pick a **session type** — Read with me, Build with me, Language practice,
   Deep work — or keep Bring your own task. Presets set durations, category,
   planned blocks, and the line the audience sees; your goal is left alone.
   LockIn warns you here if you are guarding OBS, your browser, or your music
   app, and can unguard one in a click.
3. Open the **stream window** (also **Window → Stream Window**, `Cmd+2`).
   Choose the dark or light canvas and whether to show your goal.
4. In OBS, add **macOS Screen Capture**, select **Window** capture, and choose
   **LockIn Stream**. Crop the title bar if desired. Start the broadcast in OBS.
   Capture this audience window rather than the entire desktop; the host window
   contains private notes and app controls. Keep OBS and any apps needed for
   hosting out of your guarded apps list.
5. Start focus. The audience sees the countdown, your category and optional
   goal, and an invitation to work on their own task. Goal/category edits during
   a block apply to the next block, preserving the current block's history.
6. During the break, invite a chat check-in and save your own outcome: **Goal
   done**, **Made progress**, or **Got stuck**, with an optional private note.
   Notes never appear in the audience window. **Goal done** clears the goal so
   the next block starts fresh; a goal you already rewrote during the block is
   kept. History always keeps the goal each block actually ran with.
7. Shared sessions wait after the break, even if Settings uses Autopilot or
   immediate restart. Choose **Start next block** when you and chat are ready,
   or **Finish for now**. Closing the audience window does not stop the timer.

The audience window shows which block you are on out of how many planned, and
during a break it shows the clock time you will be back, not just a countdown.

### Stream appearance and motion

The Stream page offers **Off**, **Subtle**, and **Ambient** motion. Ambient is
the default: a slow background glow accompanies gentle timer, phase, and audience
transitions. Subtle keeps the background still; Off makes all updates immediate.
macOS **Reduce Motion** overrides either animated mode without changing the saved
choice. Breaks use a warmer canvas, and a thin line tracks the current phase.

The goal and chat invitation stay readable at smaller sizes. Below 820 pixels
wide, the audience moves into a compact rotating strip instead of disappearing.
The full wall crossfades between pages and briefly highlights completed tasks.

## The wall

Viewers appear on the stream by name. Type `!task read chapter 3` in chat and
that person shows up beside your countdown; `!done` checks theirs off. `!goal`,
`!doing`, `!working` and `!focus` all work too, so nobody is met with silence
for guessing. You can also add someone by hand from the Stream page.

The two commands stand on the audience window beside your countdown, so nobody
has to already know them — turn that off under **Show the chat commands on
stream** if your overlay says it elsewhere. Each person carries a small count of
how long they have been working alongside you, so a room that has been going a
while looks like one.

Finishing one does not clear it. The crossed-off line stays where it is and the
next `!task` starts a new one underneath, keeping the arrival time it came in
with, so an hour in the wall reads as an hour of work rather than a list of
whatever eight people happen to be doing this minute. The header carries the
running score for the whole stream — done over posted — which survives the wall
paging and old lines ageing off the end of a long session. Correcting a task you
have not finished yet rewrites it in place and does not move the count; a line
you take down, or one belonging to someone you block, comes back out of it.

Connect your channel on the Stream page and chat feeds the wall directly. The
connection is anonymous and read-only — no login, no API key, no Twitch
developer account, and LockIn never posts to your chat. It reconnects on its
own if the connection drops mid-stream.

New tasks wait for your approval before they appear — text you have not read
should not go out on your own broadcast. Turn on **Show tasks without asking
me first** only when chat outruns you. Anything that reads as a link is refused
outright, names and tasks are trimmed to fit, one unfinished task per person at
a time, and blocking someone takes their text off screen at once.

Words are checked against a list before anything is shown, and the check folds
spacing, punctuation, accents, repeated letters, and digits standing in for
letters, so one entry catches its variants rather than needing one line per
spelling. Names are held to the same standard, since they appear on screen too.
Two deliberate attempts — a blocked word or a link — and that person is blocked
for the rest of the stream.

When someone is waiting, the Stream tab shows a count and the menu bar shows a
dot — both silent. A sound and a notification are available and both start off,
because both can reach the broadcast: a sound goes out if OBS is capturing
desktop audio, and a banner is drawn on screen if you capture a display rather
than a window. The notification carries no viewer-written text at all, not even
a name — only how many are waiting. Arrivals are grouped, so a rush is one
interruption rather than twenty, and clearing the queue lets the next person
through immediately.

The shipped list is a starting point. Add your own terms to `blocked-words.txt`
in the LockIn support folder (**Edit list** on the Stream page opens it), one
per line. No word list is complete, and anyone determined will get past one —
approve-first is what actually protects the stream; the list is what makes
approve-first survivable when chat is busy.

## Recap

When a run finishes, the Stream page shows what it added up to — blocks, focus
time, categories, goals finished, and how many people worked alongside you —
with **Copy recap** to put it on the clipboard as plain text. It is rebuilt
from history, so quitting mid-stream does not cost you the summary.

Everyone gets their name up. Once more people are here than fit the window, the
wall turns pages on its own, fast enough that a full pass finishes inside a
focus block — at a hundred people that is roughly every twenty seconds, not a
fixed minute that would leave the last page unseen for a quarter of an hour.

A **playlist link** on the Stream page opens your music app in one click. LockIn
never plays or rebroadcasts audio, and your music app is not part of the
capture. Most commercial music is not cleared for streaming — check your
platform's rules and use a DMCA-safe library.

History includes goals, categories, and check-ins, with category filtering.
The Stream page summarizes completed focus minutes by category for this week.
CSV and JSON exports include the new fields; existing history remains readable.
Shared-session settings, categories, and the next goal are saved locally.

LockIn supplies a capture window, not broadcasting or chat services. Viewers
participate through your streaming platform's chat; they do not need LockIn.

## Not Included Yet

- No website blocking.
- No `/etc/hosts` edits.
- No Network Extension.
- No sudo or privileged helper.
- No account, login, sync, or cloud backend.
- No Electron.

## Requirements

- macOS 13 or newer
- Xcode command line tools or Xcode
- Swift Package Manager

## Build And Run

Run tests:

```bash
swift test
```

Build a real `.app` bundle:

```bash
Scripts/build_app.sh
```

Launch:

```bash
open build/LockIn.app
```

If an older copy is already running, stop it before opening the rebuilt app:

```bash
killall LockIn 2>/dev/null || true
open build/LockIn.app
```

You can also run the executable directly during development:

```bash
swift run LockIn
```

## Blocking Behavior

LockIn observes macOS app activation events. During focus, if a guarded app becomes active, LockIn reacts immediately.

- **Guard Screen**: hides the app, shows the guard overlay, and lets the app keep running in the background.
- **Hide Only**: hides the app without showing the guard overlay.
- **Quit App**: asks the app to quit. This only happens when selected explicitly.

Guarding only runs during focus. It stops during break, break-ended, idle, completed, and cancelled states.

Protected apps are never hidden or quit and cannot be added:

- Finder
- Dock
- System Settings / System Preferences
- Terminal
- loginwindow
- WindowServer
- LockIn itself

## Storage

LockIn stores all data locally in:

```text
~/Library/Application Support/LockIn/
```

Files:

- `config.json`
- `session-state.json`
- `session-history.jsonl`

Config and active session state use atomic writes. If config or active-session JSON becomes invalid, LockIn preserves a timestamped `.invalid-*` copy and recovers with safe defaults.

## Project Layout

```text
FocusLock/
├── App/
├── Core/
├── Models/
├── Resources/
├── UI/
└── Tests/
```

Core logic is in `FocusLockCore` so timer recovery, persistence, blocking validation, history, and export behavior can be tested without launching the app UI.

## Known Limitations

- Website blocking is intentionally out of scope for this MVP.
- Quit App mode uses normal app termination, not force quit.
- Session history still keeps a legacy `strictMode` export field for backward compatibility.
# LockInApp
