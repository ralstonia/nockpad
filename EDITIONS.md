# Five editions, one choice at a time

## Original — Ram · v0.1.0

The first working version: terminal-inspired Pomodoro timer, optional tick and
ambient sounds, a Kanban board, and an independent jotpad. This is the baseline
Ram used and shaped. Its published ZIP and source tag are preserved.

## Return — Codex · v0.2.0

**Question:** how can the app make returning from an interruption less difficult?

A persistent breadcrumb panel sits above the timer. Type an optional next concrete
step; it saves as you type. When focus stops, Return remembers the task context and
stop time and brings you to the timer pane. A five-minute focus offers a smaller
starting commitment. Breadcrumbs are kept separately for each task (and unassigned focus), and survive restarting the app. There are no mandatory
prompts or inferred reasons for interruptions.

A short focus records its own planned duration. It does not earn a full pomodoro
unless it reaches the configured focus duration, and it does not force a long break.

## Quiet — Codex · v0.3.0

**Question:** what is the least an app needs to help someone begin?

The timer workspace becomes a single persistent intention, start/pause/reset, and
15/25/45-minute presets. Its large countdown is hidden until requested. Tick, ambient
audio, completion sound, phase notifications, and foreground jumps are off by default;
users can opt in through Settings. The menu bar and footer still provide time, and
Board/Jotpad stay available. There is no score or dashboard on the focus stage.

## Fieldnotes — Codex · v0.4.0

**Question:** can notes become the front door to focused work?

Fieldnotes opens on the jotpad. Today's Page opens or creates one date-linked page
with prompts for thoughts, working notes, and next steps. Reopening a daily page
preserves its contents. Append Timestamp adds a local-time marker at the end of the
selected note. Export Markdown writes a plain-text `.md` file through the system
save dialog. Ordinary notes, search, copy, and automatic local saving remain available.

This is plain text, not a Markdown renderer. Export has to be chosen explicitly;
there is no access to a user's documents folder in the background.

## Rhythm — Codex · v0.5.0

**Question:** can a person notice their working patterns without being graded?

Rhythm opens on a session dashboard. It shows completed focus sessions and their
planned minutes for today and the last seven local calendar days. Skipped sessions,
breaks, future timestamps, and other-day sessions are excluded from today's totals.
The user chooses a daily session target and can leave a separate, optional reflection
for each day. A ten-minute focus offers a small next session. Recent session history
shows both completed and skipped phases explicitly.

No productivity score, streak penalty, activity monitoring, or claim that timer time
measures useful output. Short focus time is recorded as short focus time.

## Packaging and data boundaries

All editions are native macOS apps, ad-hoc signed and unnotarized previews. Each
uses an independent sandbox bundle identity:

| Edition | Bundle ID |
| --- | --- |
| Original | `app.nockpad.mac` |
| Return | `app.nockpad.mac.return` |
| Quiet | `app.nockpad.mac.quiet` |
| Fieldnotes | `app.nockpad.mac.fieldnotes` |
| Rhythm | `app.nockpad.mac.rhythm` |

They can coexist and do not silently share or migrate data. The private personal
FocusBoard app remains separate. The four experimental release tags share a source
commit; `scripts/package.sh <edition>` selects the edition, product name, bundle ID,
and version at build time. First-party behavior checks and universal builds are
included; the new screens and export dialog still need broader interactive testing.
