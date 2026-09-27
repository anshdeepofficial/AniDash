# AniDash v1.15.9 - Streaming Stability Hotfix

## 🎬 Playback & Buffering
- Restored the proven long-form MPV buffering profile that was reduced in v1.15.7.
- Restored a 180-second cache window, 60-second forward readahead, 2-second underrun recovery buffer, and larger FFmpeg probe/socket buffers.
- Increased the network timeout back to 20 seconds so transient CDN or cellular/Wi-Fi jitter does not prematurely starve playback.
- Added sustained-stall recovery: if playback remains buffered without meaningful progress for 8 seconds, AniDash first tries an alternate stream, then an alternate server, while preserving the current timestamp.

## 🌐 Stream Headers & HLS Reliability
- Added case-insensitive normalization for `Referer` / `referrer`, `User-Agent`, `Origin`, and `Cookie`.
- Removed duplicate User-Agent/Referer forwarding through MPV's generic `http-header-fields` path.
- Quality options now retain the headers that belong to their own source URL instead of reusing the primary source's headers.
- HLS master playlists and their media segments now receive consistent provider headers, reducing 403/throttling/reconnect loops on protected CDNs.

## 🔄 Recovery & Resume
- Alternate-stream and alternate-server recovery now resumes from the latest stable playback position instead of falling back to the original start position.
- Quality changes re-arm the stall watchdog and preserve source-specific headers.
- Existing v1.15.8 stable-position recovery remains intact.

## 🛠️ Build Compatibility
- Pinned FlexColorScheme 8.3.1, the Flutter 3.35-compatible release, so the Android release build uses the updated AppBarThemeData and BottomAppBarThemeData APIs.

## 🧪 Validation
- Added regression tests for mixed-case/duplicate provider headers and fallback Referer generation.
- Android release build runs the stream-header regression test before producing signed split APKs.

**Version:** 1.15.9 (93)
