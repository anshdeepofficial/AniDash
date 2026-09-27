# AniDash v1.15.10 — Video Playback Fix & Reliable Background Notifications

## 🎬 Video Player & Playback Fixes
- **Instant Playback (Fixed Stuck at 94% / Black Screen)**: Removed the blocking HTTP Range speed probe which previously caused `cache-pause-initial: yes` and left the player waiting indefinitely on frame 0. Playback now begins instantly.
- **100s+ Forward Buffer (Demuxer Readahead)**: Enforced `demuxer-readahead-secs: 120` and `cache-secs: 300` with buffer memory expanded to 128 MB – 512 MB. The player aggressively buffers 100 to 120 seconds ahead of your playback position.
- **Fixed Macroblocking & Visual Artifacts**: Removed `vd-lavc-fast: yes` and `hr-seek-framedrop: yes` which were skipping dequantization and reference frames, causing severe pixelation and corrupted decoder output.
- **Automatic Server Fallback on Stall**: The stall recovery watchdog now seamlessly tries alternate servers (e.g., Momo, Vidstreaming, etc.) if all alternate stream URLs on the current server fail.

## 🔔 Background Notifications (Outside the App)
- **Fixed Background Worker Crash**: Initialized Hive adapters in the background isolate so `EpisodeReleaseTask` no longer fails when reading watch progress.
- **SharedPreferences Fast Cache**: Added persistent caching for tracked anime so the background worker can check releases without database lock issues.
- **Fixed Notification Icons on Android**: Corrected drawable resource names (`ic_notification` / `ic_notification_large`), resolving Android `DrawableResourceAndroidBitmap` lookup errors.
- **Android 12–14 Alarm Compatibility**: Added `inexactAllowWhileIdle` fallback for upcoming episode countdown notifications on devices where exact alarms are restricted.
- **WorkManager Auto-Update**: Set periodic task policy to `ExistingWorkPolicy.replace` so Android schedules background notification checks reliably after app updates.
- **24–48 Hour Catch-up Window**: Background check scans past 24–48 hours with persistent deduplication keys so no episode releases are missed during Doze mode or deep sleep.

**Version:** 1.15.10 (94)
