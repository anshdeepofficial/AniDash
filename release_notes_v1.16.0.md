# AniDash v1.16.0

## Playback reliability

- Removed competing stall-recovery loops that could reopen a stream, jump back after the intro, or corrupt visible frames.
- Added balanced MPV buffering and same-stream reconnection for smoother playback on fast and weak connections.
- Preserved the selected episode position and English Dub preference during temporary network stalls.
- Prevented silent English Dub to Japanese Sub switching.
- Fixed quality-specific stream headers and late stream-open false failures.
- Replaced simulated loading percentages with one honest indeterminate loader.
- Fixed the full progress bar and `-00:00` display before the real duration is known.

## Continue Watching

- Recently played anime now remain first after app restarts.
- Ongoing shows are no longer incorrectly treated as completed from partial provider episode counts.
- Reopening a dismissed title restores it to Continue Watching.

## Notifications

- News, English Dub, Japanese Sub, Continue Watching, and Download notification switches are independently enforced.
- Release alerts now strictly follow the selected playback audio preference.
- English Dub users receive only English Dub release alerts; Japanese/Sub users receive only Japanese Sub alerts.
- Release reminders are restricted to watched or tracked anime.
- Fixed the Android background worker being reset whenever the app opened.
- Improved background plugin registration and app lifecycle state tracking.
- Fixed the notification status-bar icon fallback.

## Internal quality

- Added safer source matching and watch-progress persistence behavior.
- Completed static analysis with no issues.
- All 48 unit tests pass.
