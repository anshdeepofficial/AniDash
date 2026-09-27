# AniDash v1.15.11 — Fixed Dub/Sub Auto-Switching & Background Notifications

## 🎙️ Fixed English DUB Playback (No More Auto-Switching to SUB)
- **Eliminated DUB Hijacking in Provider**: Fixed a critical bug in `JustAnimeProvider` where candidate endpoints (like Momo/Megaplay) without dub sources were silently returning `sub` streams, prematurely stopping the search and forcing Japanese SUB. Candidate endpoints now return null for DUB requests when dub is absent, allowing candidate endpoints (AniNeko DUB, Zoko DUB, Gigi DUB) to be queried and played.
- **Audio-Aware Endpoint Priority**: When English DUB is preferred or selected, DUB endpoints (`/anineko/dub`, `/zokoanime`, `/megaplay`, `/animegg`) are prioritized first.
- **Stall & Recovery Protection**: Automatic stall watchdog and recovery mechanisms now strictly match the active audio language (`isDub == targetDub`), preventing stall recoveries from switching the user from DUB to SUB.
- **All DUB Servers Exhaustion Check**: Before offering Japanese SUB as a last resort, AniDash now actively iterates through all available DUB servers (`Zoko`, `AniNeko`, `Momo`, `Gigi`).
- **Initial Server Matching**: When launching an episode from a cold start, AniDash now initializes the player with a server stub matching the user's `preferDub` preference instead of defaulting to a SUB server.

## 🔔 Fixed Notifications & Ended Completed Series Spam
- **No More Spam on Completed Anime**:
  - Filtered out all finished and completed anime (`isCompletedOrFinished == true` or `status == 'completed'`) from background tracking and reminders.
  - Tapping "Mark All Previous Episodes as Watched" or using batch selection now marks the series status as `'completed'` when all episodes are watched.
  - Blocked continue-watching reminders for episodes that have already been watched and completed.
- **Reliable System Notifications Outside the App**:
  - Added robust fallback mechanism (`_safeShow`) for system notifications with `@mipmap/ic_launcher` fallback in case custom drawables fail on OEM Android skins.
  - Copied small notification icon directly to `res/drawable/ic_notification.png` so Android's resource loader never fails to find it.
  - Enabled `BigTextStyleInformation` for all system notifications so release notes, episode titles, and updates expand cleanly in the Android status bar and notification tray.

**Version:** 1.15.11 (95)
