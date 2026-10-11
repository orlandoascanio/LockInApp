# First-use flow and local activation baseline

Quietwhile's guide has three steps: choose a distraction, prepare a block,
then review availability and start. New installs start at 25 minutes of focus
and a 5-minute break. Existing saved durations are preserved. Websites are
optional, and the preparation step asks for access only to the chosen browser.
Notifications are offered during the first running block and can be deferred;
they remain available in Settings. Startup does not request permission.

Skipping the guide preserves selections and closes it permanently, just as
before. If no active distraction is selected, Focus offers **Choose a
distraction** and **Use timer only**. Help → Welcome Guide can replay the flow.
The legacy `onboardingCompleted` config key means the guide was closed; it is
not an activation event.

## Baseline

`onboarding-progress.json` lives beside `config.json` in Quietwhile's data
folder (Settings can reveal that folder). It is local and is never uploaded.
It contains timestamps and counts, not selected app names, website domains,
goals, or a user/account identifier. `preferredBrowserBundleID` remembers the
browser choice so the guide can be resumed or replayed consistently.

| Field | Meaning |
| --- | --- |
| `cohortStartedAt` | First launch for a new install under this implementation. Absent for existing installs. |
| `guideDismissedAt` | First use of Skip setup. |
| `guideCompletedAt` | First time the summary was completed, including Look around first. |
| `firstBlockStartedAt` | First block started, independent of guide completion and protection. |
| `protectionAtFirstStart` | Enabled, installed app count; enabled site count; authorised installed browser count. Sites need at least one authorised browser. |
| `firstFullBlockCompletedAt` | First block that ran for its original planned duration, including timer-only blocks. |
| `activatedAt` | First full block completed with protection available at the last check. An interception is not required. |
| `firstInterceptionAt` | First app/site interception, recorded separately from activation. |
| `day7ReturnedAt` | First main-window/menu-control visit from 168 to less than 192 elapsed hours after cohort start. |
| `timerOnlyChosen` | Explicit timer-only choice; suppresses the empty first-use prompt. |
| `notificationsDeferred` | The contextual notification offer was deferred. |

Time to start is `firstBlockStartedAt - cohortStartedAt`. Time to activation
is `activatedAt - cohortStartedAt`. Missing events mean **not yet observed**,
not zero elapsed time. Day-7 retention is unknown until the whole observation
window has passed.

Early skips can appear as completed in the general session history; this
baseline checks the original planned duration. Cancelled and abandoned blocks
do not activate. Availability follows enabled apps/sites and browser access,
including changes during focus. Pending block data survives a relaunch and is
reconciled against session history. No browser access means selected sites
alone cannot activate.

These are availability measurements, not proof of continuous enforcement:
browser guarding covers supported browsers' frontmost tabs. A selected site
is available in an authorised browser and remains unguarded in other browsers.

The file gives a per-install baseline. Population activation rates, cohort
comparisons and retention percentages require separately collected, consented
observations; this implementation does not create that collection pipeline.
Do not infer an improvement percentage from local tests or guide completion.

## Verification

Run `swift test` for availability, migration, dismissal/completion separation,
timer-only use, full-duration activation, skip/cancel/abandonment, day-7 window,
and persistence/relaunch cases. Build the app with `Scripts/build_app.sh`.
Exercise the UI with `QUIETWHILE_DATA_DIR` set to a scratch folder. Real system
permission grants and denials require separate interactive verification.
Scratch runs also write widget snapshots inside that folder, preserving the
installed app's widget data.
