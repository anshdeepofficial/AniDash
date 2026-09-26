# AniDash v1.15.8 - Stable Playback Position Recovery, Account Sync Restoration & Notification Inbox Redesign

### ⚡ Playback Engine & Stream Recovery Fixes
- **Eliminated 2-Second Restart Loop**: Fixed an issue where duplicate `open()` calls, stream reconnects, or alternate server switches would reset playback progress back to zero (`Duration.zero`).
- **Stable Playback Position Memory**: Added `_lastStablePosition` in `PlayerStateNotifier` to preserve the user's current playback timestamp across stream buffering, quality switches, and background recoveries.
- **Enhanced Quality & Server Switching**: `changeQuality` and fallback routines now pass full `mediaId` and `episode` context to ensure stream sessions remain properly synchronized without restarting the video.
- **Smarter Stream Fallback**: In the event that a primary stream stalls, alternate source recovery now seamlessly resumes from the exact position where playback stopped.

### 🔄 Automatic Account Watch Progress Sync
- **Startup Race Condition Resolved**: Fixed a bug where initial account sync on `HomeScreen` executed before AniList/MAL authentication finished restoring asynchronously, causing watch progress not to sync on first launch.
- **Reactive Auth State Listener**: Added an active authentication listener (`_authListener`) that immediately triggers account watch progress sync as soon as credentials are ready or account status transitions.

### 📬 Redesigned Notification Inbox
- **Category-Specific Visual Badges**: Integrated color-coded icons and avatars for each notification type:
  - 🎬 **Sub Releases** (Brand Primary)
  - 🎙️ **English Dub Releases** (Deep Orange)
  - ⏳ **Upcoming Countdowns** (24h, 2h, 1h - Amber)
  - ▶️ **Continue Watching Reminders** (Tertiary)
  - 🚀 **App Updates** (Secondary)
- **Swipe to Delete**: Added smooth swipe-to-dismiss (`Dismissible`) gestures to delete individual notifications from the inbox.
- **Safe Clear All**: Added a confirmation dialog before clearing all notifications to prevent accidental data loss.
- **Polished Empty State**: Enhanced empty inbox view with thematic iconography and clear helpful descriptions.

### ⚙️ UI & Player Settings Polish
- **Next Episode Prompt Toggle**: Added a toggle for the floating "Next Episode Prompt" in the in-player settings bottom sheet.
- **Settings Sheet Layout**: Corrected ListTile spacing and layout formatting in the in-player settings sheet.
- **About Screen Updates**: Added a direct "Check for Updates" button on the About screen (`/settings/update`).
- **Header Sanitization**: Normalized User-Agent and referer headers across background tasks.
